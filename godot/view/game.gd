extends Node2D
# game.gd — 消除 Core 表现层（v2：目标关 / 果冻 / 冰锁 / 墙 / 特效）。
# 只跟 board.gd 打交道：读 grid/fx/jelly/coat/objectives/collected/score/moves_left，调 try_swap。
# 操作：点一个道具再点相邻道具 → 交换（滑动动画）。R 在多个 demo 关之间切换并重开。

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const CelestialBg := preload("res://ui/celestial_bg.gd")
const Burst := preload("res://ui/burst.gd")

var W := 9    # 关卡维度(载入后由 board 同步)；默认 9×9，对齐 Candy Crush
var H := 9
const SPECIES := [0, 1, 2, 3, 4]
const CELL := 72.0   # 9 列正好填满画布宽(9*72+8*6=696)；行数随关卡变(可竖长)
const GAP := 6.0
const VIEW_W := 720.0
const VIEW_H := 1520.0
var ORIGIN := Vector2(12.0, 200.0)   # 按关卡维度在 _relayout 里算(居中)
const TARGET := 2000
const MOVES := 25

# 6 种道具：颜色 + 形状符号双重区分（呼应 06：小尺寸靠形状不只靠色）。第6色=橙，补齐 CC 红橙黄绿蓝紫
var COLORS := [Color("e74c3c"), Color("f5b301"), Color("27ae60"), Color("2e86de"), Color("8e44ad"), Color("e67e22")]
# 引擎 species 0-5 → pieces.json species id（红药水/金星杖/绿魔法球/蓝符文板/紫魔烛/第6色暖橙符纸）
# TODO(美术): 第6色(id7 paper_talisman)为临时占位,待重渲定稿后改此 id + COLORS[5] 配色;勿用 id8(粉蘑菇,撞粉)
const PIECE_SPECIES := [1, 3, 9, 6, 2, 7]
var piece_tex := []          # piece_tex[0-5] = {SP_NONE:基础, SP_LINE_H:横炸, SP_LINE_V:竖炸}
var colorbomb_tex: Texture2D
const SYMBOLS := ["●", "▲", "■", "◆", "✶", "⬢"]
# 特效标记：SP_NONE/LINE_H/LINE_V/BOMB/COLORBOMB
const FX_GLYPH := ["", "▬", "▮", "✸", "◎"]

var board: Board
var cur_seed := 12345
var demo_idx := 0        # 当前关索引（按 R 递进）
var algo_levels: Array = []   # 算法生成的关卡库（res://levels.json，C++ 导出）；非空则优先玩它
var equipped_skill: String = ""   # 本局所带技能 id（角色 id 归一）
var loadout: Dictionary = {}       # Meta 喂参（技能+铭文：步数/倍率/开局特效）；空则只按 equipped_skill
signal game_over(result)           # 对局结束(过关/失败)→ app 弹结算屏
var _over_fired := false           # 本局是否已发过 game_over(只发一次)
var _skill_aim: String = ""       # 技能瞄准模式: ""/"borrow"/"repay"/"sametypeclear"
var skill_button: Button
var tiles := []          # tiles[y][x] -> ColorRect（道具底色块）
var labels := []         # labels[y][x] -> Label（道具符号/特效标记）
var jelly_rects := []    # jelly_rects[y][x] -> ColorRect（果冻底层标记）
var coat_rects := []     # coat_rects[y][x] -> ColorRect（冰锁遮罩）
var coat_labels := []    # coat_labels[y][x] -> Label（冰锁层数指示）
var choco_rects := []    # choco_rects[y][x] -> ColorRect（巧克力占位：棕色半透明遮罩，无美术图依赖）
var ingredient_rects := []  # ingredient_rects[y][x] -> ColorRect（运料占位：樱桃红实心块，无美术图依赖）
var cannon_rects := []   # cannon_rects[y][x] -> ColorRect（糖果炮占位：深色炮台 + 向下箭头子节点，无美术图依赖）
var bomb_labels := []    # bomb_labels[y][x] -> Label（炸弹倒计时：红色数字叠在棋子上，醒目显示剩余步数）
var popcorn_rects := []  # popcorn_rects[y][x] -> ColorRect（爆米花占位：黄白半透明遮罩盖住整格，无美术图依赖）
var popcorn_labels := [] # popcorn_labels[y][x] -> Label（爆米花剩余命中数：深色数字，砸到 0 变彩球）
var exit_rects := []     # exit_rects[i] -> ColorRect（底部出口标记：原料落到此被收集，独立于格网格）
var piece_rects := []    # piece_rects[y][x] -> TextureRect（宝石立绘：基础/横炸/竖炸/彩球）
var burst_rects := []    # burst_rects[y][x] -> Burst（爆炸形态的放射能量光环，仅 SP_BOMB 显示）
var selected := Vector2i(-1, -1)
var input_locked := false

var title_label: Label
var score_label: Label
var moves_label: Label
var status_label: Label
var hint_label: Label
var sel_frame: ColorRect
var _bg                  # CelestialBg(背景+魔法阵)，按维度更新圆心/半径
var _frame: Panel        # 棋盘奶白软底框，按维度更新位置/大小


func _ready() -> void:
	_load_pieces()
	_build_hud()
	algo_levels = LevelLibrary.load_file("res://levels.json")   # 优先读 C++ 导出的算法关卡库
	_new_game()


# 轮询对局结束(覆盖交换/技能/死局等所有结束来源)，发一次 game_over 给 app。
func _process(_dt: float) -> void:
	if not _over_fired and not input_locked and board != null and board.is_over():
		_over_fired = true   # 动画期间(input_locked)推迟，避免结算屏中途 free 掉正在动画的节点
		emit_signal("game_over", board.result())


# ───────────────────────────── Demo 关定义 ─────────────────────────────
# 每个 demo 关返回构造 Board 所需的全部参数（按需带 objs/jelly/coat/mask）。
# 关卡轮播：纯分数关[现状] → COLLECT → CLEAR_JELLY → CLEAR_BLOCKER → 运料 → 拆弹 → 糖果炮 → 爆米花。
const DEMO_COUNT := 8

func _demo_level(idx: int) -> Dictionary:
	match idx:
		1:
			# COLLECT 关：收集红色(species 0) 与 蓝色(species 3)，叠加异形墙。
			return {
				"name": "Demo 2/8 · 收集关 (COLLECT) + 墙",
				"target": 0,
				"moves": 30,
				"mask": _demo_wall_mask(),
				"objs": [
					{"type": "COLLECT", "species": 0, "target": 12},
					{"type": "COLLECT", "species": 3, "target": 12},
				],
				"jelly": [],
				"coat": [],
				"ing": [],
				"exits": [],
			}
		2:
			# CLEAR_JELLY 关：中心 4x4 果冻（内 2x2 双层），清掉 18 层。
			return {
				"name": "Demo 3/8 · 果冻关 (CLEAR_JELLY)",
				"target": 0,
				"moves": 30,
				"mask": [],
				"objs": [{"type": "CLEAR_JELLY", "species": -1, "target": 18}],
				"jelly": _demo_jelly_layer(),
				"coat": [],
				"ing": [],
				"exits": [],
			}
		3:
			# CLEAR_BLOCKER 关：边框一圈单层冰锁，解锁 12 个；叠加少量墙。
			return {
				"name": "Demo 4/8 · 冰锁关 (CLEAR_BLOCKER) + 墙",
				"target": 0,
				"moves": 35,
				"mask": _demo_corner_mask(),
				"objs": [{"type": "CLEAR_BLOCKER", "species": -1, "target": 12}],
				"jelly": [],
				"coat": _demo_coat_layer(),
				"ing": [],
				"exits": [],
			}
		4:
			# COLLECT_INGREDIENT 关：顶部几颗原料下落，落到底部出口被收集（运料关，对标 CC 三大关型）。
			return {
				"name": "Demo 5/8 · 运料关 (COLLECT_INGREDIENT)",
				"target": 0,
				"moves": 40,
				"mask": [],
				"objs": [{"type": "COLLECT_INGREDIENT", "species": -1, "target": 4}],
				"jelly": [],
				"coat": [],
				"ing": _demo_ingredient_layer(),
				"exits": [],   # 空 = 整最底行皆出口
				"bomb": [],
			}
		5:
			# DEFUSE_BOMB 关：盘上几颗倒计时炸弹，限步内消除拆够 N 个过关；任一炸弹归零即引爆判负（紧迫感）。
			return {
				"name": "Demo 6/8 · 拆弹关 (DEFUSE_BOMB)",
				"target": 0,
				"moves": 40,
				"mask": [],
				"objs": [{"type": "DEFUSE_BOMB", "species": -1, "target": 4}],
				"jelly": [],
				"coat": [],
				"ing": [],
				"exits": [],
				"bomb": _demo_bomb_layer(),
			}
		6:
			# 糖果炮关 (Candy Cannon)：顶行两门炮——产原料炮源源供原料 + 产普通糖炮持续补给盘面。
			# 与运料关协同：炮口(复用 WALL，不可消不可动)每有效步从下方产原料，玩家把它运到底部出口，收够 N 过关。
			return {
				"name": "Demo 7/8 · 糖果炮关 (Candy Cannon + 运料)",
				"target": 0,
				"moves": 45,
				"mask": [],
				"objs": [{"type": "COLLECT_INGREDIENT", "species": -1, "target": 6}],
				"jelly": [],
				"coat": [],
				"ing": _blank_layer(),   # 初始无散落原料：原料全部由炮产出（演示"持续供给"）
				"exits": [],   # 空 = 整最底行皆出口
				"bomb": [],
				"cannon": _demo_cannon_layer(),
			}
		7:
			# POP_POPCORN 关 (Popcorn)：盘中几颗爆米花——用条纹/爆炸/彩球砸够 N 次变彩球。
			# 爆米花格不可消不可换、随重力下落；普通三消不碰它，只特效命中-1，归0当场变一枚色彩炸弹给玩家用。
			return {
				"name": "Demo 8/8 · 爆米花关 (POP_POPCORN)",
				"target": 0,
				"moves": 40,
				"mask": [],
				"objs": [{"type": "POP_POPCORN", "species": -1, "target": 3}],
				"jelly": [],
				"coat": [],
				"ing": [],
				"exits": [],
				"bomb": [],
				"cannon": [],
				"popcorn": _demo_popcorn_layer(),
			}
		_:
			# 纯分数关[现状]：异形墙 + 分数目标（objectives 为空 → 走旧式分数判定）。
			return {
				"name": "Demo 1/8 · 分数关 (SCORE) + 墙",
				"target": TARGET,
				"moves": MOVES,
				"mask": _demo_wall_mask(),
				"objs": [],
				"jelly": [],
				"coat": [],
				"ing": [],
				"exits": [],
			}


# 滚动挖矿 demo：可见 1 页(8x8) + 每列 3 页深的预设 feed（v1 纯随机长盘）。挖穿 feed=通关。
func _make_scroll_demo() -> Board:
	var b := Board.new(W, H, SPECIES, 999999, 60, cur_seed)
	b.is_scrolling = true
	var rng := RandomNumberGenerator.new()
	rng.seed = cur_seed + 777
	var fd := []
	for x in W:
		var col := []
		for i in (3 * H):   # 下方 3 页的深层内容
			col.append(SPECIES[rng.randi() % SPECIES.size()])
		fd.append(col)
	b.feed = fd
	return b

func _new_game() -> void:
	if not algo_levels.is_empty():
		if demo_idx >= algo_levels.size():
			board = _make_scroll_demo()
			title_label.text = "滚动挖矿关 · 长盘 feed 下流，挖穿通关"
		else:
			var i: int = demo_idx % algo_levels.size()
			var ld: Dictionary = algo_levels[i]
			board = LevelLibrary.to_board(ld)
			title_label.text = "算法关 %d/%d · %s" % [i + 1, algo_levels.size(), String(ld.get("difficulty", "?"))]
	else:
		var lvl := _demo_level(demo_idx)
		board = Board.new(W, H, SPECIES, lvl["target"], lvl["moves"], cur_seed,
				lvl["mask"], lvl["objs"], lvl["jelly"], lvl["coat"], [], lvl.get("ing", []), lvl.get("exits", []), lvl.get("bomb", []), lvl.get("cannon", []), lvl.get("popcorn", []))
		title_label.text = lvl["name"]
	if not loadout.is_empty():
		board.apply_loadout(loadout)
		board.skill = SKILL_ID.get(board.skill, board.skill)   # 角色 id → 技能 id 归一
		equipped_skill = board.skill                           # 同步给技能按钮逻辑
	else:
		board.skill = equipped_skill
	_skill_aim = ""
	selected = Vector2i(-1, -1)
	input_locked = false
	_over_fired = false
	W = board.width                  # 关卡维度可变(默认 9×9，可竖长)，由 board 同步
	H = board.height
	_rebuild_tiles()                 # 按本关维度(重)建网格
	_relayout()                      # 居中 + 更新框/圆环/技能条/提示位置
	_render()
	_update_skill_button()


# 全 false 的 H×W 掩码模板。
func _blank_mask() -> Array:
	var m := []
	for y in H:
		var row := []
		for x in W:
			row.append(false)
		m.append(row)
	return m

# 演示用异形棋盘：切 4 角 + 中心 2x2 柱。
func _demo_wall_mask() -> Array:
	var m := _blank_mask()
	for c in [Vector2i(0, 0), Vector2i(W - 1, 0), Vector2i(0, H - 1), Vector2i(W - 1, H - 1),
			Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)]:
		m[c.y][c.x] = true
	return m

# 仅切 4 角的轻量墙（冰锁关用，避免墙太多挤占冰锁空间）。
func _demo_corner_mask() -> Array:
	var m := _blank_mask()
	for c in [Vector2i(0, 0), Vector2i(W - 1, 0), Vector2i(0, H - 1), Vector2i(W - 1, H - 1)]:
		m[c.y][c.x] = true
	return m

# 全 0 的 H×W 整型层模板（jelly/coat 共用）。
func _blank_layer() -> Array:
	var m := []
	for y in H:
		var row := []
		for x in W:
			row.append(0)
		m.append(row)
	return m

# 中心 4x4 区域果冻：外圈 1 层、内 2x2 叠 2 层（演示多层叠深）。
func _demo_jelly_layer() -> Array:
	var j := _blank_layer()
	for y in range(2, 6):
		for x in range(2, 6):
			j[y][x] = 1
	for y in range(3, 5):
		for x in range(3, 5):
			j[y][x] = 2
	return j

# 边框一圈单层冰锁（避开会成为墙的 4 角），内部点缀一颗双层锁演示层数。
func _demo_coat_layer() -> Array:
	var c := _blank_layer()
	for x in W:
		c[0][x] = 1
		c[H - 1][x] = 1
	for y in H:
		c[y][0] = 1
		c[y][W - 1] = 1
	for corner in [Vector2i(0, 0), Vector2i(W - 1, 0), Vector2i(0, H - 1), Vector2i(W - 1, H - 1)]:
		c[corner.y][corner.x] = 0  # 角是墙，不放锁
	c[2][2] = 2
	return c

# 运料关：顶行点几颗原料（分布在不同列），靠下落+消除让它们沉到底部出口被收。
func _demo_ingredient_layer() -> Array:
	var g := _blank_layer()
	for x in [1, 3, 5, 7]:   # 顶行 4 颗原料，对应目标 target=4（整最底行为出口）
		g[0][x] = 1
	return g

# 拆弹关：盘中散布几颗倒计时炸弹（炸弹格 grid 仍是普通棋子，bomb 是叠加倒计时）。
# 给较宽裕步数(12-15)，玩家须在归零前消除该格拆弹；任一归零即引爆判负。target=4 拆够即过关。
func _demo_bomb_layer() -> Array:
	var g := _blank_layer()
	var spots := [Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(6, 6), Vector2i(4, 4)]
	var counts := [12, 13, 14, 15, 12]
	for i in spots.size():
		var p: Vector2i = spots[i]
		if p.y < H and p.x < W:
			g[p.y][p.x] = counts[i]
	return g

# 糖果炮关：顶行两门炮（炮口复用 WALL，不可消不可动）。一门产原料(=2)供运料目标，一门产普通糖(=1)持续补给。
# cannon[y][x]：0 无炮 / 1 产普通糖 / 2 产原料。每有效步从炮口正下方空格产出，源源不断供给盘面。
func _demo_cannon_layer() -> Array:
	var g := _blank_layer()
	var ing_spots := [Vector2i(2, 0), Vector2i(6, 0)]   # 顶行两门产原料炮（运料目标靠它喂）
	var candy_spots := [Vector2i(4, 0)]                  # 顶行一门产普通糖炮（持续补给消除资源）
	for p in ing_spots:
		if p.y < H and p.x < W:
			g[p.y][p.x] = 2
	for p in candy_spots:
		if p.y < H and p.x < W:
			g[p.y][p.x] = 1
	return g

# 爆米花关：盘中散布几颗爆米花（popcorn[y][x]=N=被特效砸 N 次变彩球；爆米花格 grid 是普通棋子占位）。
# 玩家用条纹/爆炸/彩球砸爆米花换彩球——"用特效砸爆米花换彩球"的策略维度。target=3 砸够 3 次过关。
func _demo_popcorn_layer() -> Array:
	var g := _blank_layer()
	var spots := [Vector2i(2, 3), Vector2i(5, 4), Vector2i(3, 5)]   # 三颗爆米花，错落在场中
	var counts := [2, 3, 2]                                          # 各需 2/3/2 次特效命中
	for i in spots.size():
		var p: Vector2i = spots[i]
		if p.y < H and p.x < W:
			g[p.y][p.x] = counts[i]
	return g


# ───────────────────────────── HUD / 节点构建 ─────────────────────────────
func _build_hud() -> void:
	# 占星浅蓝背景(几何在 _relayout 按维度设)
	_bg = CelestialBg.new()
	_bg.light_mode = true          # 浅蓝通透星空(对齐 board.png)
	_bg.show_circle = true
	_bg.inner_ring = false         # 对局大阵：金环在棋盘外侧
	_bg.planets = true
	_bg.z_index = -10
	add_child(_bg)
	# 棋盘奶白软底框(几何在 _relayout 设)
	_frame = Panel.new()
	_frame.z_index = -5
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.42, 0.64, 1.0, 0.09)   # 淡蓝软底(饱和蓝,高透明)
	fs.set_corner_radius_all(30)
	fs.set_border_width_all(2)
	fs.border_color = Color("e9c97c")
	fs.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	fs.shadow_size = 18
	_frame.add_theme_stylebox_override("panel", fs)
	add_child(_frame)
	# 选中高亮框
	sel_frame = ColorRect.new()
	sel_frame.color = Color(1, 1, 1, 0.28)
	sel_frame.size = Vector2(CELL, CELL)
	sel_frame.visible = false
	sel_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_frame.z_index = 5
	add_child(sel_frame)
	# 顶部 HUD 状态条
	title_label = _mk_label(Vector2(40, 44), 24)
	title_label.add_theme_color_override("font_color", Color("6e5520"))   # 浅底用深金
	score_label = _mk_label(Vector2(40, 86), 28)
	score_label.add_theme_color_override("font_color", Color("1e2c4e"))   # 浅底用深蓝
	moves_label = _mk_label(Vector2(40, 130), 26)
	moves_label.add_theme_color_override("font_color", Color("2c3a60"))
	status_label = _mk_label(Vector2(500, 86), 32)
	status_label.add_theme_color_override("font_color", Color("17744a"))
	hint_label = _mk_label(Vector2(19, 1112), 18)
	hint_label.add_theme_color_override("font_color", Color(0.16, 0.24, 0.42, 0.78))
	hint_label.text = "点一个道具，再点相邻道具交换 · 按 R 切换关卡"
	skill_button = Button.new()
	skill_button.z_index = 50
	skill_button.add_theme_font_size_override("font_size", 22)
	skill_button.pressed.connect(_use_skill)
	skill_button.visible = false
	add_child(skill_button)


# 按当前 W/H 居中布局：算 ORIGIN + 更新背景圆环/框/技能条/提示位置。
func _relayout() -> void:
	var bw := W * CELL + (W - 1) * GAP
	var bh := H * CELL + (H - 1) * GAP
	var area_top := 168.0
	var area_bot := 1402.0
	ORIGIN = Vector2((VIEW_W - bw) * 0.5, maxf(area_top, area_top + (area_bot - area_top - bh) * 0.5))
	var bc := ORIGIN + Vector2(bw, bh) * 0.5
	_bg.circle_center = bc
	_bg.glow_center = bc
	_bg.circle_radius = bw * 0.5 + 38.0   # 贴棋盘外缘
	_bg.queue_redraw()
	_frame.position = Vector2(ORIGIN.x - 16, ORIGIN.y - 16)
	_frame.size = Vector2(bw + 32, bh + 32)
	skill_button.position = Vector2(ORIGIN.x, ORIGIN.y - 52)   # 棋盘正上方
	skill_button.size = Vector2(bw, 42)
	hint_label.position = Vector2(ORIGIN.x, ORIGIN.y + bh + 16)


func _mk_label(pos: Vector2, fsize: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _rebuild_tiles() -> void:
	# 释放旧网格(切到不同维度的关卡时)，再按当前 W/H 重建
	for arr in [tiles, labels, jelly_rects, coat_rects, coat_labels, choco_rects, ingredient_rects, cannon_rects, bomb_labels, popcorn_rects, popcorn_labels, piece_rects, burst_rects]:
		for row in arr:
			for n in row:
				n.queue_free()
	for n in exit_rects:   # 出口标记是一维数组（底行各列一个），单独释放
		n.queue_free()
	tiles.clear()
	labels.clear()
	jelly_rects.clear()
	coat_rects.clear()
	coat_labels.clear()
	choco_rects.clear()
	ingredient_rects.clear()
	cannon_rects.clear()
	bomb_labels.clear()
	popcorn_rects.clear()
	popcorn_labels.clear()
	exit_rects.clear()
	piece_rects.clear()
	burst_rects.clear()
	tiles.resize(H)
	labels.resize(H)
	jelly_rects.resize(H)
	coat_rects.resize(H)
	coat_labels.resize(H)
	choco_rects.resize(H)
	ingredient_rects.resize(H)
	cannon_rects.resize(H)
	bomb_labels.resize(H)
	popcorn_rects.resize(H)
	popcorn_labels.resize(H)
	piece_rects.resize(H)
	burst_rects.resize(H)
	for y in H:
		tiles[y] = []
		labels[y] = []
		jelly_rects[y] = []
		coat_rects[y] = []
		coat_labels[y] = []
		choco_rects[y] = []
		ingredient_rects[y] = []
		cannon_rects[y] = []
		bomb_labels[y] = []
		popcorn_rects[y] = []
		popcorn_labels[y] = []
		piece_rects[y] = []
		burst_rects[y] = []
		for x in W:
			# 果冻底层标记（z 在道具之下，作"底色"露在道具缝隙/边缘外）。
			var jr := ColorRect.new()
			jr.size = Vector2(CELL, CELL)
			jr.visible = false
			jr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			jr.z_index = -2
			add_child(jr)
			jelly_rects[y].append(jr)

			var rect := ColorRect.new()
			rect.size = Vector2(CELL, CELL)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(rect)
			tiles[y].append(rect)

			# 宝石立绘(基础/横/竖/彩球)，叠在底色块上、符号/冰锁之下
			var pr := TextureRect.new()
			pr.size = Vector2(CELL + GAP + 4, CELL + GAP + 4)   # 裁边后立绘已贴满，尺寸≈格距+略overlap→棋子真正挨着
			pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(pr)
			piece_rects[y].append(pr)

			# 爆炸形态光环：叠在宝石之下(z=-1)，仅 SP_BOMB 显示
			var bu := Burst.new()
			bu.size = Vector2(CELL + 22, CELL + 22)
			bu.z_index = -1
			bu.visible = false
			bu.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(bu)
			burst_rects[y].append(bu)

			var lab := Label.new()
			lab.size = Vector2(CELL, CELL)
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lab.add_theme_font_size_override("font_size", 36)
			lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lab.z_index = 1
			add_child(lab)
			labels[y].append(lab)

			# 冰锁遮罩：冷色半透明填充，叠在道具之上（暗示"冻住"）。
			var cr := ColorRect.new()
			cr.size = Vector2(CELL, CELL)
			cr.color = Color(0.78, 0.90, 1.0, 0.22)
			cr.visible = false
			cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cr.z_index = 2
			add_child(cr)
			coat_rects[y].append(cr)

			# 冰锁层数指示：锁图标(单层)/层数(多层)，叠在遮罩之上。
			var clab := Label.new()
			clab.size = Vector2(CELL, CELL)
			clab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			clab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			clab.add_theme_font_size_override("font_size", 30)
			clab.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 0.95))
			clab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			clab.z_index = 3
			clab.visible = false
			add_child(clab)
			coat_labels[y].append(clab)

			# 巧克力占位：棕色半透明遮罩盖住整格（代码占位，不依赖任何美术图）。
			var choc := ColorRect.new()
			choc.size = Vector2(CELL, CELL)
			choc.color = Color(0.36, 0.20, 0.09, 0.72)   # 棕色半透明（巧克力色）
			choc.visible = false
			choc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			choc.z_index = 4   # 叠在道具/冰锁之上，暗示"被巧克力覆盖、不可动"
			add_child(choc)
			choco_rects[y].append(choc)

			# 运料占位：樱桃红实心块（略缩小内嵌，像一颗"待运下落物"坐在格上；代码占位无美术图依赖）。
			var ingr := ColorRect.new()
			ingr.size = Vector2(CELL - 16, CELL - 16)
			ingr.color = Color(0.86, 0.12, 0.22, 0.95)   # 樱桃红（与巧克力棕、冰锁蓝区分）
			ingr.visible = false
			ingr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ingr.z_index = 5   # 叠在道具/冰锁/巧克力之上，醒目表示"原料在此、随重力下落"
			add_child(ingr)
			ingredient_rects[y].append(ingr)

			# 炸弹倒计时：红色粗体数字叠在棋子上（剩余步数）。炸弹格 grid 是普通棋子(照常渲染立绘)，
			# 此 Label 只额外叠一个倒计时数字——醒目、独立，不碰 piece_tex/颜色/其他层。
			var blab := Label.new()
			blab.size = Vector2(CELL, CELL)
			blab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			blab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			blab.add_theme_font_size_override("font_size", 40)
			blab.add_theme_color_override("font_color", Color(1.0, 0.12, 0.08, 1.0))   # 醒目红
			blab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))   # 黑描边保证棋子上可读
			blab.add_theme_constant_override("outline_size", 6)
			blab.visible = false
			blab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			blab.z_index = 7   # 最高层：压住所有占位/遮罩，倒计时永远可见
			add_child(blab)
			bomb_labels[y].append(blab)

			# 爆米花占位：黄白半透明遮罩盖住整格（像一块爆米花坐在格上；代码占位，无任何美术图依赖）。
			# 仿 coat 双节点结构：遮罩(ColorRect) + 剩余命中数(Label)。砸到 0 时由 _render_cell 隐藏 → 露出底下变出的彩球立绘。
			var pop := ColorRect.new()
			pop.size = Vector2(CELL, CELL)
			pop.color = Color(0.99, 0.93, 0.62, 0.78)   # 黄白爆米花色（与巧克力棕、原料樱桃红、冰锁蓝区分）
			pop.visible = false
			pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pop.z_index = 4   # 与巧克力/炮台同层级：盖在道具/冰锁之上，暗示"被爆米花覆盖、不可消不可换"
			add_child(pop)
			popcorn_rects[y].append(pop)

			# 爆米花剩余命中数：深色粗体数字叠在遮罩上（还需几次特效命中才变彩球）。
			var plab := Label.new()
			plab.size = Vector2(CELL, CELL)
			plab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plab.add_theme_font_size_override("font_size", 30)
			plab.add_theme_color_override("font_color", Color(0.45, 0.30, 0.05, 0.98))   # 深棕数字（黄白遮罩上可读）
			plab.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
			plab.add_theme_constant_override("outline_size", 4)
			plab.visible = false
			plab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plab.z_index = 5   # 数字压在爆米花遮罩之上
			add_child(plab)
			popcorn_labels[y].append(plab)

			# 糖果炮占位：深色炮台块盖住整格(炮口=WALL，本就暗格) + 向下箭头子节点暗示"从此向下产棋子"。
			# 炮台色按产出类型微调(普通糖=钢灰、原料=暗樱桃)，箭头始终向下。代码占位，无任何美术图依赖。
			var cann := ColorRect.new()
			cann.size = Vector2(CELL, CELL)
			cann.color = Color(0.16, 0.18, 0.24, 0.95)   # 深炮台色（盖在暗墙格上，凸显"这是炮不是普通墙"）
			cann.visible = false
			cann.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cann.z_index = 4   # 叠在墙底色之上、与巧克力同层级，醒目标识炮口
			add_child(cann)
			var carrow := Label.new()
			carrow.text = "▼"
			carrow.size = Vector2(CELL, CELL)
			carrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			carrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			carrow.add_theme_font_size_override("font_size", 34)
			carrow.add_theme_color_override("font_color", Color(0.96, 0.86, 0.40, 0.98))   # 暖金箭头（炮口产出方向）
			carrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cann.add_child(carrow)   # 箭头随炮台一起定位/显隐
			cannon_rects[y].append(cann)

	# 出口标记：仅运料关（board 有 ing 层）才建——底部出口列各一条金色色条 + 下箭头，提示"原料落此被收"。
	if board != null and not board.ing.is_empty():
		for cx in board.exit_cols:
			var ex := ColorRect.new()
			ex.size = Vector2(CELL, 10)
			ex.color = Color(0.96, 0.80, 0.30, 0.95)   # 金色出口条（与樱桃红原料呼应"运到这"）
			ex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ex.z_index = 6
			ex.set_meta("col", cx)   # 记住所属列，渲染时按列定位到底行下方
			add_child(ex)
			var arrow := Label.new()
			arrow.text = "▼"
			arrow.add_theme_font_size_override("font_size", 22)
			arrow.add_theme_color_override("font_color", Color(0.96, 0.80, 0.30, 0.95))
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arrow.z_index = 6
			ex.add_child(arrow)
			arrow.position = Vector2(CELL * 0.5 - 11, -28)
			exit_rects.append(ex)


func _cell_pos(x: int, y: int) -> Vector2:
	return ORIGIN + Vector2(x * (CELL + GAP), y * (CELL + GAP))


# 读棋子对应清单(resources/pieces/pieces.json)，为本局 6 个 species 载入 基础/横/竖 + 彩球立绘。
func _load_pieces() -> void:
	piece_tex.clear()
	colorbomb_tex = null
	var path := "res://art/pieces/pieces.json"
	if not FileAccess.file_exists(path):
		return
	var m = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(m) != TYPE_DICTIONARY:
		return
	colorbomb_tex = _piece_tex(m.get("colorbomb", ""))
	var sp_map: Dictionary = m.get("species", {})
	for sid in PIECE_SPECIES:
		var s: Dictionary = sp_map.get(str(sid), {})
		piece_tex.append({
			ME.SP_NONE: _piece_tex(s.get("basic", "")),
			ME.SP_LINE_H: _piece_tex(s.get("h", "")),
			ME.SP_LINE_V: _piece_tex(s.get("v", "")),
		})


func _res_abs(p: String) -> String:
	return ProjectSettings.globalize_path("res://../" + p).simplify_path()


func _piece_tex(p) -> Texture2D:
	if p == null or String(p).is_empty():
		return null
	var path := String(p)
	var img: Image = null
	if ResourceLoader.exists(path):   # 已导入资源(导出可带) 优先
		var t = load(path)
		if t is Texture2D:
			img = t.get_image()
	if img == null:                    # 回退:从源 png 直接读(编辑器/开发)
		img = Image.new()
		var fp := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
		if img.load(fp) != OK:
			return null
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()    # 裁掉透明边距→立绘贴满格，棋子能真正挨着
	if used.size.x > 8 and used.size.y > 8:
		img = img.get_region(used)
	return ImageTexture.create_from_image(img)


# ───────────────────────────── 渲染 ─────────────────────────────
func _render() -> void:
	for y in H:
		for x in W:
			_render_cell(x, y)
	_render_exits()
	_render_hud()
	sel_frame.visible = selected.x >= 0
	if selected.x >= 0:
		sel_frame.position = _cell_pos(selected.x, selected.y)


# 出口标记定位：每条金色色条贴在所属出口列底行(y=H-1)正下方（仅运料关有）。
func _render_exits() -> void:
	for ex in exit_rects:
		var cx: int = ex.get_meta("col", 0)
		ex.position = _cell_pos(cx, H - 1) + Vector2(0, CELL + 2)


func _render_cell(x: int, y: int) -> void:
	var sp: int = board.grid[y][x]
	var f: int = board.fx[y][x]
	var jl: int = _layer_at(board.jelly, x, y)
	var co: int = _layer_at(board.coat, x, y)
	var p := _cell_pos(x, y)

	# 道具底色块 + 宝石立绘 + 符号
	var rect: ColorRect = tiles[y][x]
	var pr: TextureRect = piece_rects[y][x]
	var lab: Label = labels[y][x]
	var bu = burst_rects[y][x]
	rect.position = p
	pr.position = p + Vector2(CELL * 0.5, CELL * 0.5) - pr.size * 0.5   # 居中于格心(立绘大于格→铺满挨着)
	pr.pivot_offset = pr.size * 0.5   # 缩放动画绕中心
	pr.scale = Vector2.ONE
	bu.position = p - Vector2(11, 11)
	bu.visible = false
	lab.position = p
	var has_pieces := not piece_tex.is_empty()
	if sp == ME.WALL:
		rect.color = Color("0c0e14")          # 墙=暗格（异形棋盘）
		pr.visible = false
		lab.text = ""
	elif sp < 0:
		rect.color = Color(0, 0, 0, 0)         # EMPTY 透明
		pr.visible = false
		lab.text = ""
	else:
		# 普通棋子：优先宝石立绘；无图(清单/资源缺失)→回退纯色+符号，保证可玩可辨
		var tex: Texture2D = null
		if has_pieces and sp < piece_tex.size():
			if f == ME.SP_COLORBOMB:
				tex = colorbomb_tex
			else:
				tex = piece_tex[sp].get(ME.SP_NONE)   # 横/竖/炸/普通都用干净基础宝石；方向由 bu 光条指示(替掉烤死的脏光束)
		if tex != null:
			rect.color = Color(0.42, 0.64, 1.0, 0.16)   # 淡蓝格(饱和蓝,高透明;近白会发灰故用真蓝)
			pr.texture = tex
			pr.visible = true
			lab.text = ""
			if f == ME.SP_BOMB:
				bu.mode = "burst"; bu.z_index = -1    # 炸弹：宝石下方放射爆裂
				bu.visible = true; bu.queue_redraw()
			elif f == ME.SP_LINE_H:
				bu.mode = "lineh"; bu.z_index = 1     # 横特效：宝石上方利落横光条
				bu.visible = true; bu.queue_redraw()
			elif f == ME.SP_LINE_V:
				bu.mode = "linev"; bu.z_index = 1     # 竖特效：竖光条
				bu.visible = true; bu.queue_redraw()
		else:
			# 回退：纯色块 + 符号
			pr.visible = false
			if f != ME.SP_NONE:
				rect.color = COLORS[sp].lightened(0.28)
				lab.text = FX_GLYPH[f]
			else:
				rect.color = COLORS[sp]
				lab.text = SYMBOLS[sp]
	# 冰锁下置灰（锁住感）
	if co > 0 and sp >= 0:
		rect.color = rect.color.lerp(Color("3a4252"), 0.45)
		pr.modulate = Color(0.62, 0.68, 0.80)
	else:
		pr.modulate = Color(1, 1, 1)

	# 果冻底层标记：半透明青色块，多层叠深（不透明度随层数升高）。
	var jr: ColorRect = jelly_rects[y][x]
	if jl > 0 and sp != ME.WALL:
		jr.position = p
		var a := 0.30 + 0.18 * float(jl - 1)   # 1 层 .30，2 层 .48 …
		jr.color = Color(0.20, 0.85, 0.80, min(a, 0.75))
		jr.visible = true
	else:
		jr.visible = false

	# 冰锁指示：冷色遮罩 + 锁图标(单层)/层数(多层)。
	var cr: ColorRect = coat_rects[y][x]
	var clab: Label = coat_labels[y][x]
	if co > 0 and sp != ME.WALL:
		cr.position = p
		cr.color = Color(0.78, 0.90, 1.0, min(0.20 + 0.14 * float(co - 1), 0.55))
		cr.visible = true
		clab.position = p
		clab.text = "🔒" if co == 1 else "🔒%d" % co
		clab.visible = true
	else:
		cr.visible = false
		clab.visible = false

	# 巧克力占位：该格被巧克力覆盖 → 盖棕色半透明块（不可消/不可换/不下落的压力源）。
	var ch: int = _layer_at(board.choco, x, y)
	var chr: ColorRect = choco_rects[y][x]
	if ch > 0 and sp != ME.WALL:
		chr.position = p
		chr.visible = true
	else:
		chr.visible = false

	# 运料占位：该格是原料 → 盖樱桃红实心块（随重力下落、不可消/不可换；落到底部出口被收集）。
	var ig: int = _layer_at(board.ing, x, y)
	var igr: ColorRect = ingredient_rects[y][x]
	if ig > 0 and sp != ME.WALL:
		igr.position = p + Vector2(8, 8)   # 内嵌 8px：像一颗坐在格中央的运料物
		igr.visible = true
	else:
		igr.visible = false

	# 炸弹倒计时：该格有炸弹(bomb>0) → 红色数字叠在棋子上显示剩余步数（炸弹格仍是普通棋子，照常渲染立绘）。
	var bo: int = _layer_at(board.bomb, x, y)
	var blab: Label = bomb_labels[y][x]
	if bo > 0 and sp >= 0:
		blab.position = p
		blab.text = str(bo)   # 剩余步数；归零即引爆判负 → 玩家须在此前消除该格拆弹
		blab.visible = true
	else:
		blab.visible = false

	# 爆米花占位：该格是爆米花(popcorn>0) → 盖黄白遮罩 + 剩余命中数（不可消不可换、随重力下落；特效砸到 0 变彩球）。
	# 归 0 后 popcorn=0 → 遮罩/数字隐藏，此时该格 fx 已是 SP_COLORBOMB → 上面立绘逻辑自动画出彩球，玩家可用。
	var po: int = _layer_at(board.popcorn, x, y)
	var prect: ColorRect = popcorn_rects[y][x]
	var plab: Label = popcorn_labels[y][x]
	if po > 0 and sp >= 0:
		prect.position = p
		prect.visible = true
		plab.position = p
		plab.text = str(po)   # 剩余命中数；用特效(条纹/爆炸/彩球)砸够这么多次 → 变彩球
		plab.visible = true
	else:
		prect.visible = false
		plab.visible = false

	# 糖果炮占位：该格是炮口(cannon>0) → 盖深色炮台 + 向下箭头（炮口 grid=WALL，本就暗格；此块凸显"这是炮"）。
	# 与其他层相反：炮口【就在 WALL 格上】渲染（不是 sp!=WALL）。产出在它正下方，玩家可直觉读出供给方向。
	var ca: int = _layer_at(board.cannon, x, y)
	var cann: ColorRect = cannon_rects[y][x]
	if ca > 0:
		cann.position = p
		cann.color = Color(0.30, 0.10, 0.14, 0.95) if ca == 2 else Color(0.16, 0.18, 0.24, 0.95)  # 产原料炮=暗樱桃、普通糖炮=钢灰
		cann.visible = true
	else:
		cann.visible = false


func _render_hud() -> void:
	score_label.text = _objectives_text()
	moves_label.text = "步数 %d" % board.moves_left
	if board.is_won():
		status_label.text = "🎉 过关！(R 下一关)"
	elif board.is_lost():
		status_label.text = "步数耗尽 (R 重试)"
	else:
		status_label.text = ""


# 目标 HUD 文案：按 board.objectives 逐条显示进度；为空时回退旧式分数显示。
func _objectives_text() -> String:
	if board.objectives.is_empty():
		return "分数 %d / %d" % [board.score, TARGET]
	var parts := []
	for o in board.objectives:
		var t: String = o["type"]
		if t == "SCORE":
			parts.append("分数 %d/%d" % [board.score, o["target"]])
		elif t == "COLLECT":
			var sp: int = o["species"]
			var sym: String = SYMBOLS[sp] if sp >= 0 and sp < SYMBOLS.size() else "?"
			var got: int = board.collected.get(sp, 0)
			parts.append("收集 %s %d/%d" % [sym, got, o["target"]])
		elif t == "CLEAR_JELLY":
			parts.append("果冻 %d/%d" % [board.jelly_cleared, o["target"]])
		elif t == "CLEAR_BLOCKER":
			parts.append("解锁 %d/%d" % [board.blocker_cleared, o["target"]])
		elif t == "COLLECT_INGREDIENT":
			parts.append("运料 %d/%d" % [board.ingredient_collected, o["target"]])
		elif t == "DEFUSE_BOMB":
			parts.append("拆弹 %d/%d" % [board.bomb_defused, o["target"]])
		else:
			parts.append("%s %d" % [t, o["target"]])
	return "   ·   ".join(parts)


# 安全读取层值：层数组可能为空（该关无 jelly/coat）。
func _layer_at(layer: Array, x: int, y: int) -> int:
	if layer.is_empty():
		return 0
	return layer[y][x]


# ───────────────────────────── 输入 ─────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		var n: int = (algo_levels.size() + 1) if not algo_levels.is_empty() else DEMO_COUNT
		demo_idx = (demo_idx + 1) % n
		cur_seed += 1
		_new_game()
		return
	if input_locked or board.is_over():
		return
	var pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos == Vector2.INF:
		return
	var cell := _cell_from(pos)
	if cell.x < 0:
		return
	if _skill_aim != "":
		_apply_skill_at(cell)
		return
	if board.grid[cell.y][cell.x] == ME.WALL:
		return  # 墙不可选
	# 冰锁格：board 会拒绝交换，这里直接给反馈（轻闪 + 不进入选中态）。
	if _layer_at(board.coat, cell.x, cell.y) > 0:
		_flash_locked(cell)
		return
	if selected.x < 0:
		selected = cell
		_render()
	elif _adjacent(selected, cell):
		var a := selected
		selected = Vector2i(-1, -1)
		_render()
		_attempt(a, cell)
	else:
		selected = cell
		_render()


func _cell_from(pos: Vector2) -> Vector2i:
	var local := pos - ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var x := int(local.x / (CELL + GAP))
	var y := int(local.y / (CELL + GAP))
	# 排除落在格间空隙上的点击
	if local.x - x * (CELL + GAP) > CELL or local.y - y * (CELL + GAP) > CELL:
		return Vector2i(-1, -1)
	if x >= 0 and x < W and y >= 0 and y < H:
		return Vector2i(x, y)
	return Vector2i(-1, -1)


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1


func _attempt(a: Vector2i, b: Vector2i) -> void:
	input_locked = true
	var pa := _cell_pos(a.x, a.y)
	var pb := _cell_pos(b.x, b.y)
	var nodes := [tiles[a.y][a.x], labels[a.y][a.x], tiles[b.y][b.x], labels[b.y][b.x]]

	await _slide(nodes, [pb, pb, pa, pa], 0.12)

	var initial := _swap_preview_matches(a, b)   # 交换后会消除的格(供清除闪光)
	var pre := _grid_copy(board.grid)            # 移动前盘面(供落定动画 diff)
	var r: Dictionary = board.try_swap(a, b)
	if not r["ok"]:
		await _slide(nodes, [pa, pa, pb, pb], 0.12)  # 非法 → 滑回
		_render()
		input_locked = false
		return

	_render()
	if board.last_cascade_cells.is_empty():
		_animate_clear_flash(initial)                       # 无级联记录(彩球/融合)→单次闪初始消除
	else:
		_animate_cascade_flashes(board.last_cascade_cells)  # 逐级联依次闪,呈现连锁传播
	await _animate_settle(pre)                              # 变动格"落定"(下落+缩放归位)
	input_locked = false


func _slide(nodes: Array, targets: Array, dur: float) -> void:
	var tw := create_tween().set_parallel(true)
	for i in nodes.size():
		tw.tween_property(nodes[i], "position", targets[i], dur)
	await tw.finished


func _grid_copy(g: Array) -> Array:
	var out := []
	for row in g:
		out.append(row.duplicate())
	return out


# 在副本上预演交换，返回会被消除的格(供清除闪光)。特效交换无普通消除→空。
func _swap_preview_matches(a: Vector2i, b: Vector2i) -> Array:
	var g := _grid_copy(board.grid)
	ME._swap_cells(g, a, b)
	return ME.find_matches(g, board.coat)


# 逐级联依次闪：第 i 级延迟 0.08*i 起闪，呈现连锁一波波传播。
func _animate_cascade_flashes(cascades: Array) -> void:
	for i in cascades.size():
		_animate_clear_flash(cascades[i], 0.08 * i)


# 清除闪光：在消除格上快速白闪(看不到旧棋子被清，但给出"这里消除了"的反馈)。delay 起闪延迟。
func _animate_clear_flash(cells: Array, delay: float = 0.0) -> void:
	for c in cells:
		var fl := ColorRect.new()
		fl.color = Color(1, 1, 1, 0.0)
		fl.size = Vector2(CELL, CELL)
		fl.position = _cell_pos(c.x, c.y)
		fl.z_index = 6
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fl)
		var tw := create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_property(fl, "color", Color(1, 1, 1, 0.85), 0.05)
		tw.tween_property(fl, "color", Color(1, 1, 1, 0.0), 0.16)
		tw.tween_callback(fl.queue_free)


# 落定：变动格(对比 pre)的宝石从上方略降 + 缩放归位，按行错峰，似"下落补齐"。
func _animate_settle(pre: Array) -> void:
	var tw := create_tween().set_parallel(true)
	var any := false
	for y in H:
		for x in W:
			if y < pre.size() and x < pre[y].size() and pre[y][x] == board.grid[y][x]:
				continue   # 未变动
			var pr: TextureRect = piece_rects[y][x]
			if not pr.visible:
				continue
			any = true
			var dest := pr.position
			pr.position = dest - Vector2(0, 18)
			pr.scale = Vector2(0.5, 0.5)
			var d := 0.018 * y
			tw.tween_property(pr, "position", dest, 0.2).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(pr, "scale", Vector2.ONE, 0.2).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if any:
		await tw.finished
	else:
		tw.kill()


# 消除后整盘轻微"脉冲"提示发生了变化（v1 简化版反馈；逐级联动画留待 v1.x）
func _pop_flash() -> void:
	modulate = Color(1.15, 1.15, 1.15)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1), 0.14)
	await tw.finished


# 点冰锁格的反馈：该格遮罩快速闪一下（提示"锁住、不可换"）。
func _flash_locked(cell: Vector2i) -> void:
	var cr: ColorRect = coat_rects[cell.y][cell.x]
	if not cr.visible:
		return
	var base := cr.color
	var tw := create_tween()
	tw.tween_property(cr, "color", Color(1.0, 1.0, 1.0, 0.65), 0.06)
	tw.tween_property(cr, "color", base, 0.12)


# ───────────────────────────── Meta 技能 UI 接线（10 §7）─────────────────────────────
# 角色 id → board 用的技能 id（多数同名；借贷的角色 id 是 borrrower）。
const SKILL_ID := {"borrrower": "borrow"}
const SKILL_NAME := {
	"borrow": "借贷", "timerewind": "时间回退", "snapshot": "存档快照",
	"longswap": "隔位对换", "gravityflip": "重力翻转", "colorshield": "彩球护盾",
	"sametypeclear": "同类消除", "foresight": "预知", "breaker": "破障",
	"chainbonus": "连消奖步(被动)", "collector": "连击收集(被动)", "lucky": "提示(被动)",
}
const PASSIVE_SKILLS := ["chainbonus", "collector", "lucky", ""]

# app.gd 装备角色后调用：传入角色 id，归一成 board 技能 id 并重开。
func set_skill(char_id: String) -> void:
	equipped_skill = SKILL_ID.get(char_id, char_id)
	if is_node_ready():   # HUD 已建好才重开；否则 _ready 的 _new_game 会读 equipped_skill
		_new_game()

func _update_skill_button() -> void:
	if skill_button == null:
		return
	var s := equipped_skill
	skill_button.visible = s != "" and s != "lucky"
	if not skill_button.visible:
		return
	var disp: String = SKILL_NAME.get(s, s)
	if s in PASSIVE_SKILLS:
		skill_button.text = "%s · 自动生效" % disp
		skill_button.disabled = true
		return
	skill_button.disabled = board.is_over()
	if s == "borrow":
		skill_button.text = ("还债（欠 %d）" % board.borrow_debt) if board.borrow_debt > 0 else "借一个直线特效"
	elif s == "snapshot":
		skill_button.text = "跳回存档" if board.saved_state != null else "存档"
	elif s == "longswap":
		skill_button.text = "隔位对换：就绪✓" if board.longswap_armed else "隔位对换（下一步隔一格）"
	else:
		skill_button.text = "技能：%s" % disp

func _use_skill() -> void:
	if board == null or board.is_over():
		return
	match equipped_skill:
		"borrow":
			_skill_aim = "repay" if board.borrow_debt > 0 else "borrow"
			hint_label.text = "选一个特效格还债" if _skill_aim == "repay" else "选一个普通格，借入直线特效"
		"sametypeclear":
			_skill_aim = "sametypeclear"
			hint_label.text = "选一个道具，消除全场同类"
		"timerewind":
			board.skill_rewind()
		"snapshot":
			if board.saved_state != null:
				board.skill_load()
			else:
				board.skill_save()
		"colorshield":
			board.skill_shield()
		"gravityflip":
			board.skill_gravity_flip()
		"breaker":
			board.skill_break()
		"foresight":
			var mv: Array = board.skill_foresight()
			if not mv.is_empty():
				var m = mv[0]
				hint_label.text = "预知：试试 (%d,%d)↔(%d,%d)" % [m[0].x, m[0].y, m[1].x, m[1].y]
		"longswap":
			board.longswap_armed = true
	_render()
	_update_skill_button()

func _apply_skill_at(cell: Vector2i) -> void:
	match _skill_aim:
		"borrow":
			board.skill_borrow(cell, ME.SP_LINE_H)
		"repay":
			board.skill_repay(cell)
		"sametypeclear":
			var sp: int = board.grid[cell.y][cell.x]
			if sp >= 0:
				board.skill_clear_species(sp)
	_skill_aim = ""
	selected = Vector2i(-1, -1)
	_render()
	_update_skill_button()
