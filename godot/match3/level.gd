extends Node2D
# level.gd — 对局主场景（GAME_SPEC 新视图体系）。逻辑复用 core/board.gd + match_engine.gd。
#
# 当前布局：
#   顶部：透明源图裁剪后的关卡/步数/目标/星级 HUD。
#   中部：魔法书棋盘，可变尺寸，障碍和棋子按数据层增量同步。
#   底部：4 个萌宠技能头像 + 充能条。

const CoreBoard := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")
const LevelConfig := preload("res://match3/level_config.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const ClearVisuals := preload("res://match3/clear_visuals.gd")
const LevelLayout := preload("res://match3/level_layout.gd")
const LevelMotion := preload("res://match3/level_motion.gd")
const PetCast := preload("res://match3/pets/pet_cast.gd")
const PetRegistry := preload("res://match3/pets/pet_registry.gd")
const LEVELS_PATH := "res://levels.json"

const GEM_COLORS := {
	# 从宝石贴图实采的主体色(高饱和中亮像素均值), 与宝石一致
	"red": Color(0.691, 0.108, 0.048), "blue": Color(0.052, 0.297, 0.789),
	"green": Color(0.373, 0.635, 0.045), "gold": Color(0.746, 0.426, 0.058),
	"purple": Color(0.326, 0.061, 0.728), "pink": Color(0.780, 0.120, 0.411),
}
const GEM_FX_COLORS := {
	# Additive 特效专用: 提亮但保留高饱和度, 避免先混白后被白色贴图冲淡。
	"red": Color(1.0, 0.16, 0.07), "blue": Color(0.08, 0.64, 1.0),
	"green": Color(0.48, 1.0, 0.10), "gold": Color(1.0, 0.70, 0.08),
	"purple": Color(0.58, 0.22, 1.0), "pink": Color(1.0, 0.20, 0.58),
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
# 5合1 = 独立分层水晶球，不套普通阴影。(4合1 站立特效见下方 _start_combo_idle)
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
const CELL_TEXTURE := "res://assets/board/board_cell.png"
const BOOK_FRAME := "res://assets/level/book_frame.png"      # v0.02 魔法书主体(982×980, 9-slice缩放适配棋盘)
const BOOK_RIBBONS := "res://assets/level/book_ribbons.png"  # v0.02 书底书签(982×77, 与 book_frame 同宽)
const CELL_SQ := "res://assets/level/cell_sq.png"            # v0.02 米黄圆角棋格(cell.png 128²)
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
const BG_TEXTURE := "res://assets/level/background.png"  # v0.02 新天空背景(941×1672, 按宽铺满)
const BARRIER_ICE_ICON := "res://assets/obstacles/ob_ice.png"  # synced from resources/barrier/ob_ice.png
const BARRIER_MARKER_NAME := "CoatBarrierSprite"
const BARRIER_FILL := 1.26  # v0.02 冰块放大补偿(ob_ice实体仅占0.686, ×1.26→实体≈cell*0.86, 与棋子一致)
const JELLY_MARKER_NAME := "JellyGoalSprite"
const JELLY_FILL := 0.94
const JELLY_TINT := Color(0.46, 0.82, 1.0, 0.26)
const WALL_STONE_ICON := "res://assets/obstacles/ob_stone.png"
const WALL_MARKER_NAME := "WallStoneSprite"
const WALL_FILL := 0.90
# UI 素材
const KEY_SHADER := "res://match3/magenta_key.gdshader"

# ── v0.02 顶部状态栏新素材(米黄风格, 设计稿换皮; 替换旧紫金分散顶栏) ──

# 关卡目标(占位) 与 技能(占位)

const DESIGN_W := LevelLayout.DESIGN_W
const DESIGN_H := 1520.0
const SWAP_TIME := 0.14
const CLEAR_TIME := 0.156
const CLEAR_POP_TIME := 0.117
const CLEAR_POP_SCALE := 1.32
const CLEAR_BURST_SCALE := 1.52  # 炸裂瞬间冲大的残影倍率(替代旧"缩回吸走"收尾)
const CLEAR_FX_BATCH_SIZE := 8
const COLORBOMB_ABSORB_TARGET_BUDGET := 18
const COLORBOMB_FINE_CLEAR_BUDGET := 12
const COLORBOMB_CLEAR_FX_BATCH_SIZE := 6
const ELIM_HOLD := 0.156  # 消除后停顿(等普通消除动画跑完)再下落
const LINE_CLEAR_STAGGER := 0.026  # 横/竖炸路径碎裂按触发点向外错峰, 0.02s * 1.3
const OPENING_DROP_TIME := 0.56
const OPENING_DROP_ROW_STAGGER := 0.045
const OPENING_DROP_MAX_STAGGER := 0.30
const OPENING_FREEZE_STAGGER := 0.018
const OPENING_FREEZE_MAX_STAGGER := 0.18
const OPENING_FREEZE_SETTLE := 0.16
const OPENING_STONE_COLOR := Color(0.62, 0.56, 0.50)
const ENDGAME_BONUS_RESULT_HOLD := 0.45
const ENDGAME_BONUS_SPECIAL_CHAIN_MAX := 30

# ── 布局锚点（对齐参考图；截图后微调） ──
const BOSS_C := Vector2(562, 336)
const CELL_FILL := 1.0          # 格子填满格位
const GEM_FILL := 0.84
const COLORBOMB_FILL := 0.74  # v0.02 彩球略小一点, 避免 5 合 1 压住相邻格
const TRAY_TOP := 1236.0  # 技能栏顶(棋盘底锚定于此); 下移让棋盘整体下移, 露出更多角色

var board
var board_origin: Vector2
var cell_size: float = 0.0
var _levels: Array = []          # 真实关卡库(levels.json 的 levels 数组), 空=回退 LevelConfig
var _playable: Array = []        # 可玩关索引(跳过 objectives 为空的关), 元素是 _levels 的下标
var _play_pos: int = 0           # 当前在 _playable 列表中的位置(翻关用)
var _level_idx: int = 0          # 当前 _levels 下标(=_playable[_play_pos]); _levels 空时复用为 LevelConfig 下标
var _settled := false            # 本关已结算(通关/失败), 锁输入直到点击下一关/重试
var _cur_cfg: Dictionary = {}    # 当前关顶部显示用 cfg(只含 id), HUD 刷新重画 ui_layer 时复用
var _gem_nodes: Array = []
var _jelly_nodes: Array = []
var _coat_nodes: Array = []
var _wall_nodes: Array = []
var _sel := Vector2i(-1, -1)
var _sel_node: Sprite2D = null  # 当前选中的棋子节点(放大提亮置顶)
var _sel_node_scale := Vector2.ONE
var _sel_node_mod := Color.WHITE
var _hl_markers: Array = []
var _busy := false
var _level_generation: int = 0
var _opening_drop_tween: Tween = null
var _key_mat: ShaderMaterial = null
var _dir_glow_shader: Shader = null  # 横/纵摇头点头的方向性高光 shader(缓存资源)
var _gem_saturation_shader: Shader = null
var _gem_saturation_mat: ShaderMaterial = null
var _colorbomb_inner_light_shader: Shader = null
var _time_rewind_cast_pending := false
var _active_cast: PetCast = null               # 当前在途宠物施法控制器(契约 C); 换关/退场时 cancel + free

@onready var background_layer: CanvasLayer = $BackgroundLayer
@onready var board_layer: CanvasLayer = $BoardLayer
@onready var gem_layer: CanvasLayer = $GemLayer
@onready var character_layer: CanvasLayer = $CharacterLayer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var skill_bar: CanvasLayer = $SkillBar

# ── 子控制器(契约 A 消费者, 铁律2 挂 level 子树)。公开供测试经 level.hud / level.skills 断言。──
const LevelHud := preload("res://match3/hud.gd")
const LevelSkills := preload("res://match3/skills.gd")
var hud: LevelHud = null
var skills: LevelSkills = null

# _init 在 .new()/instantiate 时即运行(早于 _ready), 保证不入树的测试也拿到 level.hud / level.skills。
func _init() -> void:
	hud = LevelHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(self)
	skills = LevelSkills.new()
	skills.name = "Skills"
	add_child(skills)
	skills.setup(self)
	skills.skill_pressed.connect(_on_skill_pressed)

func _ready() -> void:
	# 图层顺序：背景(0) < 棋盘格(2)/棋子(3) < 角色层(4) < UI(5) < 技能栏(6)
	character_layer.layer = 4
	board_layer.layer = 2
	gem_layer.layer = 3
	$FXLayer.layer = 4
	Fx.attach($FXLayer, gem_layer)  # 特效挂 FXLayer, 震动抖棋子层
	# 阶段6: 接真实 126 关。读 levels.json → 构建"可玩关索引"(跳过 18 个空 objectives 关,
	# 否则空目标 → is_won 退化为 score>=target_score(=0) → 进关即赢)。json 缺失则回退 LevelConfig。
	_levels = LevelLibrary.load_file(LEVELS_PATH)
	_playable = []
	for i in range(_levels.size()):
		var objs = _levels[i].get("objectives", [])
		if objs is Array and not objs.is_empty():
			_playable.append(i)
	var launch_level_idx := _launch_level_idx_from_args(OS.get_cmdline_user_args(), _levels.size() if not _levels.is_empty() else LevelConfig.count())
	_play_pos = 0
	if not _levels.is_empty():
		_level_idx = _playable[0] if not _playable.is_empty() else 0
		if launch_level_idx >= 0 and _playable.has(launch_level_idx):
			_level_idx = launch_level_idx
			_play_pos = _playable.find(launch_level_idx)
	else:
		_level_idx = launch_level_idx if launch_level_idx >= 0 else 0
	load_level(_level_idx)

func _exit_tree() -> void:
	_level_generation += 1
	_kill_opening_drop_tween()
	_cancel_active_cast()

func _launch_level_idx_from_args(args: Array, level_count: int) -> int:
	for i in range(args.size()):
		var arg := String(args[i])
		var raw := ""
		if arg == "--level":
			if i + 1 >= args.size():
				return -1
			raw = String(args[i + 1])
		elif arg.begins_with("--level="):
			raw = arg.substr("--level=".length())
		if raw.is_empty():
			continue
		if not raw.is_valid_int():
			return -1
		return _player_level_to_raw_idx(raw.to_int(), level_count)
	return -1

func _player_level_to_raw_idx(level_number: int, level_count: int) -> int:
	var player_idx := level_number - 1
	if player_idx < 0:
		return -1
	if not _playable.is_empty():
		if player_idx >= _playable.size():
			return -1
		return int(_playable[player_idx])
	if level_count > 0 and player_idx >= level_count:
		return -1
	return player_idx

func _display_level_number(raw_idx: int) -> int:
	if not _playable.is_empty():
		var player_idx := _playable.find(raw_idx)
		if player_idx >= 0:
			return player_idx + 1
	return raw_idx + 1

## species → 特效染色(取宝石色并提亮便于可见)。
func _fx_color(sp: int) -> Color:
	if sp < 0 or sp >= GEM_KEYS.size():
		return Color(1, 1, 1)
	return GEM_FX_COLORS[GEM_KEYS[sp]] as Color

## 横/竖光束用更饱和的触发色。Additive 光束若先提白, 会把彩色主光洗成白光。
func _line_fx_color(sp: int) -> Color:
	return _fx_color(sp)

static func gem_raw_color_for_species(sp: int) -> Color:
	if sp < 0 or sp >= GEM_KEYS.size():
		return Color(1, 1, 1)
	return GEM_COLORS[GEM_KEYS[sp]]

## species → 宝石饱和原色(不提亮)。碎裂粒子专用：提亮会让红冲成粉、蓝冲成青白(additive 重叠更甚)。
func _gem_raw_color(sp: int) -> Color:
	return gem_raw_color_for_species(sp)

func _asset_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		err = image.load(path)
	if err != OK:
		push_warning("Unable to load PNG texture: %s" % path)
		return null
	var tex := ImageTexture.create_from_image(image)
	tex.take_over_path(path)
	return tex

func load_level(idx: int) -> void:
	_kill_opening_drop_tween()
	_cancel_active_cast()
	_level_generation += 1
	var generation := _level_generation
	# cfg 仅用于顶部标题"第 N 关"显示(levels.json 无数字 id → 用关序号)。
	var cfg: Dictionary
	if not _levels.is_empty() and idx >= 0 and idx < _levels.size():
		# 阶段6: 用现成的"JSON一关→可玩Board"工厂(配齐 objectives/move_limit/障碍/盘面)。
		board = LevelLibrary.to_board(_levels[idx])
		cfg = {"id": _display_level_number(idx)}
	else:
		# 回退: levels.json 缺失时仍能跑旧 LevelConfig 占位关(防 json 缺失白屏)。
		var lc: Dictionary = LevelConfig.get_level(idx)
		var ncolors: int = int(lc.get("colors", 6))
		var species: Array = []
		for i in range(ncolors):
			species.append(i)
		board = CoreBoard.new(lc["cols"], lc["rows"], species, 999999, 999, 12345 + idx)
		cfg = {"id": lc["id"]}
	board.skill = "timerewind"
	_sel = Vector2i(-1, -1)
	_sel_node = null
	_hl_markers = []
	_busy = true
	_settled = false
	skills.reset_charge()   # 新关重置技能充能
	_compute_layout()
	_render_background()
	_render_board(true)
	_render_chrome(cfg)
	_play_opening_drop(generation)
	print("[阶段6] 关卡 #%d  %d×%d  cell=%d  目标=%s  步数=%d  合法移动=%s"
		% [cfg["id"], board.width, board.height, int(cell_size), str(board.objectives), board.moves_left, str(ME.has_legal_move(board.grid, board._layers()))])

func _compute_layout() -> void:
	# 预留边框外凸: 角花顶点离格角 = 紫条中线偏移 + 角花半径; 取与紫条厚度的较大值
	# v0.02: 棋盘落"书页内金线框"(book_frame 内边线), 与书页边缘留页边距(像书的正文区)。
	# v0.02: 书本左右贴屏幕边(满屏宽,间距0); playable 棋盘优先填满书内镶边宽度。
	var layout: Dictionary = LevelLayout.compute_layout(board.width, board.height)
	cell_size = float(layout["cell_size"])
	board_origin = layout["board_origin"]

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

func _cell_center(row: int, col: int) -> Vector2:
	return LevelLayout.cell_center(row, col, cell_size, board_origin)

func _pos_to_cell(p: Vector2) -> Vector2i:
	return LevelLayout.pos_to_cell(p, board.width, board.height, cell_size, board_origin)

# ───────── 背景 / 棋盘 ─────────

func _render_background() -> void:
	_clear_layer(background_layer)
	# 全屏深色兜底：bg_scene 缩放后未覆盖到的区域不再露出 viewport 默认灰
	var base := ColorRect.new()
	base.color = Color(0.05, 0.035, 0.10, 1.0)
	base.position = Vector2.ZERO
	base.size = Vector2(DESIGN_W, DESIGN_H)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 装饰底,勿吞棋盘点击
	background_layer.add_child(base)
	var tex: Texture2D = _load_texture_from_file(BG_TEXTURE)
	if tex == null:
		return
	var sz: Vector2 = tex.get_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	# v0.02 天空背景: 用 TextureRect(Control) 与兜底同层, 按比例铺满全屏(超出居中裁切)。
	# 注: 同 CanvasLayer 下 Control 会盖 Node2D, 故背景用 Control 而非 Sprite2D 才能盖住兜底。
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE  # v0.02 拉伸铺满(完整显示左右, 不裁; 横向略压)
	tr.position = Vector2.ZERO
	tr.size = Vector2(DESIGN_W, DESIGN_H)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(tr)

func _render_board_panel() -> void:
	# v0.02: 魔法书主体 book_frame 用 9-slice —— 四角装饰(~37px)+金框/书脊不变形, 只拉书页中段;
	#        书页内框(左右38/顶≈角38/底44)对齐棋格。书签与书框同宽, 上沿贴书框下沿。
	var book_rect := _book_frame_rect()
	var center := book_rect.position + book_rect.size * 0.5
	_nine(board_layer, BOOK_FRAME, center, book_rect.size.x, book_rect.size.y, BOOK_NINE_ML, BOOK_NINE_MT, BOOK_NINE_MB)
	_render_book_inner_inlay()
	if _asset_exists(BOOK_RIBBONS):
		var rib_tex := _load_texture_from_file(BOOK_RIBBONS)
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
		board_layer.add_child(rib)

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
	board_layer.add_child(inlay)

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
	board_layer.add_child(highlight)

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
		board_layer.add_child(mask)
		return
	var fallback := ColorRect.new()
	fallback.name = node_name
	fallback.color = BOOK_PAGE_PATCH_COLOR
	fallback.position = rect.position
	fallback.size = rect.size
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(fallback)

func _book_page_patch_texture(left: bool) -> Texture2D:
	var base: Texture2D = load(BOOK_FRAME) if ResourceLoader.exists(BOOK_FRAME) else _load_texture_from_file(BOOK_FRAME)
	if base == null:
		return null
	var patch := AtlasTexture.new()
	patch.atlas = base
	patch.region = BOOK_PAGE_PATCH_LEFT_REGION if left else BOOK_PAGE_PATCH_RIGHT_REGION
	return patch

func _load_texture_from_file(path: String) -> Texture2D:
	var file_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(file_path):
		return _load_texture(path)
	var image := Image.load_from_file(file_path)
	if image == null or image.is_empty():
		return _load_texture(path)
	var tex := ImageTexture.create_from_image(image)
	tex.take_over_path(path)
	return tex

func _render_board(opening_drop: bool = false) -> void:
	_clear_layer(board_layer)
	_clear_layer(gem_layer)
	_jelly_nodes = []
	_coat_nodes = []
	_wall_nodes = []
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
				board_layer.add_child(cs)
			var visual_sp: int = _opening_visual_species(r, c) if opening_drop else board.grid[r][c]
			var gnode: Sprite2D = _make_gem(visual_sp, center)
			if gnode != null and opening_drop:
				gnode.position = _opening_drop_start_position(center, r)
			# 阶段5: 若该格已是特效棋子(交换后/续局), 叠 shine 标记
			if gnode != null and board.fx[r][c] != ME.SP_NONE:
				_apply_fx_overlay(gnode, board.fx[r][c])
			node_row.append(gnode)
		_gem_nodes.append(node_row)
	_render_jelly_visuals()
	if opening_drop:
		_wall_nodes = _blank_visual_rows()
	else:
		_render_wall_visuals()
	if opening_drop:
		_render_opening_coat_visuals()
	else:
		_render_coat_visuals()

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

func _opening_drop_delay(row: int, height: int = -1) -> float:
	var h: int = height if height > 0 else board.height
	if h <= 1:
		return 0.0
	var row_from_bottom: int = clampi(h - 1 - row, 0, h - 1)
	var full_span := float(h - 1) * OPENING_DROP_ROW_STAGGER
	var capped_span := minf(full_span, OPENING_DROP_MAX_STAGGER)
	return capped_span * float(row_from_bottom) / float(h - 1)

func _opening_drop_window(height: int = -1) -> float:
	var h: int = height if height > 0 else board.height
	return OPENING_DROP_TIME + _opening_drop_delay(0, h)

func _opening_wall_cells() -> Array:
	var cells := []
	for r in range(board.height):
		for c in range(board.width):
			if board.grid[r][c] == ME.WALL:
				cells.append(Vector2i(c, r))
	return cells

func _opening_freeze_delay(index: int, count: int = -1) -> float:
	var wall_count: int = count if count > 0 else _opening_wall_cells().size()
	if wall_count <= 1:
		return 0.0
	var safe_index: int = clampi(index, 0, wall_count - 1)
	return minf(float(safe_index) * OPENING_FREEZE_STAGGER, OPENING_FREEZE_MAX_STAGGER)

func _opening_freeze_window(wall_count: int) -> float:
	if wall_count <= 0:
		return 0.0
	return _opening_freeze_delay(wall_count - 1, wall_count) + OPENING_FREEZE_SETTLE

func _settle_opening_gems(generation: int) -> bool:
	if generation != _level_generation:
		return false
	for r in range(board.height):
		for c in range(board.width):
			var n: Sprite2D = _gem_nodes[r][c]
			if n != null and is_instance_valid(n):
				n.position = _cell_center(r, c)
	return true

func _settle_opening_coat_markers(generation: int) -> bool:
	if generation != _level_generation:
		return false
	for r in range(_coat_nodes.size()):
		var row = _coat_nodes[r]
		if not (row is Array):
			continue
		for c in range(row.size()):
			var n: Sprite2D = row[c]
			if n != null and is_instance_valid(n):
				n.position = _coat_marker_position(r, c)
	return true

func _show_opening_wall_marker(pos: Vector2i, animate: bool) -> void:
	_clear_gem_node_at(pos.y, pos.x)
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

func _play_opening_freeze(generation: int) -> void:
	var wall_cells: Array = _opening_wall_cells()
	if wall_cells.is_empty() or generation != _level_generation:
		return
	var last_delay := 0.0
	for i in range(wall_cells.size()):
		var delay := _opening_freeze_delay(i, wall_cells.size())
		if delay > last_delay:
			await get_tree().create_timer(delay - last_delay).timeout
			last_delay = delay
		if generation != _level_generation:
			return
		var p: Vector2i = wall_cells[i]
		Fx.spawn_beam(BOSS_C, _cell_center(p.y, p.x), OPENING_STONE_COLOR)
		_show_opening_wall_marker(p, true)
	await get_tree().create_timer(OPENING_FREEZE_SETTLE).timeout
	if generation != _level_generation:
		return

func _apply_opening_freeze_instant(generation: int) -> void:
	if generation != _level_generation:
		return
	_settle_opening_coat_markers(generation)
	for p in _opening_wall_cells():
		_show_opening_wall_marker(p, false)

func _play_opening_drop(generation: int) -> void:
	if not is_inside_tree():
		if _settle_opening_gems(generation):
			_settle_opening_coat_markers(generation)
			_apply_opening_freeze_instant(generation)
			_finish_opening_drop(generation)
		return
	var t: Tween = null
	var any := false
	for r in range(board.height):
		for c in range(board.width):
			var n: Sprite2D = _gem_nodes[r][c]
			if n == null or not is_instance_valid(n):
				continue
			if t == null:
				t = create_tween().set_parallel(true)
				_opening_drop_tween = t
			var target := _cell_center(r, c)
			_queue_opening_drop_node(t, n, target, r)
			any = true
	for r in range(_coat_nodes.size()):
		var row = _coat_nodes[r]
		if not (row is Array):
			continue
		for c in range(row.size()):
			var n: Sprite2D = row[c]
			if n == null or not is_instance_valid(n):
				continue
			if t == null:
				t = create_tween().set_parallel(true)
				_opening_drop_tween = t
			_queue_opening_drop_node(t, n, _coat_marker_position(r, c), r)
			any = true
	if any and t != null:
		t.finished.connect(_on_opening_drop_finished.bind(generation, t), CONNECT_ONE_SHOT)
		return
	_on_opening_drop_finished(generation, null)

func _on_opening_drop_finished(generation: int, tween: Tween) -> void:
	if _opening_drop_tween == tween:
		_opening_drop_tween = null
	if not _settle_opening_gems(generation):
		return
	if not _settle_opening_coat_markers(generation):
		return
	await _play_opening_freeze(generation)
	_finish_opening_drop(generation)

func _queue_opening_drop_node(t: Tween, n: Node2D, target: Vector2, row: int) -> void:
	var delay := _opening_drop_delay(row)
	var tw := t.tween_property(n, "position", target, OPENING_DROP_TIME)
	tw.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _kill_opening_drop_tween() -> void:
	if _opening_drop_tween != null and _opening_drop_tween.is_valid():
		_opening_drop_tween.kill()
	_opening_drop_tween = null

func _finish_opening_drop(generation: int) -> void:
	if generation != _level_generation:
		return
	_busy = false

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
	gem_layer.add_child(gs)
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

func _layer_value(layer: Array, row: int, col: int) -> int:
	if layer.is_empty() or row < 0 or row >= layer.size():
		return 0
	var row_data = layer[row]
	if not (row_data is Array) or col < 0 or col >= row_data.size():
		return 0
	return int(row_data[col])

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
	if board == null or board_layer == null:
		return
	for r in range(board.height):
		var row: Array = []
		for c in range(board.width):
			row.append(_make_jelly_marker(r, c))
		_jelly_nodes.append(row)

func _make_jelly_marker(row: int, col: int) -> ColorRect:
	if _layer_value(board.jelly, row, col) <= 0 or board.grid[row][col] == ME.WALL:
		return null
	var marker := ColorRect.new()
	marker.name = JELLY_MARKER_NAME
	marker.add_to_group(JELLY_MARKER_NAME)
	var size := Vector2(cell_size * JELLY_FILL, cell_size * JELLY_FILL)
	marker.position = _cell_center(row, col) - size * 0.5
	marker.size = size
	marker.color = JELLY_TINT
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 1
	board_layer.add_child(marker)
	return marker

func _render_wall_visuals() -> void:
	_wall_nodes = []
	if board == null or gem_layer == null:
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
	gem_layer.add_child(marker)
	return marker

func _render_coat_visuals() -> void:
	_coat_nodes = []
	if board == null or gem_layer == null or not ResourceLoader.exists(BARRIER_ICE_ICON):
		return
	var tex: Texture2D = load(BARRIER_ICE_ICON)
	for r in range(board.height):
		var row: Array = []
		for c in range(board.width):
			row.append(_make_coat_marker(r, c, tex))
		_coat_nodes.append(row)

func _render_opening_coat_visuals() -> void:
	_coat_nodes = []
	if board == null or gem_layer == null or not ResourceLoader.exists(BARRIER_ICE_ICON):
		return
	var tex: Texture2D = load(BARRIER_ICE_ICON)
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
	gem_layer.add_child(marker)
	return marker

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

# ───────── 整页 UI（对齐参考图） ─────────

# HUD/技能栏抽至 match3/hud.gd + match3/skills.gd(契约 A 消费者, docs/11 §2 / 附录A)。
# level 仅经子控制器编排, 状态闸门 _busy/_settled 仍只住 level(铁律1)。
func _render_chrome(cfg: Dictionary) -> void:
	_cur_cfg = cfg
	# v0.02: 设计稿为纯三消, 移除 Boss 对战区(狐狸/Boss/道具书)。score 计分逻辑不受影响。
	_clear_layer(skill_bar)
	hud.render_chrome(cfg)   # 清角色层 + ui_layer, 渲染顶栏
	skills.build()           # 技能栏(4 头像 + 冷却条 + 时兔相框)

# 阶段6: 每步 resolve/swap 后刷新 HUD(目标卡进度 + 步数徽章)——只重画 ui_layer。
func _refresh_hud() -> void:
	hud.refresh()

func _display_moves_left() -> int:
	return hud.display_moves_left()

func _set_moves_display_override(value: int) -> void:
	hud.set_moves_display_override(value)

func _clear_moves_display_override() -> void:
	hud.clear_moves_display_override()

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

# 技能栏按钮点击 dispatcher(经 skills.skill_pressed 信号触发)。
# 忙/结算闸门 + PetCast dispatch + 锁回调留在 level(铁律1/§4.7); 充能态查 skills。
func _on_skill_pressed(idx: int) -> void:
	if _busy or _settled:
		return
	if board == null:
		return
	if not skills.is_ready(idx):
		if skills.is_clickable(idx):
			if PetRegistry.has_pet(String(LevelSkills.SKILLS[idx].get("skill", ""))):
				_cast_pet(idx, false)   # 未充满: 仍播 peek 反馈演出(无效果)
			else:
				skills.pulse(idx)
		return
	var did := false
	var skill_name := String(LevelSkills.SKILLS[idx].get("skill", ""))
	if PetRegistry.has_pet(skill_name):
		did = _cast_pet(idx, true)   # 宠物施法经控制器接管: 锁/落地/解锁走信号(契约 C)
	else:
		# 仅剩未宠物化的技能走旧分支; 宠物化一个迁出一个(破障已由 RaccoonMinerCast 接管)。
		match skill_name:
			"龙息大招":
				did = await _skill_dragon()
			"幸运祝福":
				did = await _skill_blessing()
	if did:
		if skills.uses_charge(idx):
			skills.clear_charge(idx)   # 放完清零重攒
		skills.refresh_visual()

# ── 宠物施法接线(契约 C, docs/11 §4.3)。经 PetRegistry 实例化施法控制器, 连三信号, start_cast。──
# 锁的读写只在 level.gd: cast_started→上锁, cast_committed→同步棋盘, cast_finished→解锁。
# 换关/退场时 _cancel_active_cast() 兜底; PetCast._exit_tree 也会随子树销毁自动 cancel(双保险)。
func _cast_pet(idx: int, cast_effect: bool) -> bool:
	var skill_name := String(LevelSkills.SKILLS[idx].get("skill", ""))
	var cast_script: Script = PetRegistry.cast_for(skill_name)
	if cast_script == null:
		return false
	_cancel_active_cast()   # 同一时刻只允许一个在途施法
	var cast: PetCast = cast_script.new()
	add_child(cast)
	# 头像显隐/相框置顶 + 冷却刷新经 skills 子控制器(§4.7); 锁的读写仍只在 level 侧(铁律1)。
	cast.setup({
		"skill_bar": skill_bar,
		"board": board,
		"cell_size": cell_size,
		"board_origin": board_origin,
		"cast_effect": cast_effect,
		"load_texture": Callable(self, "_load_texture"),
		"set_avatar_casting": Callable(skills, "_set_time_rabbit_avatar_casting"),
		"refresh_skill_ui": Callable(skills, "refresh_visual"),
	})
	cast.cast_started.connect(_on_pet_cast_started)
	cast.cast_committed.connect(_on_pet_cast_committed)
	cast.cast_finished.connect(_on_pet_cast_finished.bind(cast))
	_active_cast = cast
	if not cast.start_cast():
		_cancel_active_cast()
		return false
	return true

func _on_pet_cast_started() -> void:
	# 施法全程锁盘(PB 修复语义): 演出+落地+归位整段禁止棋盘/键盘交互。
	_busy = true
	_time_rewind_cast_pending = true

func _on_pet_cast_committed() -> void:
	# 效果已落地(board 已 rewind), 同步棋盘视图 + HUD。
	_sel = Vector2i(-1, -1)
	_sel_node = null
	_clear_highlights()
	_render_board(false)
	_refresh_hud()

func _on_pet_cast_finished(cast: PetCast) -> void:
	# 演出全部结束(含归位/取消) → 释放锁。
	# 技能栏冷却/置灰刷新已由施法控制器在归位时调过(_restore_avatar → refresh_skill_ui, 末尾再把头像拉满亮),
	# 这里不重复刷, 否则会把已复原满亮的头像重新压暗(回归 OLD: 收尾后时兔头像满亮)。
	_time_rewind_cast_pending = false
	_busy = false
	if cast == _active_cast:
		_active_cast = null
	if cast != null and is_instance_valid(cast):
		cast.queue_free()

# 取消在途施法并回收控制器(换关/退场)。幂等: 无在途施法时 no-op。
func _cancel_active_cast() -> void:
	_time_rewind_cast_pending = false
	var cast := _active_cast
	_active_cast = null
	if cast != null and is_instance_valid(cast):
		cast.cancel()
		cast.queue_free()

func _ellipse_points(center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = maxi(8, steps)
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

# ── idx2 龙宝宝/龙息大招: 清盘上最多色的全部 + 中间一整行非空格 + beam/爆炸/强震。 ──
func _skill_dragon() -> bool:
	# 找数量最多的 species
	var best_sp: int = -1
	var best_n: int = 0
	for sp in board.species:
		var cnt: int = ME.cells_of_species(board.grid, sp).size()
		if cnt > best_n:
			best_n = cnt
			best_sp = sp
	if best_sp < 0:
		return false
	var cell_set := {}   # 去重(同色 ∪ 中间行)
	for p in ME.cells_of_species(board.grid, best_sp):
		cell_set[p] = true
	var mid: int = board.height / 2
	for c in range(board.width):
		if board.grid[mid][c] >= 0:
			cell_set[Vector2i(c, mid)] = true
	var cells: Array = cell_set.keys()
	if cells.is_empty():
		return false
	_busy = true
	# 龙息: 盘顶 → 盘中央一道光束 + 多点爆炸 + 强震
	var top: Vector2 = _cell_center(0, board.width / 2) - Vector2(0, cell_size)
	Fx.spawn_beam(top, _cell_center(mid, board.width / 2), _fx_color(best_sp))
	for p in cells:
		Fx.spawn_explosion(_cell_center(p.y, p.x), _fx_color(board.grid[p.y][p.x]), 1.4)
	Fx.shake(14.0)
	ME._apply_clears(board.grid, board.fx, cells, [])
	for p in cells:
		var node: Sprite2D = _gem_nodes[p.y][p.x]
		if node != null and is_instance_valid(node):
			node.queue_free()
		_gem_nodes[p.y][p.x] = null
	await _collapse_and_refill()
	await _resolve_cascades()
	_busy = false
	return true

# ── idx3 瓢虫/幸运祝福: 随机一普通格埋炸弹(fx=SP_BOMB, 阶段5渲染显示 shine), 金色庆祝特效。不清盘。 ──
func _skill_blessing() -> bool:
	# 选项A(本实现): 埋个炸弹给玩家下步引爆——不清盘, 留策略空间。
	var cands: Array = []
	for r in range(board.height):
		for c in range(board.width):
			if board.grid[r][c] >= 0 and board.fx[r][c] == ME.SP_NONE:
				cands.append(Vector2i(c, r))
	if cands.is_empty():
		return false
	var p: Vector2i = cands[board.rng.randi() % cands.size()]
	board.fx[p.y][p.x] = ME.SP_BOMB
	var node: Sprite2D = _gem_nodes[p.y][p.x]
	if node != null and is_instance_valid(node):
		_apply_fx_overlay(node, ME.SP_BOMB)
	Fx.spawn_explosion(_cell_center(p.y, p.x), Color(1.0, 0.85, 0.3), 1.5)
	return true

# ───────── 阶段6: 结算(通关/失败) ─────────

# 一步完整结算后判定: 赢→通关面板 / 输→失败面板。须在扣步+刷HUD之后调。
## 判定并进入结算。返回"是否已进入结算"——调用链据此跳过尾部解锁, 保住 _show_result 上的 _busy 锁。
func _check_settlement() -> bool:
	if _settled:
		return true
	if board.is_won():
		_settled = true
		_busy = true
		await _run_win_bonus_and_show()
		return true
	elif board.is_lost():
		_show_result(false)
		return true
	return false

func _run_win_bonus_and_show() -> void:
	await _play_endgame_bonus()
	_refresh_hud()
	_show_result(true)

func _play_endgame_bonus() -> void:
	var bonus_moves: int = maxi(board.moves_left, 0)
	var picks: Array = board.prepare_endgame_bonus_lines()
	if picks.is_empty():
		_clear_moves_display_override()
		return
	if bonus_moves > 0:
		_set_moves_display_override(0)
	await _play_endgame_bonus_conversion_matrix(picks)
	var seeds := []
	for item in picks:
		seeds.append(item["pos"])
	await _play_endgame_bonus_special_blast(seeds, 1)
	await _resolve_endgame_bonus_special_chain()
	_clear_moves_display_override()
	await get_tree().create_timer(ENDGAME_BONUS_RESULT_HOLD).timeout

func _play_endgame_bonus_conversion_matrix(picks: Array) -> void:
	var virtual_fx := {}
	var preview_cells := []
	for item in picks:
		var p: Vector2i = item["pos"]
		var kind: int = int(item["kind"])
		if kind == ME.SP_NONE:
			continue
		var n: Sprite2D = _gem_nodes[p.y][p.x]
		if n == null or not is_instance_valid(n):
			continue
		virtual_fx[p] = kind
		preview_cells.append(p)
	if virtual_fx.is_empty():
		return
	await _play_colorbomb_absorb_preview(Vector2i(-1, -1), preview_cells, virtual_fx.keys(), _endgame_bonus_conversion_preview_center(preview_cells), false)
	await _show_colorbomb_virtual_conversion(virtual_fx)

func _endgame_bonus_conversion_preview_center(preview_cells: Array) -> Vector2:
	if preview_cells.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for p in preview_cells:
		center += _cell_center(p.y, p.x)
	return center / float(preview_cells.size())

func _play_endgame_bonus_special_blast(seeds: Array, score_level: int) -> bool:
	var clear_set: Dictionary = ME._expand_triggers(board.grid, board.fx, seeds)
	var cells: Array = clear_set.keys()
	if cells.is_empty():
		return false
	var raw_special_fx_cells = _special_fx_cells_for_clear_visuals(cells)
	var clear_visual_timing := _clear_visual_timing_for_triggers(seeds)
	var acc: Dictionary = ME.account_clears(board.grid, cells, board.fx, board.rng, board.species, board._layers())
	board._accumulate(acc.get("by_species", {}))
	board._accumulate_progress(acc)
	_refresh_jelly_visuals()
	_refresh_coat_visuals()
	var locked := {}
	for p in acc.get("locked", []):
		locked[p] = true
	var to_clear := []
	for p in cells:
		if not locked.has(p):
			to_clear.append(p)
	for bp in acc.get("cake_blast", []):
		to_clear.append(bp)
	board._gain(ME.score_for_clear(to_clear.size(), score_level))
	await _play_clear(to_clear, [], {}, raw_special_fx_cells, clear_visual_timing)
	ME._apply_clears(board.grid, board.fx, to_clear, [])
	for p in to_clear:
		var n: Sprite2D = _gem_nodes[p.y][p.x]
		if n != null and is_instance_valid(n):
			n.queue_free()
		_gem_nodes[p.y][p.x] = null
	await _collapse_and_refill()
	return true

func _resolve_endgame_bonus_special_chain() -> void:
	var guard := 0
	while guard < ENDGAME_BONUS_SPECIAL_CHAIN_MAX:
		guard += 1
		await _resolve_cascades()
		var seeds := _endgame_bonus_special_seeds()
		if seeds.is_empty():
			break
		var blasted: bool = await _play_endgame_bonus_special_blast(seeds, guard + 1)
		if not blasted:
			break

func _endgame_bonus_special_seeds() -> Array:
	var seeds := []
	if board == null or board.fx.is_empty():
		return seeds
	for y in range(board.height):
		for x in range(board.width):
			var cell: int = board.grid[y][x]
			if cell == ME.EMPTY or cell == ME.WALL:
				continue
			if int(board.fx[y][x]) != ME.SP_NONE:
				seeds.append(Vector2i(x, y))
	return seeds

# 程序绘制居中半透明遮罩 + 结算面板(标题 + 下一关/重试按钮)。无现成素材, 纯绘制。
# 锁输入(_settled=true), 按钮: 通关→下一关 / 失败→重试本关。
# 结算: 上状态闸门(铁律1只住 level) + 经 hud 渲染面板; 按钮回调 Callable 注入连回 level。
func _show_result(win: bool) -> void:
	_settled = true
	_busy = true
	hud.show_result(win, Callable(self, "_on_result_button"))

# 结算按钮点击: 通关→下一关; 失败→重载本关。先解锁结算态再 load。
func _on_result_button(win: bool) -> void:
	_settled = false
	_busy = false
	if win:
		_goto_relative(1)   # 下一关(可玩关循环)
	else:
		load_level(_level_idx)   # 重试本关

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

func _sprite_fit(layer: CanvasLayer, path: String, center: Vector2, max_size: float, use_key: bool) -> Sprite2D:
	var tex := _load_texture(path)
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.position = center
	s.scale = _fit_scale(tex, max_size)
	if use_key:
		s.material = _magenta_material()
	layer.add_child(s)
	return s

func _label(layer: CanvasLayer, text: String, center: Vector2, font_size: int, color: Color, box_w: float, outline_size: int = 5, outline_color: Color = Color(0, 0, 0, 0.7)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline_size)
	l.add_theme_color_override("font_outline_color", outline_color)
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

# 翻到相对当前的第 step 关(+1下一关/-1上一关), 在可玩关列表里循环。
# _levels 为空(回退)时改用 LevelConfig 下标循环。
func _goto_relative(step: int) -> void:
	if not _playable.is_empty():
		_play_pos = (_play_pos + step + _playable.size()) % _playable.size()
		_level_idx = _playable[_play_pos]
	else:
		var n: int = LevelConfig.count()
		_level_idx = (_level_idx + step + n) % n
	load_level(_level_idx)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _busy or _settled or _time_rewind_cast_pending:
			return   # 演出/施法/结算进行中禁止键盘翻关, 防止 load_level 与在途 await 链并发撕裂
		match event.keycode:
			KEY_RIGHT, KEY_SPACE:
				_goto_relative(1)
			KEY_LEFT:
				_goto_relative(-1)
		return
	if _busy or _settled or _time_rewind_cast_pending:
		return   # 结算遮罩/施法演出中 → 棋盘交互锁死(只接结算面板按钮)
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
	var n: Sprite2D = _gem_nodes[cell.y][cell.x]
	if n == null or not is_instance_valid(n):
		return
	_sel_node = n
	_sel_node_scale = n.scale
	_sel_node_mod = n.modulate
	n.scale = _sel_node_scale * 1.25       # 放大
	n.modulate = Color(1.5, 1.42, 1.18)    # 提亮(暖金光)
	n.z_index = 20                          # 置顶, 不被相邻棋子盖住(修"偶尔不显示")

func _deselect() -> void:
	_sel = Vector2i(-1, -1)
	if _sel_node != null and is_instance_valid(_sel_node):
		_sel_node.scale = _sel_node_scale
		_sel_node.modulate = _sel_node_mod
		_sel_node.z_index = 0
	_sel_node = null

func _try_swap(a: Vector2i, b: Vector2i) -> void:
	# 问题2: 彩球参与的交换(彩球+任意相邻格)是激活组合, 不走 is_legal_swap。
	var cb_pos := Vector2i(-1, -1)
	var partner := Vector2i(-1, -1)
	if board.fx[a.y][a.x] == ME.SP_COLORBOMB:
		cb_pos = a
		partner = b
	elif board.fx[b.y][b.x] == ME.SP_COLORBOMB:
		cb_pos = b
		partner = a
	if cb_pos.x >= 0:
		# partner 必须非墙/非空(普通宝石或特效宝石); 否则当非法, 不消耗、不动作。
		if board.grid[partner.y][partner.x] < 0:
			return
		await _resolve_colorbomb(cb_pos, partner)
		return
	if board.fx[a.y][a.x] != ME.SP_NONE and board.fx[b.y][b.x] != ME.SP_NONE:
		await _resolve_fusion(a, b)
		return
	_busy = true
	_clear_highlights()
	var legal: bool = ME.is_legal_swap(board.grid, a, b, 1, board._layers())
	var na: Sprite2D = _gem_nodes[a.y][a.x]
	var nb: Sprite2D = _gem_nodes[b.y][b.x]
	var pa: Vector2 = _cell_center(a.y, a.x)
	var pb: Vector2 = _cell_center(b.y, b.x)
	await _animate_swap(na, nb, pa, pb)
	if not legal:
		await _animate_swap(na, nb, pb, pa)  # 非法换回
		_busy = false
		return
	_remember_time_rewind_snapshot()
	# 提交交换(数据 + 节点引用)
	ME._swap_cells(board.grid, a, b)
	ME._swap_cells(board.fx, a, b)
	_gem_nodes[a.y][a.x] = nb
	_gem_nodes[b.y][b.x] = na
	# 阶段3: 消除-下落-补充-连锁
	var spawn_preference := ME.swap_special_spawn_preference(board.grid, board.fx, board._layers(), b, a)
	var settle: Dictionary = await _resolve_cascades(spawn_preference, true)
	var settled_now: bool = await _finish_consumed_move(int(settle.get("choco_cleared", 0)), int(settle.get("cascades", 0)))
	if not settled_now:
		_busy = false   # 已结算时保持 _show_result 的锁, 由结算面板按钮接管流转

func _remember_time_rewind_snapshot() -> void:
	if board == null:
		return
	if board.skill != "timerewind" or board.rewind_used:
		return
	board._push_history()
	skills.refresh_visual()

## 问题2: 彩球激活组合。cb_pos/partner 为【交换前】坐标(引擎 colorbomb_clear_plan 读交换前 fx/grid)。
## 彩球+普通=该色全消; 彩球+条纹=全场该色变条纹引爆; 彩球+十字=全场该色变十字引爆; 双彩球=全盘消。
func _resolve_colorbomb(cb_pos: Vector2i, partner: Vector2i) -> void:
	_busy = true
	_clear_highlights()
	_deselect()
	# 引擎纯函数算好全部清除格(含触发链)。用交换前坐标。
	# override 记录彩球+条纹/十字星时的"虚拟特效"爆点，表现层据此播放同几何的动画。
	var plan: Dictionary = ME.colorbomb_clear_plan(board.grid, board.fx, cb_pos, partner)
	var cells: Array = plan["cells"]
	var virtual_fx: Dictionary = plan.get("override", {})
	var visual_species: Dictionary = ClearVisuals.special_clear_species_overrides(board.grid, board.fx, cells, {}, virtual_fx)
	if cells.is_empty():
		_busy = false
		return
	_remember_time_rewind_snapshot()
	# 算账(在清空前读 species/fx): 目标计数 + 计分 + 技能充能。复用 board 累加逻辑。
	var acc: Dictionary = ME.account_clears(board.grid, cells, board.fx, board.rng, board.species, board._layers())
	board._accumulate(acc.get("by_species", {}))
	board._accumulate_progress(acc)
	_refresh_jelly_visuals()
	_refresh_coat_visuals()
	skills.charge(acc.get("by_species", {}))
	var locked := {}
	for p in acc.get("locked", []):
		locked[p] = true
	var to_clear := []
	for p in cells:
		if not locked.has(p):
			to_clear.append(p)
	for bp in acc.get("cake_blast", []):
		to_clear.append(bp)
	board._gain(ME.score_for_clear(to_clear.size(), 1))
	# 表现: 彩球吸收预览 + 对清除格放特效(限量精细, 避免一次太多卡顿)。
	await _play_colorbomb_absorb_preview(cb_pos, cells, virtual_fx.keys())
	if ClearVisuals.colorbomb_combo_has_conversion_phase(virtual_fx):
		await _show_colorbomb_virtual_conversion(virtual_fx)
	var fine_budget: int = COLORBOMB_FINE_CLEAR_BUDGET
	var fx_batch_count := 0
	for p in cells:
		if p == cb_pos:
			continue
		var spawned_fx := false
		var fk: int = board.fx[p.y][p.x]
		var vk: int = int(virtual_fx.get(p, ME.SP_NONE))
		if vk != ME.SP_NONE:
			_play_special_fx(p, vk)   # 彩球+十字星/条纹: 目标色格按虚拟特效播同几何动画
			spawned_fx = true
		elif fk != ME.SP_NONE:
			_play_special_fx(p, fk)   # 卷入的条纹/十字/彩球放几何特效
			spawned_fx = true
		elif visual_species.has(p):
			Fx.spawn_shatter(_cell_center(p.y, p.x), _gem_raw_color(int(visual_species[p])))
			spawned_fx = true
		elif fine_budget > 0:
			var sp: int = board.grid[p.y][p.x]
			if sp >= 0 and sp < GEM_KEYS.size():
				Fx.spawn_elimination(GEM_KEYS[sp], _cell_center(p.y, p.x), cell_size * 0.72)
				fine_budget -= 1
				spawned_fx = true
		if spawned_fx:
			fx_batch_count += 1
			if fx_batch_count >= COLORBOMB_CLEAR_FX_BATCH_SIZE:
				fx_batch_count = 0
				await get_tree().process_frame
	await get_tree().create_timer(0.30).timeout   # 让爆发可见
	# 清除: 只清 account_clears 过滤后的格，锁住/原料/巧克力/爆米花/神秘糖仅破层或揭开。
	ME._apply_clears(board.grid, board.fx, to_clear, [])
	for p in to_clear:
		var n: Sprite2D = _gem_nodes[p.y][p.x]
		if n != null and is_instance_valid(n):
			n.queue_free()
		_gem_nodes[p.y][p.x] = null
	await _collapse_and_refill()
	var settle: Dictionary = await _resolve_cascades()   # 收尾连锁(下落后可能形成新匹配)
	var settled_now: bool = await _finish_consumed_move(int(acc.get("choco_cleared", 0)) + int(settle.get("choco_cleared", 0)), int(settle.get("cascades", 0)))
	if not settled_now:
		_busy = false


func _colorbomb_absorb_preview_targets(cb_pos: Vector2i, cells: Array, priority_targets: Array = [], budget_limit: int = COLORBOMB_ABSORB_TARGET_BUDGET) -> Array:
	var targets := []
	if not priority_targets.is_empty():
		targets = _colorbomb_conversion_outline_targets(cb_pos, cells, priority_targets)
	else:
		for p in cells:
			if p == cb_pos:
				continue
			targets.append(p)
		var end_pos := _cell_center(cb_pos.y, cb_pos.x) + Vector2(0.0, cell_size * 0.18)
		targets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _cell_center(a.y, a.x).distance_squared_to(end_pos) < _cell_center(b.y, b.x).distance_squared_to(end_pos)
		)
	var capped := []
	for i in range(mini(targets.size(), budget_limit)):
		capped.append(targets[i])
	return capped


func _colorbomb_conversion_outline_targets(cb_pos: Vector2i, cells: Array, priority_targets: Array = []) -> Array:
	if priority_targets.is_empty():
		return []
	var allowed := {}
	for p in cells:
		if p == cb_pos:
			continue
		allowed[p] = true
	var seen := {}
	var targets := []
	for p in priority_targets:
		if p == cb_pos:
			continue
		if not allowed.has(p):
			continue
		if seen.has(p):
			continue
		seen[p] = true
		targets.append(p)
	targets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return targets


func _play_colorbomb_absorb_preview(cb_pos: Vector2i, cells: Array, priority_targets: Array = [], end_pos_override: Variant = null, pulse_core: bool = true) -> void:
	var end_pos := _cell_center(cb_pos.y, cb_pos.x) + Vector2(0.0, cell_size * 0.18)
	if end_pos_override is Vector2:
		end_pos = end_pos_override
	var available_cells := []
	for p in cells:
		if p == cb_pos:
			continue
		if _gem_nodes[p.y][p.x] == null:
			continue
		if board.grid[p.y][p.x] < 0:
			continue
		available_cells.append(p)
	var conversion_outline_targets := _colorbomb_conversion_outline_targets(cb_pos, available_cells, priority_targets)
	for i in range(conversion_outline_targets.size()):
		var outline_pos: Vector2i = conversion_outline_targets[i]
		var outline_start := _cell_center(outline_pos.y, outline_pos.x)
		var outline_col := _fx_color(board.grid[outline_pos.y][outline_pos.x])
		Fx.spawn_target_outline(outline_start, outline_col, cell_size * 0.88, 0.012 * float(i % 8))
	var targets := _colorbomb_absorb_preview_targets(cb_pos, available_cells, priority_targets, COLORBOMB_ABSORB_TARGET_BUDGET)
	var budget: int = mini(targets.size(), COLORBOMB_ABSORB_TARGET_BUDGET)
	var max_arrival := 0.0
	for i in range(budget):
		var p: Vector2i = targets[i]
		var start := _cell_center(p.y, p.x)
		var sp: int = board.grid[p.y][p.x]
		var col := _fx_color(sp)
		var delay := 0.05 + 0.055 * float(i % 5) + 0.018 * float(i / 5)
		var orb_dur := 0.42
		if delay > 0.0:
			get_tree().create_timer(delay).timeout.connect(Fx.spawn_absorb_residue.bind(start, col), CONNECT_ONE_SHOT)
		else:
			Fx.spawn_absorb_residue(start, col)
		if conversion_outline_targets.is_empty():
			Fx.spawn_target_outline(start, col, cell_size * 0.88, delay * 0.35)
		Fx.spawn_color_absorb_orb(start, end_pos, col, delay, orb_dur)
		var arrival := delay + orb_dur * 1.22
		max_arrival = maxf(max_arrival, arrival)
		if pulse_core:
			_pulse_colorbomb_core(cb_pos, arrival)
	if budget > 0:
		await get_tree().create_timer(max_arrival + 0.08).timeout
		if pulse_core:
			_pulse_colorbomb_core(cb_pos)
		await get_tree().create_timer(0.18).timeout
	else:
		await get_tree().create_timer(0.08).timeout

func _colorbomb_node_at(cb_pos: Vector2i) -> Sprite2D:
	if cb_pos.y < 0 or cb_pos.y >= _gem_nodes.size() or cb_pos.x < 0 or cb_pos.x >= _gem_nodes[cb_pos.y].size():
		return null
	var root: Sprite2D = _gem_nodes[cb_pos.y][cb_pos.x]
	if root == null or not is_instance_valid(root):
		return null
	return root

func _pulse_colorbomb_core(cb_pos: Vector2i, delay: float = 0.0) -> void:
	if delay > 0.0 and is_inside_tree():
		get_tree().create_timer(delay).timeout.connect(_pulse_colorbomb_core.bind(cb_pos, 0.0), CONNECT_ONE_SHOT)
		return
	var root := _colorbomb_node_at(cb_pos)
	if root == null:
		return
	var base_self := root.self_modulate
	var base_scale := root.scale
	var bright := Color(1.30, 1.22, 0.92, 1.0)
	var t := create_tween()
	t.tween_property(root, "self_modulate", bright, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(root, "scale", base_scale * 1.06, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(root, "self_modulate", base_self, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(root, "scale", base_scale, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _show_colorbomb_virtual_conversion(virtual_fx: Dictionary) -> void:
	if not ClearVisuals.colorbomb_combo_has_conversion_phase(virtual_fx):
		return
	var tween := create_tween().set_parallel(true)
	for p in virtual_fx:
		var kind: int = int(virtual_fx[p])
		if kind == ME.SP_NONE:
			continue
		var n: Sprite2D = _gem_nodes[p.y][p.x]
		if n == null or not is_instance_valid(n):
			continue
		_apply_fx_overlay(n, kind)
		var base_scale: Vector2 = n.scale
		var base_mod: Color = n.modulate
		var glow_mod := base_mod.lerp(Color(1.0, 0.96, 0.62, base_mod.a), 0.62)
		tween.tween_property(n, "scale", base_scale * 1.13, ClearVisuals.COLORBOMB_CONVERT_TIME * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(n, "modulate", glow_mod, ClearVisuals.COLORBOMB_CONVERT_TIME * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(n, "scale", base_scale, ClearVisuals.COLORBOMB_CONVERT_TIME * 0.45).set_delay(ClearVisuals.COLORBOMB_CONVERT_TIME * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(n, "modulate", base_mod, ClearVisuals.COLORBOMB_CONVERT_TIME * 0.45).set_delay(ClearVisuals.COLORBOMB_CONVERT_TIME * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(ClearVisuals.colorbomb_virtual_conversion_delay(virtual_fx)).timeout


func _resolve_fusion(a: Vector2i, b: Vector2i) -> void:
	_busy = true
	_clear_highlights()
	_deselect()
	var ka: int = board.fx[a.y][a.x]
	var kb: int = board.fx[b.y][b.x]
	var na: Sprite2D = _gem_nodes[a.y][a.x]
	var nb: Sprite2D = _gem_nodes[b.y][b.x]
	var pa: Vector2 = _cell_center(a.y, a.x)
	var pb: Vector2 = _cell_center(b.y, b.x)
	_remember_time_rewind_snapshot()
	await _animate_swap(na, nb, pa, pb)
	ME._swap_cells(board.grid, a, b)
	ME._swap_cells(board.fx, a, b)
	_gem_nodes[a.y][a.x] = nb
	_gem_nodes[b.y][b.x] = na
	var seeds: Array = ME.special_fusion_cells(board.grid, a, b, ka, kb)
	var fusion_fx: Array = board.fx.duplicate(true)
	fusion_fx[a.y][a.x] = ME.SP_NONE
	fusion_fx[b.y][b.x] = ME.SP_NONE
	var to_set: Dictionary = ME._expand_triggers(board.grid, fusion_fx, seeds)
	var cells: Array = to_set.keys()
	if cells.is_empty():
		var settled_early: bool = await _finish_consumed_move(0, 0)
		if not settled_early:
			_busy = false
		return
	var fusion_special_fx_cells = _special_fx_cells_for_clear_visuals(cells)
	var fusion_clear_timing := _clear_visual_timing_for_triggers(seeds, {}, fusion_fx)
	var acc: Dictionary = ME.account_clears(board.grid, cells, board.fx, board.rng, board.species, board._layers())
	board._accumulate(acc.get("by_species", {}))
	board._accumulate_progress(acc)
	_refresh_jelly_visuals()
	_refresh_coat_visuals()
	skills.charge(acc.get("by_species", {}))
	var locked := {}
	for p in acc.get("locked", []):
		locked[p] = true
	var to_clear := []
	for p in cells:
		if not locked.has(p):
			to_clear.append(p)
	for bp in acc.get("cake_blast", []):
		to_clear.append(bp)
	board._gain(ME.score_for_clear(to_clear.size(), 1))
	_play_fusion_fx_after_swap(a, b, ka, kb)
	board.fx[a.y][a.x] = ME.SP_NONE
	board.fx[b.y][b.x] = ME.SP_NONE
	fusion_special_fx_cells.erase(a)
	fusion_special_fx_cells.erase(b)
	await _play_clear(to_clear, [], {}, fusion_special_fx_cells, fusion_clear_timing)
	ME._apply_clears(board.grid, board.fx, to_clear, [])
	for p in to_clear:
		var n: Sprite2D = _gem_nodes[p.y][p.x]
		if n != null and is_instance_valid(n):
			n.queue_free()
		_gem_nodes[p.y][p.x] = null
	await _collapse_and_refill()
	var settle: Dictionary = await _resolve_cascades()
	var settled_now: bool = await _finish_consumed_move(int(acc.get("choco_cleared", 0)) + int(settle.get("choco_cleared", 0)), int(settle.get("cascades", 0)))
	if not settled_now:
		_busy = false


func _play_fusion_fx_after_swap(a: Vector2i, b: Vector2i, ka: int, kb: int) -> void:
	var a_after := b
	var b_after := a
	var a_line := ka == ME.SP_LINE_H or ka == ME.SP_LINE_V
	var b_line := kb == ME.SP_LINE_H or kb == ME.SP_LINE_V
	var a_bomb := ka == ME.SP_BOMB
	var b_bomb := kb == ME.SP_BOMB
	if a_line and b_line:
		_play_special_fx(a_after, ka)
		_play_special_fx(b_after, kb)
	elif a_bomb and b_line:
		_play_wide_line_fx(b_after, kb, _line_fx_color(board.grid[b_after.y][b_after.x]))
	elif a_line and b_bomb:
		_play_wide_line_fx(a_after, ka, _line_fx_color(board.grid[a_after.y][a_after.x]))
	elif a_bomb and b_bomb:
		_play_double_bomb_fusion_fx(a_after, b_after)


func _play_double_bomb_fusion_fx(a_after: Vector2i, b_after: Vector2i) -> void:
	Fx.spawn_local_burst(_cell_center(a_after.y, a_after.x), _fx_color(board.grid[a_after.y][a_after.x]), cell_size * 2.5, 25)
	Fx.spawn_local_burst(_cell_center(b_after.y, b_after.x), _fx_color(board.grid[b_after.y][b_after.x]), cell_size * 2.5, 25)


func _play_wide_line_fx(pos: Vector2i, kind: int, col: Color) -> void:
	if kind == ME.SP_LINE_H:
		for dy in range(-1, 2):
			var row := pos.y + dy
			if row >= 0 and row < board.height:
				Fx.spawn_line_blast(_cell_center(row, 0), _cell_center(row, board.width - 1), col)
	elif kind == ME.SP_LINE_V:
		for dx in range(-1, 2):
			var col_idx := pos.x + dx
			if col_idx >= 0 and col_idx < board.width:
				Fx.spawn_line_blast(_cell_center(0, col_idx), _cell_center(board.height - 1, col_idx), col)


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

func _clear_highlights() -> void:
	for mk in _hl_markers:
		if mk != null and is_instance_valid(mk):
			mk.queue_free()
	_hl_markers = []

## 阶段5: 引擎驱动逐级连锁——引擎算"清哪些格/生成什么特效"，视图负责逐级动画。
## 每级: collect_clears → 播特效+淡出 → _apply_clears(落特效/清格) → 节点同步 → 下落补充。
func _resolve_cascades(preferred_spawn: Vector2i = Vector2i(-1, -1), force_preferred: bool = false) -> Dictionary:
	var guard: int = 0
	var cascade_level: int = 0   # 连锁级数(1起): 越深计分倍率越高, 与引擎 resolve 同口径
	var step_choco := 0
	var cascade_preferred := preferred_spawn
	var cascade_force_preferred := force_preferred
	while guard < 30:
		guard += 1
		var cascade_trigger_seeds: Array = ME.find_matches(board.grid, board._layers())
		var c: Dictionary = ME.collect_clears(board.grid, board.fx, board._layers(), cascade_preferred, ME.SP_NONE, cascade_force_preferred)
		cascade_preferred = Vector2i(-1, -1)
		cascade_force_preferred = false
		var to_clear: Array = c["to_clear"]
		var spawns: Array = c["spawns"]
		if to_clear.is_empty():
			break
		cascade_level += 1
		# spawn_set: 这些格变特效棋子(节点不删/不淡出, 只叠 shine)
		var spawn_set := {}
		var triggered_spawn_set: Dictionary = c.get("triggered_spawns", {})
		var triggered_spawn_fx: Dictionary = c.get("triggered_spawn_fx", {})
		var protected_spawn_set := {}
		for s in spawns:
			var sp_pos: Vector2i = s["pos"]
			spawn_set[sp_pos] = true
			if not triggered_spawn_set.has(sp_pos):
					protected_spawn_set[sp_pos] = true
		var raw_special_fx_cells = _special_fx_cells_for_clear_visuals(to_clear, triggered_spawn_fx)
		var clear_visual_timing := _clear_visual_timing_for_triggers(cascade_trigger_seeds, triggered_spawn_fx)
		# 阶段6: 目标计数(路线A 手动累加)。account_clears 须在 _apply_clears 之前调(要读未清空的 species),
		# 它会原地递减 board 的障碍层数组(经 _layers() 引用), 与 board.try_swap 路径同口径。
		# 严格复用 board 内部累加逻辑(_accumulate / _accumulate_progress), 字段名/key 类型完全一致, 杜绝分叉。
		var acc: Dictionary = ME.account_clears(board.grid, to_clear, board.fx, board.rng, board.species, board._layers())
		board._accumulate(acc.get("by_species", {}))   # collected[species] 累加(key=int)
		board._accumulate_progress(acc)                # 果冻/涂层/巧克力/炸弹/爆米花/蛋糕/神秘糖累加
		step_choco += int(acc.get("choco_cleared", 0))
		# 占位: overlays 消费者(契约B, P7)尚不存在; 现 jelly/coat 视觉刷新即其雏形(§2.4), 暂留原位。
		_refresh_jelly_visuals()
		_refresh_coat_visuals()                       # 同步已破冰锁, 避免数据清了画面还在
		# 计分: 锁住格(coat/choco/popcorn/mystery)不计入清除数, 与 board 直清路径同口径。
		var locked := {}
		for p in acc.get("locked", []):
			locked[p] = true
		var filtered_clear := []
		for p in to_clear:
			if not locked.has(p):
				filtered_clear.append(p)
		for bp in acc.get("cake_blast", []):
			filtered_clear.append(bp)
		to_clear = filtered_clear
		var score_gained: int = ME.score_for_clear(to_clear.size(), cascade_level)
		board._gain(score_gained)
		for s in spawns:
			var sp_pos: Vector2i = s["pos"]
			board.fx[sp_pos.y][sp_pos.x] = int(triggered_spawn_fx.get(sp_pos, s["kind"]))
		# 契约 A: 组装 StepReport(只读数据包, 字段/序照抄 §2.2), 按固定序分发(§2.3 / 任务§3)。
		# 数据=本级联局部变量正式化命名+改道, 行为零变化。消费者只读 report, 不回写/不互调。
		var report := {
			"cascade_level": cascade_level,
			"to_clear": to_clear,                       # 已剔 locked、已并 cake_blast
			"spawns": spawns,
			"protected_spawns": protected_spawn_set,
			"triggered_spawn_fx": triggered_spawn_fx,
			"account": acc,                             # account_clears 原样(9 计数器/by_species/locked/cake_blast)
			"score_gained": score_gained,
		}
		hud.on_step(report)                            # 目标进度/步数(读 report.account)
		skills.on_step(report)                         # by_species 充能(现 _charge_skills)
		# overlays.on_step(report)                     # 占位: 障碍演出消费者(契约B, P7)尚不存在
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
	return {"choco_cleared": step_choco, "cascades": cascade_level}

func _special_fx_cells_for_clear_visuals(cells: Array, overrides: Dictionary = {}) -> Dictionary:
	var out := {}
	if board == null:
		return out
	for p in cells:
		if not (p is Vector2i):
			continue
		if p.y < 0 or p.y >= board.height or p.x < 0 or p.x >= board.width:
			continue
		var fx_kind: int = int(overrides.get(p, ME.SP_NONE))
		if fx_kind == ME.SP_NONE:
			fx_kind = int(board.fx[p.y][p.x])
		if fx_kind != ME.SP_NONE:
			out[p] = fx_kind
	return out

func _clear_visual_timing_for_triggers(seeds: Array, overrides: Dictionary = {}, fx_snapshot: Array = []) -> Dictionary:
	var cell_delay := {}
	var special_delay := {}
	if board == null:
		return {"cell_delay": cell_delay, "special_delay": special_delay}
	var queue := []
	var queued := {}
	for raw in seeds:
		if not (raw is Vector2i):
			continue
		var p: Vector2i = raw
		var kind := _special_kind_for_clear_timing(p, overrides, fx_snapshot)
		if kind == ME.SP_NONE or queued.has(p):
			continue
		queue.append({"pos": p, "delay": 0.0})
		queued[p] = true
		special_delay[p] = 0.0
	var cursor := 0
	while cursor < queue.size():
		var item: Dictionary = queue[cursor]
		cursor += 1
		var p: Vector2i = item["pos"]
		var base_delay: float = float(item["delay"])
		var kind := _special_kind_for_clear_timing(p, overrides, fx_snapshot)
		if kind == ME.SP_NONE:
			continue
		for e in ME.special_effect_cells(board.grid, p, kind, board.grid[p.y][p.x]):
			var delay := base_delay + _special_effect_cell_delay(p, kind, e)
			if not cell_delay.has(e) or delay < float(cell_delay[e]):
				cell_delay[e] = delay
			var hit_kind := _special_kind_for_clear_timing(e, overrides, fx_snapshot)
			if hit_kind != ME.SP_NONE and not queued.has(e):
				queue.append({"pos": e, "delay": delay})
				queued[e] = true
				special_delay[e] = delay
	return {"cell_delay": cell_delay, "special_delay": special_delay}

func _special_kind_for_clear_timing(pos: Vector2i, overrides: Dictionary, fx_snapshot: Array = []) -> int:
	if board == null:
		return ME.SP_NONE
	if pos.y < 0 or pos.y >= board.height or pos.x < 0 or pos.x >= board.width:
		return ME.SP_NONE
	if overrides.has(pos):
		return int(overrides[pos])
	var fx_layer: Array = fx_snapshot if not fx_snapshot.is_empty() else board.fx
	if fx_layer.is_empty():
		return ME.SP_NONE
	return int(fx_layer[pos.y][pos.x])

func _special_effect_cell_delay(trigger: Vector2i, kind: int, cell: Vector2i) -> float:
	match kind:
		ME.SP_LINE_H:
			return float(absi(cell.x - trigger.x)) * LINE_CLEAR_STAGGER
		ME.SP_LINE_V:
			return float(absi(cell.y - trigger.y)) * LINE_CLEAR_STAGGER
		_:
			return 0.0

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
	var clear_set := {}
	var played_special_fx := {}
	for p in to_clear:
		clear_set[p] = true
	for p in to_clear:
		var clear_delay: float = float(line_clear_delays.get(p, 0.0))
		max_fx_delay = maxf(max_fx_delay, clear_delay)
		var fx_kind: int = board.fx[p.y][p.x]
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
				pop.tween_property(n, "scale", base_scale * CLEAR_POP_SCALE, CLEAR_POP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				pop.tween_property(n, "scale", base_scale * CLEAR_BURST_SCALE, CLEAR_TIME - CLEAR_POP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				pop.parallel().tween_property(n, "modulate:a", 0.0, CLEAR_TIME - CLEAR_POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
		await get_tree().create_timer(ELIM_HOLD + max_fx_delay).timeout

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

func _clear_gem_node_at(row: int, col: int) -> void:
	var n: Sprite2D = _gem_nodes[row][col]
	_gem_nodes[row][col] = null
	if n != null and is_instance_valid(n):
		n.queue_free()

func _node_matches_species(node: Sprite2D, sp: int) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_meta("species"):
		return false
	return int(node.get_meta("species")) == sp

func _replace_gem_node(row: int, col: int, old_node: Sprite2D = null) -> Sprite2D:
	if old_node != null and is_instance_valid(old_node):
		old_node.queue_free()
	var sp: int = board.grid[row][col]
	if sp < 0:
		return null
	var node := _make_gem(sp, _cell_center(row, col))
	if node != null:
		_apply_fx_overlay(node, board.fx[row][col])
	return node

func _reuse_or_replace_gem_node(row: int, col: int, node: Sprite2D) -> Sprite2D:
	var sp: int = board.grid[row][col]
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
			var sp: int = board.grid[row][col]
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

func _animate_board_changes_from_snapshot(before_grid: Array, old_nodes: Array) -> void:
	if board == null:
		return
	if before_grid.is_empty() or old_nodes.is_empty():
		_sync_changed_visuals_to_board()
		return
	if _grid_has_fall_obstacle(before_grid) or _grid_has_fall_obstacle(board.grid):
		var wall_slide_time := _sync_wall_slide_visuals(before_grid, old_nodes)
		_repair_missing_gem_nodes_from_board()
		_refresh_wall_visuals()
		_refresh_jelly_visuals()
		_refresh_coat_visuals()
		if wall_slide_time > 0.0:
			await get_tree().create_timer(wall_slide_time).timeout
		return
	var new_nodes: Array = _blank_visual_rows()
	var t := create_tween().set_parallel(true)
	var moved := false
	for col in range(board.width):
		var seg_end: int = board.height - 1
		for row in range(board.height - 1, -2, -1):
			if row >= 0 and not _fall_barrier_in_grid(before_grid, row, col):
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
	if moved:
		await t.finished

func debug_first_legal_swap() -> bool:
	for y in range(board.height):
		for x in range(board.width):
			var a := Vector2i(x, y)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b: Vector2i = a + d
				if b.x < board.width and b.y < board.height and ME.is_legal_swap(board.grid, a, b, 1, board._layers()):
					_try_swap(a, b)
					return true
	return false

func _finish_consumed_move(step_choco: int, cascades: int) -> bool:
	var before_grid: Array = board.grid.duplicate(true)
	var before_fx: Array = board.fx.duplicate(true)
	var old_nodes: Array = _gem_nodes.duplicate(true)
	board._settle_consumed_move(step_choco, cascades)
	if before_grid != board.grid or before_fx != board.fx:
		await _animate_board_changes_from_snapshot(before_grid, old_nodes)
	else:
		_refresh_jelly_visuals()
		_refresh_coat_visuals()
	_refresh_hud()
	skills.refresh_visual()
	var settled_now: bool = await _check_settlement()
	if is_inside_tree():
		await get_tree().process_frame
	return settled_now

func _fall_barrier_in_grid(grid_snapshot: Array, row: int, col: int) -> bool:
	return LevelMotion.fall_barrier_in_grid(grid_snapshot, board.coat, board.choco, row, col)

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
		if board.grid[row][col] != ME.EMPTY and board.grid[row][col] != ME.WALL:
			slots.append(row)
	return slots

func _ordinary_refill_start_position(row: int, col: int, _spawn_index: int, spawn_count: int) -> Vector2:
	# v0.02: 新棋子统一从棋盘顶边明显上方落入(pour from top), 不再只在目标格上方少量生成。
	# 额外 +TOP_POUR 格, 保证即便单消(spawn_count小)新棋子也从顶部明显落下而非"中间冒出"。
	return LevelMotion.ordinary_refill_start_position(_cell_center(row, col), cell_size, spawn_count)

func _ordinary_refill_duration_for_positions(start_pos: Vector2, target: Vector2) -> float:
	return LevelMotion.ordinary_refill_duration_for_positions(start_pos, target, cell_size)

func _queue_cascade_fall_tween(tween: Tween, node: Node2D, target: Vector2, duration: float) -> void:
	tween.tween_property(node, "position", target, duration).set_trans(Tween.TRANS_LINEAR)

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

func _grid_has_fall_obstacle(grid_data: Array) -> bool:
	return LevelMotion.grid_has_fall_obstacle(grid_data, board.coat, board.choco)

func _wall_refill_start_position(row: int, col: int, source_map: Array = []) -> Vector2:
	return LevelMotion.wall_refill_start_position(row, col, source_map, board_origin, cell_size)

func _wall_slide_target_has_fall_obstacle_above(grid_data: Array, row: int, col: int) -> bool:
	return LevelMotion.wall_slide_target_has_fall_obstacle_above(grid_data, board.coat, board.choco, board.cannon, row, col)

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
	t.tween_method(apply_position, 0.0, 1.0, total_time).set_trans(Tween.TRANS_LINEAR)
	return total_time

func _source_none() -> Vector2i:
	return LevelMotion.source_none()

func _source_spawn(col: int) -> Vector2i:
	return LevelMotion.source_spawn(col)

func _wall_slide_path_rows(grid_snapshot: Array) -> Array:
	return LevelMotion.wall_slide_path_rows(grid_snapshot)

func _wall_slide_source_rows(grid_snapshot: Array) -> Array:
	return LevelMotion.wall_slide_source_rows(grid_snapshot)

func _wall_slide_tracking_fixed_cell(grid_snapshot: Array, row: int, col: int) -> bool:
	return LevelMotion.fall_barrier_in_grid(grid_snapshot, board.coat, board.choco, row, col)

func _build_wall_slide_tracking_maps(before_grid: Array) -> Dictionary:
	return LevelMotion.build_wall_slide_tracking_maps(before_grid, board.coat, board.choco, board.cannon, board.is_scrolling)

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

func _sync_wall_slide_visuals(before_grid: Array, old_nodes: Array) -> float:
	var move_time := 0.0
	var used := {}
	var new_nodes := _blank_visual_rows()
	var tracking_maps := _build_wall_slide_tracking_maps(before_grid)
	var source_map: Array = tracking_maps["source"]
	var path_map: Array = tracking_maps["path"]
	for row in range(board.height - 1, -1, -1):
		for col in range(board.width):
			var sp: int = board.grid[row][col]
			if sp < 0:
				continue
			var allow_cross_column := _wall_slide_target_has_fall_obstacle_above(before_grid, row, col)
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
	var old_nodes: Array = _gem_nodes.duplicate(true)
	ME.apply_gravity(board.grid, board.fx, false, board._layers())
	var refill_feed: Array = board.feed if board.is_scrolling else []
	if not board.is_scrolling:
		ME.refill(board.grid, board.species, board.rng, board.fx, refill_feed, board._layers())
	var new_nodes: Array = _blank_visual_rows()
	if _grid_has_fall_obstacle(before_grid) or _grid_has_fall_obstacle(board.grid):
		var wall_slide_time := _sync_wall_slide_visuals(before_grid, old_nodes)
		_repair_missing_gem_nodes_from_board()
		_refresh_wall_visuals()
		_refresh_jelly_visuals()
		_refresh_coat_visuals()
		if wall_slide_time > 0.0:
			await get_tree().create_timer(wall_slide_time).timeout
		return
	var t := create_tween().set_parallel(true)
	var moved := false
	for col in range(board.width):
		var seg_end: int = board.height - 1
		for row in range(board.height - 1, -2, -1):
			if row >= 0 and not _fall_barrier_in_grid(before_grid, row, col):
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
	if moved:
		await t.finished
