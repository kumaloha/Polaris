extends Node2D
# level.gd — 对局主场景（GAME_SPEC 新视图体系）。逻辑复用 core/board.gd + match_engine.gd。
#
# 当前布局：
#   顶部：透明源图裁剪后的关卡/步数/目标/星级 HUD。
#   中部：魔法书棋盘，可变尺寸，障碍和棋子按数据层增量同步。
#   底部：4 个萌宠技能头像 + 充能条。

signal time_rabbit_sequence_done

const CoreBoard := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")
const LevelConfig := preload("res://match3/level_config.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const ClearVisuals := preload("res://match3/clear_visuals.gd")
const LevelLayout := preload("res://match3/level_layout.gd")
const LevelMotion := preload("res://match3/level_motion.gd")
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
const COLOR_GOLD := Color(1.0, 0.92, 0.5)  # 统一金色文字(金币数/第N关/步数)
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
const JELLY_GOAL_ICON := "res://assets/obstacles/ob_bubble.png"
const JELLY_MARKER_NAME := "JellyGoalSprite"
const JELLY_FILL := 0.94
const JELLY_TINT := Color(0.46, 0.82, 1.0, 0.26)
const WALL_STONE_ICON := "res://assets/obstacles/ob_stone.png"
const WALL_MARKER_NAME := "WallStoneSprite"
const WALL_FILL := 0.90
# UI 素材
const STAR_GOLD := "res://assets/ui/ui_star_gold.png"
const KEY_SHADER := "res://match3/magenta_key.gdshader"

# ── v0.02 顶部状态栏新素材(米黄风格, 设计稿换皮; 替换旧紫金分散顶栏) ──
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

# 关卡目标(占位) 与 技能(占位)
const OBJECTIVES_DEMO := [
	{"icon": "res://assets/gems/gem_water.png", "n": "16"},
	{"icon": "res://assets/gems/gem_star.png", "n": "28"},
	{"icon": "res://assets/avatars/av_raccoon_miner.png", "n": "2"},
]
const SKILLS := [
	# gem: 该萌宠对应的宝石颜色(消该色宝石→给该萌宠加进度条), 决定冷却条颜色
	{"av": "res://assets/pets/timerewind/rabbit_avatar.png", "name": "时兔", "skill": "时间回退", "gem": "purple"},
	{"av": "res://assets/avatars/av_raccoon_miner.png", "name": "矿工程", "skill": "破障", "gem": "blue"},
	{"av": "res://assets/avatars/av_dragon_red.png", "name": "龙宝宝", "skill": "龙息大招", "gem": "red"},
	{"av": "res://assets/avatars/av_ladybug.png", "name": "瓢虫", "skill": "幸运祝福", "gem": "red"},
]
const RABBIT_REWIND_CAST_NODE := "TimeRabbitRewindCast"
const RABBIT_REWIND_CAST_EFFECT_NODE := "TimeRewindCastEffect"
const RABBIT_REWIND_FRAME_NODE := "RabbitFrame"
const RABBIT_REWIND_HOURGLASS_NODE := "RabbitHourglass"
const RABBIT_REWIND_AVATAR_FRAME := "res://assets/level/pet_avatar_frame.png"
const RABBIT_REWIND_AVATAR_FRAME_NODE := "TimeRabbitAvatarFrame"
const RABBIT_REWIND_AVATAR_FRAME_BG_NODE := "TimeRabbitAvatarFrameBg"
const RABBIT_REWIND_AVATAR_FRAME_BG_COLOR := Color(0.96, 0.84, 0.62, 0.48)
const RABBIT_REWIND_AVATAR := "res://assets/pets/timerewind/rabbit_avatar.png"
const RABBIT_REWIND_K1 := "res://assets/pets/timerewind/rabbit_k1_peektop.png"
const RABBIT_REWIND_K2 := "res://assets/pets/timerewind/rabbit_k2_peek.png"
const RABBIT_REWIND_K25 := "res://assets/pets/timerewind/rabbit_k25_pushup.png"
const RABBIT_REWIND_K3 := "res://assets/pets/timerewind/rabbit_k3_climb.png"
const RABBIT_REWIND_K4 := "res://assets/pets/timerewind/rabbit_k4_crouch.png"
const RABBIT_REWIND_K5 := "res://assets/pets/timerewind/rabbit_k5_leap.png"
const RABBIT_REWIND_K55 := "res://assets/pets/timerewind/rabbit_k55_fall.png"
const RABBIT_REWIND_K6 := "res://assets/pets/timerewind/rabbit_k6_idle.png"
const RABBIT_REWIND_K7 := "res://assets/pets/timerewind/rabbit_k7_charge.png"
const RABBIT_REWIND_K75 := "res://assets/pets/timerewind/rabbit_k75_castclosed.png"
const RABBIT_REWIND_K8 := "res://assets/pets/timerewind/rabbit_k8_cast.png"
const RABBIT_REWIND_HOURGLASS := "res://assets/pets/timerewind/rabbit_prop_hourglass.png"
const RABBIT_REWIND_CAST_SEQUENCE := [RABBIT_REWIND_K1, RABBIT_REWIND_K2, RABBIT_REWIND_K25, RABBIT_REWIND_K3, RABBIT_REWIND_K4, RABBIT_REWIND_K5, RABBIT_REWIND_K55, RABBIT_REWIND_K6, RABBIT_REWIND_K7, RABBIT_REWIND_K75, RABBIT_REWIND_K8]
const RABBIT_REWIND_PEEK_SEQUENCE := [RABBIT_REWIND_K1, RABBIT_REWIND_K2, RABBIT_REWIND_K25, RABBIT_REWIND_K3, RABBIT_REWIND_K4, RABBIT_REWIND_K6]
const RABBIT_REWIND_FRAME_WIDTH_SCALE := {
	RABBIT_REWIND_K2: 0.90,
	RABBIT_REWIND_K25: 0.74,
	RABBIT_REWIND_K3: 0.72,
	RABBIT_REWIND_K4: 0.76,
}
const RABBIT_REWIND_HOME_W := 138.0
const RABBIT_REWIND_PEEK_W := 172.0
const RABBIT_REWIND_LEAP_W := 232.0
const RABBIT_REWIND_CAST_W := 220.0
const RABBIT_REWIND_CAST_MIN_W := 96.0
const RABBIT_REWIND_CAST_VISIBLE_ASPECT := 1191.0 / 908.0
const RABBIT_REWIND_CAST_TOP_GAP := 8.0
const RABBIT_REWIND_CAST_AVATAR_GAP := 18.0
const RABBIT_REWIND_CAST_GAP_BIAS := 36.0
const RABBIT_REWIND_HOURGLASS_W := 44.0
const RABBIT_REWIND_HOURGLASS_OFFSET := Vector2(28.0, -86.0)
const RABBIT_REWIND_HOURGLASS_BOARD_Y := 0.24
const RABBIT_REWIND_HOURGLASS_FLOAT_SCALE := 1.5
const RABBIT_REWIND_TIME_SCALE := 2.75
const RABBIT_REWIND_CAST_HOLD := 0.82
const TIME_REWIND_RING_STEPS := 64
const TIME_REWIND_FLASH_COLOR := Color(0.52, 0.84, 1.0, 0.38)
const TIME_REWIND_RING_COLOR := Color(0.56, 0.88, 1.0, 0.82)
const TIME_REWIND_EFFECT_TIME := 0.58

const DESIGN_W := LevelLayout.DESIGN_W
const DESIGN_H := 1520.0
const SWAP_TIME := 0.14
const CLEAR_TIME := 0.156
const CLEAR_POP_TIME := 0.117
const CLEAR_POP_SCALE := 1.25
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
const SKILL_AV_Y := LevelLayout.SKILL_AV_Y
const SKILL_AV_W := LevelLayout.SKILL_AV_W
const SKILL_CD_Y := 1440.0
const SKILL_NAME_Y := 1472.0

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
var _moves_display_override: int = -1
var _topbar_moves_value_label: Label = null
var _busy := false
var _level_generation: int = 0
var _opening_drop_tween: Tween = null
var _key_mat: ShaderMaterial = null
var _dir_glow_shader: Shader = null  # 横/纵摇头点头的方向性高光 shader(缓存资源)
var _gem_saturation_shader: Shader = null
var _gem_saturation_mat: ShaderMaterial = null
var _colorbomb_inner_light_shader: Shader = null
# 阶段7: 技能充能状态(改: 不再按时间冷却, 而是消除对应色宝石才涨)。idx 与 SKILLS 对齐。
const SKILL_CHARGE_REQ := 10.0                  # 满充能所需消除数(20 * 0.5)
var _skill_charge := [0.0, 0.0, 0.0, 0.0]      # 各技能当前充能数(消对应色宝石累加, 满=可用)
var _skill_btns: Array = []                     # 4 个 TextureButton 引用(随 disabled/置灰)
var _skill_bar_fills: Array = []                # 4 个冷却条填充 Panel 引用(随 ratio 改宽)
var _skill_bar_geo: Array = []                  # 每条 {center,w,h,inset,ih}: 改填充宽度复用
var _time_rewind_cast_pending := false

@onready var background_layer: CanvasLayer = $BackgroundLayer
@onready var board_layer: CanvasLayer = $BoardLayer
@onready var gem_layer: CanvasLayer = $GemLayer
@onready var character_layer: CanvasLayer = $CharacterLayer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var skill_bar: CanvasLayer = $SkillBar

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
	_skill_charge = [0.0, 0.0, 0.0, 0.0]   # 新关重置技能充能
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

# 棋盘金边框：4 边(edge拉伸) + 4 角(corner翻转复用同一张)。在格子之上渲染。
func _render_board_frame() -> void:
	# v0.02: 棋盘金边框改由 parchment_panel(底框自带金边)提供, 不再画紫金 band/line/corner。
	return

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
	_render_board_frame()  # 金边框(最上层,盖格子边缘)

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

func _render_chrome(cfg: Dictionary) -> void:
	_cur_cfg = cfg
	_clear_layer(character_layer)
	_clear_layer(ui_layer)
	_clear_layer(skill_bar)
	# v0.02: 设计稿为纯三消, 移除 Boss 对战区(狐狸/Boss/道具书)。score 计分逻辑不受影响。
	_render_ui_layer()
	_render_skillbar()

# 阶段6: ui_layer(顶栏+吊坠绳+目标卡+步数徽章+星级)整层重画。
# HUD 刷新只动 ui_layer(不重画角色/技能栏/棋盘), 目标进度/步数随每步更新。
func _render_ui_layer() -> void:
	_render_topbar_v2(_cur_cfg)

# 阶段6: 每步 resolve/swap 后刷新 HUD(目标卡进度 + 步数徽章)——只重画 ui_layer。
func _refresh_hud() -> void:
	_clear_layer(ui_layer)
	_topbar_moves_value_label = null
	_render_ui_layer()

func _display_moves_left() -> int:
	if _moves_display_override >= 0:
		return _moves_display_override
	return board.moves_left if board != null else 0

func _set_moves_display_override(value: int) -> void:
	_moves_display_override = maxi(value, 0)
	if _topbar_moves_value_label != null and is_instance_valid(_topbar_moves_value_label):
		_topbar_moves_value_label.text = str(_display_moves_left())

func _clear_moves_display_override() -> void:
	_moves_display_override = -1
	if _topbar_moves_value_label != null and is_instance_valid(_topbar_moves_value_label):
		_topbar_moves_value_label.text = str(_display_moves_left())

# v0.02: 米黄风格顶部状态栏(banner 横铺 + 绶带关卡号 + 星条 + 双目标 + 圆环头像 + 链/花装饰)。
# 换皮不动数据: 关卡号=cfg.id, 步数=board.moves_left, 目标=_objectives_view(), 星级=首颗金星覆盖底图槽位。
func _render_topbar_v2(cfg: Dictionary) -> void:
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
	var moves: int = _display_moves_left()
	_label(ui_layer, "剩余步数", _topbar_moves_label_center(), 22, Color(0.235, 0.098, 0.039), 150, 0)
	_topbar_moves_value_label = _label(ui_layer, str(maxi(moves, 0)), _topbar_moves_number_center(), 44, Color(0.86, 0.18, 0.16), 135, 4, Color(1, 1, 1, 0.5))
	# 关卡目标(下方右格, 竖线 PIL实测 @0.30, 右格中心 0.60)
	var view: Array = _objectives_view()
	if view.is_empty():
		view = OBJECTIVES_DEMO
	var n: int = mini(view.size(), 3)
	for i in range(n):
		var item: Dictionary = view[i]
		var slot: Dictionary = _topbar_objective_slot(i, n, tw, th)
		var icon_center: Vector2 = slot["icon"]
		var text_center: Vector2 = slot["text"]
		var icon_path: String = String(item.get("icon", ""))
		_sprite_fit(ui_layer, icon_path, icon_center, TB_OBJ_ICON_MAX, icon_path == BARRIER_ICE_ICON)
		_label(ui_layer, _objective_counter_text(item), text_center, 30, Color(1, 1, 1), TB_OBJ_TEXT_W, 4, Color(0, 0, 0, 0.9))

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

# 阶段6: 遍历 board.objectives 产出目标卡视图数据(图标+进度+目标)。
# type→进度取值: COLLECT 用 collected[species]; 其余障碍类用对应 *_cleared/*_collected/... 计数器。
# COLLECT 用该色宝石图标; 非 COLLECT 类暂用矿工头像占位(TODO 美术: 给障碍目标各出专属图标)。
const OBJ_PLACEHOLDER_ICON := "res://assets/avatars/av_raccoon_miner.png"
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

func _render_skillbar() -> void:
	# v0.02: 去掉底部宠物区的背景托盘 + 流光动效(不适合新的天空米黄背景), 仅保留萌宠头像/技能。
	# 4 技能头像(可点) + 冷却条(接真冷却) + 名字 + 技能名(在流光之上)
	# 阶段7: 头像改 TextureButton(吃点击触发技能); 冷却条持有填充节点引用, 随 _process 改宽。
	_skill_btns = []
	_skill_bar_fills = []
	_skill_bar_geo = []
	var n: int = SKILLS.size()
	for i in range(n):
		var sk: Dictionary = SKILLS[i]
		var cx: float = DESIGN_W * (float(i) + 0.5) / float(n)
		if i == 0:
			_skill_avatar_frame(Vector2(cx, SKILL_AV_Y), SKILL_AV_W)
		_skill_button(String(sk["av"]), Vector2(cx, SKILL_AV_Y), SKILL_AV_W, i)
		# 充能条(圆角胶囊): 颜色 = 该萌宠对应宝石色, 槽为其暗化版; 初始 ratio 按当前充能数。
		var gem_col: Color = GEM_COLORS.get(sk.get("gem", "purple"), Color(0.82, 0.45, 1.0))
		var track_col: Color = gem_col.darkened(0.72)
		track_col.a = 0.95
		var ratio0: float = clampf(_skill_charge[i] / SKILL_CHARGE_REQ, 0.0, 1.0)
		_cd_bar(i, Vector2(cx, SKILL_CD_Y + 4.0), SKILL_AV_W * 0.56, 18.0, ratio0, gem_col, track_col)
		_label(skill_bar, str(sk["name"]), Vector2(cx, SKILL_NAME_Y), 22, Color(1, 0.95, 0.8), SKILL_AV_W + 20)
		# v0.02: 去掉最下方技能解释文字(sk.skill)
	_update_skill_cd_visual()  # 同步初始置灰/宽度(重画 ui 后冷却态仍在时保持一致)

# ───────── 阶段7: 技能按钮 / 冷却 / 四技能 ─────────

## 可点技能头像: TextureButton(品红抠像), 按宽等比缩放, Control 左上角定位(中心-半尺寸)。
## 存进 _skill_btns 供 _process 置灰/禁用。
func _skill_button(path: String, center: Vector2, width: float, idx: int) -> void:
	var tex := _load_texture(path)
	if tex == null:
		_skill_btns.append(null)
		return
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var sz: Vector2 = tex.get_size()
	var h: float = width * (sz.y / sz.x) if sz.x > 0.0 else width
	btn.size = Vector2(width, h)
	btn.position = center - btn.size * 0.5   # TextureButton 是左上角定位 → 减半尺寸居中
	btn.z_index = 2
	btn.material = _magenta_material()        # 品红抠像(与静态头像一致)
	btn.set_meta("avatar_texture_path", path)
	btn.set_meta("avatar_texture", tex)
	btn.pressed.connect(_on_skill_pressed.bind(idx))
	skill_bar.add_child(btn)
	_skill_btns.append(btn)

func _skill_avatar_frame(center: Vector2, width: float) -> void:
	var bg := Polygon2D.new()
	bg.name = RABBIT_REWIND_AVATAR_FRAME_BG_NODE
	bg.polygon = _ellipse_points(Vector2.ZERO, width * 0.44, width * 0.44, 56)
	bg.color = RABBIT_REWIND_AVATAR_FRAME_BG_COLOR
	bg.position = center
	bg.z_index = 0
	skill_bar.add_child(bg)

	var frame_tex := _load_texture(RABBIT_REWIND_AVATAR_FRAME)
	if frame_tex == null:
		return
	var frame := Sprite2D.new()
	frame.name = RABBIT_REWIND_AVATAR_FRAME_NODE
	frame.texture = frame_tex
	frame.position = center
	frame.scale = _fit_scale(frame_tex, width * 1.12)
	frame.z_index = 4
	skill_bar.add_child(frame)

## 冷却条(圆角胶囊): 与 _rounded_bar 同款外观, 但持有填充 Panel 引用(存 _skill_bar_fills),
## 并记录几何(_skill_bar_geo) 供 _process 改宽。ratio 0..1。
func _cd_bar(idx: int, center: Vector2, w: float, h: float, ratio: float, fill_color: Color, bg_color: Color) -> void:
	var r: int = int(h * 0.5)
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(r)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.95, 0.8, 0.42)
	bg.add_theme_stylebox_override("panel", sb)
	bg.size = Vector2(w, h)
	bg.position = center - Vector2(w, h) * 0.5
	skill_bar.add_child(bg)
	var inset := 2.0
	var ih: float = h - inset * 2.0
	var fl := Panel.new()
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = fill_color
	sbf.set_corner_radius_all(int(ih * 0.5))
	fl.add_theme_stylebox_override("panel", sbf)
	fl.position = center - Vector2(w, h) * 0.5 + Vector2(inset, inset)
	fl.size = Vector2(maxf((w - inset * 2.0) * clampf(ratio, 0.0, 1.0), ih), ih)
	skill_bar.add_child(fl)
	_skill_bar_fills.append(fl)
	_skill_bar_geo.append({"center": center, "w": w, "h": h, "inset": inset, "ih": ih})

## 消除对应色宝石→给该技能充能。by_species: dict(species:int → count)。
## 每个技能按其 gem 对应的 species 累加, 封顶 SKILL_CHARGE_REQ。多个技能可同色, 都涨。
func _charge_skills(by_species: Dictionary) -> void:
	if by_species.is_empty():
		return
	var changed := false
	for i in range(SKILLS.size()):
		var sp: int = GEM_KEYS.find(SKILLS[i].get("gem", ""))
		if sp < 0:
			continue
		var gained: int = by_species.get(sp, 0)
		if gained <= 0:
			continue
		_skill_charge[i] = minf(_skill_charge[i] + float(gained), SKILL_CHARGE_REQ)
		changed = true
	if changed:
		_update_skill_cd_visual()

## 刷新每条充能填充宽度 + 头像禁用/置灰。ratio = charge/REQ(满=1, 可点)。
func _update_skill_cd_visual() -> void:
	for i in range(_skill_bar_fills.size()):
		var fl = _skill_bar_fills[i]
		if fl == null or not is_instance_valid(fl):
			continue
		var geo: Dictionary = _skill_bar_geo[i]
		var ratio: float = _skill_charge_ratio(i)
		var w: float = geo["w"]
		var inset: float = geo["inset"]
		var ih: float = geo["ih"]
		fl.size = Vector2(maxf((w - inset * 2.0) * ratio, ih), ih)
	for i in range(_skill_btns.size()):
		var btn = _skill_btns[i]
		if btn == null or not is_instance_valid(btn):
			continue
		var ready: bool = _skill_ready(i)
		btn.disabled = not _skill_clickable(i)
		if i == 0 and bool(btn.get_meta("time_rabbit_casting", false)):
			btn.visible = true
			btn.texture_normal = null
			btn.modulate.a = 1.0
		else:
			btn.modulate.a = 1.0 if ready else 0.82

func _skill_uses_charge(idx: int) -> bool:
	if idx < 0 or idx >= SKILLS.size():
		return false
	return String(SKILLS[idx].get("skill", "")) != "时间回退"

func _skill_charge_ratio(idx: int) -> float:
	if idx < 0 or idx >= _skill_charge.size():
		return 0.0
	return clampf(_skill_charge[idx] / SKILL_CHARGE_REQ, 0.0, 1.0)

func _skill_clickable(idx: int) -> bool:
	if idx < 0 or idx >= SKILLS.size():
		return false
	match String(SKILLS[idx].get("skill", "")):
		"时间回退":
			return board != null and board.skill == "timerewind" and not board.rewind_used and not _time_rewind_cast_pending and not board.is_over()
		_:
			return _skill_ready(idx)

func _skill_ready(idx: int) -> bool:
	if idx < 0 or idx >= SKILLS.size():
		return false
	match String(SKILLS[idx].get("skill", "")):
		"时间回退":
			return board != null and board.skill == "timerewind" and not board.rewind_used and not _time_rewind_cast_pending and not board.move_history.is_empty() and not board.is_over()
		_:
			return _skill_charge[idx] >= SKILL_CHARGE_REQ

## 点技能: 守卫(忙/结算/未充满→忽略) → 分派 → 成功后充能清零(重攒)。技能不消耗步数。
func _on_skill_pressed(idx: int) -> void:
	if _busy or _settled:
		return
	if board == null:
		return
	if not _skill_ready(idx):
		if _skill_clickable(idx):
			if String(SKILLS[idx].get("skill", "")) == "时间回退":
				_play_time_rewind_pet_animation(false)
			else:
				_pulse_skill_button(idx)
		return
	var did := false
	match SKILLS[idx]["skill"]:
		"时间回退":
			did = _skill_time_rewind()
		"提示":
			did = await _skill_hint()
		"破障":
			did = await _skill_break()
		"龙息大招":
			did = await _skill_dragon()
		"幸运祝福":
			did = await _skill_blessing()
	if did:
		if _skill_uses_charge(idx):
			_skill_charge[idx] = 0.0   # 放完清零重攒
		_update_skill_cd_visual()

func _pulse_skill_button(idx: int) -> void:
	if idx < 0 or idx >= _skill_btns.size():
		return
	var btn = _skill_btns[idx]
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _time_rabbit_skill_button() -> TextureButton:
	if _skill_btns.is_empty():
		return null
	var btn = _skill_btns[0]
	if btn == null or not is_instance_valid(btn) or not (btn is TextureButton):
		return null
	return btn as TextureButton

func _set_time_rabbit_avatar_casting(is_casting: bool) -> void:
	var btn := _time_rabbit_skill_button()
	if btn != null:
		btn.visible = true
		btn.set_meta("time_rabbit_casting", is_casting)
		if is_casting:
			if btn.texture_normal != null:
				btn.set_meta("avatar_texture", btn.texture_normal)
			btn.texture_normal = null
		else:
			var tex = btn.get_meta("avatar_texture", null)
			if tex is Texture2D:
				btn.texture_normal = tex
			else:
				var path := String(btn.get_meta("avatar_texture_path", RABBIT_REWIND_AVATAR))
				btn.texture_normal = _load_texture(path)
		btn.modulate.a = 1.0

func _play_time_rewind_pet_animation(cast_effect: bool = true) -> void:
	if skill_bar == null:
		return
	var old := skill_bar.get_node_or_null(RABBIT_REWIND_CAST_NODE)
	if old != null:
		old.name = "%sOld" % RABBIT_REWIND_CAST_NODE
		_detach_and_free_later(old)
	var old_hourglass := skill_bar.get_node_or_null(RABBIT_REWIND_HOURGLASS_NODE)
	if old_hourglass != null:
		_detach_and_free_later(old_hourglass)
	_set_time_rabbit_avatar_casting(true)
	var rig := Node2D.new()
	rig.name = RABBIT_REWIND_CAST_NODE
	rig.z_index = 200
	rig.position = _time_rabbit_home_anchor()
	var sequence: Array = RABBIT_REWIND_CAST_SEQUENCE if cast_effect else RABBIT_REWIND_PEEK_SEQUENCE
	rig.set_meta("frame_sequence", PackedStringArray(sequence))
	skill_bar.add_child(rig)
	var rabbit := _make_time_rabbit_avatar_sprite(RABBIT_REWIND_FRAME_NODE, SKILL_AV_W)
	rabbit.z_index = 2
	rig.add_child(rabbit)
	var hourglass := _make_time_rabbit_prop_sprite(RABBIT_REWIND_HOURGLASS_NODE, RABBIT_REWIND_HOURGLASS, RABBIT_REWIND_HOURGLASS_W)
	hourglass.position = _time_rabbit_cast_anchor() + RABBIT_REWIND_HOURGLASS_OFFSET
	hourglass.modulate.a = 0.0
	hourglass.visible = false
	hourglass.z_index = 260
	hourglass.set_meta("base_scale", hourglass.scale)
	skill_bar.add_child(hourglass)
	if is_inside_tree():
		_start_time_rabbit_tween(rig, rabbit, hourglass, cast_effect)

func _make_time_rabbit_sprite(node_name: String, path: String, width: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	_set_time_rabbit_frame(sprite, path, width, false)
	return sprite

func _make_time_rabbit_avatar_sprite(node_name: String, width: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	_set_time_rabbit_avatar_frame(sprite, width)
	return sprite

func _make_time_rabbit_prop_sprite(node_name: String, path: String, width: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	var tex := _load_texture(path)
	if tex != null:
		sprite.texture = tex
		sprite.scale = _scale_to_width(tex, width)
	return sprite

func _set_time_rabbit_frame(sprite: Sprite2D, path: String, width: float, flip_h: bool = false) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var tex := _load_texture(path)
	if tex == null:
		return
	sprite.texture = tex
	sprite.scale = _scale_to_width(tex, _time_rabbit_frame_width(path, width))
	var display_h: float = tex.get_size().y * sprite.scale.y
	sprite.position = Vector2(0.0, -display_h * 0.5)
	sprite.flip_h = flip_h
	sprite.set_meta("anchor", "bottom")

func _time_rabbit_frame_width(path: String, width: float) -> float:
	return width * float(RABBIT_REWIND_FRAME_WIDTH_SCALE.get(path, 1.0))

func _set_time_rabbit_avatar_frame(sprite: Sprite2D, width: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var tex := _load_texture(RABBIT_REWIND_AVATAR)
	if tex == null:
		return
	sprite.texture = tex
	sprite.scale = _fit_scale(tex, width)
	sprite.position = Vector2.ZERO
	sprite.flip_h = false
	sprite.rotation = 0.0
	sprite.modulate.a = 1.0
	sprite.set_meta("anchor", "center")

func _time_rabbit_home_anchor() -> Vector2:
	var count: int = maxi(SKILLS.size(), 1)
	return Vector2(DESIGN_W * 0.5 / float(count), SKILL_AV_Y)

func _time_rabbit_cast_anchor() -> Vector2:
	var home := _time_rabbit_home_anchor()
	if board != null:
		var book_rect := _book_frame_rect()
		var board_rect := _current_board_rect()
		var avatar_top := SKILL_AV_Y - SKILL_AV_W * 0.5
		var min_y := maxf(
			book_rect.end.y + 28.0,
			board_rect.end.y + 8.0 + RABBIT_REWIND_CAST_MIN_W * RABBIT_REWIND_CAST_VISIBLE_ASPECT + RABBIT_REWIND_CAST_TOP_GAP
		)
		var max_y := avatar_top - RABBIT_REWIND_CAST_AVATAR_GAP
		var desired_y := (book_rect.end.y + avatar_top) * 0.5 + RABBIT_REWIND_CAST_GAP_BIAS
		var cast_y := max_y if max_y < min_y else clampf(maxf(desired_y, min_y), min_y, max_y)
		return Vector2(book_rect.get_center().x, cast_y)
	return home + Vector2(0.0, -150.0)

func _time_rabbit_cast_width() -> float:
	if board == null:
		return RABBIT_REWIND_CAST_W
	var cast := _time_rabbit_cast_anchor()
	var board_rect := _current_board_rect()
	var cast_bottom := cast.y - 8.0
	var available_h: float = cast_bottom - board_rect.end.y - RABBIT_REWIND_CAST_TOP_GAP
	var safe_w: float = available_h / RABBIT_REWIND_CAST_VISIBLE_ASPECT
	return clampf(safe_w, RABBIT_REWIND_CAST_MIN_W, RABBIT_REWIND_CAST_W)

func _time_rewind_effect_anchor() -> Vector2:
	return _current_board_rect().get_center()

func _rabbit_rewind_time(seconds: float) -> float:
	return seconds * RABBIT_REWIND_TIME_SCALE

func _time_rabbit_jump_points(home: Vector2, cast: Vector2) -> Array:
	var apex_y := minf(home.y, cast.y) - 170.0
	return [
		Vector2(home.x, home.y - 78.0),
		Vector2(lerpf(home.x, cast.x, 0.36), apex_y),
		Vector2(lerpf(home.x, cast.x, 0.76), cast.y - 48.0),
		cast,
	]

func _time_rabbit_jump_durations() -> Array:
	return [0.14, 0.13, 0.12, 0.11]

func _time_rabbit_hourglass_float_anchor(cast: Vector2) -> Vector2:
	if board == null:
		return cast + Vector2(0.0, -170.0)
	var board_rect := _current_board_rect()
	return Vector2(board_rect.get_center().x, board_rect.position.y + board_rect.size.y * RABBIT_REWIND_HOURGLASS_BOARD_Y)

func _start_time_rabbit_tween(rig: Node2D, rabbit: Sprite2D, hourglass: Sprite2D, cast_effect: bool) -> void:
	var home := _time_rabbit_home_anchor()
	var cast := _time_rabbit_cast_anchor()
	var cast_w := _time_rabbit_cast_width()
	var leap_w := minf(RABBIT_REWIND_LEAP_W, cast_w * 1.06)
	var t := create_tween()
	rig.set_meta("cast_tween", t)
	t.tween_property(rig, "position", home + Vector2(0.0, 12.0), _rabbit_rewind_time(0.08)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K1, RABBIT_REWIND_HOME_W, home + Vector2(0.0, 8.0), _rabbit_rewind_time(0.06))
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K2, RABBIT_REWIND_PEEK_W, home, _rabbit_rewind_time(0.08))
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K25, RABBIT_REWIND_PEEK_W, home + Vector2(0.0, -18.0), _rabbit_rewind_time(0.08))
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K3, RABBIT_REWIND_PEEK_W, home + Vector2(0.0, -34.0), _rabbit_rewind_time(0.08))
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K4, RABBIT_REWIND_PEEK_W, home + Vector2(0.0, -42.0), _rabbit_rewind_time(0.08))
	if cast_effect:
		_queue_time_rabbit_jump(t, rig, rabbit, home, cast, leap_w, cast_w)
		t.tween_callback(Callable(self, "_show_time_rabbit_hourglass").bind(hourglass))
		t.tween_property(hourglass, "modulate:a", 0.96, _rabbit_rewind_time(0.20)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(hourglass, "position", _time_rabbit_hourglass_float_anchor(cast), _rabbit_rewind_time(0.20)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(hourglass, "scale", hourglass.scale * RABBIT_REWIND_HOURGLASS_FLOAT_SCALE, _rabbit_rewind_time(0.20)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K7, cast_w, cast, _rabbit_rewind_time(0.11))
		_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K75, cast_w, cast + Vector2(0.0, -4.0), _rabbit_rewind_time(0.12))
		t.parallel().tween_property(hourglass, "rotation", TAU, _rabbit_rewind_time(0.30)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K8, cast_w, cast + Vector2(0.0, -8.0), _rabbit_rewind_time(0.20))
		t.tween_interval(RABBIT_REWIND_CAST_HOLD)
		t.tween_callback(Callable(self, "_commit_time_rewind_cast"))
		t.tween_property(hourglass, "modulate:a", 0.0, _rabbit_rewind_time(0.18))
		_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K55, leap_w * 0.92, home + Vector2(0.0, -118.0), _rabbit_rewind_time(0.14), true)
		_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K5, leap_w * 0.86, home + Vector2(0.0, -72.0), _rabbit_rewind_time(0.14), true)
	else:
		_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K6, cast_w * 0.78, home + Vector2(0.0, -20.0), _rabbit_rewind_time(0.12))
		t.tween_property(rabbit, "rotation", 0.08, _rabbit_rewind_time(0.06)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(rabbit, "rotation", -0.08, _rabbit_rewind_time(0.06)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(rabbit, "rotation", 0.0, _rabbit_rewind_time(0.06)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K4, RABBIT_REWIND_PEEK_W, home + Vector2(0.0, -38.0), _rabbit_rewind_time(0.07), true)
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K3, RABBIT_REWIND_PEEK_W, home + Vector2(0.0, -22.0), _rabbit_rewind_time(0.07), true)
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K25, RABBIT_REWIND_PEEK_W, home + Vector2(0.0, -12.0), _rabbit_rewind_time(0.07), true)
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K2, RABBIT_REWIND_PEEK_W, home + Vector2(0.0, 4.0), _rabbit_rewind_time(0.07), true)
	_queue_time_rabbit_frame(t, rig, rabbit, RABBIT_REWIND_K1, RABBIT_REWIND_HOME_W, home + Vector2(0.0, 16.0), _rabbit_rewind_time(0.07), true)
	_queue_time_rabbit_avatar_frame(t, rig, rabbit, home, _rabbit_rewind_time(0.08))
	t.tween_callback(Callable(self, "_retire_time_rabbit_rig").bind(rig))

func _queue_time_rabbit_jump(t: Tween, rig: Node2D, rabbit: Sprite2D, home: Vector2, cast: Vector2, leap_w: float, cast_w: float) -> void:
	var points := _time_rabbit_jump_points(home, cast)
	var durations := _time_rabbit_jump_durations()
	for i in range(points.size()):
		var width := leap_w if i < points.size() - 1 else cast_w * 0.84
		var path := RABBIT_REWIND_K5 if i < points.size() - 1 else RABBIT_REWIND_K6
		_queue_time_rabbit_jump_frame(t, rig, rabbit, path, width, points[i], _rabbit_rewind_time(float(durations[i])))

func _queue_time_rabbit_jump_frame(t: Tween, rig: Node2D, rabbit: Sprite2D, path: String, width: float, target: Vector2, seconds: float) -> void:
	t.tween_callback(Callable(self, "_set_time_rabbit_frame").bind(rabbit, path, width, false))
	t.tween_property(rig, "position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _queue_time_rabbit_frame(t: Tween, rig: Node2D, rabbit: Sprite2D, path: String, width: float, target: Vector2, seconds: float, flip_h: bool = false) -> void:
	t.tween_callback(Callable(self, "_set_time_rabbit_frame").bind(rabbit, path, width, flip_h))
	t.tween_property(rig, "position", target, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _queue_time_rabbit_avatar_frame(t: Tween, rig: Node2D, rabbit: Sprite2D, target: Vector2, seconds: float) -> void:
	t.tween_callback(Callable(self, "_set_time_rabbit_avatar_frame").bind(rabbit, SKILL_AV_W))
	t.tween_property(rig, "position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_time_rabbit_hourglass(hourglass: Sprite2D) -> void:
	if hourglass == null or not is_instance_valid(hourglass):
		return
	hourglass.visible = true
	hourglass.modulate.a = 0.96
	hourglass.rotation = 0.0

func _commit_time_rewind_cast() -> void:
	var did := false
	if board != null:
		did = board.skill_rewind()
	if did:
		_sel = Vector2i(-1, -1)
		_sel_node = null
		_clear_highlights()
		_render_board(false)
		_refresh_hud()
		_spawn_time_rewind_cast_effect()
	_time_rewind_cast_pending = false
	_busy = false
	_update_skill_cd_visual()

func _spawn_time_rewind_cast_effect() -> void:
	if skill_bar == null:
		return
	var old := skill_bar.get_node_or_null(RABBIT_REWIND_CAST_EFFECT_NODE)
	if old != null:
		if old.is_inside_tree():
			old.queue_free()
		else:
			old.free()
	var effect := Node2D.new()
	effect.name = RABBIT_REWIND_CAST_EFFECT_NODE
	effect.z_index = 180
	effect.position = _time_rewind_effect_anchor()
	effect.set_meta("effect", "time_rewind")
	skill_bar.add_child(effect)
	var board_rect := _current_board_rect()
	var flash := ColorRect.new()
	flash.name = "TimeRewindBoardFlash"
	flash.position = board_rect.position - effect.position
	flash.size = board_rect.size
	flash.color = TIME_REWIND_FLASH_COLOR
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.add_child(flash)
	var base_radius := maxf(board_rect.size.x, board_rect.size.y) * 0.36
	for i in range(3):
		var ring := Line2D.new()
		ring.name = "TimeRewindRing%d" % i
		ring.closed = true
		ring.width = 4.0 - float(i) * 0.6
		var col := TIME_REWIND_RING_COLOR
		col.a = 0.78 - float(i) * 0.16
		ring.default_color = col
		var rx := base_radius * (1.0 + float(i) * 0.22)
		var ry := rx * 0.56
		ring.points = _ellipse_points(Vector2.ZERO, rx, ry, TIME_REWIND_RING_STEPS)
		effect.add_child(ring)
	var clock := Line2D.new()
	clock.name = "TimeRewindClockHand"
	clock.width = 5.0
	clock.default_color = Color(0.82, 0.94, 1.0, 0.88)
	clock.points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, -base_radius * 0.46)])
	clock.z_index = 4
	effect.add_child(clock)
	for i in range(20):
		var sand := ColorRect.new()
		sand.name = "TimeRewindSand%d" % i
		sand.size = Vector2(5.0 + float(i % 4), 5.0 + float(i % 4))
		sand.position = Vector2(sin(float(i) * 1.7) * 34.0, 132.0 - float(i) * 13.0)
		sand.color = Color(0.74, 0.94, 1.0, 0.95)
		sand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sand.z_index = 5
		effect.add_child(sand)
	if is_inside_tree():
		var t := create_tween().set_parallel(true)
		for child in effect.get_children():
			if child is CanvasItem:
				t.tween_property(child, "modulate:a", 0.0, TIME_REWIND_EFFECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if child is ColorRect and String(child.name).begins_with("TimeRewindSand"):
				t.tween_property(child, "position:y", child.position.y - 96.0, TIME_REWIND_EFFECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(clock, "rotation", -TAU * 0.85, TIME_REWIND_EFFECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(effect, "scale", Vector2(1.22, 1.22), TIME_REWIND_EFFECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.finished.connect(_retire_time_rabbit_rig.bind(effect), CONNECT_ONE_SHOT)

func _current_board_rect() -> Rect2:
	if board == null:
		return Rect2(Vector2(DESIGN_W * 0.18, DESIGN_H * 0.36), Vector2(DESIGN_W * 0.64, DESIGN_H * 0.32))
	return Rect2(board_origin, Vector2(float(board.width) * cell_size, float(board.height) * cell_size))

func _ellipse_points(center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = maxi(8, steps)
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _arc_points(center: Vector2, rx: float, ry: float, start_angle: float, end_angle: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = maxi(2, steps)
	for i in range(n):
		var t := float(i) / float(n - 1)
		var a := lerpf(start_angle, end_angle, t)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _retire_time_rabbit_rig(rig: Node2D) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	var restores_avatar := skill_bar != null and rig.name == RABBIT_REWIND_CAST_NODE and skill_bar.get_node_or_null(RABBIT_REWIND_CAST_NODE) == rig
	rig.visible = false
	if restores_avatar:
		_update_skill_cd_visual()
		_set_time_rabbit_avatar_casting(false)
		var hourglass := skill_bar.get_node_or_null(RABBIT_REWIND_HOURGLASS_NODE)
		if hourglass != null:
			_detach_and_free_later(hourglass)
		emit_signal("time_rabbit_sequence_done")
	_detach_and_free_later(rig)

func _detach_and_free_later(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var was_inside := node.is_inside_tree()
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if was_inside:
		node.queue_free()
	else:
		node.free()

# ── idx0 时兔/时间回退: 回到历史窗口内最早一步, 不额外扣步。 ──
func _skill_time_rewind() -> bool:
	if board == null:
		return false
	if board.skill != "timerewind":
		board.skill = "timerewind"
	if board.rewind_used or board.move_history.is_empty():
		return false
	_time_rewind_cast_pending = true
	_play_time_rewind_pet_animation(true)
	if not is_inside_tree():
		_commit_time_rewind_cast()
	return true

# ── 旧提示技能: 保留方法供后续宠物/调试复用。高亮最优一步两格, 不改盘/不resolve/不扣步。 ──
func _skill_hint() -> bool:
	var mv: Array = ME.best_moves(board.grid, 1, board._layers(), board.objectives)
	if mv.is_empty():
		return false
	_clear_highlights()
	var pair: Array = mv[0]   # [a, b]，a/b 为 Vector2i(col,row)
	for cell in pair:
		var mk := Sprite2D.new()
		mk.texture = load(CELL_TEXTURE)
		mk.modulate = Color(0.4, 1.0, 0.5, 0.7)
		mk.scale = _fit_scale(mk.texture, cell_size * 1.04)
		mk.position = _cell_center(cell.y, cell.x)   # cell=(col,row) → (y=row, x=col)
		mk.z_index = 2
		gem_layer.add_child(mk)
		_hl_markers.append(mk)
		var tw := create_tween().set_loops(0)
		tw.tween_property(mk, "modulate:a", 0.25, 0.45)
		tw.tween_property(mk, "modulate:a", 0.75, 0.45)
	# 2.5s 后自动清除高亮(无阻塞 await: 用一次性计时器)
	get_tree().create_timer(2.5).timeout.connect(_clear_highlights)
	return true

# ── idx1 矿工程/破障: 占位——随机清 N 个普通格 + 连锁收尾。(关接 coat 层后改 ME.break_blockers) ──
func _skill_break() -> bool:
	# TODO(关卡): 当前关多无障碍 coat → 占位随机破普通格。接 coat 层后改调 ME.break_blockers 真破障。
	var cands: Array = []
	for r in range(board.height):
		for c in range(board.width):
			if board.grid[r][c] >= 0 and board.fx[r][c] == ME.SP_NONE:
				cands.append(Vector2i(c, r))
	if cands.is_empty():
		return false
	for i in range(cands.size() - 1, 0, -1):   # Fisher-Yates(用 board.rng 保确定性)
		var j: int = board.rng.randi() % (i + 1)
		var tmp = cands[i]; cands[i] = cands[j]; cands[j] = tmp
	var n: int = mini(3, cands.size())
	var cells: Array = cands.slice(0, n)
	_busy = true
	for p in cells:
		Fx.spawn_explosion(_cell_center(p.y, p.x), _fx_color(board.grid[p.y][p.x]), 1.2)
	Fx.shake(7.0)
	ME._apply_clears(board.grid, board.fx, cells, [])
	for p in cells:
		var node: Sprite2D = _gem_nodes[p.y][p.x]
		if node != null and is_instance_valid(node):
			node.queue_free()
		_gem_nodes[p.y][p.x] = null
	await _collapse_and_refill()
	await _resolve_cascades()   # 收尾连锁 + 计数
	_busy = false
	return true

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
func _check_settlement() -> void:
	if _settled:
		return
	if board.is_won():
		_settled = true
		_busy = true
		await _run_win_bonus_and_show()
	elif board.is_lost():
		_show_result(false)

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
func _show_result(win: bool) -> void:
	_settled = true
	_busy = true
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
	btn.pressed.connect(_on_result_button.bind(win))
	ui_layer.add_child(btn)

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
		match event.keycode:
			KEY_RIGHT, KEY_SPACE:
				_goto_relative(1)
			KEY_LEFT:
				_goto_relative(-1)
		return
	if _busy or _settled:
		return   # 结算遮罩展示中 → 棋盘交互锁死(只接结算面板按钮)
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
	await _finish_consumed_move(int(settle.get("choco_cleared", 0)), int(settle.get("cascades", 0)))
	_busy = false

func _remember_time_rewind_snapshot() -> void:
	if board == null:
		return
	if board.skill != "timerewind" or board.rewind_used:
		return
	board._push_history()
	_update_skill_cd_visual()

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
	_charge_skills(acc.get("by_species", {}))
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
	await _finish_consumed_move(int(acc.get("choco_cleared", 0)) + int(settle.get("choco_cleared", 0)), int(settle.get("cascades", 0)))
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
		await _finish_consumed_move(0, 0)
		_busy = false
		return
	var fusion_special_fx_cells = _special_fx_cells_for_clear_visuals(cells)
	var fusion_clear_timing := _clear_visual_timing_for_triggers(seeds, {}, fusion_fx)
	var acc: Dictionary = ME.account_clears(board.grid, cells, board.fx, board.rng, board.species, board._layers())
	board._accumulate(acc.get("by_species", {}))
	board._accumulate_progress(acc)
	_refresh_jelly_visuals()
	_refresh_coat_visuals()
	_charge_skills(acc.get("by_species", {}))
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
	await _finish_consumed_move(int(acc.get("choco_cleared", 0)) + int(settle.get("choco_cleared", 0)), int(settle.get("cascades", 0)))
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
		_refresh_jelly_visuals()
		_refresh_coat_visuals()                       # 同步已破冰锁, 避免数据清了画面还在
		_charge_skills(acc.get("by_species", {}))      # 问题1: 消对应色宝石→技能充能
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
		board._gain(ME.score_for_clear(to_clear.size(), cascade_level))
		for s in spawns:
			var sp_pos: Vector2i = s["pos"]
			board.fx[sp_pos.y][sp_pos.x] = int(triggered_spawn_fx.get(sp_pos, s["kind"]))
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
				pop.tween_property(n, "scale", base_scale * 0.1, CLEAR_TIME - CLEAR_POP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				pop.parallel().tween_property(n, "modulate:a", 0.0, CLEAR_TIME - CLEAR_POP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
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

func _finish_consumed_move(step_choco: int, cascades: int) -> void:
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
	_update_skill_cd_visual()
	await _check_settlement()
	if is_inside_tree():
		await get_tree().process_frame

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
