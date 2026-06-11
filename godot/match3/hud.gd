class_name LevelHud
extends Node
## HUD 子控制器（契约 A 消费者, docs/11 §2 / 附录A）。
##
## 从 level.gd 抽出顶栏簇 + 结算面板渲染：标题/金币/暂停槽、目标卡、步数、星级、结算面板。
## 行为零变化——所有顶栏锚点/UV/目标视图/计数文案/结算面板布局原样平移自旧 level.gd。
##
## 生命周期：作为 level 的子 Node（铁律2），换关随 level 子树存活；自身不持有 tween。
## 状态闸门（_busy/_settled）只住 level（铁律1），本类只读 board / 只渲染 ui_layer。
##
## 注入：level 引用（读 live ui_layer/character_layer/board/_cur_cfg + 共享渲染 helper），
##   布局/锚点常量随本模块走（防腐规矩 #4）。
##
## 增量刷新（消灭"每步全清重画"）：缓存步数 Label 与每张目标卡的进度 Label，
##   on_step(report) 读 report.account 直接改文本，不重画整个 ui_layer。

const LevelLayout := preload("res://match3/level_layout.gd")
const ME := preload("res://core/match_engine.gd")

# ── 顶栏布局常量（迁自 level.gd 顶栏簇）──
const COLOR_GOLD := Color(1.0, 0.92, 0.5)  # 统一金色文字(金币数/第N关/步数)
const STAR_GOLD := "res://assets/ui/ui_star_gold.png"
const LV_STAR_GOLD := "res://assets/level/star_gold.png"       # 174×176 金星(已点亮)
const LV_TOP := "res://assets/level/top_transparent.png"  # v0.02 顶栏原图(1024×1536, 下方透明长画布)
const LV_TOP_REGION := Rect2(0, 340, 1024, 507)  # 只显示顶栏主体区域, 避免透明长画布压缩框和圆
const TOPBAR_Y_OFFSET := -48.0  # 顶部整组上提, 让吊链露出的长度更短
const TB_LEVEL_LABEL_UV := Vector2(142.0 / 720.0, 176.0 / 356.0)
const TB_MOVES_LABEL_UV := Vector2(146.0 / 720.0, 237.0 / 356.0)
const TB_MOVES_NUMBER_UV := Vector2(140.0 / 720.0, 282.0 / 356.0)
const TB_STAR_XS := [360.0 / 720.0, 482.0 / 720.0, 625.0 / 720.0]
const TB_STAR_Y := 199.0 / 356.0
const TB_OBJ_SLOT_GAP := 124.0
const TB_OBJ_ICON_TEXT_GAP := 58.0
const TB_OBJ_Y_UV := 281.0 / 356.0
const TB_OBJ_ICON_MAX := 80.0
const TB_OBJ_TEXT_W := 56.0

const OBJECTIVES_DEMO := [
	{"icon": "res://assets/gems/gem_water.png", "n": "16"},
	{"icon": "res://assets/gems/gem_star.png", "n": "28"},
	{"icon": "res://assets/avatars/av_raccoon_miner.png", "n": "2"},
]

# 目标卡图标资源(迁自 level.gd)。
const JELLY_GOAL_ICON := "res://assets/obstacles/ob_bubble.png"
const BARRIER_ICE_ICON := "res://assets/obstacles/ob_ice.png"  # synced from resources/barrier/ob_ice.png
# COLLECT 用该色宝石图标; 非 COLLECT 类暂用矿工头像占位(TODO 美术: 给障碍目标各出专属图标)。
const OBJ_PLACEHOLDER_ICON := "res://assets/avatars/av_raccoon_miner.png"

const DESIGN_W := LevelLayout.DESIGN_W
const DESIGN_H := 1520.0

# 宝石图标(目标卡 COLLECT 用)。与 level.gd GEM_TEXTURES 同序(species 0..5)。
const GEM_TEXTURES := [
	"res://art/gems/base/gem_ruby.png", "res://art/gems/base/gem_water.png",
	"res://art/gems/base/gem_clover.png", "res://art/gems/base/gem_star.png",
	"res://art/gems/base/gem_orb.png", "res://art/gems/base/heart_neon.png",
]

# ── 注入上下文 ──
var _level = null   # level.gd 实例(读 live ui_layer/character_layer/board/_cur_cfg + 共享 helper)

# ── 增量刷新缓存 ──
var _topbar_moves_value_label: Label = null
var _objective_progress_labels: Array = []   # 每张目标卡的进度 Label(随 on_step 直接改文本)
var _moves_display_override: int = -1

func setup(level) -> void:
	_level = level

# ───────── 对外接口 ─────────

## 整层重画(换关/重试)。清角色层 + ui_layer, 渲染顶栏。
func render_chrome(cfg: Dictionary) -> void:
	if _level == null:
		return
	_level._cur_cfg = cfg
	_clear_layer(_level.character_layer)
	_render_ui_layer()

## 增量刷新(每步 resolve/swap 后): 重画 ui_layer(目标卡进度 + 步数徽章)。
## 缓存 Label 由 _render_topbar_v2 内重建; on_step 走缓存改文本不重画。
func refresh() -> void:
	if _level == null:
		return
	_clear_layer(_level.ui_layer)
	_topbar_moves_value_label = null
	_objective_progress_labels = []
	_render_ui_layer()

## 契约 A 消费者: 读 report.account 增量刷新目标进度 Label + 步数(不重画 ui_layer)。
## report.account 含 9 计数器/by_species/locked/cake_blast(account_clears 原样返回)。
func on_step(_report: Dictionary) -> void:
	if _level == null or _level.board == null:
		return
	# 步数(回退/结算前可能被 override 覆盖, 这里只在无 override 时跟 board.moves_left)
	if _moves_display_override < 0 and _topbar_moves_value_label != null and is_instance_valid(_topbar_moves_value_label):
		_topbar_moves_value_label.text = str(maxi(_level.board.moves_left, 0))
	# 目标卡进度: 用 _objectives_view() 现值刷每张卡的剩余计数文本(缓存 Label, 不重画)。
	var view: Array = _objectives_view()
	for i in range(mini(view.size(), _objective_progress_labels.size())):
		var lbl = _objective_progress_labels[i]
		if lbl != null and is_instance_valid(lbl):
			lbl.text = _objective_counter_text(view[i])

## 结算面板(通关/失败)。on_button: Callable(win:bool) 注入连回 level(状态闸门只住 level)。
func show_result(win: bool, on_button: Callable) -> void:
	if _level == null:
		return
	var ui_layer: CanvasLayer = _level.ui_layer
	var board = _level.board
	# 半透明遮罩(吃满屏点击, 防穿透到棋盘)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.01, 0.05, 0.72)
	veil.size = Vector2(DESIGN_W, DESIGN_H)
	veil.position = Vector2.ZERO
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(veil)
	# 居中面板(深紫底+金边, 复用 StyleBoxFlat 风格)
	var pw := 480.0
	var ph := 320.0
	var pc := Vector2(DESIGN_W * 0.5, DESIGN_H * 0.5)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.24, 0.98)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(5)
	sb.border_color = Color(0.88, 0.70, 0.32)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(pw, ph)
	panel.position = pc - Vector2(pw, ph) * 0.5
	ui_layer.add_child(panel)
	# 标题(金色)
	_label(ui_layer, "通关!" if win else "失败", pc + Vector2(0, -86), 56, COLOR_GOLD, pw)
	# 副信息: 分数 / 剩余步数
	_label(ui_layer, "得分 %d" % board.score, pc + Vector2(0, -20), 26, Color(1, 0.95, 0.82), pw)
	_label(ui_layer, "剩余步数 %d" % maxi(board.moves_left, 0), pc + Vector2(0, 18), 22, Color(0.85, 0.8, 0.95), pw)
	# 按钮(金底深字, 可点 Button): 通关→下一关 / 失败→重试本关
	var btn := Button.new()
	btn.text = "下一关" if win else "重试"
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_color_override("font_color", Color(0.16, 0.09, 0.04))
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.95, 0.80, 0.42)
	bsb.set_corner_radius_all(18)
	btn.add_theme_stylebox_override("normal", bsb)
	var bhsb := bsb.duplicate()
	bhsb.bg_color = Color(1.0, 0.88, 0.55)
	btn.add_theme_stylebox_override("hover", bhsb)
	btn.add_theme_stylebox_override("pressed", bhsb)
	var bw := 220.0
	var bh := 70.0
	btn.size = Vector2(bw, bh)
	btn.position = pc + Vector2(-bw * 0.5, 70.0)
	btn.pressed.connect(on_button.bind(win))
	ui_layer.add_child(btn)

# ───────── 步数显示 override(结算奖励演出期间 level 调) ─────────

func display_moves_left() -> int:
	if _moves_display_override >= 0:
		return _moves_display_override
	return _level.board.moves_left if (_level != null and _level.board != null) else 0

func set_moves_display_override(value: int) -> void:
	_moves_display_override = maxi(value, 0)
	if _topbar_moves_value_label != null and is_instance_valid(_topbar_moves_value_label):
		_topbar_moves_value_label.text = str(display_moves_left())

func clear_moves_display_override() -> void:
	_moves_display_override = -1
	if _topbar_moves_value_label != null and is_instance_valid(_topbar_moves_value_label):
		_topbar_moves_value_label.text = str(display_moves_left())

# ───────── 顶栏渲染(迁自 level.gd 顶栏簇, 行为零变化) ─────────

# 阶段6: ui_layer(顶栏+吊坠绳+目标卡+步数徽章+星级)整层重画。
func _render_ui_layer() -> void:
	_render_topbar_v2(_level._cur_cfg)

# v0.02: 米黄风格顶部状态栏(banner 横铺 + 绶带关卡号 + 星条 + 双目标 + 圆环头像 + 链/花装饰)。
# 换皮不动数据: 关卡号=cfg.id, 步数=board.moves_left, 目标=_objectives_view(), 星级=首颗金星覆盖底图槽位。
func _render_topbar_v2(cfg: Dictionary) -> void:
	var ui_layer: CanvasLayer = _level.ui_layer
	# v0.02: top_transparent.png 作顶栏底; 仅取顶栏主体区域, 满屏宽顶对齐。
	var tw: float = DESIGN_W
	var th: float = _topbar_height()
	var top_tex := _topbar_texture()
	if top_tex != null:
		var top := TextureRect.new()
		top.texture = top_tex
		top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		top.stretch_mode = TextureRect.STRETCH_SCALE
		top.position = Vector2(0.0, TOPBAR_Y_OFFSET)
		top.size = Vector2(tw, th)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(top)
	# 关卡号(左上红绶带)
	_label(ui_layer, "第 %d 关" % int(cfg.get("id", 1)), _topbar_level_label_center(), 22, Color(1, 0.97, 0.9), 150, 4, Color(0.45, 0.04, 0.04, 0.9))
	# 只绘制第一颗金星; 后两颗保留 top_transparent.png 自带的空槽。
	_sprite_w(ui_layer, LV_STAR_GOLD, _topbar_star_center(0, tw, th), 44.0, false)
	# 剩余步数(下方左格)
	var moves: int = display_moves_left()
	_label(ui_layer, "剩余步数", _topbar_moves_label_center(), 22, Color(0.235, 0.098, 0.039), 150, 0)
	_topbar_moves_value_label = _label(ui_layer, str(maxi(moves, 0)), _topbar_moves_number_center(), 44, Color(0.86, 0.18, 0.16), 135, 4, Color(1, 1, 1, 0.5))
	# 关卡目标(下方右格, 竖线 PIL实测 @0.30, 右格中心 0.60)
	var view: Array = _objectives_view()
	if view.is_empty():
		view = OBJECTIVES_DEMO
	var n: int = mini(view.size(), 3)
	_objective_progress_labels = []
	for i in range(n):
		var item: Dictionary = view[i]
		var slot: Dictionary = _topbar_objective_slot(i, n, tw, th)
		var icon_center: Vector2 = slot["icon"]
		var text_center: Vector2 = slot["text"]
		var icon_path: String = String(item.get("icon", ""))
		_sprite_fit(ui_layer, icon_path, icon_center, TB_OBJ_ICON_MAX, icon_path == BARRIER_ICE_ICON)
		var lbl := _label(ui_layer, _objective_counter_text(item), text_center, 30, Color(1, 1, 1), TB_OBJ_TEXT_W, 4, Color(0, 0, 0, 0.9))
		_objective_progress_labels.append(lbl)

func _topbar_texture() -> Texture2D:
	var tex := _load_texture(LV_TOP)
	if tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = LV_TOP_REGION
	return atlas

func _topbar_height() -> float:
	return DESIGN_W * LV_TOP_REGION.size.y / LV_TOP_REGION.size.x

func _topbar_point(uv: Vector2) -> Vector2:
	return Vector2(DESIGN_W * uv.x, TOPBAR_Y_OFFSET + _topbar_height() * uv.y)

func _topbar_level_label_center() -> Vector2:
	return _topbar_point(TB_LEVEL_LABEL_UV)

func _topbar_moves_label_center() -> Vector2:
	return _topbar_point(TB_MOVES_LABEL_UV)

func _topbar_moves_number_center() -> Vector2:
	return _topbar_point(TB_MOVES_NUMBER_UV)

func _topbar_star_center(index: int, tw: float, th: float) -> Vector2:
	var i: int = clampi(index, 0, TB_STAR_XS.size() - 1)
	return Vector2(tw * float(TB_STAR_XS[i]), TOPBAR_Y_OFFSET + th * TB_STAR_Y)

func _objective_counter_text(item: Dictionary) -> String:
	if item.has("n"):
		return String(item["n"])
	var target: int = int(item.get("target", 0))
	var progress: int = int(item.get("progress", 0))
	return str(maxi(target - progress, 0))

func _topbar_objective_slot(index: int, count: int, tw: float, th: float) -> Dictionary:
	var n: int = maxi(1, mini(count, 3))
	var center_x: float = tw * 0.62 + (float(index) - float(n - 1) * 0.5) * TB_OBJ_SLOT_GAP
	var y: float = TOPBAR_Y_OFFSET + th * TB_OBJ_Y_UV
	return {
		"icon": Vector2(center_x - TB_OBJ_ICON_TEXT_GAP * 0.5, y),
		"text": Vector2(center_x + TB_OBJ_ICON_TEXT_GAP * 0.5, y),
	}

# 阶段6: 遍历 board.objectives 产出目标卡视图数据(图标+进度+目标)。
# type→进度取值: COLLECT 用 collected[species]; 其余障碍类用对应 *_cleared/*_collected/... 计数器。
func _objective_label(t: String) -> String:
	match t:
		"COLLECT":
			return "收集"
		"CLEAR_JELLY":
			return "清果冻"
		"CLEAR_BLOCKER":
			return "涂层"
		"CLEAR_CHOCO":
			return "巧克力"
		"COLLECT_INGREDIENT":
			return "原料"
		"DEFUSE_BOMB":
			return "炸弹"
		"POP_POPCORN":
			return "爆米花"
		"DESTROY_CAKE":
			return "蛋糕"
		"REVEAL_MYSTERY":
			return "神秘"
		"SCORE":
			return "分数"
		_:
			return ""

func _objectives_view() -> Array:
	var out: Array = []
	var board = _level.board if _level != null else null
	if board == null or board.objectives == null:
		return out
	if board.objectives.is_empty():
		if board.target_score > 0:
			out.append({"icon": STAR_GOLD, "label": _objective_label("SCORE"), "progress": mini(board.score, board.target_score), "target": board.target_score})
		return out
	for o in board.objectives:
		var t: String = String(o.get("type", ""))
		var sp: int = int(o.get("species", -1))
		var target: int = int(o.get("target", 0))
		var icon: String = OBJ_PLACEHOLDER_ICON
		var progress: int = 0
		match t:
			"COLLECT":
				if sp >= 0 and sp < GEM_TEXTURES.size():
					icon = GEM_TEXTURES[sp]
				progress = int(board.collected.get(sp, 0))
			"CLEAR_JELLY":
				if ResourceLoader.exists(JELLY_GOAL_ICON):
					icon = JELLY_GOAL_ICON
				progress = board.jelly_cleared
			"CLEAR_BLOCKER":
				if ResourceLoader.exists(BARRIER_ICE_ICON):
					icon = BARRIER_ICE_ICON
				progress = board.blocker_cleared
			"CLEAR_CHOCO":
				progress = board.choco_cleared
			"COLLECT_INGREDIENT":
				progress = board.ingredient_collected
			"DEFUSE_BOMB":
				progress = board.bomb_defused
			"POP_POPCORN":
				progress = board.popcorn_hit
			"DESTROY_CAKE":
				progress = board.cake_destroyed
			"REVEAL_MYSTERY":
				progress = board.mystery_revealed
			"SCORE":
				progress = board.score
			_:
				progress = 0
		# 进度封顶到 target(已达成不显示溢出, 如 25/21 → 21/21)。
		out.append({"icon": icon, "label": _objective_label(t), "progress": mini(progress, target), "target": target})
	return out

# ───────── 共享渲染 helper 转发(实现留 level.gd, board_view 二期也复用) ─────────

func _clear_layer(layer: CanvasLayer) -> void:
	_level._clear_layer(layer)

func _label(layer: CanvasLayer, text: String, center: Vector2, font_size: int, color: Color, box_w: float, outline_size: int = 5, outline_color: Color = Color(0, 0, 0, 0.7)) -> Label:
	return _level._label(layer, text, center, font_size, color, box_w, outline_size, outline_color)

func _sprite_w(layer: CanvasLayer, path: String, center: Vector2, width: float, use_key: bool) -> Sprite2D:
	return _level._sprite_w(layer, path, center, width, use_key)

func _sprite_fit(layer: CanvasLayer, path: String, center: Vector2, max_size: float, use_key: bool) -> Sprite2D:
	return _level._sprite_fit(layer, path, center, max_size, use_key)

func _load_texture(path: String) -> Texture2D:
	return _level._load_texture(path)
