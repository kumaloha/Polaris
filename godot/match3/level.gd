extends Node2D
# level.gd — 对局主场景（GAME_SPEC 新视图体系）。逻辑复用 core/board.gd + match_engine.gd。
#
# 布局对齐用户「目标样式」参考图：
#   顶部：暂停 | 第N关横幅 | 金币
#   关卡目标米色大面板(3目标) ；左挂步数圆徽章 ；右上星级+进度条
#   角色区：左主角狐狸+道具书 / 右暗影魔王Boss ；下方 Boss名+血条(带数值)
#   棋盘 8×8(金框) ；底部技能栏(深托盘) 4头像+名字+技能名+冷却条
# 逻辑联动(血量随score/目标计数/步数递减/技能effect/消除)后续接，本版为视觉框架。

const CoreBoard := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")
const LevelConfig := preload("res://match3/level_config.gd")

const GEM_COLORS := {
	"red": Color(1.0, 0.24, 0.24), "blue": Color(0.31, 0.63, 1.0),
	"green": Color(0.3, 1.0, 0.4), "gold": Color(1.0, 0.78, 0.2),
	"purple": Color(0.7, 0.3, 1.0), "pink": Color(1.0, 0.4, 0.7),
}
const GEM_TEXTURES := [
	"res://assets/gems/gem_ruby.png", "res://assets/gems/gem_water.png",
	"res://assets/gems/gem_clover.png", "res://assets/gems/gem_star.png",
	"res://assets/gems/gem_orb.png", "res://assets/gems/gem_heart.png",
]
const CELL_TEXTURE := "res://assets/board/board_cell.png"
const BOARD_PANEL_TEXTURE := "res://assets/board/bg_board.png"
const BG_TEXTURE := "res://assets/ui/bg_scene.png"
# UI 素材
const PANEL_BEIGE := "res://assets/ui/ui_panel_beige.png"
const PANEL_DARK := "res://assets/ui/ui_panel_dark.png"
const STEP_FRAME := "res://assets/ui/ui_step_frame.png"
const HPBAR_TEX := "res://assets/ui/ui_boss_hpbar.png"
const COIN_TEX := "res://assets/ui/ui_coin.png"
const STAR_GOLD := "res://assets/ui/ui_star_gold.png"
const STAR_GRAY := "res://assets/ui/ui_star_gray.png"
const BOSS_TEX := "res://assets/ui/boss_horned_king.png"
const HERO_TEX := "res://assets/ui/char_fox_hero.png"
const PROP_TEX := "res://assets/ui/ui_magic_book.png"
const ORB_TEX := "res://assets/gems/gem_orb.png"
const KEY_SHADER := "res://match3/magenta_key.gdshader"

# 关卡目标(占位) 与 技能(占位)
const OBJECTIVES_DEMO := [
	{"icon": "res://assets/gems/gem_water.png", "n": "16"},
	{"icon": "res://assets/gems/gem_star.png", "n": "28"},
	{"icon": "res://assets/avatars/av_raccoon_miner.png", "n": "2"},
]
const SKILLS := [
	{"av": "res://assets/avatars/av_deer_oracle.png", "name": "星鹿", "skill": "提示"},
	{"av": "res://assets/avatars/av_raccoon_miner.png", "name": "矿工程", "skill": "破障"},
	{"av": "res://assets/avatars/av_dragon_red.png", "name": "龙宝宝", "skill": "龙息大招"},
	{"av": "res://assets/avatars/av_ladybug.png", "name": "瓢虫", "skill": "幸运祝福"},
]

const DESIGN_W := 720.0
const DESIGN_H := 1520.0
const SWAP_TIME := 0.14
const BG_CRYSTAL_UV := Vector2(0.632, 0.41)   # 水晶球在 bg_scene 图中的归一化位置(白核扫描 px594,330)
const BG_CRYSTAL_TARGET := Vector2(360, 344)  # 对齐到狐狸与 Boss 正中间
const BG_SCALE := 1.95

# ── 布局锚点（对齐参考图；截图后微调） ──
const PAUSE_C := Vector2(58, 58)
const PAUSE_W := 92.0
const TITLE_C := Vector2(360, 46)
const TITLE_W := 278.0
const TITLE_H := 68.0
const COIN_C := Vector2(602, 50)
const COIN_W := 56.0
const OBJPANEL_C := Vector2(360, 166)
const OBJPANEL_W := 436.0
const OBJPANEL_H := 142.0
const STEP_C := Vector2(62, 212)
const STEP_W := 118.0
const STAR_C := Vector2(636, 130)   # 中星
const STAR_GAP := 50.0
const STAR_W := 46.0
const HERO_C := Vector2(166, 350)
const HERO_W := 246.0
const ORB_C := Vector2(362, 372)   # 水晶球(狐狸与 Boss 正中间)
const ORB_W := 96.0
const PROP_C := Vector2(452, 416)
const PROP_W := 102.0
const BOSS_C := Vector2(562, 336)
const BOSS_W := 244.0
const BOSSNAME_C := Vector2(360, 468)
const HPBAR_C := Vector2(360, 502)
const HPBAR_W := 364.0
const HPBAR_H := 46.0
const BOARD_TOP := 464.0
const BOARD_BOTTOM := 1198.0
const BOARD_RATIO := 0.96
const CELL_FILL := 0.90
const GEM_FILL := 0.84
const BOARD_PANEL_PAD := 0.40
const BOARD_PANEL_MARGIN := 80
const TRAY_TOP := 1206.0
const SKILL_AV_Y := 1306.0
const SKILL_AV_W := 132.0
const SKILL_CD_Y := 1372.0
const SKILL_NAME_Y := 1404.0
const SKILL_SKILLNAME_Y := 1438.0

var board
var board_origin: Vector2
var cell_size: float = 0.0
var _level_idx: int = 0
var _gem_nodes: Array = []
var _sel := Vector2i(-1, -1)
var _sel_marker: Sprite2D = null
var _hl_markers: Array = []
var _busy := false
var _key_mat: ShaderMaterial = null

@onready var background_layer: CanvasLayer = $BackgroundLayer
@onready var board_layer: CanvasLayer = $BoardLayer
@onready var gem_layer: CanvasLayer = $GemLayer
@onready var character_layer: CanvasLayer = $CharacterLayer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var skill_bar: CanvasLayer = $SkillBar

func _ready() -> void:
	# 图层顺序：背景(0) < 角色(1) < 棋盘格(2)/棋子(3) < FX(4) < UI(5) < 技能栏(6)
	# 棋盘在角色之上 → 棋盘顶压角色脚时由棋盘盖住角色(用户要求)
	character_layer.layer = 1
	board_layer.layer = 2
	gem_layer.layer = 3
	$FXLayer.layer = 4
	load_level(_level_idx)

func load_level(idx: int) -> void:
	var cfg: Dictionary = LevelConfig.get_level(idx)
	var ncolors: int = int(cfg.get("colors", 6))
	var species: Array = []
	for i in range(ncolors):
		species.append(i)
	board = CoreBoard.new(cfg["cols"], cfg["rows"], species, 999999, 999, 12345 + idx)
	_sel = Vector2i(-1, -1)
	_sel_marker = null
	_hl_markers = []
	_busy = false
	_compute_layout()
	_render_background()
	_render_board()
	_render_chrome(cfg)
	print("[前端框架] 关卡 #%d  %d×%d  cell=%d  合法移动=%s"
		% [cfg["id"], board.width, board.height, int(cell_size), str(ME.has_legal_move(board.grid))])

func _compute_layout() -> void:
	var avail_w: float = DESIGN_W * BOARD_RATIO
	var avail_h: float = BOARD_BOTTOM - BOARD_TOP
	cell_size = floor(min(avail_w / float(board.width), avail_h / float(board.height)))
	var board_w: float = board.width * cell_size
	var board_h: float = board.height * cell_size
	board_origin = Vector2((DESIGN_W - board_w) * 0.5, BOARD_TOP + (avail_h - board_h) * 0.5)

func _cell_center(row: int, col: int) -> Vector2:
	return board_origin + Vector2(col, row) * cell_size + Vector2(cell_size, cell_size) * 0.5

func _pos_to_cell(p: Vector2) -> Vector2i:
	var c: int = int(floor((p.x - board_origin.x) / cell_size))
	var r: int = int(floor((p.y - board_origin.y) / cell_size))
	if r < 0 or r >= board.height or c < 0 or c >= board.width:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

# ───────── 背景 / 棋盘 ─────────

func _render_background() -> void:
	_clear_layer(background_layer)
	if not ResourceLoader.exists(BG_TEXTURE):
		return
	var tex: Texture2D = load(BG_TEXTURE)
	var spr := Sprite2D.new()
	spr.texture = tex
	var sz: Vector2 = tex.get_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		background_layer.add_child(spr)
		return
	# 摆放背景：把图中水晶球(BG_CRYSTAL_UV)对齐到狐狸与 Boss 中间(BG_CRYSTAL_TARGET)。
	# 图比屏幕大，超出部分自然裁切（"图大不全用"）。
	spr.scale = Vector2.ONE * BG_SCALE
	var crystal_px: Vector2 = Vector2(sz.x * BG_CRYSTAL_UV.x, sz.y * BG_CRYSTAL_UV.y)
	spr.position = BG_CRYSTAL_TARGET - (crystal_px - sz * 0.5) * BG_SCALE
	background_layer.add_child(spr)

func _render_board_panel() -> void:
	if not ResourceLoader.exists(BOARD_PANEL_TEXTURE):
		return
	var board_w: float = board.width * cell_size
	var board_h: float = board.height * cell_size
	var pad: float = cell_size * BOARD_PANEL_PAD
	var np := NinePatchRect.new()
	np.texture = load(BOARD_PANEL_TEXTURE)
	np.position = board_origin - Vector2(pad, pad)
	np.size = Vector2(board_w + pad * 2.0, board_h + pad * 2.0)
	np.patch_margin_left = BOARD_PANEL_MARGIN
	np.patch_margin_right = BOARD_PANEL_MARGIN
	np.patch_margin_top = BOARD_PANEL_MARGIN
	np.patch_margin_bottom = BOARD_PANEL_MARGIN
	board_layer.add_child(np)

func _render_board() -> void:
	_clear_layer(board_layer)
	_clear_layer(gem_layer)
	_render_board_panel()
	_gem_nodes = []
	var cell_tex: Texture2D = load(CELL_TEXTURE) if ResourceLoader.exists(CELL_TEXTURE) else null
	for r in range(board.height):
		var node_row: Array = []
		for c in range(board.width):
			var center: Vector2 = _cell_center(r, c)
			if cell_tex != null:
				var cs := Sprite2D.new()
				cs.texture = cell_tex
				cs.position = center
				cs.scale = _fit_scale(cell_tex, cell_size * CELL_FILL)
				board_layer.add_child(cs)
			node_row.append(_make_gem(board.grid[r][c], center))
		_gem_nodes.append(node_row)

func _make_gem(sp: int, center: Vector2) -> Sprite2D:
	if sp < 0 or sp >= GEM_TEXTURES.size() or not ResourceLoader.exists(GEM_TEXTURES[sp]):
		return null
	var tex: Texture2D = load(GEM_TEXTURES[sp])
	var gs := Sprite2D.new()
	gs.texture = tex
	gs.position = center
	gs.scale = _fit_scale(tex, cell_size * GEM_FILL)
	gem_layer.add_child(gs)
	return gs

# ───────── 整页 UI（对齐参考图） ─────────

func _render_chrome(cfg: Dictionary) -> void:
	_clear_layer(character_layer)
	_clear_layer(ui_layer)
	_clear_layer(skill_bar)
	_render_characters()
	_render_topbar(cfg)
	_render_objective_panel()
	_render_step_badge()
	_render_stars()
	_render_skillbar()

func _render_topbar(cfg: Dictionary) -> void:
	# 暂停按钮（圆徽底 + ❚❚）
	_sprite_w(ui_layer, STEP_FRAME, PAUSE_C, PAUSE_W, false)
	_label(ui_layer, "❚❚", PAUSE_C, 30, Color(1, 0.95, 0.75), 80)
	# 第 N 关 横幅(深色金边 + 金字)
	_ninepatch(ui_layer, PANEL_DARK, TITLE_C, TITLE_W, TITLE_H, 28)
	_label(ui_layer, "第 %d 关" % cfg["id"], TITLE_C, 38, Color(1.0, 0.86, 0.4), TITLE_W)
	# 金币
	_sprite_w(ui_layer, COIN_TEX, COIN_C, COIN_W, false)
	_label(ui_layer, "2350", COIN_C + Vector2(58, 0), 34, Color(1, 0.92, 0.5), 140)

func _render_objective_panel() -> void:
	_ninepatch(ui_layer, PANEL_BEIGE, OBJPANEL_C, OBJPANEL_W, OBJPANEL_H, 38)
	_label(ui_layer, "关卡目标", OBJPANEL_C + Vector2(0, -OBJPANEL_H * 0.5 + 26), 26, Color(0.32, 0.16, 0.05), OBJPANEL_W)
	var n: int = OBJECTIVES_DEMO.size()
	for i in range(n):
		var item: Dictionary = OBJECTIVES_DEMO[i]
		var cx: float = OBJPANEL_C.x + (float(i) - float(n - 1) * 0.5) * 124.0
		var icy: float = OBJPANEL_C.y + 6.0
		_sprite_w(ui_layer, item["icon"], Vector2(cx, icy), 60, false)
		_label(ui_layer, str(item["n"]), Vector2(cx, icy + 50.0), 28, Color(0.32, 0.16, 0.05), 110)

func _render_step_badge() -> void:
	_sprite_w(ui_layer, STEP_FRAME, STEP_C, STEP_W, false)
	_label(ui_layer, "26", STEP_C + Vector2(0, -8), 42, Color.WHITE, STEP_W)
	_label(ui_layer, "剩余步数", STEP_C + Vector2(0, 26), 17, Color(0.9, 0.9, 0.95), STEP_W + 10)

func _render_stars() -> void:
	var paths: Array = [STAR_GOLD, STAR_GRAY, STAR_GRAY]
	for i in range(3):
		var cx: float = STAR_C.x + float(i - 1) * STAR_GAP
		_sprite_w(ui_layer, paths[i], Vector2(cx, STAR_C.y), STAR_W, false)
	# 进度条(圆角胶囊)
	_rounded_bar(ui_layer, Vector2(STAR_C.x, STAR_C.y + 38.0), STAR_GAP * 2.0 + STAR_W, 12.0,
		0.2, Color(0.74, 0.34, 1.0, 1.0), Color(0.12, 0.06, 0.2, 0.9))

func _render_characters() -> void:
	# 主角狐狸(透明底,不去背) + 道具书 + Boss(去背) + Boss名 + 血条
	_sprite_w(character_layer, HERO_TEX, HERO_C, HERO_W, false)
	_sprite_w(character_layer, BOSS_TEX, BOSS_C, BOSS_W, true)
	# 道具魔法书（水晶球来自背景图，不再另放占位）
	_sprite_w(character_layer, PROP_TEX, PROP_C, PROP_W, false)

func _render_hpbar(center: Vector2, w: float, h: float, ratio: float, text: String) -> void:
	# 金边深槽 + 鲜红圆角填充 + 数值（程序绘制，颜色/边框/比例可控）。
	var slot := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.02, 0.03, 0.96)
	sb.set_corner_radius_all(int(h * 0.5))
	sb.set_border_width_all(4)
	sb.border_color = Color(0.88, 0.68, 0.30)
	slot.add_theme_stylebox_override("panel", sb)
	slot.size = Vector2(w, h)
	slot.position = center - Vector2(w, h) * 0.5
	character_layer.add_child(slot)
	var inset := 7.0
	var ih: float = h - inset * 2.0
	var fill := Panel.new()
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = Color(0.93, 0.14, 0.13)
	sbf.set_corner_radius_all(int(ih * 0.5))
	fill.add_theme_stylebox_override("panel", sbf)
	fill.size = Vector2(maxf((w - inset * 2.0) * clampf(ratio, 0.0, 1.0), ih), ih)
	fill.position = center - Vector2(w, h) * 0.5 + Vector2(inset, inset)
	character_layer.add_child(fill)
	_label(character_layer, text, center, 26, Color.WHITE, w)

func _render_skillbar() -> void:
	# 深色托盘
	var tray := ColorRect.new()
	tray.color = Color(0.04, 0.02, 0.09, 0.92)
	tray.size = Vector2(DESIGN_W, DESIGN_H - TRAY_TOP)
	tray.position = Vector2(0, TRAY_TOP)
	skill_bar.add_child(tray)
	var line := ColorRect.new()
	line.color = Color(0.85, 0.7, 0.3, 0.9)
	line.size = Vector2(DESIGN_W, 3)
	line.position = Vector2(0, TRAY_TOP)
	skill_bar.add_child(line)
	# 4 技能头像 + 冷却条 + 名字 + 技能名
	var n: int = SKILLS.size()
	for i in range(n):
		var sk: Dictionary = SKILLS[i]
		var cx: float = DESIGN_W * (float(i) + 0.5) / float(n)
		_sprite_w(skill_bar, sk["av"], Vector2(cx, SKILL_AV_Y), SKILL_AV_W, true)
		# 冷却条(圆角胶囊)
		_rounded_bar(skill_bar, Vector2(cx, SKILL_CD_Y + 4.0), SKILL_AV_W * 0.56, 18.0,
			0.85, Color(0.82, 0.45, 1.0, 1.0), Color(0.16, 0.09, 0.26, 0.95))
		_label(skill_bar, str(sk["name"]), Vector2(cx, SKILL_NAME_Y), 22, Color(1, 0.95, 0.8), SKILL_AV_W + 20)
		_label(skill_bar, str(sk["skill"]), Vector2(cx, SKILL_SKILLNAME_Y), 19, Color(0.85, 0.8, 0.95), SKILL_AV_W + 20)

# ───────── 渲染 helper ─────────

func _sprite_w(layer: CanvasLayer, path: String, center: Vector2, width: float, use_key: bool) -> Sprite2D:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var s := Sprite2D.new()
	s.texture = tex
	s.position = center
	s.scale = _scale_to_width(tex, width)
	if use_key:
		s.material = _magenta_material()
	layer.add_child(s)
	return s

func _ninepatch(layer: CanvasLayer, path: String, center: Vector2, w: float, h: float, margin: int) -> NinePatchRect:
	if not ResourceLoader.exists(path):
		return null
	var np := NinePatchRect.new()
	np.texture = load(path)
	np.position = center - Vector2(w, h) * 0.5
	np.size = Vector2(w, h)
	np.patch_margin_left = margin
	np.patch_margin_right = margin
	np.patch_margin_top = margin
	np.patch_margin_bottom = margin
	layer.add_child(np)
	return np

func _label(layer: CanvasLayer, text: String, center: Vector2, font_size: int, color: Color, box_w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(box_w, float(font_size) + 16.0)
	l.position = center - l.size * 0.5
	layer.add_child(l)
	return l

func _magenta_material() -> ShaderMaterial:
	if _key_mat == null:
		_key_mat = ShaderMaterial.new()
		_key_mat.shader = load(KEY_SHADER)
	return _key_mat

func _fit_scale(tex: Texture2D, target: float) -> Vector2:
	var sz: Vector2 = tex.get_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return Vector2.ONE
	return Vector2.ONE * (target / maxf(sz.x, sz.y))

func _scale_to_width(tex: Texture2D, width: float) -> Vector2:
	var w: float = tex.get_size().x
	if w <= 0.0:
		return Vector2.ONE
	return Vector2.ONE * (width / w)

# 圆角胶囊进度条：深槽 + 亮色填充(ratio 0..1)。
func _rounded_bar(layer: CanvasLayer, center: Vector2, w: float, h: float, ratio: float, fill_color: Color, bg_color: Color) -> void:
	var r: int = int(h * 0.5)
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(r)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.95, 0.8, 0.42)  # 金色边框
	bg.add_theme_stylebox_override("panel", sb)
	bg.size = Vector2(w, h)
	bg.position = center - Vector2(w, h) * 0.5
	layer.add_child(bg)
	if ratio > 0.0:
		var inset := 2.0
		var ih: float = h - inset * 2.0
		var fl := Panel.new()
		var sbf := StyleBoxFlat.new()
		sbf.bg_color = fill_color
		sbf.set_corner_radius_all(int(ih * 0.5))
		fl.add_theme_stylebox_override("panel", sbf)
		fl.size = Vector2(maxf((w - inset * 2.0) * clampf(ratio, 0.0, 1.0), ih), ih)
		fl.position = center - Vector2(w, h) * 0.5 + Vector2(inset, inset)
		layer.add_child(fl)

func _clear_layer(layer: CanvasLayer) -> void:
	for ch in layer.get_children():
		ch.queue_free()

# ───────── 交互（阶段2） ─────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT, KEY_SPACE:
				_level_idx = (_level_idx + 1) % LevelConfig.count()
				load_level(_level_idx)
			KEY_LEFT:
				_level_idx = (_level_idx - 1 + LevelConfig.count()) % LevelConfig.count()
				load_level(_level_idx)
		return
	if _busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = _pos_to_cell(event.position)
		if cell.x < 0:
			return
		_on_cell_clicked(cell)

func _on_cell_clicked(cell: Vector2i) -> void:
	if _gem_nodes[cell.y][cell.x] == null:
		return
	if _sel.x < 0:
		_select(cell)
	elif cell == _sel:
		_deselect()
	elif _is_adjacent(_sel, cell):
		var a: Vector2i = _sel
		_deselect()
		await _try_swap(a, cell)
	else:
		_deselect()
		_select(cell)

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return (a.y == b.y and absi(a.x - b.x) == 1) or (a.x == b.x and absi(a.y - b.y) == 1)

func _select(cell: Vector2i) -> void:
	_sel = cell
	if _sel_marker == null or not is_instance_valid(_sel_marker):
		_sel_marker = Sprite2D.new()
		_sel_marker.texture = load(CELL_TEXTURE)
		_sel_marker.modulate = Color(1.0, 0.85, 0.3, 0.55)
		gem_layer.add_child(_sel_marker)
	_sel_marker.scale = _fit_scale(_sel_marker.texture, cell_size * 1.02)
	_sel_marker.position = _cell_center(cell.y, cell.x)
	_sel_marker.visible = true

func _deselect() -> void:
	_sel = Vector2i(-1, -1)
	if _sel_marker != null and is_instance_valid(_sel_marker):
		_sel_marker.visible = false

func _try_swap(a: Vector2i, b: Vector2i) -> void:
	_busy = true
	_clear_highlights()
	var legal: bool = ME.is_legal_swap(board.grid, a, b)
	var na: Sprite2D = _gem_nodes[a.y][a.x]
	var nb: Sprite2D = _gem_nodes[b.y][b.x]
	var pa: Vector2 = _cell_center(a.y, a.x)
	var pb: Vector2 = _cell_center(b.y, b.x)
	await _animate_swap(na, nb, pa, pb)
	if legal:
		ME._swap_cells(board.grid, a, b)
		ME._swap_cells(board.fx, a, b)
		_gem_nodes[a.y][a.x] = nb
		_gem_nodes[b.y][b.x] = na
		_flash_matches()
	else:
		await _animate_swap(na, nb, pb, pa)
	_busy = false

func _animate_swap(na: Sprite2D, nb: Sprite2D, to_a: Vector2, to_b: Vector2) -> void:
	var t := create_tween().set_parallel(true)
	var any := false
	if na != null and is_instance_valid(na):
		t.tween_property(na, "position", to_b, SWAP_TIME)
		any = true
	if nb != null and is_instance_valid(nb):
		t.tween_property(nb, "position", to_a, SWAP_TIME)
		any = true
	if any:
		await t.finished

func _flash_matches() -> void:
	_clear_highlights()
	var matches: Array = ME.find_matches(board.grid)
	for m in matches:
		var mk := ColorRect.new()
		mk.color = Color(1.0, 0.9, 0.2, 0.5)
		mk.size = Vector2(cell_size, cell_size) * 0.96
		mk.position = _cell_center(m.y, m.x) - mk.size * 0.5
		gem_layer.add_child(mk)
		_hl_markers.append(mk)
		var t := create_tween().set_loops(0)
		t.tween_property(mk, "color:a", 0.28, 0.4)
		t.tween_property(mk, "color:a", 0.6, 0.4)

func _clear_highlights() -> void:
	for mk in _hl_markers:
		if mk != null and is_instance_valid(mk):
			mk.queue_free()
	_hl_markers = []

func debug_first_legal_swap() -> bool:
	for y in range(board.height):
		for x in range(board.width):
			var a := Vector2i(x, y)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b: Vector2i = a + d
				if b.x < board.width and b.y < board.height and ME.is_legal_swap(board.grid, a, b):
					_try_swap(a, b)
					return true
	return false
