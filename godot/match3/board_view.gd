class_name BoardView
extends Node
## 棋盘视图子控制器（契约 E, docs/11 §6 / 附录A）。
##
## 从 level.gd 抽出"棋子节点所有权 + 渲染 + 增量同步 + 墙滑视觉 + 站立特效 + 选中态"。
## 行为零变化——所有渲染/同步/墙滑/特效逻辑原样平移自旧 level.gd（计算仍在 level_motion）。
##
## 生命周期：作为 level 的子 Node（铁律2），换关随 level 子树存活；tween 经 create_tween 绑自身。
## 状态闸门（_busy/_settled/generation）只住 level（铁律1），本类只渲染、只读 board。
##
## 所有权：`_gem_nodes` 私有化，外界经 `node_at(cell)` 点访问 / `gem_nodes()` 取整阵（开局演出用）。
##   level 的级联主循环/try_swap/彩球/融合仍编排节拍，节点增删/换/叠 shine 经本类接口。
##
## 注入：level 引用（读 live gem_layer/board_layer + 共享 helper），board/cell_size/board_origin
##   经 rebuild() 同步（level 在 _compute_layout 后传入；本类持自己的副本供渲染计算）。
##
## overlay 消费（契约 B §3.3）：建格/增量同步处经 OverlayRegistry.ensure_overlays_at 维护障碍 overlay；
##   StepReport 分发经 OverlayRegistry.broadcast_step。本类只消费 registry 接口，不改 registry 文件。

const ME := preload("res://core/match_engine.gd")
const ClearVisuals := preload("res://match3/clear_visuals.gd")
const LevelLayout := preload("res://match3/level_layout.gd")
const LevelMotion := preload("res://match3/level_motion.gd")
const OverlayRegistry := preload("res://match3/overlays/overlay_registry.gd")
const ObjectiveIcons := preload("res://match3/objective_icons.gd")

# ── 棋子/障碍渲染常量（迁自 level.gd 棋盘渲染簇）──
const GEM_COLORS := {
	# 从宝石贴图实采的主体色(高饱和中亮像素均值), 与宝石一致
	"red": Color(0.691, 0.108, 0.048), "blue": Color(0.052, 0.297, 0.789),
	"green": Color(0.373, 0.635, 0.045), "gold": Color(0.746, 0.426, 0.058),
	"purple": Color(0.326, 0.061, 0.728), "pink": Color(0.780, 0.120, 0.411),
}
const GEM_KEYS := ["red", "blue", "green", "gold", "purple", "pink"]  # species 顺序→宝石色(同 GEM_TEXTURES)
const GEM_TEXTURES := [
	"res://art/gems/base/gem_ruby.png", "res://art/gems/base/gem_water.png",
	"res://art/gems/base/gem_clover.png", "res://art/gems/base/gem_star.png",
	"res://art/gems/base/gem_orb.png", "res://art/gems/base/heart_neon.png",
]
const GEM_SHADOW_COLOR := Color(0.10, 0.08, 0.16, 0.28)
# v0.02: 各棋子图案占整图比例不同(PIL实测), 按 1/max(宽高占比) 补偿 scale, 统一视觉大小。
# species 顺序: 0红方块 1蓝水滴 2绿四叶 3金星 4紫月 5粉心
const GEM_CONTENT_COMP := [1.16, 1.16, 0.84, 1.28, 1.25, 0.88]  # 实体统一(PIL测; greenx→0.84, 粉色素材填满显大→压到0.88)
const GEM_TINT := [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]  # green_new 素材已降白点, 不再用 modulate 压
const GEM_SATURATION := 0.86  # 实验: 棋盘宝石整体降一点饱和度, 不改原图
const GEM_SATURATION_SHADER := "res://match3/gem_saturation.gdshader"
const COLORBOMB_CORE := "res://assets/level/diamond_white.png"  # v0.02 单张 5 合 1 白钻球
const COLORBOMB_INNER_LIGHT_SHADER := "res://match3/colorbomb_inner_light.gdshader"
const COLORBOMB_INNER_LIGHT_NAME := "InnerLight"
const COLORBOMB_LAYER_NAMES := [COLORBOMB_INNER_LIGHT_NAME, "FlowingRim", "GoldGroundGlow", "CoreInnerSwirl", "CoreInnerStars", "CubeRing"]
const COLORBOMB_INNER_LIGHT_COLORS := [
	Color(1.0, 0.10, 0.08, 0.48),  # red
	Color(0.16, 0.92, 0.22, 0.46), # green
	Color(0.56, 0.20, 1.0, 0.48),  # purple
	Color(1.0, 0.24, 0.76, 0.46),  # pink
	Color(1.0, 0.88, 0.14, 0.42),  # yellow
	Color(0.12, 0.54, 1.0, 0.48),  # blue
]
const COLORBOMB_INNER_LIGHT_RADIUS := 0.36
const COLORBOMB_INNER_LIGHT_SECONDS := 0.56
# v0.02: 特殊棋子站立特效(替换旧 shine 静态光贴图) —— 姿态循环动画 + 本体高光。
# 消除方向=运动轴: 横=左右挤压摇头 / 纵=上下挤压点头 / 十字(SP_BOMB)=全向脉冲(最强)。
# 动画相对棋子"基础 scale"做乘法；十字只提亮棋子本体，不额外加外圈白光。
const COMBO_GLOW_NAME := "combo_glow"      # 兼容旧版本残留的白光子节点名，停止特效时清掉
# 横/纵 挤压摇摆(单轴): 慢悠悠 idle, 相对 base 的幅度
const COMBO_SWING_AMP := 0.14              # 转头时沿轴收窄幅度(相对base; 端点最窄)
const COMBO_SWING_WIDEN := 0.025           # 过中间(正面)时沿轴轻微鼓出, 避免 4 合 1 idle 摇晃过大
const COMBO_VERTICAL_SCALE_AMP := 0.075     # 纵向点头只轻微压 y, 避免水滴/心形读成左右晃或过度变形
const COMBO_VERTICAL_SCALE_WIDEN := 0.012   # 纵向回正时很轻的 y 轴鼓出
const COMBO_SWING_OFFSET := 3.0            # 小幅视觉偏移, 让对称素材也能读出左/右或上/下方向
const COMBO_VERTICAL_SWING_OFFSET := 1.8   # 纵向点头更克制, 避免水滴/蓝宝石读成单向上翘
# 十字(SP_BOMB): 心跳节奏(lub-dub-rest)。第一下更大, 第二下更小, 都是快起快落, 最后留休止。
const COMBO_HEARTBEAT_FIRST_AMP := 0.16    # 第一跳(lub)峰值, 稍大一点才像心脏先重击
const COMBO_HEARTBEAT_SECOND_AMP := 0.09   # 第二跳(dub)峰值, 小于第一跳形成节奏差
const COMBO_HEARTBEAT_UP := 0.12           # 快速鼓起, 避免慢慢膨胀
const COMBO_HEARTBEAT_DOWN := 0.10         # 快速回落
const COMBO_HEARTBEAT_GAP := 0.07          # 两跳之间的短间隔
const COMBO_HEARTBEAT_REST := 0.58         # 第二跳后的长休止, 读成心跳而不是连续呼吸
# v0.02: 十字站立特效用「暖金提亮」(同点击选中 _select 的发光), 放大时亮、缩回原色。
const COMBO_BRIGHTEN := Color(1.5, 1.42, 1.18)  # 恒定暖金提亮(首轮随第1次放大淡入, 之后整轮保持)
# 横/纵: 方向性中性白高光(光在哪侧=朝哪侧转), 取代无方向感的整体提亮。
const DIR_GLOW_SHADER := "res://match3/directional_glow.gdshader"
const COMBO_LIGHT_STRENGTH := 1.65         # 高光强度(够强才压过棋子美术自带明暗, 方向清晰)
const COMBO_LIGHT_W := 0.30                 # 高光半宽(越小一侧亮一侧暗对比越强)
const COMBO_LIGHT_TINT := Color(1.0, 1.0, 1.0)  # 中性白光, 避免蓝色 4 合 1 被暖色重染成紫
const COMBO_LIGHT_SWING := 0.40            # 光泽相对中心(0.5)的扫动振幅 → 钟摆于 [0.10, 0.90]
const COMBO_SWING_CYCLE := 1.7             # 一个完整摇动来回(钟摆正弦)时长(秒)
const COMBO_RIM_STRENGTH := 0.28           # 伪 3D: 边缘光补出厚度
const COMBO_BULGE_STRENGTH := 0.86         # 伪 3D: 高光按弧面鼓起分布
const COMBO_SPECULAR_STRENGTH := 0.34      # 伪 3D: 白色镜面小热点, 强化宝石弧面
const CELL_SQ := "res://assets/level/cell_sq.png"            # v0.02 米黄圆角棋格(cell.png 128²)
# ── 魔法书棋盘外框(book_frame 9-slice + 书页内框) ──
const BOOK_FRAME := "res://assets/level/book_frame.png"      # v0.02 魔法书主体(982×980, 9-slice缩放适配棋盘)
const BOOK_RIBBONS := "res://assets/level/book_ribbons.png"  # v0.02 书底书签(982×77, 与 book_frame 同宽)
const BOOK_NINE_ML := 54    # 9-slice margin(≥内边线inset, 保金框/四角花不变形)
const BOOK_NINE_MT := 28
const BOOK_NINE_MB := 58
const BOOK_INNER_INLAY_NODE := "BookInnerInlay"
const BOOK_INLAY_MASK_LEFT_NODE := "BookInlayMaskLeft"
const BOOK_INLAY_MASK_RIGHT_NODE := "BookInlayMaskRight"
const BOOK_INLAY_MASK_BLEED := 8.0
const BOOK_PAGE_PATCH_LEFT_REGION := Rect2(130, 108, 64, 760)
const BOOK_PAGE_PATCH_RIGHT_REGION := Rect2(788, 108, 64, 760)
const BOOK_PAGE_PATCH_COLOR := Color(0.99, 0.86, 0.58, 1.0)
const BOOK_INLAY_COLOR := Color(0.72, 0.49, 0.18, 0.70)
const BOOK_INLAY_HIGHLIGHT := Color(1.0, 0.86, 0.42, 0.42)
const BARRIER_ICE_ICON := "res://assets/obstacles/ob_ice.png"  # synced from resources/barrier/ob_ice.png
const BARRIER_MARKER_NAME := "CoatBarrierSprite"
const BARRIER_FILL := 0.88  # 单格障碍：略大于普通宝石、略小于石头，避免多冰块互相叠成大贴纸。
const JELLY_MARKER_NAME := "JellyGoalSprite"
const JELLY_FILL := 0.94
const JELLY_TINT := Color(0.46, 0.82, 1.0, 0.26)
const JELLY_ICON_MODULATE := Color(1.0, 1.0, 1.0, 0.84)
const DROP_EXIT_MARKER_NAME := "DropExitSprite"
const DROP_EXIT_FILL := 0.84
const WALL_STONE_ICON := "res://assets/obstacles/ob_stone.png"
const WALL_MARKER_NAME := "WallStoneSprite"
const WALL_FILL := 0.90

const CELL_FILL := 1.0          # 格子填满格位
const GEM_FILL := 0.84
const COLORBOMB_FILL := 0.74  # v0.02 彩球略小一点, 避免 5 合 1 压住相邻格
const OPENING_DROP_ROW_STAGGER := 0.045  # 开局掉落起始位用(节拍/序在 level)

# ── 普通三消基础爆炸节拍（2026-06-10 magic basic pop）──
const BASIC_CLEAR_TIME := 0.156
const BASIC_CLEAR_POP_TIME := 0.117
const BASIC_CLEAR_POP_SCALE := 1.25
const BASIC_CLEAR_SHRINK_SCALE := 0.1

# ── 消除演出节拍常量（_play_clear 用，gem_shatter_white_v3 烟花式规格，与 Fx.SHATTER_* 对表）──
const CLEAR_SWELL_TIME := 0.08   # 本体膨胀(撑爆前奏, TRANS_BACK 弹性)
const CLEAR_SWELL_SCALE := 1.25
const CLEAR_WHITE_PUSH := 2.4    # 膨胀期 self_modulate 过曝倍率(向白推, 读作"内部蓄能")
const CLEAR_BREAK_AT := 0.08     # 崩拍: 膨胀到位即崩, shatter_01 大闪光在 Fx 同拍起播
const CLEAR_BODY_HIDE_DELAY := 0.02  # 本体在崩拍后一渲染帧隐藏——切换藏在闪光底下(v3 规格)
const CLEAR_FX_BATCH_SIZE := 8
const LINE_CLEAR_STAGGER := 0.026  # 横/竖炸路径碎裂按触发点向外错峰, 0.02s * 1.3
const ELIM_HOLD := 0.08  # 崩拍即放行下落(v3)——碎块烟花与棋子下落并行(跟手感契约, 不等碎块播完)
const SWAP_TIME := 0.14

# ── 注入上下文 ──
var _level = null   # level.gd 实例(读 live gem_layer/board_layer + 共享 helper)

# ── 棋盘渲染状态(本类持自己的 board/几何副本, 渲染计算用)──
var board                       # core/board.gd 实例, 只读
var cell_size: float = 0.0
var board_origin: Vector2

# ── 节点所有权(私有化, 外界经 node_at 访问)──
var _gem_nodes: Array = []
var _jelly_nodes: Array = []
var _coat_nodes: Array = []
var _wall_nodes: Array = []
var _exit_nodes: Array = []
var _overlay_nodes: Dictionary = {}   # 契约B: {[key,cell] -> OverlayBase}, board_view 持有

# ── 选中态视觉(选中坐标/路由仍在 level; 这里只管视觉)──
var _sel_node: Sprite2D = null  # 当前选中的棋子节点(放大提亮置顶)
var _sel_node_scale := Vector2.ONE
var _sel_node_mod := Color.WHITE

# ── 缓存材质/着色器 ──
var _dir_glow_shader: Shader = null  # 横/纵摇头点头的方向性高光 shader(缓存资源)
var _gem_saturation_shader: Shader = null
var _gem_saturation_mat: ShaderMaterial = null
var _colorbomb_inner_light_shader: Shader = null

func setup(level) -> void:
	_level = level

## 同步 board/几何副本（level._compute_layout 后调；渲染/墙滑计算用本类自己的副本）。
func sync_geometry(p_board, p_cell_size: float, p_board_origin: Vector2) -> void:
	board = p_board
	cell_size = p_cell_size
	board_origin = p_board_origin

# ───────── 共享 helper 转发(留在 level, 与 hud/skills 同口径)──────────

func _asset_exists(path: String) -> bool:
	return _level._asset_exists(path)

func _load_texture(path: String) -> Texture2D:
	return _level._load_texture(path)

func _fit_scale(tex: Texture2D, target: float) -> Vector2:
	return _level._fit_scale(tex, target)

func _magenta_material() -> ShaderMaterial:
	return _level._magenta_material()

func _clear_layer(layer: CanvasLayer) -> void:
	_level._clear_layer(layer)

func _gem_layer() -> CanvasLayer:
	return _level.gem_layer

func _board_layer() -> CanvasLayer:
	return _level.board_layer

## species → 特效染色(取宝石色并提亮便于可见)。
func _fx_color(sp: int) -> Color:
	return _level._fx_color(sp)

## species → 宝石饱和原色(不提亮)。碎裂粒子专用。
func _gem_raw_color(sp: int) -> Color:
	return _level._gem_raw_color(sp)

func _line_fx_color(sp: int) -> Color:
	return _level._fx_color(sp)

# ───────── 契约 E 接口面（全部 await 友好）──────────

## 全量重建（换关/回退/施法落地后）。同步 board/几何副本并重画整盘。
func rebuild(p_board, p_cell_size: float = -1.0, p_board_origin = null, opening_drop: bool = false) -> void:
	board = p_board
	if p_cell_size >= 0.0:
		cell_size = p_cell_size
	else:
		cell_size = _level.cell_size
	if p_board_origin != null:
		board_origin = p_board_origin
	else:
		board_origin = _level.board_origin
	_render_board(opening_drop)

## 受控访问（替代直摸 _gem_nodes）。
func node_at(cell: Vector2i) -> Sprite2D:
	if cell.y < 0 or cell.y >= _gem_nodes.size():
		return null
	var row = _gem_nodes[cell.y]
	if not (row is Array) or cell.x < 0 or cell.x >= row.size():
		return null
	return row[cell.x]

## 整阵只读访问（开局掉落演出节拍仍在 level, 经此取节点; P6 迁入 opening director 后由其持引用）。
func gem_nodes() -> Array:
	return _gem_nodes

func coat_nodes() -> Array:
	return _coat_nodes

## 开局演出节拍（仍在 level, P6 迁入 director）需要的几何/格集访问。
func coat_marker_position(row: int, col: int) -> Vector2:
	return _coat_marker_position(row, col)

func opening_wall_cells() -> Array:
	return _opening_wall_cells()

func cell_center(row: int, col: int) -> Vector2:
	return _cell_center(row, col)

## 清掉某格节点并置空（级联/彩球/融合/龙息消除时调）。
func clear_node_at(cell: Vector2i) -> void:
	var n: Sprite2D = node_at(cell)
	if cell.y >= 0 and cell.y < _gem_nodes.size() and _gem_nodes[cell.y] is Array and cell.x >= 0 and cell.x < _gem_nodes[cell.y].size():
		_gem_nodes[cell.y][cell.x] = null
	if n != null and is_instance_valid(n):
		n.queue_free()

## 交换两格节点引用（try_swap/fusion 提交交换时调）。
func swap_nodes(a: Vector2i, b: Vector2i) -> void:
	var na: Sprite2D = node_at(a)
	var nb: Sprite2D = node_at(b)
	_gem_nodes[a.y][a.x] = nb
	_gem_nodes[b.y][b.x] = na

## 选中态：放大提亮置顶。
func set_selected(cell: Vector2i) -> void:
	var n: Sprite2D = node_at(cell)
	if n == null or not is_instance_valid(n):
		return
	_sel_node = n
	_sel_node_scale = n.scale
	_sel_node_mod = n.modulate
	n.scale = _sel_node_scale * 1.25       # 放大
	n.modulate = Color(1.5, 1.42, 1.18)    # 提亮(暖金光)
	n.z_index = 20                          # 置顶, 不被相邻棋子盖住(修"偶尔不显示")

## 清除选中态视觉（复原 scale/modulate/z）。
func clear_selected() -> void:
	if _sel_node != null and is_instance_valid(_sel_node):
		_sel_node.scale = _sel_node_scale
		_sel_node.modulate = _sel_node_mod
		_sel_node.z_index = 0
	_sel_node = null

## 交换/回弹动画（async）。
func play_swap(na: Sprite2D, nb: Sprite2D, to_a: Vector2, to_b: Vector2) -> void:
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

## 契约A 演出执行（async）：消除动画 + 落特效/清格节点同步 + 下落补充。
## level 的级联循环组装 report、推进 board、分发 hud/skills/overlays 后, await 本方法。
## 入参与旧 _resolve_cascades 内联段一致(行为零变化)。
func play_step(report: Dictionary, raw_special_fx_cells: Dictionary, clear_visual_timing: Dictionary) -> void:
	var to_clear: Array = report["to_clear"]
	var spawns: Array = report["spawns"]
	var protected_spawn_set: Dictionary = report["protected_spawns"]
	var triggered_spawn_set: Dictionary = report.get("triggered_spawns", {})
	# overlays 消费(契约B §3.3): 障碍演出消费者读 report 自播(不阻塞主循环)。
	OverlayRegistry.broadcast_step(_overlay_nodes, report)
	await _play_clear(to_clear, spawns, protected_spawn_set, raw_special_fx_cells, clear_visual_timing)
	# 引擎执行清除: spawn 格落特效(保留 species), 其余格 grid=EMPTY/fx=SP_NONE
	ME._apply_clears(board.grid, board.fx, to_clear, spawns, triggered_spawn_set)
	# 节点同步: 非 spawn 格删节点置 null; spawn 格给节点叠 shine(此时 board.fx 已是新 kind)
	var cleared_this_step := {}
	for p in to_clear:
		cleared_this_step[p] = true
		if protected_spawn_set.has(p):
			_apply_fx_overlay(_gem_nodes[p.y][p.x], board.fx[p.y][p.x])
		else:
			var n: Sprite2D = _gem_nodes[p.y][p.x]
			if n != null and is_instance_valid(n):
				n.queue_free()
			_gem_nodes[p.y][p.x] = null
	for p in protected_spawn_set:
		if not cleared_this_step.has(p):
			_apply_fx_overlay(_gem_nodes[p.y][p.x], board.fx[p.y][p.x])
	await _collapse_and_refill()

# ───────── 几何 ─────────

func _cell_center(row: int, col: int) -> Vector2:
	return LevelLayout.cell_center(row, col, cell_size, board_origin)

func _layer_value(layer: Array, row: int, col: int) -> int:
	if layer.is_empty() or row < 0 or row >= layer.size():
		return 0
	var row_data = layer[row]
	if not (row_data is Array) or col < 0 or col >= row_data.size():
		return 0
	return int(row_data[col])

func _cell_has_ingredient(row: int, col: int) -> bool:
	return board != null and _layer_value(board.ing, row, col) > 0

func _visual_species_for_cell(row: int, col: int) -> int:
	if board == null:
		return ME.EMPTY
	if _cell_has_ingredient(row, col):
		return ME.EMPTY
	return int(board.grid[row][col])

# ───────── 整盘渲染 ─────────

func _render_board(opening_drop: bool = false) -> void:
	_clear_layer(_board_layer())
	_clear_layer(_gem_layer())
	_jelly_nodes = []
	_coat_nodes = []
	_wall_nodes = []
	_exit_nodes = []
	_clear_overlay_nodes()
	_render_board_panel()
	_gem_nodes = []
	var cell_tex: Texture2D = load(CELL_SQ) if ResourceLoader.exists(CELL_SQ) else null
	for r in range(board.height):
		var node_row: Array = []
		for c in range(board.width):
			var center: Vector2 = _cell_center(r, c)
			# v0.02: 米黄圆角棋格(cell_sq.png), 半透叠魔法书页上
			if cell_tex != null:
				var cs := Sprite2D.new()
				cs.texture = cell_tex
				cs.position = center
				cs.scale = _fit_scale(cell_tex, cell_size * CELL_FILL)
				cs.modulate = Color(1, 1, 1, 0.5)
				_board_layer().add_child(cs)
			var visual_sp: int = ME.EMPTY if _cell_has_ingredient(r, c) else (_opening_visual_species(r, c) if opening_drop else _visual_species_for_cell(r, c))
			var gnode: Sprite2D = _make_gem(visual_sp, center)
			if gnode != null and opening_drop:
				gnode.position = _opening_drop_start_position(center, r)
			# 阶段5: 若该格已是特效棋子(交换后/续局), 叠 shine 标记
			if gnode != null and board.fx[r][c] != ME.SP_NONE:
				_apply_fx_overlay(gnode, board.fx[r][c])
			node_row.append(gnode)
		_gem_nodes.append(node_row)
	_render_drop_exit_visuals()
	_render_jelly_visuals()
	if opening_drop:
		_wall_nodes = _blank_visual_rows()
	else:
		_render_wall_visuals()
	if opening_drop:
		_render_opening_coat_visuals()
	else:
		_render_coat_visuals()
	_rebuild_overlay_nodes()

# ── 书框几何(LevelLayout 委派；本类持自己的 board/几何副本)──
func _board_cell_size_for_grid(cols: int, rows: int) -> float:
	return LevelLayout.board_cell_size_for_grid(cols, rows)

func _book_frame_width_for_board() -> float:
	return LevelLayout.book_frame_width_for_board()

func _book_frame_rect() -> Rect2:
	return LevelLayout.book_frame_rect(board.height, cell_size, board_origin)

func _book_baked_inner_rect() -> Rect2:
	return LevelLayout.book_baked_inner_rect(board.height, cell_size, board_origin)

func _book_board_inner_rect() -> Rect2:
	return LevelLayout.book_board_inner_rect(board.width, board.height, cell_size, board_origin)

func _render_board_panel() -> void:
	# v0.02: 魔法书主体 book_frame 用 9-slice —— 四角装饰(~37px)+金框/书脊不变形, 只拉书页中段;
	#        书页内框(左右38/顶≈角38/底44)对齐棋格。书签与书框同宽, 上沿贴书框下沿。
	var book_rect := _book_frame_rect()
	var center := book_rect.position + book_rect.size * 0.5
	_nine(_board_layer(), BOOK_FRAME, center, book_rect.size.x, book_rect.size.y, BOOK_NINE_ML, BOOK_NINE_MT, BOOK_NINE_MB)
	_render_book_inner_inlay()
	if _asset_exists(BOOK_RIBBONS):
		var rib_tex: Texture2D = _level._load_texture_from_file(BOOK_RIBBONS)
		if rib_tex == null:
			return
		var rib := NinePatchRect.new()
		rib.name = "BookRibbons"
		rib.texture = rib_tex
		var rw: float = book_rect.size.x
		var rh: float = rw * float(rib_tex.get_height()) / float(rib_tex.get_width())
		rib.size = Vector2(rw, rh)
		rib.position = Vector2(center.x - rw * 0.5, book_rect.position.y + book_rect.size.y)
		rib.patch_margin_left = BOOK_NINE_ML
		rib.patch_margin_right = BOOK_NINE_ML
		rib.patch_margin_top = 0
		rib.patch_margin_bottom = 0
		rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board_layer().add_child(rib)

func _render_book_inner_inlay() -> void:
	var baked := _book_baked_inner_rect()
	var target := _book_board_inner_rect()
	if target.size.x <= 0.0 or target.size.y <= 0.0:
		return
	if absf(target.position.x - baked.position.x) <= 0.5 \
			and absf(target.position.y - baked.position.y) <= 0.5 \
			and absf(target.size.x - baked.size.x) <= 0.5 \
			and absf(target.size.y - baked.size.y) <= 0.5:
		return
	var left_gap: float = target.position.x - baked.position.x
	if left_gap > 0.5:
		_book_inlay_mask(
			BOOK_INLAY_MASK_LEFT_NODE,
			Rect2(
				Vector2(baked.position.x - BOOK_INLAY_MASK_BLEED, baked.position.y - BOOK_INLAY_MASK_BLEED),
				Vector2(left_gap + BOOK_INLAY_MASK_BLEED, baked.size.y + BOOK_INLAY_MASK_BLEED * 2.0)
			)
		)
	var right_gap: float = baked.end.x - target.end.x
	if right_gap > 0.5:
		_book_inlay_mask(
			BOOK_INLAY_MASK_RIGHT_NODE,
			Rect2(
				Vector2(target.end.x, baked.position.y - BOOK_INLAY_MASK_BLEED),
				Vector2(right_gap + BOOK_INLAY_MASK_BLEED, baked.size.y + BOOK_INLAY_MASK_BLEED * 2.0)
			)
		)

	var inlay := Panel.new()
	inlay.name = BOOK_INNER_INLAY_NODE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = BOOK_INLAY_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	inlay.add_theme_stylebox_override("panel", style)
	inlay.position = target.position
	inlay.size = target.size
	inlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inlay.z_index = 30
	_board_layer().add_child(inlay)

	var highlight := Panel.new()
	highlight.name = "%sHighlight" % BOOK_INNER_INLAY_NODE
	var hi_style := StyleBoxFlat.new()
	hi_style.bg_color = Color.TRANSPARENT
	hi_style.border_color = BOOK_INLAY_HIGHLIGHT
	hi_style.set_border_width_all(1)
	hi_style.set_corner_radius_all(4)
	highlight.add_theme_stylebox_override("panel", hi_style)
	highlight.position = target.position + Vector2(2.0, 2.0)
	highlight.size = target.size - Vector2(4.0, 4.0)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.z_index = 31
	_board_layer().add_child(highlight)

func _book_inlay_mask(node_name: String, rect: Rect2) -> void:
	var patch := _book_page_patch_texture(node_name == BOOK_INLAY_MASK_LEFT_NODE)
	if patch != null:
		var mask := TextureRect.new()
		mask.name = node_name
		mask.texture = patch
		mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mask.stretch_mode = TextureRect.STRETCH_SCALE
		mask.position = rect.position
		mask.size = rect.size
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board_layer().add_child(mask)
		return
	var fallback := ColorRect.new()
	fallback.name = node_name
	fallback.color = BOOK_PAGE_PATCH_COLOR
	fallback.position = rect.position
	fallback.size = rect.size
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_layer().add_child(fallback)

func _book_page_patch_texture(left: bool) -> Texture2D:
	var base: Texture2D = load(BOOK_FRAME) if ResourceLoader.exists(BOOK_FRAME) else _level._load_texture_from_file(BOOK_FRAME)
	if base == null:
		return null
	var patch := AtlasTexture.new()
	patch.atlas = base
	patch.region = BOOK_PAGE_PATCH_LEFT_REGION if left else BOOK_PAGE_PATCH_RIGHT_REGION
	return patch

## NinePatch 素材(金框/横幅/底纹),四边 patch_margin。
func _nine(layer: CanvasLayer, path: String, center: Vector2, w: float, h: float, ml: int, mt: int, mb: int) -> void:
	if not ResourceLoader.exists(path):
		return
	var np := NinePatchRect.new()
	np.texture = load(path)
	np.position = center - Vector2(w, h) * 0.5
	np.size = Vector2(w, h)
	np.patch_margin_left = ml
	np.patch_margin_right = ml
	np.patch_margin_top = mt
	np.patch_margin_bottom = mb
	layer.add_child(np)

func _blank_visual_rows() -> Array:
	var rows := []
	for r in range(board.height):
		var row := []
		for c in range(board.width):
			row.append(null)
		rows.append(row)
	return rows

func _opening_visual_species(row: int, col: int) -> int:
	var sp: int = board.grid[row][col]
	if _layer_value(board.coat, row, col) > 0:
		return ME.EMPTY
	if sp >= 0:
		return sp
	if board.species.is_empty():
		return sp
	if sp != ME.WALL:
		return sp
	return int(board.species[abs(row * 31 + col * 17) % board.species.size()])

func _opening_drop_start_position(final_center: Vector2, row: int) -> Vector2:
	return final_center - Vector2(0.0, cell_size * float(row + 1.5))

func _opening_wall_cells() -> Array:
	var cells := []
	for r in range(board.height):
		for c in range(board.width):
			if board.grid[r][c] == ME.WALL:
				cells.append(Vector2i(c, r))
	return cells

## 开局石头标记（boss 施法时由 level 的开局演出调）。animate=true 弹入。
func show_opening_wall_marker(pos: Vector2i, animate: bool) -> void:
	clear_node_at(pos)
	if _wall_nodes.is_empty():
		_wall_nodes = _blank_visual_rows()
	var tex := _load_texture(WALL_STONE_ICON) if _asset_exists(WALL_STONE_ICON) else null
	if tex == null:
		return
	var marker := _make_wall_marker(pos.y, pos.x, tex)
	_wall_nodes[pos.y][pos.x] = marker
	if marker == null or not animate or not is_inside_tree():
		return
	var base_scale: Vector2 = marker.scale
	marker.modulate.a = 0.0
	marker.scale = base_scale * 0.55
	var t := create_tween().set_parallel(true)
	t.tween_property(marker, "modulate:a", 1.0, 0.16)
	t.tween_property(marker, "scale", base_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_gem(sp: int, center: Vector2) -> Sprite2D:
	if sp < 0 or sp >= GEM_TEXTURES.size() or not _asset_exists(GEM_TEXTURES[sp]):
		return null
	var tex := _load_texture(GEM_TEXTURES[sp])
	if tex == null:
		return null
	var gs := Sprite2D.new()
	gs.texture = tex
	gs.position = center
	gs.scale = _fit_scale(tex, cell_size * GEM_FILL) * GEM_CONTENT_COMP[sp]
	gs.modulate = GEM_TINT[sp]  # v0.02 绿棋子降高光白点(其余白色不变)
	gs.material = _gem_saturation_material()
	gs.set_meta("species", sp)
	gs.set_meta("fx", ME.SP_NONE)
	_attach_shape_shadow(gs, tex)  # v0.02: 统一棋子形状阴影(自身纹理染黑)
	_gem_layer().add_child(gs)
	return gs

# v0.02: 统一棋子形状阴影 —— 用本体纹理染成轻软暗紫灰(同形状)×0.85, 下偏移一丢丢, 居本体下层半透。
# 复用已存在的 "shadow" 子节点(无则新建)。普通棋子 / 冰块 / 5合1彩球共用同一套逻辑。
func _attach_shape_shadow(node: Sprite2D, tex: Texture2D) -> void:
	var sh: Sprite2D = node.get_node_or_null("shadow")
	if sh == null:
		sh = Sprite2D.new()
		sh.name = "shadow"
		node.add_child(sh)
	sh.texture = tex
	sh.z_index = -1
	sh.scale = Vector2(0.85, 0.85)
	sh.position = Vector2(0.0, (cell_size * 0.14) / (node.scale.y if node.scale.y != 0.0 else 1.0))
	sh.modulate = GEM_SHADOW_COLOR

func _free_layer_visual_rows(rows: Array) -> void:
	for row in rows:
		for node in row:
			if node != null and is_instance_valid(node):
				node.queue_free()

func _refresh_coat_visuals() -> void:
	_free_layer_visual_rows(_coat_nodes)
	_render_coat_visuals()

func _refresh_jelly_visuals() -> void:
	_free_layer_visual_rows(_jelly_nodes)
	_render_jelly_visuals()

func _refresh_wall_visuals() -> void:
	_free_layer_visual_rows(_wall_nodes)
	_render_wall_visuals()

func _render_jelly_visuals() -> void:
	_jelly_nodes = []
	if board == null or _board_layer() == null:
		return
	for r in range(board.height):
		var row: Array = []
		for c in range(board.width):
			row.append(_make_jelly_marker(r, c))
		_jelly_nodes.append(row)

func _make_jelly_marker(row: int, col: int) -> Sprite2D:
	if _layer_value(board.jelly, row, col) <= 0 or board.grid[row][col] == ME.WALL:
		return null
	var tex := ObjectiveIcons.texture_for_mechanism("target_mark", maxi(52, int(cell_size * JELLY_FILL)))
	if tex == null:
		return null
	var marker := Sprite2D.new()
	marker.name = JELLY_MARKER_NAME
	marker.add_to_group(JELLY_MARKER_NAME)
	marker.texture = tex
	marker.position = _cell_center(row, col)
	marker.scale = _fit_scale(tex, cell_size * JELLY_FILL)
	marker.modulate = JELLY_ICON_MODULATE
	marker.z_index = 1
	_board_layer().add_child(marker)
	return marker

func _render_drop_exit_visuals() -> void:
	_exit_nodes = []
	if board == null or _board_layer() == null:
		return
	if not _should_render_drop_exits():
		return
	var tex := ObjectiveIcons.texture_for_mechanism("drop_exit", maxi(52, int(cell_size * DROP_EXIT_FILL)))
	if tex == null:
		return
	var exit_set := {}
	for cx in board.exit_cols:
		exit_set[int(cx)] = true
	for r in range(board.height):
		var row: Array = []
		for c in range(board.width):
			var marker: Sprite2D = null
			if r == board.height - 1 and exit_set.has(c) and board.grid[r][c] != ME.WALL:
				marker = Sprite2D.new()
				marker.name = DROP_EXIT_MARKER_NAME
				marker.add_to_group(DROP_EXIT_MARKER_NAME)
				marker.texture = tex
				marker.position = _cell_center(r, c) + Vector2(0.0, cell_size * 0.12)
				marker.scale = _fit_scale(tex, cell_size * DROP_EXIT_FILL)
				marker.z_index = 2
				_board_layer().add_child(marker)
			row.append(marker)
		_exit_nodes.append(row)

func _should_render_drop_exits() -> bool:
	if board == null or board.exit_cols.is_empty():
		return false
	for o in board.objectives:
		if String(o.get("type", "")) == "COLLECT_INGREDIENT":
			return true
	for row in board.ing:
		if row is Array:
			for value in row:
				if int(value) > 0:
					return true
	if board.exit_cols.size() != board.width:
		return true
	for x in range(board.width):
		if not board.exit_cols.has(x):
			return true
	return false

func _render_wall_visuals() -> void:
	_wall_nodes = []
	if board == null or _gem_layer() == null:
		return
	var tex := _load_texture(WALL_STONE_ICON) if _asset_exists(WALL_STONE_ICON) else null
	for r in range(board.height):
		var row: Array = []
		for c in range(board.width):
			row.append(_make_wall_marker(r, c, tex))
		_wall_nodes.append(row)

func _make_wall_marker(row: int, col: int, tex: Texture2D) -> Sprite2D:
	if board.grid[row][col] != ME.WALL or tex == null:
		return null
	var marker := Sprite2D.new()
	marker.name = WALL_MARKER_NAME
	marker.add_to_group(WALL_MARKER_NAME)
	marker.texture = tex
	marker.material = _magenta_material()
	marker.position = _cell_center(row, col)
	marker.scale = _fit_scale(tex, cell_size * WALL_FILL)
	marker.z_index = 5
	_gem_layer().add_child(marker)
	return marker

func _render_coat_visuals() -> void:
	_coat_nodes = []
	if board == null or _gem_layer() == null:
		return
	var tex: Texture2D = load(BARRIER_ICE_ICON) if ResourceLoader.exists(BARRIER_ICE_ICON) else ObjectiveIcons.texture_for_mechanism("crystal_shell", maxi(52, int(cell_size * BARRIER_FILL)))
	for r in range(board.height):
		var row: Array = []
		for c in range(board.width):
			row.append(_make_coat_marker(r, c, tex))
		_coat_nodes.append(row)

func _render_opening_coat_visuals() -> void:
	_coat_nodes = []
	if board == null or _gem_layer() == null:
		return
	var tex: Texture2D = load(BARRIER_ICE_ICON) if ResourceLoader.exists(BARRIER_ICE_ICON) else ObjectiveIcons.texture_for_mechanism("crystal_shell", maxi(52, int(cell_size * BARRIER_FILL)))
	for r in range(board.height):
		var row: Array = []
		for c in range(board.width):
			var marker := _make_coat_marker(r, c, tex)
			if marker != null:
				marker.position = _opening_drop_start_position(_coat_marker_position(r, c), r)
			row.append(marker)
		_coat_nodes.append(row)

func _coat_marker_position(row: int, col: int) -> Vector2:
	return _cell_center(row, col) + Vector2(0.0, cell_size * 0.05)

func _make_coat_marker(row: int, col: int, tex: Texture2D) -> Sprite2D:
	var layers := _layer_value(board.coat, row, col)
	if layers <= 0 or board.grid[row][col] == ME.WALL:
		return null
	var marker := Sprite2D.new()
	marker.name = BARRIER_MARKER_NAME
	marker.add_to_group(BARRIER_MARKER_NAME)
	marker.texture = tex
	marker.material = _magenta_material()
	marker.position = _coat_marker_position(row, col)  # v0.02 冰块水平居中, 仅保留轻微下沉贴合格子
	marker.scale = _fit_scale(tex, cell_size * BARRIER_FILL)
	marker.z_index = 8
	_attach_shape_shadow(marker, tex)  # v0.02: 统一形状阴影(同棋子)
	_gem_layer().add_child(marker)
	return marker

# ───────── overlay 消费(契约 B §3.3)──────────

func _clear_overlay_nodes() -> void:
	for node in _overlay_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	_overlay_nodes.clear()


func _overlay_parent() -> Node:
	var layer := _gem_layer()
	return layer if layer != null else self

func _rebuild_overlay_nodes() -> void:
	if board == null:
		return
	OverlayRegistry.rebuild_all(board, _overlay_parent(), _overlay_nodes, cell_size, func(c: Vector2i) -> Vector2:
		return _cell_center(c.y, c.x))

func _ingredient_rows_by_col(layer: Array) -> Dictionary:
	var by_col := {}
	for row in range(layer.size()):
		if not (layer[row] is Array):
			continue
		for col in range(layer[row].size()):
			if int(layer[row][col]) > 0:
				if not by_col.has(col):
					by_col[col] = []
				by_col[col].append(row)
	for col in by_col.keys():
		by_col[col].sort()
		by_col[col].reverse()   # bottom-most first; ingredient gravity preserves per-column order.
	return by_col

func _sync_ingredient_overlay_motion(before_ing: Array, after_ing: Array, fallback_duration: float = 0.0) -> float:
	if board == null or before_ing.is_empty():
		return 0.0
	var before_by_col := _ingredient_rows_by_col(before_ing)
	if before_by_col.is_empty():
		return 0.0
	var after_by_col := _ingredient_rows_by_col(after_ing)
	var max_time := 0.0
	for raw_col in before_by_col.keys():
		var col: int = int(raw_col)
		var before_rows: Array = before_by_col[col]
		var after_rows: Array = after_by_col.get(col, [])
		for idx in range(before_rows.size()):
			var from_row: int = int(before_rows[idx])
			var from_cell := Vector2i(col, from_row)
			var old_key := ["ing", from_cell]
			var node = _overlay_nodes.get(old_key)
			if node == null or not is_instance_valid(node):
				continue
			var has_final_cell := idx < after_rows.size()
			var target_row: int = int(after_rows[idx]) if has_final_cell else (board.height - 1 if board.exit_cols.has(col) else from_row)
			var target_cell := Vector2i(col, target_row)
			var target_pos := _cell_center(target_row, col)
			_overlay_nodes.erase(old_key)
			if has_final_cell:
				node.cell = target_cell
				_overlay_nodes[["ing", target_cell]] = node
			var duration: float = maxf(fallback_duration, _fall_duration_for_positions(node.position, target_pos))
			if not is_inside_tree() or duration <= 0.0:
				node.position = target_pos
				if not has_final_cell:
					node.on_cleared()
				continue
			var t := create_tween()
			t.tween_property(node, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			if not has_final_cell:
				t.tween_callback(Callable(node, "on_cleared"))
			max_time = maxf(max_time, duration)
	return max_time

func _sync_overlays_at(cell: Vector2i) -> void:
	if board == null:
		return
	OverlayRegistry.ensure_overlays_at(cell, board, _overlay_parent(), _overlay_nodes, cell_size, _cell_center(cell.y, cell.x))

# ───────── 站立特效(fx overlay + combo idle + colorbomb)──────────

## 阶段5: 标记棋子为特效棋子并施加「站立特效」。kind==SP_NONE / 其它则清除特效回普通棋子。
## v0.02: 站立特效 = 姿态循环动画 + 贴边白光描边(见 _start_combo_idle), 取代旧 shine 静态光贴图。
func _apply_fx_overlay(node: Sprite2D, kind: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _fx_overlay_is_current(node, kind):
		return
	node.set_meta("fx", kind)
	_stop_combo_idle(node)  # 先停旧站立特效(kill tween + 移描边 + 复位 scale), 再按新 kind 施加
	_stop_colorbomb_idle(node)
	var old: Node = node.get_node_or_null("shine")  # 兼容: 清掉可能残留的旧 shine 贴图
	if old != null:
		old.queue_free()
	_clear_colorbomb_layers(node)
	if kind == ME.SP_COLORBOMB:
		_apply_colorbomb_layers(node)
		return
	if kind == ME.SP_NONE:
		return
	if kind == ME.SP_LINE_H or kind == ME.SP_LINE_V or kind == ME.SP_BOMB:
		_start_combo_idle(node, kind)

func _fx_overlay_is_current(node: Sprite2D, kind: int) -> bool:
	if int(node.get_meta("fx", ME.SP_NONE)) != kind:
		return false
	match kind:
		ME.SP_LINE_H, ME.SP_LINE_V, ME.SP_BOMB:
			return _stored_tween_is_running(node, "combo_tween")
		ME.SP_COLORBOMB:
			return _stored_tween_is_running(node, "colorbomb_tween")
		ME.SP_NONE:
			return not _stored_tween_is_running(node, "combo_tween") and not _stored_tween_is_running(node, "colorbomb_tween")
		_:
			return false

func _stored_tween_is_running(node: Sprite2D, key: String) -> bool:
	if not node.has_meta(key):
		return false
	var tw = node.get_meta(key)
	return tw is Tween and tw.is_valid()

func _gem_saturation_material() -> ShaderMaterial:
	if _gem_saturation_mat != null:
		return _gem_saturation_mat
	if _gem_saturation_shader == null:
		_gem_saturation_shader = load(GEM_SATURATION_SHADER)
	_gem_saturation_mat = ShaderMaterial.new()
	_gem_saturation_mat.shader = _gem_saturation_shader
	_gem_saturation_mat.set_shader_parameter("saturation", GEM_SATURATION)
	return _gem_saturation_mat

# 启动特殊棋子站立特效:
#   横/纵 = 方向性高光(光左右/上下扫, 表达朝哪侧转) + 转头变窄; 十字 = 全向脉冲 + 峰值暖金提亮。
func _start_combo_idle(node: Sprite2D, kind: int) -> void:
	var base: Vector2 = node.scale
	var base_mod: Color = node.modulate
	var base_offset: Vector2 = node.offset
	node.set_meta("combo_base_scale", base)
	node.set_meta("combo_base_mod", base_mod)
	node.set_meta("combo_base_offset", base_offset)
	var t := node.create_tween().set_loops()
	match kind:
		ME.SP_LINE_H:
			node.material = _directional_glow_material(true)
			_build_swing_loop(t, node, base, true, node.material)
		ME.SP_LINE_V:
			node.material = _directional_glow_material(false)
			_build_swing_loop(t, node, base, false, node.material)
		ME.SP_BOMB:
			_build_pulse_loop(t, node, base, base_mod)
	node.set_meta("combo_tween", t)

# 方向性高光材质(每棋子独立, 各自动画 light_pos)。horizontal=横(光左右扫), false=纵(光上下扫)。
func _directional_glow_material(horizontal: bool) -> ShaderMaterial:
	if _dir_glow_shader == null:
		_dir_glow_shader = load(DIR_GLOW_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _dir_glow_shader
	m.set_shader_parameter("light_axis", Vector2(1.0, 0.0) if horizontal else Vector2(0.0, 1.0))
	m.set_shader_parameter("light_w", COMBO_LIGHT_W)
	m.set_shader_parameter("light_strength", COMBO_LIGHT_STRENGTH)
	m.set_shader_parameter("light_tint", COMBO_LIGHT_TINT)
	m.set_shader_parameter("rim_strength", COMBO_RIM_STRENGTH)
	m.set_shader_parameter("bulge_strength", COMBO_BULGE_STRENGTH)
	m.set_shader_parameter("specular_strength", COMBO_SPECULAR_STRENGTH)
	m.set_shader_parameter("base_saturation", GEM_SATURATION)
	m.set_shader_parameter("light_pos", 0.5)
	return m

# 横(horizontal=true)=左右摇头; 纵=上下点头。方向由"高光位置"表达: 光扫到一侧=朝该侧转;
# 配合本体沿轴"转头变窄"(透视), 回正最宽。光左右/上下扫一个来回 + 停顿。
func _build_swing_loop(t: Tween, node: Sprite2D, base: Vector2, horizontal: bool, mat: ShaderMaterial) -> void:
	# 单条相位 tween(0→TAU, 线性, loop) 同时驱动「光泽位置」+「转头形变」, 二者天然同相、连续循环。
	# 光泽 = 0.5 + 振幅*sin(ph): 过中间最快、到两端减速回头(钟摆), 无停顿、不卡中间。
	# 转头形变按运动轴选择: 横向只改 x, 纵向只改 y, 避免上下点头读成左右摇。
	var cb := func(ph: float) -> void:
		var s: float = sin(ph)
		mat.set_shader_parameter("light_pos", 0.5 + COMBO_LIGHT_SWING * s)
		node.scale = _combo_swing_scale(base, horizontal, s)
		node.offset = Vector2(COMBO_SWING_OFFSET * s, 0.0) if horizontal else Vector2(0.0, COMBO_VERTICAL_SWING_OFFSET * s)
	t.tween_method(cb, 0.0, TAU, COMBO_SWING_CYCLE).set_trans(Tween.TRANS_LINEAR)

func _combo_swing_scale(base: Vector2, horizontal: bool, s: float) -> Vector2:
	var depth := absf(s)
	if horizontal:
		var widen_x: float = base.x * COMBO_SWING_WIDEN
		var shrink_x: float = base.x * COMBO_SWING_AMP
		return Vector2(base.x + widen_x - (widen_x + shrink_x) * depth, base.y)
	var widen_y: float = base.y * COMBO_VERTICAL_SCALE_WIDEN
	var shrink_y: float = base.y * COMBO_VERTICAL_SCALE_AMP
	return Vector2(base.x, base.y + widen_y - (widen_y + shrink_y) * depth)

# 十字(SP_BOMB)=lub-dub-rest 心跳: 快速大跳提亮 → 原色回落 → 短停 → 快速小跳提亮 → 原色回落 → 长休止。
func _build_pulse_loop(t: Tween, node: Sprite2D, base: Vector2, base_mod: Color) -> void:
	var first_peak: Vector2 = base * (1.0 + COMBO_HEARTBEAT_FIRST_AMP)
	var second_peak: Vector2 = base * (1.0 + COMBO_HEARTBEAT_SECOND_AMP)
	t.tween_property(node, "scale", first_peak, COMBO_HEARTBEAT_UP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "modulate", COMBO_BRIGHTEN, COMBO_HEARTBEAT_UP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", base, COMBO_HEARTBEAT_DOWN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "modulate", base_mod, COMBO_HEARTBEAT_DOWN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_interval(COMBO_HEARTBEAT_GAP)
	t.tween_property(node, "scale", second_peak, COMBO_HEARTBEAT_UP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "modulate", COMBO_BRIGHTEN, COMBO_HEARTBEAT_UP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", base, COMBO_HEARTBEAT_DOWN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "modulate", base_mod, COMBO_HEARTBEAT_DOWN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_interval(COMBO_HEARTBEAT_REST)

# 停止站立特效: kill 姿态/提亮 tween, 复位 scale 与 modulate 到 base。
func _stop_combo_idle(node: Sprite2D) -> void:
	for key in ["combo_tween", "combo_mod_tween"]:
		if node.has_meta(key):
			var tw = node.get_meta(key)
			if tw is Tween and tw.is_valid():
				tw.kill()
			node.remove_meta(key)
	var glow := node.get_node_or_null(COMBO_GLOW_NAME)  # 兼容: 清掉可能残留的旧白光节点
	if glow != null:
		glow.queue_free()
	node.material = _gem_saturation_material()  # 清横/纵方向高光后仍保留本轮宝石降饱和实验
	if node.has_meta("combo_base_scale"):
		node.scale = node.get_meta("combo_base_scale")
		node.remove_meta("combo_base_scale")
	if node.has_meta("combo_base_mod"):
		node.modulate = node.get_meta("combo_base_mod")
		node.remove_meta("combo_base_mod")
	if node.has_meta("combo_base_offset"):
		node.offset = node.get_meta("combo_base_offset")
		node.remove_meta("combo_base_offset")

func _stop_colorbomb_idle(node: Sprite2D) -> void:
	if not node.has_meta("colorbomb_tween"):
		return
	var tw = node.get_meta("colorbomb_tween")
	if tw is Tween and tw.is_valid():
		tw.kill()
	node.remove_meta("colorbomb_tween")

func _clear_colorbomb_layers(node: Sprite2D) -> void:
	node.offset = Vector2.ZERO
	for layer_name in COLORBOMB_LAYER_NAMES:
		var child := node.get_node_or_null(String(layer_name))
		if child != null:
			child.queue_free()

func _apply_colorbomb_layers(node: Sprite2D) -> void:
	# v0.02: 彩球用 diamond_white.png, 内部中心照光, 不再画外圈流光。
	if not _asset_exists(COLORBOMB_CORE):
		return
	var core := _load_texture(COLORBOMB_CORE)
	if core == null:
		return
	node.texture = core
	node.offset = Vector2.ZERO
	node.scale = _fit_scale(core, cell_size * COLORBOMB_FILL)
	node.z_index = 2
	# v0.02: 5合1 改用与普通棋子一致的形状阴影(本体星辰球纹理染黑), 不再用金色地面光晕素材。
	_attach_shape_shadow(node, core)
	_attach_colorbomb_inner_light(node, core)
	# 轻微上下浮动(idle), 不依赖任何子层
	var bob := node.create_tween().set_loops()
	node.set_meta("colorbomb_tween", bob)
	bob.tween_property(node, "offset", Vector2(0, -3.0), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(node, "offset", Vector2(0, 3.0), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _attach_colorbomb_inner_light(node: Sprite2D, core: Texture2D) -> void:
	var light := Sprite2D.new()
	light.name = COLORBOMB_INNER_LIGHT_NAME
	light.texture = core
	light.z_index = 3
	light.material = _colorbomb_inner_light_material()
	node.add_child(light)

func _colorbomb_inner_light_material() -> ShaderMaterial:
	if _colorbomb_inner_light_shader == null:
		_colorbomb_inner_light_shader = load(COLORBOMB_INNER_LIGHT_SHADER)
	var mat := ShaderMaterial.new()
	mat.shader = _colorbomb_inner_light_shader
	for i in range(COLORBOMB_INNER_LIGHT_COLORS.size()):
		mat.set_shader_parameter("light_color_%d" % i, COLORBOMB_INNER_LIGHT_COLORS[i])
	mat.set_shader_parameter("inner_radius", COLORBOMB_INNER_LIGHT_RADIUS)
	mat.set_shader_parameter("cycle_seconds", COLORBOMB_INNER_LIGHT_SECONDS)
	return mat

# ───────── 消除演出（_play_clear / _play_special_fx，从 level 平移）──────────

func _spawn_shatter_delayed(pos: Vector2, color: Color, delay: float) -> void:
	if delay <= 0.0:
		Fx.spawn_shatter(pos, color)
		return
	get_tree().create_timer(delay).timeout.connect(Fx.spawn_shatter.bind(pos, color), CONNECT_ONE_SHOT)

func _play_special_fx_delayed(pos: Vector2i, kind: int, delay: float) -> void:
	if delay <= 0.0:
		_play_special_fx(pos, kind)
		return
	get_tree().create_timer(delay).timeout.connect(_play_special_fx.bind(pos, kind), CONNECT_ONE_SHOT)

## 阶段5 消除表现: 遍历 to_clear——被触发的已存在特效格放对应 Fx; 普通格碎裂; 非 spawn 格淡出。
func _play_clear(to_clear: Array, spawns: Array, spawn_set: Dictionary, extra_special_fx_cells: Dictionary = {}, clear_visual_timing: Dictionary = {}) -> void:
	# 行/列横扫、十字星爆炸：路径棋子碎成触发特效的原色粒子，避免按各格颜色炸成彩虹。
	var visual_species: Dictionary = ClearVisuals.special_clear_species_overrides(board.grid, board.fx, to_clear, spawn_set)
	var line_clear_delays: Dictionary = clear_visual_timing.get("cell_delay", {})
	var special_fx_delays: Dictionary = clear_visual_timing.get("special_delay", {})
	var any := false
	var spawned_fx_count := 0
	var max_fx_delay := 0.0
	var basic_clear_hold := 0.0
	var clear_set := {}
	var played_special_fx := {}
	for p in to_clear:
		clear_set[p] = true
	for p in to_clear:
		var clear_delay: float = float(line_clear_delays.get(p, 0.0))
		max_fx_delay = maxf(max_fx_delay, clear_delay)
		var fx_kind: int = board.fx[p.y][p.x]
		var basic_clear_body := fx_kind == ME.SP_NONE and not visual_species.has(p)
		var spawned_fx := false
		# 被卷入消除的【已存在】特效棋子(它不在本级 spawn_set): 放对应 Fx 表现
		if fx_kind != ME.SP_NONE and not spawn_set.has(p):
			var special_delay: float = float(special_fx_delays.get(p, clear_delay))
			max_fx_delay = maxf(max_fx_delay, special_delay)
			_play_special_fx_delayed(p, fx_kind, special_delay)
			played_special_fx[p] = true
			spawned_fx = true
		else:
			var sp: int = board.grid[p.y][p.x]
			if sp >= 0 and sp < GEM_KEYS.size():
				if visual_species.has(p):
					# 横竖横扫/十字星: 不叠加三帧, 路径棋子碎成触发特效的纯色粒子
					_spawn_shatter_delayed(_cell_center(p.y, p.x), _gem_raw_color(int(visual_species[p])), clear_delay)
					spawned_fx = true
				else:
					# 普通消除: 染色后的三帧基础爆炸特效(蓄力→炸裂→消散)
					Fx.spawn_elimination(GEM_KEYS[sp], _cell_center(p.y, p.x), cell_size * 0.72)
					spawned_fx = true
		if spawned_fx:
			spawned_fx_count += 1
			if spawned_fx_count >= CLEAR_FX_BATCH_SIZE and is_inside_tree():
				spawned_fx_count = 0
				await get_tree().process_frame
		# spawn 格不淡出(它要变特效棋子, 留住节点); 非 spawn 格缩放淡出
		if not spawn_set.has(p):
			var n: Sprite2D = _gem_nodes[p.y][p.x]
			if n != null and is_instance_valid(n):
				_stop_combo_idle(n)
				var base_scale: Vector2 = n.scale
				var pop := create_tween()
				if clear_delay > 0.0:
					pop.tween_interval(clear_delay)
				if basic_clear_body:
					pop.tween_property(n, "scale", base_scale * BASIC_CLEAR_POP_SCALE, BASIC_CLEAR_POP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					pop.tween_property(n, "scale", base_scale * BASIC_CLEAR_SHRINK_SCALE, BASIC_CLEAR_TIME - BASIC_CLEAR_POP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
					pop.parallel().tween_property(n, "modulate:a", 0.0, BASIC_CLEAR_TIME - BASIC_CLEAR_POP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
					basic_clear_hold = maxf(basic_clear_hold, clear_delay + BASIC_CLEAR_TIME)
				else:
					# 特殊命中/横扫路径仍走当前 shatter 节拍, 不随普通基础爆炸回退。
					pop.tween_property(n, "scale", base_scale * CLEAR_SWELL_SCALE, CLEAR_SWELL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					pop.parallel().tween_property(n, "self_modulate", Color(CLEAR_WHITE_PUSH, CLEAR_WHITE_PUSH, CLEAR_WHITE_PUSH, 1.0), CLEAR_SWELL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					pop.tween_interval(CLEAR_BREAK_AT - CLEAR_SWELL_TIME + CLEAR_BODY_HIDE_DELAY)
					pop.tween_callback(func() -> void:
						if is_instance_valid(n):
							n.visible = false)
				any = true
	for p in extra_special_fx_cells:
		if clear_set.has(p):
			continue
		if played_special_fx.has(p):
			continue
		var fx_kind: int = int(extra_special_fx_cells[p])
		if fx_kind == ME.SP_NONE:
			continue
		var special_delay: float = float(special_fx_delays.get(p, line_clear_delays.get(p, 0.0)))
		max_fx_delay = maxf(max_fx_delay, special_delay)
		_play_special_fx_delayed(p, fx_kind, special_delay)
		played_special_fx[p] = true
		spawned_fx_count += 1
		any = true
		if spawned_fx_count >= CLEAR_FX_BATCH_SIZE and is_inside_tree():
			spawned_fx_count = 0
			await get_tree().process_frame
	# (按需移除消除震动)
	if any:
		# 等消除特效炸裂完再返回(下落发生在消除之后); 棋子淡出 tween 在此期间并行跑完
		await get_tree().create_timer(maxf(ELIM_HOLD + max_fx_delay, basic_clear_hold)).timeout

## 某已存在特效棋子被触发时的几何表现: 行/列用 beam, 3x3/彩球用 explosion。
func _play_special_fx(pos: Vector2i, kind: int) -> void:
	var line_col: Color = _line_fx_color(board.grid[pos.y][pos.x])
	var area_col: Color = _fx_color(board.grid[pos.y][pos.x])
	var c: Vector2 = _cell_center(pos.y, pos.x)
	match kind:
		ME.SP_LINE_H:
			Fx.spawn_line_blast(_cell_center(pos.y, 0), _cell_center(pos.y, board.width - 1), line_col)
		ME.SP_LINE_V:
			Fx.spawn_line_blast(_cell_center(0, pos.x), _cell_center(board.height - 1, pos.x), line_col)
		ME.SP_BOMB:
			Fx.spawn_local_burst(c, area_col, cell_size * 1.5)   # 3x3 范围内粒子爆裂, 不超实际清除边界
		ME.SP_COLORBOMB:
			Fx.spawn_explosion(c, area_col, 3.0)
		_:
			Fx.spawn_shatter(c, area_col)

# ───────── 增量同步簇 ──────────

func _node_matches_species(node: Sprite2D, sp: int) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_meta("species"):
		return false
	return int(node.get_meta("species")) == sp

func _replace_gem_node(row: int, col: int, old_node: Sprite2D = null) -> Sprite2D:
	if old_node != null and is_instance_valid(old_node):
		old_node.queue_free()
	var sp: int = _visual_species_for_cell(row, col)
	if sp < 0:
		return null
	var node := _make_gem(sp, _cell_center(row, col))
	if node != null:
		_apply_fx_overlay(node, board.fx[row][col])
	return node

func _reuse_or_replace_gem_node(row: int, col: int, node: Sprite2D) -> Sprite2D:
	var sp: int = _visual_species_for_cell(row, col)
	if sp < 0:
		if node != null and is_instance_valid(node):
			node.queue_free()
		return null
	if not _node_matches_species(node, sp):
		return _replace_gem_node(row, col, node)
	node.position = _cell_center(row, col)
	node.modulate.a = 1.0
	_apply_fx_overlay(node, board.fx[row][col])
	return node

func _repair_missing_gem_nodes_from_board() -> void:
	if board == null or _gem_nodes.size() != board.height:
		return
	for row in range(board.height):
		if not (_gem_nodes[row] is Array) or _gem_nodes[row].size() != board.width:
			return
	for row in range(board.height):
		for col in range(board.width):
			var sp: int = _visual_species_for_cell(row, col)
			var node: Sprite2D = _gem_nodes[row][col]
			if sp < 0:
				if node != null and is_instance_valid(node):
					node.queue_free()
				_gem_nodes[row][col] = null
				continue
			if node == null or not is_instance_valid(node):
				_gem_nodes[row][col] = _replace_gem_node(row, col)
				continue
			if not _node_matches_species(node, sp):
				_gem_nodes[row][col] = _replace_gem_node(row, col, node)
				continue
			node.modulate.a = 1.0
			_apply_fx_overlay(node, board.fx[row][col])

func _sync_changed_visuals_to_board() -> void:
	if board == null:
		return
	if _gem_nodes.size() != board.height:
		_render_board(false)
		return
	for row in range(board.height):
		if not (_gem_nodes[row] is Array) or _gem_nodes[row].size() != board.width:
			_render_board(false)
			return
		for col in range(board.width):
			_gem_nodes[row][col] = _reuse_or_replace_gem_node(row, col, _gem_nodes[row][col])
	_repair_missing_gem_nodes_from_board()
	_refresh_wall_visuals()
	_refresh_jelly_visuals()
	_refresh_coat_visuals()
	_rebuild_overlay_nodes()

func _animate_board_changes_from_snapshot(before_grid: Array, old_nodes: Array, before_ing: Array = []) -> void:
	if board == null:
		return
	if before_grid.is_empty() or old_nodes.is_empty():
		_sync_changed_visuals_to_board()
		return
	if _grid_has_fall_obstacle(before_grid, before_ing) or _grid_has_fall_obstacle(board.grid, board.ing):
		var wall_slide_time := _sync_wall_slide_visuals(before_grid, old_nodes, before_ing)
		var ing_time := _sync_ingredient_overlay_motion(before_ing, board.ing, wall_slide_time)
		_repair_missing_gem_nodes_from_board()
		_refresh_wall_visuals()
		_refresh_jelly_visuals()
		_refresh_coat_visuals()
		var wait_time: float = maxf(wall_slide_time, ing_time)
		if wait_time > 0.0 and is_inside_tree():
			await get_tree().create_timer(wait_time).timeout
		_rebuild_overlay_nodes()
		return
	var new_nodes: Array = _blank_visual_rows()
	var t := create_tween().set_parallel(true)
	var moved := false
	for col in range(board.width):
		var seg_end: int = board.height - 1
		for row in range(board.height - 1, -2, -1):
			if row >= 0 and not _fall_barrier_in_grid(before_grid, row, col, before_ing):
				continue
			if row + 1 <= seg_end:
				moved = _sync_collapse_segment(before_grid, old_nodes, new_nodes, col, row + 1, seg_end, t) or moved
			if row >= 0:
				_sync_fixed_cell_visual(row, col, old_nodes, new_nodes)
			seg_end = row - 1
	_gem_nodes = new_nodes
	_repair_missing_gem_nodes_from_board()
	_refresh_wall_visuals()
	_refresh_jelly_visuals()
	_refresh_coat_visuals()
	_rebuild_overlay_nodes()
	if moved:
		await t.finished

## level 的消费步数结算路径调本方法做增量改板（行为零变化, 含 settle/refresh 由 level 持有）。
func animate_board_changes_from_snapshot(before_grid: Array, old_nodes: Array, before_ing: Array = []) -> void:
	await _animate_board_changes_from_snapshot(before_grid, old_nodes, before_ing)

## 取整阵快照（level 在消费步数/彩球/融合前 duplicate _gem_nodes 用）。
func snapshot_gem_nodes() -> Array:
	return _gem_nodes.duplicate(true)

## 刷新果冻/冰锁底片（级联/彩球/融合/消费步数后, board 障碍层已扣减时同步视觉）。
func refresh_jelly_coat_visuals() -> void:
	_refresh_jelly_visuals()
	_refresh_coat_visuals()

## 标记某格为特效棋子（彩球虚拟转化/祝福埋弹/级联 spawn 等, 经 node_at 取节点后叠 shine）。
func apply_fx_overlay(node: Sprite2D, kind: int) -> void:
	_apply_fx_overlay(node, kind)

## 消除演出（彩球/融合/结算奖励等编排仍在 level, 经此播 clear 动画）。
func play_clear(to_clear: Array, spawns: Array, spawn_set: Dictionary, extra_special_fx_cells: Dictionary = {}, clear_visual_timing: Dictionary = {}) -> void:
	await _play_clear(to_clear, spawns, spawn_set, extra_special_fx_cells, clear_visual_timing)

## 某已存在特效棋子被触发时的几何表现（彩球/融合演出编排仍在 level, 经此播）。
func play_special_fx(pos: Vector2i, kind: int) -> void:
	_play_special_fx(pos, kind)

# ───────── 墙滑视觉簇（计算在 level_motion；本类只搬节点）──────────

func _fall_barrier_in_grid(grid_snapshot: Array, row: int, col: int, ing_snapshot: Array = []) -> bool:
	return LevelMotion.fall_barrier_in_grid(grid_snapshot, board.coat, board.choco, row, col, ing_snapshot)

func _segment_old_entries(grid_snapshot: Array, old_nodes: Array, col: int, seg_start: int, seg_end: int) -> Array:
	var entries := []
	for row in range(seg_start, seg_end + 1):
		if grid_snapshot[row][col] == ME.EMPTY or grid_snapshot[row][col] == ME.WALL:
			continue
		var node: Sprite2D = old_nodes[row][col]
		entries.append({"row": row, "node": node})
	return entries

func _segment_after_slots(col: int, seg_start: int, seg_end: int) -> Array:
	var slots := []
	for row in range(seg_start, seg_end + 1):
		if _visual_species_for_cell(row, col) != ME.EMPTY and _visual_species_for_cell(row, col) != ME.WALL:
			slots.append(row)
	return slots

func _ordinary_refill_start_position(row: int, col: int, _spawn_index: int, spawn_count: int) -> Vector2:
	# v0.02: 新棋子统一从棋盘顶边明显上方落入(pour from top), 不再只在目标格上方少量生成。
	# 额外 +TOP_POUR 格, 保证即便单消(spawn_count小)新棋子也从顶部明显落下而非"中间冒出"。
	return LevelMotion.ordinary_refill_start_position(_cell_center(row, col), cell_size, spawn_count)

func _ordinary_refill_duration_for_positions(start_pos: Vector2, target: Vector2) -> float:
	return LevelMotion.ordinary_refill_duration_for_positions(start_pos, target, cell_size)

func _queue_cascade_fall_tween(tween: Tween, node: Node2D, target: Vector2, duration: float) -> void:
	tween.tween_property(node, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _sync_collapse_segment(grid_snapshot: Array, old_nodes: Array, new_nodes: Array, col: int, seg_start: int, seg_end: int, tween: Tween) -> bool:
	var moved := false
	var old_entries := _segment_old_entries(grid_snapshot, old_nodes, col, seg_start, seg_end)
	var after_slots := _segment_after_slots(col, seg_start, seg_end)
	var old_count: int = mini(old_entries.size(), after_slots.size())
	var first_old_slot: int = after_slots.size() - old_count

	var spawn_i := 0
	for idx in range(first_old_slot - 1, -1, -1):
		var row: int = after_slots[idx]
		var center := _cell_center(row, col)
		var node := _replace_gem_node(row, col)
		new_nodes[row][col] = node
		if node != null:
			node.position = _ordinary_refill_start_position(row, col, spawn_i, first_old_slot)
			_queue_cascade_fall_tween(tween, node, center, _ordinary_refill_duration_for_positions(node.position, center))
			moved = true
		spawn_i += 1

	for idx in range(old_count):
		var row: int = after_slots[first_old_slot + idx]
		var entry: Dictionary = old_entries[idx]
		var node: Sprite2D = entry["node"]
		if not _node_matches_species(node, board.grid[row][col]):
			node = _replace_gem_node(row, col, node)
		else:
			node.modulate.a = 1.0
			_apply_fx_overlay(node, board.fx[row][col])
		new_nodes[row][col] = node
		if node != null and is_instance_valid(node):
			var target := _cell_center(row, col)
			if node.position != target:
				_queue_cascade_fall_tween(tween, node, target, _fall_duration_for_positions(node.position, target))
				moved = true

	for idx in range(old_count, old_entries.size()):
		var stale: Sprite2D = old_entries[idx]["node"]
		if stale != null and is_instance_valid(stale):
			stale.queue_free()
	return moved

func _sync_fixed_cell_visual(row: int, col: int, old_nodes: Array, new_nodes: Array) -> void:
	var old_node: Sprite2D = old_nodes[row][col]
	new_nodes[row][col] = _reuse_or_replace_gem_node(row, col, old_node)

func _fall_duration_for_positions(start_pos: Vector2, target: Vector2) -> float:
	return LevelMotion.fall_duration_for_positions(start_pos, target, cell_size)

func _grid_has_fall_obstacle(grid_data: Array, ing_snapshot: Array = []) -> bool:
	return LevelMotion.grid_has_fall_obstacle(grid_data, board.coat, board.choco, ing_snapshot)

func _wall_refill_start_position(row: int, col: int, source_map: Array = []) -> Vector2:
	return LevelMotion.wall_refill_start_position(row, col, source_map, board_origin, cell_size)

func _wall_slide_target_has_fall_obstacle_above(grid_data: Array, row: int, col: int, ing_snapshot: Array = []) -> bool:
	return LevelMotion.wall_slide_target_has_fall_obstacle_above(grid_data, board.coat, board.choco, board.cannon, row, col, ing_snapshot)

func _wall_slide_path_points(start_pos: Vector2, target: Vector2) -> Array:
	return LevelMotion.wall_slide_path_points(start_pos, target, board_origin, cell_size, board.width, board.height)

func _wall_slide_cell_path_points(start_pos: Vector2, cell_path: Array, target: Vector2) -> Array:
	return LevelMotion.wall_slide_cell_path_points(start_pos, cell_path, target, board_origin, cell_size, board.width, board.height)

func _wall_slide_position_at(start_pos: Vector2, points: Array, progress: float) -> Vector2:
	return LevelMotion.wall_slide_position_at(start_pos, points, progress)

func _wall_slide_duration_for_points(points: Array) -> float:
	return LevelMotion.wall_slide_duration_for_points(points)

func _wall_slide_duration_for_target(points: Array, duration_override: float = -1.0) -> float:
	return LevelMotion.wall_slide_duration_for_target(points, duration_override)

func _tween_wall_slide_node(node: Sprite2D, target: Vector2, cell_path: Array = [], duration_override: float = -1.0) -> float:
	if node == null or not is_instance_valid(node) or node.position == target:
		return 0.0
	var start_pos := node.position
	var points := _wall_slide_cell_path_points(start_pos, cell_path, target)
	var total_time: float = _wall_slide_duration_for_target(points, duration_override)
	if total_time <= 0.0:
		return 0.0
	var t := create_tween()
	var apply_position := func(progress: float) -> void:
		if node != null and is_instance_valid(node):
			node.position = _wall_slide_position_at(start_pos, points, progress)
	t.tween_method(apply_position, 0.0, 1.0, total_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return total_time

func _source_none() -> Vector2i:
	return LevelMotion.source_none()

func _source_spawn(col: int) -> Vector2i:
	return LevelMotion.source_spawn(col)

func _wall_slide_path_rows(grid_snapshot: Array) -> Array:
	return LevelMotion.wall_slide_path_rows(grid_snapshot)

func _wall_slide_source_rows(grid_snapshot: Array) -> Array:
	return LevelMotion.wall_slide_source_rows(grid_snapshot)

func _wall_slide_tracking_fixed_cell(grid_snapshot: Array, row: int, col: int, ing_snapshot: Array = []) -> bool:
	return LevelMotion.fall_barrier_in_grid(grid_snapshot, board.coat, board.choco, row, col, ing_snapshot)

func _build_wall_slide_tracking_maps(before_grid: Array, before_ing: Array = []) -> Dictionary:
	return LevelMotion.build_wall_slide_tracking_maps(before_grid, board.coat, board.choco, board.cannon, board.is_scrolling, before_ing)

func _wall_slide_source_priority(row: int, col: int, target_row: int, target_col: int, allow_cross_column: bool) -> int:
	return LevelMotion.wall_slide_source_priority(row, col, target_row, target_col, allow_cross_column)

func _take_wall_slide_source(before_grid: Array, old_nodes: Array, used: Dictionary, target_row: int, target_col: int, sp: int, allow_cross_column: bool = false, source_map: Array = []) -> Sprite2D:
	if not source_map.is_empty() and target_row >= 0 and target_row < source_map.size() and target_col >= 0 and target_col < source_map[target_row].size():
		var source: Vector2i = source_map[target_row][target_col]
		if source.x < 0:
			return null
		if source.y < 0:
			return null
		if used.has(source):
			return null
		var mapped_node: Sprite2D = old_nodes[source.y][source.x]
		if not _node_matches_species(mapped_node, sp):
			return null
		used[source] = true
		return mapped_node
	var best_key := Vector2i(-1, -1)
	var best_score := 1000000
	for row in range(board.height):
		for col in range(board.width):
			if not allow_cross_column and col != target_col:
				continue
			var key := Vector2i(col, row)
			if used.has(key) or before_grid[row][col] < 0:
				continue
			var score := _wall_slide_source_priority(row, col, target_row, target_col, allow_cross_column)
			if score < 0:
				continue
			var node: Sprite2D = old_nodes[row][col]
			if not _node_matches_species(node, sp):
				continue
			if score < best_score:
				best_score = score
				best_key = key
	if best_key.x < 0:
		return null
	used[best_key] = true
	return old_nodes[best_key.y][best_key.x]

func _wall_slide_spawn_source_col(source_map: Array, row: int, col: int) -> int:
	return LevelMotion.wall_slide_spawn_source_col(source_map, row, col)

func _wall_slide_spawn_travel_cells(source_map: Array, source_col: int) -> float:
	return LevelMotion.wall_slide_spawn_travel_cells(source_map, source_col)

func _wall_slide_target_refill_cap(source_map: Array, row: int, col: int) -> float:
	return LevelMotion.wall_slide_target_refill_cap(source_map, row, col)

func _wall_slide_target_path(path_map: Array, row: int, col: int) -> Array:
	return LevelMotion.wall_slide_target_path(path_map, row, col)

func _wall_slide_target_visual_path(source_map: Array, path_map: Array, row: int, col: int) -> Array:
	return LevelMotion.wall_slide_target_visual_path(source_map, path_map, row, col)

func _wall_slide_visual_start_position(source_map: Array, path_map: Array, row: int, col: int) -> Vector2:
	return LevelMotion.wall_slide_visual_start_position(source_map, path_map, row, col, board_origin, cell_size)

func _free_unused_wall_slide_sources(old_nodes: Array, used: Dictionary) -> void:
	for row in range(board.height):
		for col in range(board.width):
			var key := Vector2i(col, row)
			if used.has(key):
				continue
			var node: Sprite2D = old_nodes[row][col]
			if node != null and is_instance_valid(node):
				node.queue_free()

func _sync_wall_slide_visuals(before_grid: Array, old_nodes: Array, before_ing: Array = []) -> float:
	var move_time := 0.0
	var used := {}
	var new_nodes := _blank_visual_rows()
	var tracking_maps := _build_wall_slide_tracking_maps(before_grid, before_ing)
	var source_map: Array = tracking_maps["source"]
	var path_map: Array = tracking_maps["path"]
	for row in range(board.height - 1, -1, -1):
		for col in range(board.width):
			var sp: int = board.grid[row][col]
			if sp < 0:
				continue
			var allow_cross_column := _wall_slide_target_has_fall_obstacle_above(before_grid, row, col, before_ing)
			var node := _take_wall_slide_source(before_grid, old_nodes, used, row, col, sp, allow_cross_column, source_map)
			if node == null:
				node = _replace_gem_node(row, col)
				if node != null:
					node.position = _wall_slide_visual_start_position(source_map, path_map, row, col)
			else:
				_apply_fx_overlay(node, board.fx[row][col])
			new_nodes[row][col] = node
			if node != null and is_instance_valid(node):
				var target := _cell_center(row, col)
				var refill_cap := _wall_slide_target_refill_cap(source_map, row, col)
				var visual_path := _wall_slide_target_visual_path(source_map, path_map, row, col)
				var node_time := _tween_wall_slide_node(node, target, visual_path, refill_cap)
				if node_time > move_time:
					move_time = node_time
	_free_unused_wall_slide_sources(old_nodes, used)
	_gem_nodes = new_nodes
	return move_time

## 每轮消除后用核心重力/补充收口，并增量移动/补充表现层，确保并行层不掉队且不全盘闪烁。
func _collapse_and_refill() -> void:
	var before_grid: Array = board.grid.duplicate(true)
	var before_ing: Array = board.ing.duplicate(true)
	var old_nodes: Array = _gem_nodes.duplicate(true)
	ME.apply_gravity(board.grid, board.fx, false, board._layers())
	var collected: int = ME._drain_ingredients(board.grid, board.fx, false, board._layers())
	if collected > 0:
		board._accumulate_progress({"ingredient_collected": collected})
	var refill_feed: Array = board.feed if board.is_scrolling else []
	if not board.is_scrolling:
		ME.refill(board.grid, board.species, board.rng, board.fx, refill_feed, board._layers())
	var new_nodes: Array = _blank_visual_rows()
	if _grid_has_fall_obstacle(before_grid, before_ing) or _grid_has_fall_obstacle(board.grid, board.ing):
		var wall_slide_time := _sync_wall_slide_visuals(before_grid, old_nodes, before_ing)
		var ing_time := _sync_ingredient_overlay_motion(before_ing, board.ing, wall_slide_time)
		_repair_missing_gem_nodes_from_board()
		_refresh_wall_visuals()
		_refresh_jelly_visuals()
		_refresh_coat_visuals()
		var wait_time: float = maxf(wall_slide_time, ing_time)
		if wait_time > 0.0 and is_inside_tree():
			await get_tree().create_timer(wait_time).timeout
		_rebuild_overlay_nodes()
		return
	var t := create_tween().set_parallel(true)
	var moved := false
	for col in range(board.width):
		var seg_end: int = board.height - 1
		for row in range(board.height - 1, -2, -1):
			if row >= 0 and not _fall_barrier_in_grid(before_grid, row, col, before_ing):
				continue
			if row + 1 <= seg_end:
				moved = _sync_collapse_segment(before_grid, old_nodes, new_nodes, col, row + 1, seg_end, t) or moved
			if row >= 0:
				_sync_fixed_cell_visual(row, col, old_nodes, new_nodes)
			seg_end = row - 1
	_gem_nodes = new_nodes
	_repair_missing_gem_nodes_from_board()
	_refresh_wall_visuals()
	_refresh_jelly_visuals()
	_refresh_coat_visuals()
	_rebuild_overlay_nodes()
	if moved:
		await t.finished

## 供 level 编排调用的塌落补充入口（彩球/融合/龙息/级联清格后）。
func collapse_and_refill() -> void:
	await _collapse_and_refill()
