extends Node2D
# game.gd — 消除 Core 表现层（v2：目标关 / 果冻 / 冰锁 / 墙 / 特效）。
# 只跟 board.gd 打交道：读 grid/fx/jelly/coat/objectives/collected/score/moves_left，调 try_swap。
# 操作：点一个道具再点相邻道具 → 交换（滑动动画）。R 在多个 demo 关之间切换并重开。

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")
const LevelLibrary := preload("res://core/level_library.gd")

const W := 8
const H := 8
const SPECIES := [0, 1, 2, 3, 4]
const CELL := 78.0
const GAP := 6.0
const ORIGIN := Vector2(36.0, 200.0)
const TARGET := 2000
const MOVES := 25

# 5 种道具：颜色 + 形状符号双重区分（呼应 06：小尺寸靠形状不只靠色）
var COLORS := [Color("e74c3c"), Color("f5b301"), Color("27ae60"), Color("2e86de"), Color("8e44ad")]
const SYMBOLS := ["●", "▲", "■", "◆", "✶"]
# 特效标记：SP_NONE/LINE_H/LINE_V/BOMB/COLORBOMB
const FX_GLYPH := ["", "▬", "▮", "✸", "◎"]

var board: Board
var cur_seed := 12345
var demo_idx := 0        # 当前关索引（按 R 递进）
var algo_levels: Array = []   # 算法生成的关卡库（res://levels.json，C++ 导出）；非空则优先玩它
var equipped_skill: String = ""   # 本局所带技能 id（角色 id 归一）
var _skill_aim: String = ""       # 技能瞄准模式: ""/"borrow"/"repay"/"sametypeclear"
var skill_button: Button
var tiles := []          # tiles[y][x] -> ColorRect（道具底色块）
var labels := []         # labels[y][x] -> Label（道具符号/特效标记）
var jelly_rects := []    # jelly_rects[y][x] -> ColorRect（果冻底层标记）
var coat_rects := []     # coat_rects[y][x] -> ColorRect（冰锁遮罩）
var coat_labels := []    # coat_labels[y][x] -> Label（冰锁层数指示）
var selected := Vector2i(-1, -1)
var input_locked := false

var title_label: Label
var score_label: Label
var moves_label: Label
var status_label: Label
var hint_label: Label
var sel_frame: ColorRect


func _ready() -> void:
	_build_hud()
	_build_tiles()
	algo_levels = LevelLibrary.load_file("res://levels.json")   # 优先读 C++ 导出的算法关卡库
	_new_game()


# ───────────────────────────── Demo 关定义 ─────────────────────────────
# 每个 demo 关返回构造 Board 所需的全部参数（按需带 objs/jelly/coat/mask）。
# 关卡轮播：纯分数关[现状] → COLLECT → CLEAR_JELLY → CLEAR_BLOCKER。
const DEMO_COUNT := 4

func _demo_level(idx: int) -> Dictionary:
	match idx:
		1:
			# COLLECT 关：收集红色(species 0) 与 蓝色(species 3)，叠加异形墙。
			return {
				"name": "Demo 2/4 · 收集关 (COLLECT) + 墙",
				"target": 0,
				"moves": 30,
				"mask": _demo_wall_mask(),
				"objs": [
					{"type": "COLLECT", "species": 0, "target": 12},
					{"type": "COLLECT", "species": 3, "target": 12},
				],
				"jelly": [],
				"coat": [],
			}
		2:
			# CLEAR_JELLY 关：中心 4x4 果冻（内 2x2 双层），清掉 18 层。
			return {
				"name": "Demo 3/4 · 果冻关 (CLEAR_JELLY)",
				"target": 0,
				"moves": 30,
				"mask": [],
				"objs": [{"type": "CLEAR_JELLY", "species": -1, "target": 18}],
				"jelly": _demo_jelly_layer(),
				"coat": [],
			}
		3:
			# CLEAR_BLOCKER 关：边框一圈单层冰锁，解锁 12 个；叠加少量墙。
			return {
				"name": "Demo 4/4 · 冰锁关 (CLEAR_BLOCKER) + 墙",
				"target": 0,
				"moves": 35,
				"mask": _demo_corner_mask(),
				"objs": [{"type": "CLEAR_BLOCKER", "species": -1, "target": 12}],
				"jelly": [],
				"coat": _demo_coat_layer(),
			}
		_:
			# 纯分数关[现状]：异形墙 + 分数目标（objectives 为空 → 走旧式分数判定）。
			return {
				"name": "Demo 1/4 · 分数关 (SCORE) + 墙",
				"target": TARGET,
				"moves": MOVES,
				"mask": _demo_wall_mask(),
				"objs": [],
				"jelly": [],
				"coat": [],
			}


func _new_game() -> void:
	if not algo_levels.is_empty():
		var i: int = demo_idx % algo_levels.size()
		var ld: Dictionary = algo_levels[i]
		board = LevelLibrary.to_board(ld)
		title_label.text = "算法关 %d/%d · %s" % [i + 1, algo_levels.size(), String(ld.get("difficulty", "?"))]
	else:
		var lvl := _demo_level(demo_idx)
		board = Board.new(W, H, SPECIES, lvl["target"], lvl["moves"], cur_seed,
				lvl["mask"], lvl["objs"], lvl["jelly"], lvl["coat"])
		title_label.text = lvl["name"]
	board.skill = equipped_skill
	_skill_aim = ""
	selected = Vector2i(-1, -1)
	input_locked = false
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


# ───────────────────────────── HUD / 节点构建 ─────────────────────────────
func _build_hud() -> void:
	var bg := ColorRect.new()
	bg.color = Color("171b26")
	bg.size = Vector2(2400, 2400)
	bg.position = Vector2(-200, -200)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	title_label = _mk_label(Vector2(36, 28), 26)
	score_label = _mk_label(Vector2(36, 72), 28)
	moves_label = _mk_label(Vector2(36, 116), 26)
	status_label = _mk_label(Vector2(560, 72), 34)
	hint_label = _mk_label(Vector2(36, 850), 20)
	hint_label.text = "点一个道具，再点相邻道具交换 · 按 R 切换关卡"
	skill_button = Button.new()
	skill_button.position = Vector2(36, 150)   # HUD 与棋盘之间的空隙，避开大盘
	skill_button.size = Vector2(648, 44)
	skill_button.z_index = 50
	skill_button.add_theme_font_size_override("font_size", 22)
	skill_button.pressed.connect(_use_skill)
	skill_button.visible = false
	add_child(skill_button)


func _mk_label(pos: Vector2, fsize: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _build_tiles() -> void:
	sel_frame = ColorRect.new()
	sel_frame.color = Color(1, 1, 1, 0.28)
	sel_frame.size = Vector2(CELL, CELL)
	sel_frame.visible = false
	sel_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_frame.z_index = 5
	add_child(sel_frame)

	tiles.resize(H)
	labels.resize(H)
	jelly_rects.resize(H)
	coat_rects.resize(H)
	coat_labels.resize(H)
	for y in H:
		tiles[y] = []
		labels[y] = []
		jelly_rects[y] = []
		coat_rects[y] = []
		coat_labels[y] = []
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


func _cell_pos(x: int, y: int) -> Vector2:
	return ORIGIN + Vector2(x * (CELL + GAP), y * (CELL + GAP))


# ───────────────────────────── 渲染 ─────────────────────────────
func _render() -> void:
	for y in H:
		for x in W:
			_render_cell(x, y)
	_render_hud()
	sel_frame.visible = selected.x >= 0
	if selected.x >= 0:
		sel_frame.position = _cell_pos(selected.x, selected.y)


func _render_cell(x: int, y: int) -> void:
	var sp: int = board.grid[y][x]
	var f: int = board.fx[y][x]
	var jl: int = _layer_at(board.jelly, x, y)
	var co: int = _layer_at(board.coat, x, y)
	var p := _cell_pos(x, y)

	# 道具底色块
	var rect: ColorRect = tiles[y][x]
	rect.position = p
	if sp == ME.WALL:
		rect.color = Color("0c0e14")          # 墙=暗格（异形棋盘）
	elif sp < 0:
		rect.color = Color(0, 0, 0, 0)         # EMPTY 透明
	elif f != ME.SP_NONE:
		rect.color = COLORS[sp].lightened(0.28)  # 特效格提亮
	else:
		rect.color = COLORS[sp]
	# 冰锁下的道具置灰但仍可见（锁住感；锁下道具看得到）。
	if co > 0 and sp >= 0:
		rect.color = rect.color.lerp(Color("3a4252"), 0.45)

	# 道具符号 / 特效标记
	var lab: Label = labels[y][x]
	lab.position = p
	if sp == ME.WALL or sp < 0:
		lab.text = ""
	elif f != ME.SP_NONE:
		lab.text = FX_GLYPH[f]
	else:
		lab.text = SYMBOLS[sp]

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
		var n: int = algo_levels.size() if not algo_levels.is_empty() else DEMO_COUNT
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

	var r: Dictionary = board.try_swap(a, b)
	if not r["ok"]:
		await _slide(nodes, [pa, pa, pb, pb], 0.12)  # 非法 → 滑回
		_render()
		input_locked = false
		return

	_render()
	await _pop_flash()
	input_locked = false


func _slide(nodes: Array, targets: Array, dur: float) -> void:
	var tw := create_tween().set_parallel(true)
	for i in nodes.size():
		tw.tween_property(nodes[i], "position", targets[i], dur)
	await tw.finished


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
