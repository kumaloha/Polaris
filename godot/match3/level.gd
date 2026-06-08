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
const LevelLibrary := preload("res://core/level_library.gd")
const ClearVisuals := preload("res://match3/clear_visuals.gd")
const LEVELS_PATH := "res://levels.json"

const GEM_COLORS := {
	# 从宝石贴图实采的主体色(高饱和中亮像素均值), 与宝石一致
	"red": Color(0.691, 0.108, 0.048), "blue": Color(0.052, 0.297, 0.789),
	"green": Color(0.373, 0.635, 0.045), "gold": Color(0.746, 0.426, 0.058),
	"purple": Color(0.326, 0.061, 0.728), "pink": Color(0.780, 0.120, 0.411),
}
const COLOR_GOLD := Color(1.0, 0.92, 0.5)  # 统一金色文字(金币数/第N关/步数)
const GEM_KEYS := ["red", "blue", "green", "gold", "purple", "pink"]  # species 顺序→宝石色(同 GEM_TEXTURES)
const GEM_TEXTURES := [
	"res://art/gems/base/gem_ruby.png", "res://art/gems/base/gem_water.png",
	"res://art/gems/base/gem_clover.png", "res://art/gems/base/gem_star.png",
	"res://art/gems/base/gem_orb.png", "res://art/gems/base/gem_heart.png",
]
const GEM_SHADOW := "res://art/gems/base/gem_shadow_soft.png"  # v0.02 棋子软阴影(椭圆投影, 子节点跟随)
const GEM_SHADOW_ALPHA := 0.5
# v0.02: 各棋子图案占整图比例不同(PIL实测), 按 1/max(宽高占比) 补偿 scale, 统一视觉大小。
# species 顺序: 0红方块 1蓝水滴 2绿四叶 3金星 4紫月 5粉心
const GEM_CONTENT_COMP := [1.16, 1.16, 0.84, 1.28, 1.25, 1.03]  # 实体统一(PIL测; greenx占满图→0.84, 粉×1.03)
const GEM_TINT := [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]  # green_new 素材已降白点, 不再用 modulate 压
# 特殊棋子(阶段5) shine 贴图：横/竖直线、3x3爆炸(叠在宝石上)。
# 4合1 = 普通宝石本体 + special_4 overlay；5合1 = 独立分层水晶球，不套普通阴影。
const SHINE_LINE_H := "res://art/gems/special_4/special_4_horizontal_overlay.png"
const SHINE_LINE_V := "res://art/gems/special_4/special_4_vertical_overlay.png"
const SHINE_BOMB := "res://art/gems/special_4/special_4_area_overlay.png"
const COLORBOMB_CORE := "res://assets/level/colorbomb_orb.png"  # v0.02 单张星辰球(5.png)
const COLORBOMB_GOLD_GLOW := "res://art/gems/special_5/special_5_gold_ground_glow.png"
const COLORBOMB_INNER_SWIRL := "res://art/gems/special_5/special_5_inner_swirl.png"
const COLORBOMB_INNER_STARS := "res://art/gems/special_5/special_5_inner_stars.png"
const COLORBOMB_CUBE_RING := "res://art/gems/special_5/special_5_cube_ring.png"
const COLORBOMB_LAYER_NAMES := ["GoldGroundGlow", "CoreInnerSwirl", "CoreInnerStars", "CubeRing"]
const FX_TEXTURES := {
	ME.SP_LINE_H: SHINE_LINE_H,
	ME.SP_LINE_V: SHINE_LINE_V,
	ME.SP_BOMB: SHINE_BOMB,
}
const CELL_TEXTURE := "res://assets/board/board_cell.png"
const BOARD_PANEL_TEXTURE := "res://assets/board/bg_board.png"
const PARCHMENT_BOARD := "res://assets/ui_frames/parchment_panel.png"  # (弃用)
const BOOK_FRAME := "res://assets/level/book_frame.png"      # v0.02 魔法书主体(982×980, 9-slice缩放适配棋盘)
const BOOK_RIBBONS := "res://assets/level/book_ribbons.png"  # v0.02 书底书签(343×80, 固定贴底不缩放)
const CELL_SQ := "res://assets/level/cell_sq.png"            # v0.02 米黄圆角棋格(cell.png 128²)
# 书页内金线框(book_frame 内边线, PIL实测 982×980)相对 book 边缘的像素 inset:
const BOOK_INNER_L := 53.0  # 左(书脊+金框+页边距)
const BOOK_INNER_T := 21.0  # 顶(书页开口薄)
const BOOK_INNER_R := 53.0  # 右
const BOOK_INNER_B := 56.0  # 底(书脊厚)
const BOOK_NINE_ML := 54    # 9-slice margin(≥内边线inset, 保金框/四角花不变形)
const BOOK_NINE_MT := 28
const BOOK_NINE_MB := 58
const CELL_TILE_FILL := Color(0.80, 0.64, 0.40, 0.32)   # v0.02 米黄半透格(叠羊皮底)
const CELL_TILE_BORDER := Color(0.52, 0.37, 0.18, 0.50) # 米黄格描边
const BG_TEXTURE := "res://assets/level/background.png"  # v0.02 新天空背景(862×1825, 按宽铺满)
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
const AGED_PARCH_SHADER := "res://match3/aged_parchment.gdshader"  # 米色框做旧
const FLOW_SHADER := "res://match3/flow_light.gdshader"  # 技能栏金色流光

# ── v0.02 顶部状态栏新素材(米黄风格, 设计稿换皮; 替换旧紫金分散顶栏) ──
const LV_BANNER := "res://assets/level/banner_long.png"        # 1134×283 状态栏底框(9-slice)
const LV_PILL := "res://assets/level/bar_pill.png"             # 415×115 星级药丸条(9-slice)
const LV_FRAME_SMALL := "res://assets/level/frame_small.png"   # 337×201 双目标小框(9-slice)
const LV_FRAME_CIRCLE := "res://assets/level/frame_circle.png" # 386×378 圆形头像金环(等比, 中心透明孔)
const LV_STAR_GOLD := "res://assets/level/star_gold.png"       # 174×176 金星(已点亮)
const LV_STAR_SILVER := "res://assets/level/star_silver.png"   # 168×166 银星(未点亮)
const LV_FLAG := "res://assets/level/flag_red.png"             # 267×286 关卡号红绶带
const LV_FLOWER := "res://assets/level/deco_flower.png"        # 477×214 雏菊藤蔓角饰
const LV_CHAIN := "res://assets/level/chain_gold.png"          # 507×131 金链(顶部悬挂装饰)
const LV_HERO_AVATAR := "res://assets/avatars/av_ladybug.png"  # v0.02 圆环内头像(七星瓢虫)
const LV_TOP := "res://assets/level/top.png"  # v0.02 整张顶栏图(框+挂链+花藤+星凹槽, 810×401), 仅空位写文字/星/目标
# 顶栏布局锚点(720×1520 设计坐标; 截图后微调)
const TB_BANNER_C := Vector2(360, 132)
const TB_BANNER_W := 704.0
const TB_BANNER_H := 196.0
const TB_FLAG_C := Vector2(98, 80)
const TB_FLAG_W := 132.0
const TB_STEP_C := Vector2(150, 170)        # 移动步数(banner 左下)
const TB_PILL_C := Vector2(406, 92)
const TB_PILL_W := 256.0
const TB_PILL_H := 64.0
const TB_STAR_GAP := 44.0
const TB_STAR_W := 40.0
const TB_FRAME_C := Vector2(406, 170)       # 双目标小框
const TB_FRAME_W := 252.0
const TB_FRAME_H := 116.0
const TB_OBJ_GAP := 100.0
const TB_OBJ_ICON_W := 50.0
const TB_CIRCLE_C := Vector2(596, 138)
const TB_CIRCLE_W := 156.0
const TB_AVATAR_W := 120.0
const TB_FLOWER_W := 128.0
const TB_CHAIN_W := 120.0
const TB_STEP_LABEL_COLOR := Color(0.50, 0.28, 0.12)  # 棕褐(配米黄banner)
const TB_STEP_NUM_COLOR := Color(0.86, 0.18, 0.16)    # 红字步数

# 关卡目标(占位) 与 技能(占位)
const OBJECTIVES_DEMO := [
	{"icon": "res://assets/gems/gem_water.png", "n": "16"},
	{"icon": "res://assets/gems/gem_star.png", "n": "28"},
	{"icon": "res://assets/avatars/av_raccoon_miner.png", "n": "2"},
]
const SKILLS := [
	# gem: 该萌宠对应的宝石颜色(消该色宝石→给该萌宠加进度条), 决定冷却条颜色
	{"av": "res://assets/avatars/av_deer_oracle.png", "name": "星鹿", "skill": "提示", "gem": "purple"},
	{"av": "res://assets/avatars/av_raccoon_miner.png", "name": "矿工程", "skill": "破障", "gem": "blue"},
	{"av": "res://assets/avatars/av_dragon_red.png", "name": "龙宝宝", "skill": "龙息大招", "gem": "red"},
	{"av": "res://assets/avatars/av_ladybug.png", "name": "瓢虫", "skill": "幸运祝福", "gem": "red"},
]

const DESIGN_W := 720.0
const DESIGN_H := 1520.0
const SWAP_TIME := 0.14
const CLEAR_TIME := 0.16
const CLEAR_POP_TIME := 0.06
const CLEAR_POP_SCALE := 1.22
const CLEAR_FX_BATCH_SIZE := 8
const COLORBOMB_ABSORB_TARGET_BUDGET := 18
const COLORBOMB_FINE_CLEAR_BUDGET := 12
const COLORBOMB_CLEAR_FX_BATCH_SIZE := 6
const FALL_TIME := 0.20
const FALL_EXTRA_CELL_TIME := 0.075
const ORDINARY_REFILL_MAX_TIME := 0.46
const WALL_SLIDE_STEP_TIME := 0.065
const WALL_SLIDE_MAX_TIME := 0.85
const ELIM_HOLD := 0.20  # 消除后停顿(等魔法特效炸裂完)再下落
const OPENING_DROP_TIME := 0.56
const OPENING_DROP_ROW_STAGGER := 0.045
const OPENING_FREEZE_STAGGER := 0.035
const OPENING_FREEZE_SETTLE := 0.24
const OPENING_STONE_COLOR := Color(0.62, 0.56, 0.50)
const OPENING_FREEZE_COLOR := Color(0.45, 0.78, 1.0)
const ENDGAME_BONUS_CONVERT_STEP := 0.08
const ENDGAME_BONUS_CONVERT_HOLD := 0.70
const ENDGAME_BONUS_RESULT_HOLD := 0.45
const BG_CRYSTAL_UV := Vector2(0.632, 0.41)   # 水晶球在 bg_scene 图中的归一化位置(白核扫描 px594,330)
const BG_CRYSTAL_TARGET := Vector2(360, 344)  # 对齐到狐狸与 Boss 正中间
const BG_SCALE := 1.05

# ── 布局锚点（对齐参考图；截图后微调） ──
const PAUSE_C := Vector2(58, 58)
const PAUSE_W := 92.0
const TITLE_C := Vector2(360, 46)
const TITLE_W := 256.0  # 金框横向长度(= 米色框宽, 两者等宽)
const TITLE_H := 76.0
const TITLE_FRAME := "res://assets/ui_frames/title_frame_centered.png"  # 尖饰已修正到框中心(原图偏左35px)
const TITLE_BG_COLOR := Color(0.165, 0.10, 0.29)  # 深紫 #2a1a4a
const TITLE_ML := 140.0
const TITLE_MTB := 32.0
# title_frame 金框内窗(从 alpha 实测, 见 tools/measure_frame.gd): 紫底刚好填满金框内孔
const TITLE_FRAME_AR := 159.0 / 922.0  # 金框原始高/宽
const TITLE_FRAME_H := 56.1  # 金框竖向厚度(66 ×0.85)
const TITLE_WIN_U0 := 0.0564
const TITLE_WIN_U1 := 0.9371
const TITLE_WIN_V0 := 0.1509
const TITLE_WIN_V1 := 0.8176
const TITLE_WIN_BLEED := 8.0  # 紫底外扩(总量), 塞进金边下消 AA 缝
const COIN_C := Vector2(602, 50)
const COIN_W := 56.0
const OBJPANEL_C := Vector2(360, 135.0)  # 框顶~88(间距~9), 中心=88+高/2(高×0.8后)
const OBJPANEL_W := 446.0
const OBJPANEL_H := 160.0
const OBJ_PARCH_W := TITLE_W  # 米色框宽度 = 标题框宽度(两者等宽锁定)
const OBJ_PARCH_H := OBJ_PARCH_W * 0.4617 * 0.8  # 自然比例(1566×723)再竖压到 0.8
const OBJ_GAP := 80.0  # 三目标水平间距(框变窄随之收)
const OBJ_ICON_W := 42.0  # 目标图标宽(框变窄→图标再缩, 防顶框)
const OBJ_NUM_FONT := 20  # 目标数字字号
const OBJ_LABEL_FONT := 15  # 目标类型短标签字号(例如"果冻")
const OBJ_NUM_COLOR := Color(0.16, 0.09, 0.04)  # 深褐墨色(配做旧米纸, 像墨水写的)
const OBJ_NUM_DY := 30.0  # 数字在图标下方的偏移
const OBJ_LABEL_DY := 52.0  # 类型标签在数字下方, 让 0/65 不再靠猜图标
const OBJ_FRAME := "res://assets/ui_frames/objective_frame.png"
const OBJ_BG_COLOR := Color(0.91, 0.835, 0.628)  # 米黄羊皮纸 #e8d5a0
const OBJ_ML := 88.0
const OBJ_MT := 46.0
const OBJ_MB := 30.0
const PURPLE_BG := "res://assets/ui_frames/purple_bg.png"
const PARCHMENT := "res://assets/ui_frames/parchment_fused.png"  # 融合暗黑紫金调(脚本生成)
const TITLE_BANNER := "res://assets/ui_frames/title_banner.png"
const GEM_PENDANT := "res://assets/ui_frames/gem_pendant.png"
const CONNECTOR_LINE := "res://assets/ui_frames/connector_line.png"
const CONN_NAIL_DY := -2.0  # 钉点(上端)相对标题下边的 y 微调
const CONN_HOOK_DY := 4.0  # 吊点(下端)落到米色框顶下方多少
const CONN_HOOK_INSET := 24.0  # 吊点离米色框左右边的内收量
const BANNER_W := 214.0
const BANNER_H := 50.0
const STEP_C := Vector2(166, OBJPANEL_C.y)  # 米色框左侧, 与米色框同高(中心对齐)
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
const BOARD_EDGE := 0.0         # 棋盘距屏幕左右边(0=角花顶点刚好贴边)
const BAND_T := 22.0            # 紫条厚度(细边框)
const LINE_T := 4.0             # 金线粗细
const FRAME_C := 88.0           # 四角向外凸出预留(布局留边用; 角件紫钻略凸于此内)
const FRAME_CORNER := "res://assets/ui_frames/corner.png"
const FRAME_BAND := "res://assets/ui_frames/band_purple.png"
const FRAME_LINE := "res://assets/ui_frames/line_gold.png"
# corner.png = 居中对称的金框紫钻小角花; 居中贴在棋盘四角。边用 FRAME_LINE 金线。
const CORNER_DISPLAY := FRAME_C * 0.375  # 角花显示大小(0.3×1.25; 同时决定布局预留→贴边)
const BOARD_BG_COLOR := Color(0.12, 0.09, 0.20, 1.0)  # 棋盘深紫不透明实底(不透出后面,不金色)
const CELL_FILL := 1.0          # 格子填满格位
const GEM_FILL := 0.84
const COLORBOMB_FILL := 0.86  # v0.02 彩球放大(匹配普通棋子, 更醒目)
const TRAY_TOP := 1236.0  # 技能栏顶(棋盘底锚定于此); 下移让棋盘整体下移, 露出更多角色
const SKILL_AV_Y := 1374.0
const SKILL_AV_W := 132.0
const SKILL_CD_Y := 1440.0
const SKILL_NAME_Y := 1472.0
const SKILL_SKILLNAME_Y := 1506.0

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
var _aged_parch_mat: ShaderMaterial = null
# 阶段7: 技能充能状态(改: 不再按时间冷却, 而是消除对应色宝石才涨)。idx 与 SKILLS 对齐。
const SKILL_CHARGE_REQ := 20.0                  # 满充能所需消除数(可调)
var _skill_charge := [0.0, 0.0, 0.0, 0.0]      # 各技能当前充能数(消对应色宝石累加, 满=可用)
var _skill_btns: Array = []                     # 4 个 TextureButton 引用(随 disabled/置灰)
var _skill_bar_fills: Array = []                # 4 个冷却条填充 Panel 引用(随 ratio 改宽)
var _skill_bar_geo: Array = []                  # 每条 {center,w,h,inset,ih}: 改填充宽度复用

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
	return (GEM_COLORS[GEM_KEYS[sp]] as Color).lightened(0.25)

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
	return ImageTexture.create_from_image(image)

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
	# v0.02: 书本左右贴屏幕边(满屏宽,间距0); 棋盘整体上移一点; 棋格落书页内金线框、水平居中。
	var avail_w: float = DESIGN_W  # book 满屏宽(贴边)
	cell_size = floor((avail_w - BOOK_INNER_L - BOOK_INNER_R) / float(board.width))
	var board_w: float = board.width * cell_size
	var board_h: float = board.height * cell_size
	var book_h: float = board_h + BOOK_INNER_T + BOOK_INNER_B
	var frame_bottom: float = TRAY_TOP - 6.0
	var book_y: float = frame_bottom - book_h - 8.0  # 棋盘位置(与顶栏留间距, 较前下移)
	board_origin = Vector2((DESIGN_W - board_w) * 0.5, book_y + BOOK_INNER_T)

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
	# 全屏深色兜底：bg_scene 缩放后未覆盖到的区域不再露出 viewport 默认灰
	var base := ColorRect.new()
	base.color = Color(0.05, 0.035, 0.10, 1.0)
	base.position = Vector2.ZERO
	base.size = Vector2(DESIGN_W, DESIGN_H)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 装饰底,勿吞棋盘点击
	background_layer.add_child(base)
	if not ResourceLoader.exists(BG_TEXTURE):
		return
	var tex: Texture2D = load(BG_TEXTURE)
	var sz: Vector2 = tex.get_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	# v0.02 天空背景: 用 TextureRect(Control) 与兜底同层, 按比例铺满全屏(超出居中裁切)。
	# 注: 同 CanvasLayer 下 Control 会盖 Node2D, 故背景用 Control 而非 Sprite2D 才能盖住兜底。
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.position = Vector2.ZERO
	tr.size = Vector2(DESIGN_W, DESIGN_H)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(tr)

func _render_board_panel() -> void:
	# v0.02: 魔法书主体 book_frame 用 9-slice —— 四角装饰(~37px)+金框/书脊不变形, 只拉书页中段;
	#        书页内框(左右38/顶≈角38/底44)对齐棋格。书签(book_ribbons)固定贴书底中央。
	var board_w: float = board.width * cell_size
	var board_h: float = board.height * cell_size
	# book_frame 9-slice(金框/四角花不变形); 内边线框=棋格(board_origin 即内边线左上)。
	var book_y: float = board_origin.y - BOOK_INNER_T
	var book_h: float = board_h + BOOK_INNER_T + BOOK_INNER_B
	# v0.02: 书本左右贴屏幕边; DESIGN_W+6 补偿 book_frame 左右各3px透明边, 金框真正贴屏
	var center := Vector2(DESIGN_W * 0.5, book_y + book_h * 0.5)
	_nine(board_layer, BOOK_FRAME, center, DESIGN_W + 6.0, book_h, BOOK_NINE_ML, BOOK_NINE_MT, BOOK_NINE_MB)
	if ResourceLoader.exists(BOOK_RIBBONS):
		var rib := TextureRect.new()
		rib.texture = load(BOOK_RIBBONS)
		rib.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rib.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var rw: float = board_w * 0.42
		var rh: float = rw * (80.0 / 343.0)
		rib.size = Vector2(rw, rh)
		# 书签顶部接住书本底书脊(上半压书脊、下半垂出书外, 无悬空缝隙)
		rib.position = Vector2(DESIGN_W * 0.5 - rw * 0.5, book_y + book_h - rh * 0.55)
		rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_layer.add_child(rib)

# 棋盘金边框：4 边(edge拉伸) + 4 角(corner翻转复用同一张)。在格子之上渲染。
func _render_board_frame() -> void:
	# v0.02: 棋盘金边框改由 parchment_panel(底框自带金边)提供, 不再画紫金 band/line/corner。
	return

func _frame_edge(path: String, pos: Vector2, sz: Vector2, flip_h: bool, flip_v: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.flip_h = flip_h
	tr.flip_v = flip_v
	tr.position = pos
	tr.size = sz
	board_layer.add_child(tr)

## 一条边/线：横向素材(长×短)拉到 length×thick；vertical 时旋转90°使光泽方向一致。Sprite2D 居中。
func _frame_strip(path: String, center: Vector2, length: float, thick: float, vertical: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	var tw: float = float(s.texture.get_width())
	var th: float = float(s.texture.get_height())
	if vertical:
		s.rotation = PI * 0.5
	s.scale = Vector2(length / tw, thick / th)
	s.position = center
	board_layer.add_child(s)

## 角花: 居中对称的金框紫钻, 居中贴在棋盘角, 缩到 FRAME_C。
func _frame_corner(center: Vector2) -> void:
	if not ResourceLoader.exists(FRAME_CORNER):
		return
	var s := Sprite2D.new()
	s.texture = load(FRAME_CORNER)
	s.scale = _fit_scale(s.texture, CORNER_DISPLAY)
	s.position = center
	board_layer.add_child(s)

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
		_coat_nodes = _blank_visual_rows()
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
	if sp >= 0:
		return sp
	if board.species.is_empty():
		return sp
	if sp != ME.WALL and _layer_value(board.coat, row, col) <= 0:
		return sp
	return int(board.species[abs(row * 31 + col * 17) % board.species.size()])

func _opening_drop_start_position(final_center: Vector2, row: int) -> Vector2:
	return final_center - Vector2(0.0, cell_size * float(row + 1.5))

func _opening_drop_delay(row: int, height: int = -1) -> float:
	var h: int = height if height > 0 else board.height
	return float(h - 1 - row) * OPENING_DROP_ROW_STAGGER

func _opening_coat_cells() -> Array:
	var cells := []
	for r in range(board.height):
		for c in range(board.width):
			if _layer_value(board.coat, r, c) > 0 and board.grid[r][c] != ME.WALL:
				cells.append(Vector2i(c, r))
	return cells

func _opening_wall_cells() -> Array:
	var cells := []
	for r in range(board.height):
		for c in range(board.width):
			if board.grid[r][c] == ME.WALL:
				cells.append(Vector2i(c, r))
	return cells

func _settle_opening_gems(generation: int) -> bool:
	if generation != _level_generation:
		return false
	for r in range(board.height):
		for c in range(board.width):
			var n: Sprite2D = _gem_nodes[r][c]
			if n != null and is_instance_valid(n):
				n.position = _cell_center(r, c)
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

func _show_opening_coat_marker(pos: Vector2i, animate: bool) -> void:
	_clear_gem_node_at(pos.y, pos.x)
	if _coat_nodes.is_empty():
		_coat_nodes = _blank_visual_rows()
	var tex: Texture2D = load(BARRIER_ICE_ICON) if ResourceLoader.exists(BARRIER_ICE_ICON) else null
	if tex == null:
		return
	var marker := _make_coat_marker(pos.y, pos.x, tex)
	_coat_nodes[pos.y][pos.x] = marker
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
	var cells: Array = _opening_coat_cells()
	if (wall_cells.is_empty() and cells.is_empty()) or generation != _level_generation:
		return
	for p in wall_cells:
		if generation != _level_generation:
			return
		Fx.spawn_beam(BOSS_C, _cell_center(p.y, p.x), OPENING_STONE_COLOR)
		_show_opening_wall_marker(p, true)
		await get_tree().create_timer(OPENING_FREEZE_STAGGER).timeout
	for p in cells:
		if generation != _level_generation:
			return
		Fx.spawn_beam(BOSS_C, _cell_center(p.y, p.x), OPENING_FREEZE_COLOR)
		_show_opening_coat_marker(p, true)
		await get_tree().create_timer(OPENING_FREEZE_STAGGER).timeout
	await get_tree().create_timer(OPENING_FREEZE_SETTLE).timeout

func _apply_opening_freeze_instant(generation: int) -> void:
	if generation != _level_generation:
		return
	for p in _opening_wall_cells():
		_show_opening_wall_marker(p, false)
	for p in _opening_coat_cells():
		_show_opening_coat_marker(p, false)

func _play_opening_drop(generation: int) -> void:
	if not is_inside_tree():
		if _settle_opening_gems(generation):
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
			var delay := _opening_drop_delay(r)
			var tw := t.tween_property(n, "position", target, OPENING_DROP_TIME)
			tw.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	await _play_opening_freeze(generation)
	_finish_opening_drop(generation)

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
	gs.set_meta("species", sp)
	gs.set_meta("fx", ME.SP_NONE)
	# v0.02: 棋子形状阴影 —— 用棋子自身纹理染黑(同形状), 尺寸×0.85, 下偏移一丢丢, 居棋子下层半透。
	var sh := Sprite2D.new()
	sh.name = "shadow"
	sh.texture = tex
	sh.z_index = -1
	sh.scale = Vector2(0.85, 0.85)
	sh.position = Vector2(0.0, (cell_size * 0.14) / (gs.scale.y if gs.scale.y != 0.0 else 1.0))
	sh.modulate = Color(0.0, 0.0, 0.0, GEM_SHADOW_ALPHA)
	gs.add_child(sh)
	gem_layer.add_child(gs)
	return gs

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

func _make_coat_marker(row: int, col: int, tex: Texture2D) -> Sprite2D:
	var layers := _layer_value(board.coat, row, col)
	if layers <= 0 or board.grid[row][col] == ME.WALL:
		return null
	var marker := Sprite2D.new()
	marker.name = BARRIER_MARKER_NAME
	marker.add_to_group(BARRIER_MARKER_NAME)
	marker.texture = tex
	marker.material = _magenta_material()
	marker.position = _cell_center(row, col) + Vector2(cell_size * 0.03, cell_size * 0.05)  # v0.02 冰块略右下移(补偿 ob_ice 实体偏左上)
	marker.scale = _fit_scale(tex, cell_size * BARRIER_FILL)
	marker.z_index = 8
	# v0.02: 冰块形状阴影(同棋子: 自身形状染黑×0.85下偏移, 居冰块下层)
	var sh := Sprite2D.new()
	sh.name = "shadow"
	sh.texture = tex
	sh.z_index = -1
	sh.scale = Vector2(0.85, 0.85)
	sh.position = Vector2(0.0, (cell_size * 0.14) / (marker.scale.y if marker.scale.y != 0.0 else 1.0))
	sh.modulate = Color(0.0, 0.0, 0.0, GEM_SHADOW_ALPHA)
	marker.add_child(sh)
	gem_layer.add_child(marker)
	return marker

## 阶段5: 给宝石节点叠/移 shine 子节点(命名"shine"), 标记其为特效棋子。
## 作为子 Sprite2D 居中铺满格, 父节点下落 tween 时自动跟随。kind==SP_NONE 则移除。
func _apply_fx_overlay(node: Sprite2D, kind: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_meta("fx", kind)
	var old: Node = node.get_node_or_null("shine")
	if old != null:
		old.queue_free()
	_clear_colorbomb_layers(node)
	if kind == ME.SP_COLORBOMB:
		_apply_colorbomb_layers(node)
		return
	if kind == ME.SP_NONE or not FX_TEXTURES.has(kind):
		return
	var path: String = FX_TEXTURES[kind]
	if not _asset_exists(path):
		return
	var tex := _load_texture(path)
	if tex == null:
		return
	var shine := Sprite2D.new()
	shine.name = "shine"
	shine.texture = tex
	# 子节点缩放需抵消父节点 scale, 使 shine 实际铺满 cell。
	var parent_s: Vector2 = node.scale
	var fit: Vector2 = _fit_scale(tex, cell_size * CELL_FILL)
	shine.scale = Vector2(
		fit.x / (parent_s.x if parent_s.x != 0.0 else 1.0),
		fit.y / (parent_s.y if parent_s.y != 0.0 else 1.0))
	shine.z_index = 1  # 盖在宝石之上
	node.add_child(shine)

func _clear_colorbomb_layers(node: Sprite2D) -> void:
	node.offset = Vector2.ZERO
	for layer_name in COLORBOMB_LAYER_NAMES:
		var child := node.get_node_or_null(String(layer_name))
		if child != null:
			child.queue_free()

func _apply_colorbomb_layers(node: Sprite2D) -> void:
	# v0.02: 彩球用单张星辰球(colorbomb_orb / 5.png), 不再叠 5 层老素材合成。
	if not _asset_exists(COLORBOMB_CORE):
		return
	var core := _load_texture(COLORBOMB_CORE)
	if core == null:
		return
	node.texture = core
	node.offset = Vector2.ZERO
	node.scale = _fit_scale(core, cell_size * COLORBOMB_FILL)
	node.z_index = 2
	# 5合1 专属阴影: 金色地面光晕(special_5_gold_ground_glow, 椭圆, 彩球下方地面; 非棋子黑剪影)
	if _asset_exists(COLORBOMB_GOLD_GLOW):
		var gtex := _load_texture(COLORBOMB_GOLD_GLOW)
		if gtex != null:
			var glow := Sprite2D.new()
			glow.name = "glow"
			glow.texture = gtex
			glow.z_index = -1
			var ps: Vector2 = node.scale
			var gfit: Vector2 = _fit_scale(gtex, cell_size * 0.90)  # 阴影做小一丢丢
			glow.scale = Vector2(gfit.x / (ps.x if ps.x != 0.0 else 1.0), gfit.y / (ps.y if ps.y != 0.0 else 1.0))
			glow.position = Vector2(0.0, (cell_size * 0.20) / (ps.y if ps.y != 0.0 else 1.0))
			glow.modulate = Color(1.5, 1.34, 0.85, 1.0)  # 提亮成选中时的亮金光(默认 gold_ground_glow 太暗)
			node.add_child(glow)
	# 轻微上下浮动(idle), 不依赖任何子层
	var bob := node.create_tween().set_loops()
	bob.tween_property(node, "offset", Vector2(0, -3.0), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(node, "offset", Vector2(0, 3.0), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _add_colorbomb_layer(parent: Sprite2D, layer_name: String, path: String, offset: Vector2, relative_size: float, z: int, alpha: float) -> Sprite2D:
	if not _asset_exists(path):
		push_warning("Missing colorbomb layer art: %s" % path)
		return null
	var tex := _load_texture(path)
	if tex == null:
		return null
	var child := Sprite2D.new()
	child.name = layer_name
	child.texture = tex
	child.position = offset / maxf(parent.scale.y, 0.001)
	child.scale = Vector2.ONE * relative_size
	child.z_index = z
	child.modulate.a = alpha
	parent.add_child(child)
	return child

func _play_colorbomb_idle(root: Sprite2D, glow: Sprite2D, swirl: Sprite2D, stars: Sprite2D, ring: Sprite2D) -> void:
	var bob := root.create_tween().set_loops()
	bob.tween_property(root, "offset", Vector2(0, -3.0), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(root, "offset", Vector2(0, 3.0), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bob_units := 3.0 / maxf(root.scale.y, 0.001)
	for layer in [glow, swirl, stars, ring]:
		if layer == null:
			continue
		var layer_node := layer as Sprite2D
		var layer_bob: Tween = layer_node.create_tween().set_loops()
		var base_layer_pos: Vector2 = layer_node.position
		layer_bob.tween_property(layer_node, "position", base_layer_pos + Vector2(0, -bob_units), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		layer_bob.tween_property(layer_node, "position", base_layer_pos + Vector2(0, bob_units), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if swirl != null:
		var sw := swirl.create_tween().set_loops()
		sw.tween_property(swirl, "rotation", TAU, 4.8).as_relative()
	if ring != null:
		var rg := ring.create_tween().set_loops()
		rg.tween_property(ring, "rotation", -TAU, 6.2).as_relative()
	if stars != null:
		var st := stars.create_tween().set_loops()
		st.tween_property(stars, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		st.tween_property(stars, "modulate:a", 0.95, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ───────── 整页 UI（对齐参考图） ─────────

func _render_chrome(cfg: Dictionary) -> void:
	_cur_cfg = cfg
	_clear_layer(character_layer)
	_clear_layer(ui_layer)
	_clear_layer(skill_bar)
	# v0.02: 设计稿为纯三消, 移除 Boss 对战区(狐狸/Boss/道具书)。score 计分逻辑不受影响。
	# _render_characters()
	_render_ui_layer()
	_render_skillbar()

# 阶段6: ui_layer(顶栏+吊坠绳+目标卡+步数徽章+星级)整层重画。
# HUD 刷新只动 ui_layer(不重画角色/技能栏/棋盘), 目标进度/步数随每步更新。
func _render_ui_layer() -> void:
	_render_topbar_v2(_cur_cfg)

# 阶段6: 每步 resolve/swap 后刷新 HUD(目标卡进度 + 步数徽章)——只重画 ui_layer。
func _refresh_hud() -> void:
	_clear_layer(ui_layer)
	_render_ui_layer()

## 镂空金框 + 后方垫底色：底色填镂空区(略小不溢出金边)，NinePatch 金框盖最上。
func _framed_panel(layer: CanvasLayer, frame_path: String, center: Vector2, w: float, h: float, ml: float, mt: float, mb: float, bg_color: Color) -> void:
	var ix: float = ml * 0.5
	var bg := ColorRect.new()
	bg.color = bg_color
	bg.size = Vector2(w - ix * 2.0, h - mt - mb)
	bg.position = Vector2(center.x - bg.size.x * 0.5, center.y - h * 0.5 + mt)
	layer.add_child(bg)
	if not ResourceLoader.exists(frame_path):
		return
	var np := NinePatchRect.new()
	np.texture = load(frame_path)
	np.position = center - Vector2(w, h) * 0.5
	np.size = Vector2(w, h)
	np.patch_margin_left = int(ml)
	np.patch_margin_right = int(ml)
	np.patch_margin_top = int(mt)
	np.patch_margin_bottom = int(mb)
	layer.add_child(np)

# v0.02: 米黄风格顶部状态栏(banner 横铺 + 绶带关卡号 + 星条 + 双目标 + 圆环头像 + 链/花装饰)。
# 换皮不动数据: 关卡号=cfg.id, 步数=board.moves_left, 目标=_objectives_view(), 星级=占位(1金2银)。
func _render_topbar_v2(cfg: Dictionary) -> void:
	# v0.02: 整张 top.png 作顶栏底(框+挂链+花藤+星凹槽), 满屏宽顶对齐; 仅在空位写文字/星/目标(无头像)。
	var tw: float = DESIGN_W
	var th: float = DESIGN_W * 401.0 / 810.0  # 等比 ≈357
	if ResourceLoader.exists(LV_TOP):
		var top := TextureRect.new()
		top.texture = load(LV_TOP)
		top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		top.stretch_mode = TextureRect.STRETCH_SCALE
		top.position = Vector2.ZERO
		top.size = Vector2(tw, th)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(top)
	# 关卡号(左上红绶带, PIL 实测中心 0.178,0.261)
	_label(ui_layer, "第 %d 关" % int(cfg.get("id", 1)), Vector2(tw * 0.178, th * 0.33), 22, Color(1, 0.97, 0.9), 150, 4, Color(0.45, 0.04, 0.04, 0.9))
	# 星级 3 星(凹槽 PIL 实测 x[0.410,0.574,0.738] y0.418; 占位 1 金 2 银)
	var star_paths: Array = [LV_STAR_GOLD, LV_STAR_SILVER, LV_STAR_SILVER]
	var sxs: Array = [0.385, 0.549, 0.713]
	for i in range(3):
		_sprite_w(ui_layer, String(star_paths[i]), Vector2(tw * float(sxs[i]), th * 0.519), 44.0, false)
	# 剩余步数(下方左格 x0.205, 米黄区 PIL实测 y0.52-0.88)
	var moves: int = board.moves_left if board != null else 0
	_label(ui_layer, "剩余步数", Vector2(tw * 0.17, th * 0.64), 18, Color(0.50, 0.28, 0.12), 135)
	_label(ui_layer, str(maxi(moves, 0)), Vector2(tw * 0.17, th * 0.80), 36, Color(0.86, 0.18, 0.16), 135, 4, Color(1, 1, 1, 0.5))
	# 关卡目标(下方右格, 竖线 PIL实测 @0.30, 右格中心 0.60)
	var view: Array = _objectives_view()
	if view.is_empty():
		view = OBJECTIVES_DEMO
	var n: int = mini(view.size(), 2)
	for i in range(n):
		var item: Dictionary = view[i]
		var ox: float = tw * (0.60 + (float(i) - float(n - 1) * 0.5) * 0.20)
		var icon_path: String = String(item.get("icon", ""))
		_sprite_w(ui_layer, icon_path, Vector2(ox, th * 0.68), 58.0, icon_path == BARRIER_ICE_ICON)
		var txt: String = String(item["n"]) if item.has("n") else str(int(item.get("target", 0)))
		_label(ui_layer, txt, Vector2(ox, th * 0.785), 18, Color(0.20, 0.12, 0.05), 70)


func _render_topbar(cfg: Dictionary) -> void:
	# 暂停按钮（圆徽底 + ❚❚）
	_sprite_w(ui_layer, STEP_FRAME, PAUSE_C, PAUSE_W, false)
	_label(ui_layer, "❚❚", PAUSE_C, 30, Color(1, 0.95, 0.75), 80)
	# 第 N 关 标题框: title_frame 整体等比缩放(紫钻不变形) + 紫底刚好填满金框内窗 + 白字
	# 内窗按 alpha 实测 UV 反算到屏幕(随 TITLE_C/TITLE_W 自动跟随), 紫底外扩塞进金边下
	var f_w := TITLE_W
	var f_h := TITLE_FRAME_H  # 厚度固定, 只缩横向长度
	# 贴图已修正(尖饰=框中心), 框居中画在 TITLE_C 即可, 尖饰自然落正中
	var f_l := TITLE_C.x - f_w * 0.5
	var f_t := TITLE_C.y - f_h * 0.5
	var win_c := Vector2(
		f_l + (TITLE_WIN_U0 + TITLE_WIN_U1) * 0.5 * f_w,
		f_t + (TITLE_WIN_V0 + TITLE_WIN_V1) * 0.5 * f_h)
	var win_w := (TITLE_WIN_U1 - TITLE_WIN_U0) * f_w + TITLE_WIN_BLEED
	var win_h := (TITLE_WIN_V1 - TITLE_WIN_V0) * f_h + TITLE_WIN_BLEED
	_sprite_wh(ui_layer, PURPLE_BG, win_c, win_w, win_h, false)
	_sprite_wh(ui_layer, TITLE_FRAME, TITLE_C, f_w, f_h, false)
	# "第 N 关": "1"字对齐正中(=尖饰列), 竖向居中于内窗
	_label(ui_layer, "第 %d 关" % cfg["id"], Vector2(TITLE_C.x, win_c.y), 28, COLOR_GOLD, TITLE_W)
	# 金币
	_sprite_w(ui_layer, COIN_TEX, COIN_C, COIN_W, false)
	_label(ui_layer, "2350", COIN_C + Vector2(58, 0), 34, COLOR_GOLD, 140)

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

## 串联：紫钻吊坠(挂标题框底中央) + 八字斜线(两根镜像,从吊坠下斜向目标框顶)
func _render_title_connector() -> void:
	# 标题下尖饰=钉子, 两条 connector_line 像绳子从钉子吊住米色框顶两角
	var nail := Vector2(TITLE_C.x, TITLE_C.y + TITLE_FRAME_H * 0.5 + CONN_NAIL_DY)
	var top_y := OBJPANEL_C.y - OBJ_PARCH_H * 0.5 + CONN_HOOK_DY
	var half := OBJ_PARCH_W * 0.5 - CONN_HOOK_INSET
	_connector(nail, Vector2(OBJPANEL_C.x - half, top_y))  # 左绳(负x缩放=镜像)
	_connector(nail, Vector2(OBJPANEL_C.x + half, top_y))  # 右绳

## 把 connector_line 的原生两端(顶3,0 / 底211,241)精确映射到 钉点n→框角c。
func _connector(n: Vector2, c: Vector2) -> void:
	if not ResourceLoader.exists(CONNECTOR_LINE):
		return
	var t := Vector2(3.0, 0.0)
	var b := Vector2(211.0, 241.0)
	var s := Sprite2D.new()
	s.texture = load(CONNECTOR_LINE)
	s.centered = false
	var sx: float = (c.x - n.x) / (b.x - t.x)
	var sy: float = (c.y - n.y) / (b.y - t.y)
	s.scale = Vector2(sx, sy)
	s.position = n - Vector2(sx * t.x, sy * t.y)
	ui_layer.add_child(s)

func _render_objective_panel() -> void:
	var c: Vector2 = OBJPANEL_C
	# 1. parchment_panel 自带边框, 按自然比例画(无变形), 不加特效直接用
	_sprite_wh(ui_layer, PARCHMENT, c, OBJ_PARCH_W, OBJ_PARCH_H, false)
	# 2. objective_frame 金框已按需移除(只留米黄底)
	# 3. 目标(图标 + "进度/目标"深墨色数字)在米黄底上, 走真数据(_objectives_view)。
	# 布局循环用 size() 居中 → 1/2/3 目标自适应; 框宽/位置/绳子等视觉不变(只换数据源)。
	var view: Array = _objectives_view()
	if view.is_empty():
		view = OBJECTIVES_DEMO   # fallback: 无真数据(回退关)时仍画占位, 防空白框
	var n: int = view.size()
	for i in range(n):
		var item: Dictionary = view[i]
		var cx: float = c.x + (float(i) - float(n - 1) * 0.5) * OBJ_GAP
		# 图标在上, 数字在下(深墨色), 簇竖向居中于框
		var icy: float = c.y - 9.5
		var icon_path := String(item["icon"])
		_sprite_w(ui_layer, icon_path, Vector2(cx, icy), OBJ_ICON_W, icon_path == BARRIER_ICE_ICON)
		# 真目标画 "进度/目标"; 占位(无 progress/target)退化为单数字。
		var txt: String = item["n"] if item.has("n") else "%d/%d" % [int(item.get("progress", 0)), int(item.get("target", 0))]
		_label(ui_layer, txt, Vector2(cx, icy + OBJ_NUM_DY), OBJ_NUM_FONT, OBJ_NUM_COLOR, 90, 2, Color(1.0, 0.97, 0.86, 0.5))
		var label_text := String(item.get("label", ""))
		if not label_text.is_empty():
			_label(ui_layer, label_text, Vector2(cx, icy + OBJ_LABEL_DY), OBJ_LABEL_FONT, OBJ_NUM_COLOR, 90, 1, Color(1.0, 0.97, 0.86, 0.5))
	# "关卡目标"横幅(title_banner)与文字已按需移除

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

func _render_step_badge() -> void:
	_sprite_w(ui_layer, STEP_FRAME, STEP_C, STEP_W, false)
	var moves: int = board.moves_left if board != null else 0
	_label(ui_layer, str(maxi(moves, 0)), STEP_C + Vector2(0, -8), 42, COLOR_GOLD, STEP_W)
	_label(ui_layer, "剩余步数", STEP_C + Vector2(0, 26), 17, COLOR_GOLD, STEP_W + 10)

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
		_skill_button(sk["av"], Vector2(cx, SKILL_AV_Y), SKILL_AV_W, i)
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
	if not ResourceLoader.exists(path):
		_skill_btns.append(null)
		return
	var tex: Texture2D = load(path)
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var sz: Vector2 = tex.get_size()
	var h: float = width * (sz.y / sz.x) if sz.x > 0.0 else width
	btn.size = Vector2(width, h)
	btn.position = center - btn.size * 0.5   # TextureButton 是左上角定位 → 减半尺寸居中
	btn.material = _magenta_material()        # 品红抠像(与静态头像一致)
	btn.pressed.connect(_on_skill_pressed.bind(idx))
	skill_bar.add_child(btn)
	_skill_btns.append(btn)

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
		var ratio: float = clampf(_skill_charge[i] / SKILL_CHARGE_REQ, 0.0, 1.0)
		var w: float = geo["w"]
		var inset: float = geo["inset"]
		var ih: float = geo["ih"]
		fl.size = Vector2(maxf((w - inset * 2.0) * ratio, ih), ih)
	for i in range(_skill_btns.size()):
		var btn = _skill_btns[i]
		if btn == null or not is_instance_valid(btn):
			continue
		var ready: bool = _skill_charge[i] >= SKILL_CHARGE_REQ
		btn.disabled = not ready
		btn.modulate.a = 1.0 if ready else 0.45

## 点技能: 守卫(忙/结算/未充满→忽略) → 分派 → 成功后充能清零(重攒)。技能不消耗步数。
func _on_skill_pressed(idx: int) -> void:
	if _busy or _settled or _skill_charge[idx] < SKILL_CHARGE_REQ:
		return
	if board == null:
		return
	var did := false
	match SKILLS[idx]["skill"]:
		"提示":
			did = await _skill_hint()
		"破障":
			did = await _skill_break()
		"龙息大招":
			did = await _skill_dragon()
		"幸运祝福":
			did = await _skill_blessing()
	if did:
		_skill_charge[idx] = 0.0   # 放完清零重攒
		_update_skill_cd_visual()

# ── idx0 星鹿/提示: 高亮最优一步两格 2.5s 自动清除。不改盘/不resolve/不扣步。 ──
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
		_run_win_bonus_and_show()
	elif board.is_lost():
		_show_result(false)

func _run_win_bonus_and_show() -> void:
	await _play_endgame_bonus()
	_refresh_hud()
	_show_result(true)

func _play_endgame_bonus() -> void:
	var picks: Array = board.prepare_endgame_bonus_lines()
	if picks.is_empty():
		return
	_refresh_hud()
	for item in picks:
		var p: Vector2i = item["pos"]
		var n: Sprite2D = _gem_nodes[p.y][p.x]
		if n != null and is_instance_valid(n):
			_apply_fx_overlay(n, int(item["kind"]))
			await get_tree().create_timer(ENDGAME_BONUS_CONVERT_STEP).timeout
	await get_tree().create_timer(ENDGAME_BONUS_CONVERT_HOLD).timeout
	var seeds := []
	for item in picks:
		seeds.append(item["pos"])
	var clear_set: Dictionary = ME._expand_triggers(board.grid, board.fx, seeds)
	var cells: Array = clear_set.keys()
	if cells.is_empty():
		return
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
	board._gain(ME.score_for_clear(to_clear.size(), 1))
	await _play_clear(to_clear, [], {})
	ME._apply_clears(board.grid, board.fx, to_clear, [])
	for p in to_clear:
		var n: Sprite2D = _gem_nodes[p.y][p.x]
		if n != null and is_instance_valid(n):
			n.queue_free()
		_gem_nodes[p.y][p.x] = null
	await _collapse_and_refill()
	await _resolve_cascades()
	await get_tree().create_timer(ENDGAME_BONUS_RESULT_HOLD).timeout

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

# 非等比填充: 把整图拉到精确 w×h(实心面板填窗口用, 与 _sprite_w 的等比不同)
func _sprite_wh(layer: CanvasLayer, path: String, center: Vector2, w: float, h: float, use_key: bool) -> Sprite2D:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var sz := tex.get_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.position = center
	s.scale = Vector2(w / sz.x, h / sz.y)
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

func _aged_parchment_material() -> ShaderMaterial:
	if _aged_parch_mat == null:
		_aged_parch_mat = ShaderMaterial.new()
		_aged_parch_mat.shader = load(AGED_PARCH_SHADER)
		_aged_parch_mat.set_shader_parameter("edge_darken", 0.0)  # 不额外压暗
		_aged_parch_mat.set_shader_parameter("edge_lighten", 0.7)  # 提亮边缘抵消贴图烤进去的暗边(去阴影)
	return _aged_parch_mat

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
	# 提交交换(数据 + 节点引用)
	ME._swap_cells(board.grid, a, b)
	ME._swap_cells(board.fx, a, b)
	_gem_nodes[a.y][a.x] = nb
	_gem_nodes[b.y][b.x] = na
	# 阶段3: 消除-下落-补充-连锁
	var settle: Dictionary = await _resolve_cascades(b)
	await _finish_consumed_move(int(settle.get("choco_cleared", 0)), int(settle.get("cascades", 0)))
	_busy = false

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
	await _play_colorbomb_absorb_preview(cb_pos, cells)
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


func _play_colorbomb_absorb_preview(cb_pos: Vector2i, cells: Array) -> void:
	var end_pos := _cell_center(cb_pos.y, cb_pos.x) + Vector2(0.0, cell_size * 0.18)
	var targets := []
	for p in cells:
		if p == cb_pos:
			continue
		if board.grid[p.y][p.x] < 0:
			continue
		if _gem_nodes[p.y][p.x] == null:
			continue
		targets.append(p)
	targets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _cell_center(a.y, a.x).distance_squared_to(end_pos) < _cell_center(b.y, b.x).distance_squared_to(end_pos)
	)
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
		Fx.spawn_target_outline(start, col, cell_size * 0.88, delay * 0.35)
		Fx.spawn_color_absorb_orb(start, end_pos, col, delay, orb_dur)
		var arrival := delay + orb_dur * 1.22
		max_arrival = maxf(max_arrival, arrival)
		_pulse_colorbomb_gold_glow(cb_pos, arrival)
	if budget > 0:
		await get_tree().create_timer(max_arrival + 0.08).timeout
		_pulse_colorbomb_inner_stars(cb_pos)
		await get_tree().create_timer(0.18).timeout
	else:
		await get_tree().create_timer(0.08).timeout

func _colorbomb_layer_at(cb_pos: Vector2i, layer_name: String) -> Sprite2D:
	if cb_pos.y < 0 or cb_pos.y >= _gem_nodes.size() or cb_pos.x < 0 or cb_pos.x >= _gem_nodes[cb_pos.y].size():
		return null
	var root: Sprite2D = _gem_nodes[cb_pos.y][cb_pos.x]
	if root == null or not is_instance_valid(root):
		return null
	return root.get_node_or_null(layer_name) as Sprite2D

func _pulse_colorbomb_gold_glow(cb_pos: Vector2i, delay: float = 0.0) -> void:
	if delay > 0.0 and is_inside_tree():
		get_tree().create_timer(delay).timeout.connect(_pulse_colorbomb_gold_glow.bind(cb_pos, 0.0), CONNECT_ONE_SHOT)
		return
	var glow := _colorbomb_layer_at(cb_pos, "GoldGroundGlow")
	if glow == null:
		return
	var base_self := glow.self_modulate
	var base_scale := glow.scale
	var bright := Color(1.35, 1.18, 0.72, 1.0)
	var t := create_tween()
	t.tween_property(glow, "self_modulate", bright, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(glow, "scale", base_scale * 1.10, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(glow, "self_modulate", base_self, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(glow, "scale", base_scale, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _pulse_colorbomb_inner_stars(cb_pos: Vector2i) -> void:
	var stars := _colorbomb_layer_at(cb_pos, "CoreInnerStars")
	if stars == null:
		return
	var base_self := stars.self_modulate
	var bright := Color(1.38, 1.34, 1.0, 1.0)
	var t := create_tween()
	t.tween_property(stars, "self_modulate", bright, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(stars, "self_modulate", base_self, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(stars, "self_modulate", bright, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(stars, "self_modulate", base_self, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


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
	await _play_clear(to_clear, [], {})
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
		_play_wide_line_fx(b_after, kb, _fx_color(board.grid[b_after.y][b_after.x]))
	elif a_line and b_bomb:
		_play_wide_line_fx(a_after, ka, _fx_color(board.grid[a_after.y][a_after.x]))
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

func _flash_matches() -> void:
	_clear_highlights()
	var matches: Array = ME.find_matches(board.grid, board._layers())
	for m in matches:
		var mk := ColorRect.new()
		mk.color = Color(1.0, 0.9, 0.2, 0.5)
		mk.size = Vector2(cell_size, cell_size) * 0.96
		mk.position = _cell_center(m.y, m.x) - mk.size * 0.5
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 高亮标记勿吞点击
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

## 阶段5: 引擎驱动逐级连锁——引擎算"清哪些格/生成什么特效"，视图负责逐级动画。
## 每级: collect_clears → 播特效+淡出 → _apply_clears(落特效/清格) → 节点同步 → 下落补充。
func _resolve_cascades(preferred_spawn: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var guard: int = 0
	var cascade_level: int = 0   # 连锁级数(1起): 越深计分倍率越高, 与引擎 resolve 同口径
	var step_choco := 0
	var cascade_preferred := preferred_spawn
	while guard < 30:
		guard += 1
		var c: Dictionary = ME.collect_clears(board.grid, board.fx, board._layers(), cascade_preferred)
		cascade_preferred = Vector2i(-1, -1)
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
			_apply_fx_overlay(_gem_nodes[sp_pos.y][sp_pos.x], board.fx[sp_pos.y][sp_pos.x])
		await _play_clear(to_clear, spawns, protected_spawn_set)
		# 引擎执行清除: spawn 格落特效(保留 species), 其余格 grid=EMPTY/fx=SP_NONE
		ME._apply_clears(board.grid, board.fx, to_clear, spawns, triggered_spawn_set)
		# 节点同步: 非 spawn 格删节点置 null; spawn 格给节点叠 shine(此时 board.fx 已是新 kind)
		for p in to_clear:
			if protected_spawn_set.has(p):
				_apply_fx_overlay(_gem_nodes[p.y][p.x], board.fx[p.y][p.x])
			else:
				var n: Sprite2D = _gem_nodes[p.y][p.x]
				if n != null and is_instance_valid(n):
					n.queue_free()
				_gem_nodes[p.y][p.x] = null
		await _collapse_and_refill()
	return {"choco_cleared": step_choco, "cascades": cascade_level}

## 阶段5 消除表现: 遍历 to_clear——被触发的已存在特效格放对应 Fx; 普通格碎裂; 非 spawn 格淡出。
func _play_clear(to_clear: Array, spawns: Array, spawn_set: Dictionary) -> void:
	# 行/列横扫、十字星爆炸：路径棋子碎成触发特效的原色粒子，避免按各格颜色炸成彩虹。
	var visual_species: Dictionary = ClearVisuals.special_clear_species_overrides(board.grid, board.fx, to_clear, spawn_set)
	var any := false
	var spawned_fx_count := 0
	for p in to_clear:
		var fx_kind: int = board.fx[p.y][p.x]
		var spawned_fx := false
		# 被卷入消除的【已存在】特效棋子(它不在本级 spawn_set): 放对应 Fx 表现
		if fx_kind != ME.SP_NONE and not spawn_set.has(p):
			_play_special_fx(p, fx_kind)
			spawned_fx = true
		else:
			var sp: int = board.grid[p.y][p.x]
			if sp >= 0 and sp < GEM_KEYS.size():
				if visual_species.has(p):
					# 横竖横扫/十字星: 不叠加三帧, 路径棋子碎成触发特效的纯色粒子
					Fx.spawn_shatter(_cell_center(p.y, p.x), _gem_raw_color(int(visual_species[p])))
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
				var base_scale: Vector2 = n.scale
				var pop := create_tween()
				pop.tween_property(n, "scale", base_scale * CLEAR_POP_SCALE, CLEAR_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				pop.tween_property(n, "scale", base_scale * 0.1, CLEAR_TIME - CLEAR_POP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				pop.parallel().tween_property(n, "modulate:a", 0.0, CLEAR_TIME - CLEAR_POP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				any = true
	# (按需移除消除震动)
	if any:
		# 等消除特效炸裂完再返回(下落发生在消除之后); 棋子淡出 tween 在此期间并行跑完
		await get_tree().create_timer(ELIM_HOLD).timeout

## 某已存在特效棋子被触发时的几何表现: 行/列用 beam, 3x3/彩球用 explosion。
func _play_special_fx(pos: Vector2i, kind: int) -> void:
	var col: Color = _fx_color(board.grid[pos.y][pos.x])
	var c: Vector2 = _cell_center(pos.y, pos.x)
	match kind:
		ME.SP_LINE_H:
			Fx.spawn_line_blast(_cell_center(pos.y, 0), _cell_center(pos.y, board.width - 1), col)
		ME.SP_LINE_V:
			Fx.spawn_line_blast(_cell_center(0, pos.x), _cell_center(board.height - 1, pos.x), col)
		ME.SP_BOMB:
			Fx.spawn_local_burst(c, col, cell_size * 1.5)   # 3x3 范围内粒子爆裂, 不超实际清除边界
		ME.SP_COLORBOMB:
			Fx.spawn_explosion(c, col, 3.0)
		_:
			Fx.spawn_shatter(c, col)

func _clear_gem_node_at(row: int, col: int) -> void:
	var n: Sprite2D = _gem_nodes[row][col]
	_gem_nodes[row][col] = null
	if n != null and is_instance_valid(n):
		n.queue_free()

func _sync_visuals_to_board() -> void:
	if board == null:
		return
	_render_board(false)

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
	_check_settlement()
	if is_inside_tree():
		await get_tree().process_frame

func _fall_barrier_in_grid(grid_snapshot: Array, row: int, col: int) -> bool:
	if row < 0 or row >= grid_snapshot.size() or col < 0 or col >= grid_snapshot[row].size():
		return false
	return grid_snapshot[row][col] == ME.WALL or _layer_value(board.coat, row, col) > 0 or _layer_value(board.choco, row, col) > 0

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
	var travel_cells := maxf(1.5, float(spawn_count) + 0.5)
	return _cell_center(row, col) - Vector2(0.0, cell_size * travel_cells)

func _ordinary_refill_duration_for_positions(start_pos: Vector2, target: Vector2) -> float:
	return minf(_fall_duration_for_positions(start_pos, target), ORDINARY_REFILL_MAX_TIME)

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
			tween.tween_property(node, "position", center, _ordinary_refill_duration_for_positions(node.position, center))
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
				tween.tween_property(node, "position", target, _fall_duration_for_positions(node.position, target))
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
	var size := maxf(1.0, cell_size)
	var cells := maxf(1.0, start_pos.distance_to(target) / size)
	return FALL_TIME + maxf(0.0, cells - 1.0) * FALL_EXTRA_CELL_TIME

func _grid_has_wall(grid_data: Array) -> bool:
	for row in grid_data:
		for value in row:
			if int(value) == ME.WALL:
				return true
	return false

func _grid_has_fall_obstacle(grid_data: Array) -> bool:
	for row in range(grid_data.size()):
		for col in range(grid_data[row].size()):
			if _fall_barrier_in_grid(grid_data, row, col):
				return true
	return false

func _wall_refill_start_position(row: int, col: int, source_map: Array = []) -> Vector2:
	var source_col := _wall_slide_spawn_source_col(source_map, row, col)
	if source_col < 0:
		source_col = col
	return _cell_center(0, source_col) - Vector2(0.0, cell_size * float(row + 1.5))

func _wall_slide_target_has_fall_obstacle_above(grid_data: Array, row: int, col: int) -> bool:
	if row <= 0 or grid_data.is_empty() or col < 0 or col >= grid_data[0].size():
		return false
	for y in range(row):
		if _layer_value(board.cannon, y, col) > 0:
			continue
		if _fall_barrier_in_grid(grid_data, y, col):
			return true
	return false

func _wall_slide_target_has_wall_above(grid_data: Array, row: int, col: int) -> bool:
	return _wall_slide_target_has_fall_obstacle_above(grid_data, row, col)

func _wall_slide_path_points(start_pos: Vector2, target: Vector2) -> Array:
	var points := []
	var cur := start_pos
	var top_entry_y := board_origin.y + cell_size * 0.5
	if cur.y < top_entry_y - 0.5 and target.y >= top_entry_y:
		cur = Vector2(cur.x, top_entry_y)
		points.append(cur)
	var safety: int = board.width + board.height + 8
	while safety > 0 and cur.distance_to(target) > 0.5:
		safety -= 1
		var dx := target.x - cur.x
		var dy := target.y - cur.y
		var step_x := 0.0
		if absf(dx) > cell_size * 0.35 and dy > cell_size * 0.35:
			step_x = signf(dx) * minf(cell_size, absf(dx))
		var step_y := minf(cell_size, maxf(0.0, dy))
		if step_y <= 0.0 and absf(dx) > 0.5:
			step_x = signf(dx) * minf(cell_size, absf(dx))
		var next := cur + Vector2(step_x, step_y)
		if next.distance_to(target) < cell_size * 0.35:
			next = target
		points.append(next)
		cur = next
	if points.is_empty() or points[points.size() - 1] != target:
		points.append(target)
	return points

func _wall_slide_cell_path_points(start_pos: Vector2, cell_path: Array, target: Vector2) -> Array:
	if cell_path.is_empty():
		return _wall_slide_path_points(start_pos, target)
	var points := []
	for raw_cell in cell_path:
		var cell: Vector2i = raw_cell
		if cell.y < 0 or cell.x < 0:
			continue
		var point := _cell_center(cell.y, cell.x)
		if point.distance_to(start_pos) <= 0.5:
			continue
		if not points.is_empty() and point.distance_to(points[points.size() - 1]) <= 0.5:
			continue
		points.append(point)
	if points.is_empty() or points[points.size() - 1].distance_to(target) > 0.5:
		points.append(target)
	return points

func _wall_slide_position_at(start_pos: Vector2, points: Array, progress: float) -> Vector2:
	if points.is_empty():
		return start_pos
	var clamped := clampf(progress, 0.0, 1.0)
	var total := 0.0
	var prev := start_pos
	for raw_point in points:
		var point: Vector2 = raw_point
		total += prev.distance_to(point)
		prev = point
	if total <= 0.001:
		return points[points.size() - 1]
	var target_distance := total * clamped
	var traveled := 0.0
	prev = start_pos
	for raw_point in points:
		var point: Vector2 = raw_point
		var segment := prev.distance_to(point)
		if segment <= 0.001:
			prev = point
			continue
		if traveled + segment >= target_distance:
			var local_progress := clampf((target_distance - traveled) / segment, 0.0, 1.0)
			return prev.lerp(point, local_progress)
		traveled += segment
		prev = point
	return points[points.size() - 1]

func _wall_slide_duration_for_points(points: Array) -> float:
	if points.is_empty():
		return 0.0
	var steps := maxf(1.0, float(points.size()))
	return minf(FALL_TIME + maxf(0.0, steps - 1.0) * WALL_SLIDE_STEP_TIME, WALL_SLIDE_MAX_TIME)

func _tween_wall_slide_node(node: Sprite2D, target: Vector2, cell_path: Array = []) -> float:
	if node == null or not is_instance_valid(node) or node.position == target:
		return 0.0
	var start_pos := node.position
	var points := _wall_slide_cell_path_points(start_pos, cell_path, target)
	var total_time: float = _wall_slide_duration_for_points(points)
	if total_time <= 0.0:
		return 0.0
	var t := create_tween()
	var apply_position := func(progress: float) -> void:
		if node != null and is_instance_valid(node):
			node.position = _wall_slide_position_at(start_pos, points, progress)
	t.tween_method(apply_position, 0.0, 1.0, total_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return total_time

func _source_none() -> Vector2i:
	return Vector2i(-1, -1)

func _source_spawn(col: int) -> Vector2i:
	return Vector2i(col, -2)

func _wall_slide_path_rows(grid_snapshot: Array) -> Array:
	var rows := []
	for row in range(board.height):
		var out_row := []
		for col in range(board.width):
			if grid_snapshot[row][col] >= 0:
				out_row.append([Vector2i(col, row)])
			else:
				out_row.append([])
		rows.append(out_row)
	return rows

func _wall_slide_source_rows(grid_snapshot: Array) -> Array:
	var rows := []
	for row in range(board.height):
		var out_row := []
		for col in range(board.width):
			if grid_snapshot[row][col] >= 0:
				out_row.append(Vector2i(col, row))
			else:
				out_row.append(_source_none())
		rows.append(out_row)
	return rows

func _wall_slide_tracking_fixed_cell(grid_snapshot: Array, row: int, col: int) -> bool:
	return grid_snapshot[row][col] == ME.WALL or _layer_value(board.coat, row, col) > 0 or _layer_value(board.choco, row, col) > 0

func _wall_slide_tracking_empty_cell(grid_snapshot: Array, row: int, col: int) -> bool:
	if row < 0 or row >= board.height or col < 0 or col >= board.width:
		return false
	return grid_snapshot[row][col] == ME.EMPTY and not _wall_slide_tracking_fixed_cell(grid_snapshot, row, col)

func _wall_slide_tracking_movable_cell(grid_snapshot: Array, row: int, col: int) -> bool:
	if row < 0 or row >= board.height or col < 0 or col >= board.width:
		return false
	return grid_snapshot[row][col] >= 0 and not _wall_slide_tracking_fixed_cell(grid_snapshot, row, col)

func _wall_slide_tracking_blocked_above(grid_snapshot: Array, row: int, col: int) -> bool:
	if row <= 0 or col < 0 or col >= board.width:
		return false
	for y in range(row):
		if _layer_value(board.cannon, y, col) > 0:
			continue
		if _wall_slide_tracking_fixed_cell(grid_snapshot, y, col):
			return true
	return false

func _wall_slide_tracking_has_vertical_source_above(grid_snapshot: Array, row: int, col: int) -> bool:
	if row <= 0 or col < 0 or col >= board.width:
		return false
	for y in range(row - 1, -1, -1):
		if _wall_slide_tracking_fixed_cell(grid_snapshot, y, col):
			return false
		if _wall_slide_tracking_movable_cell(grid_snapshot, y, col):
			return true
	return false

func _move_wall_slide_tracking_cell(grid_snapshot: Array, source_map: Array, path_map: Array, from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	grid_snapshot[to_row][to_col] = grid_snapshot[from_row][from_col]
	grid_snapshot[from_row][from_col] = ME.EMPTY
	source_map[to_row][to_col] = source_map[from_row][from_col]
	source_map[from_row][from_col] = _source_none()
	var path: Array = path_map[from_row][from_col].duplicate()
	path.append(Vector2i(to_col, to_row))
	path_map[to_row][to_col] = path
	path_map[from_row][from_col] = []

func _try_fill_wall_slide_tracking_slot(grid_snapshot: Array, source_map: Array, path_map: Array, target_row: int, target_col: int) -> bool:
	if target_row <= 0 or not _wall_slide_tracking_empty_cell(grid_snapshot, target_row, target_col):
		return false
	var source_row := target_row - 1
	var candidates := [Vector2i(target_col, source_row)]
	if _wall_slide_tracking_blocked_above(grid_snapshot, target_row, target_col) and not _wall_slide_tracking_has_vertical_source_above(grid_snapshot, target_row, target_col):
		candidates.append(Vector2i(target_col + 1, source_row))
		candidates.append(Vector2i(target_col - 1, source_row))
	for p in candidates:
		if _wall_slide_tracking_movable_cell(grid_snapshot, p.y, p.x):
			_move_wall_slide_tracking_cell(grid_snapshot, source_map, path_map, p.y, p.x, target_row, target_col)
			return true
	return false

func _apply_wall_slide_tracking_gravity(grid_snapshot: Array, source_map: Array, path_map: Array) -> void:
	var moved := true
	var guard := 0
	var max_steps: int = maxi(1, board.height * board.width * 2)
	while moved and guard < max_steps:
		moved = false
		guard += 1
		for row in range(board.height - 1, 0, -1):
			for col in range(board.width):
				moved = _try_fill_wall_slide_tracking_slot(grid_snapshot, source_map, path_map, row, col) or moved

func _build_wall_slide_tracking_maps(before_grid: Array) -> Dictionary:
	var tracking_grid: Array = before_grid.duplicate(true)
	var source_map := _wall_slide_source_rows(tracking_grid)
	var path_map := _wall_slide_path_rows(tracking_grid)
	_apply_wall_slide_tracking_gravity(tracking_grid, source_map, path_map)
	if board.is_scrolling:
		return {"source": source_map, "path": path_map}
	var max_steps: int = maxi(1, board.height * board.width * 2)
	for _i in range(max_steps):
		_apply_wall_slide_tracking_gravity(tracking_grid, source_map, path_map)
		var spawned := false
		for col in range(board.width):
			if not _wall_slide_tracking_empty_cell(tracking_grid, 0, col):
				continue
			tracking_grid[0][col] = 0
			source_map[0][col] = _source_spawn(col)
			path_map[0][col] = [Vector2i(col, 0)]
			spawned = true
		if not spawned:
			_apply_wall_slide_tracking_gravity(tracking_grid, source_map, path_map)
			return {"source": source_map, "path": path_map}
	_apply_wall_slide_tracking_gravity(tracking_grid, source_map, path_map)
	return {"source": source_map, "path": path_map}

func _build_wall_slide_source_map(before_grid: Array) -> Array:
	return _build_wall_slide_tracking_maps(before_grid)["source"]

func _build_wall_slide_path_map(before_grid: Array) -> Array:
	return _build_wall_slide_tracking_maps(before_grid)["path"]

func _wall_slide_source_priority(row: int, col: int, target_row: int, target_col: int, allow_cross_column: bool) -> int:
	if row > target_row:
		return -1
	if col == target_col:
		return target_row - row
	if not allow_cross_column or row >= target_row:
		return -1
	if col == target_col + 1:
		return 1000 + target_row - row
	if col == target_col - 1:
		return 2000 + target_row - row
	return 3000 + absi(col - target_col) * 100 + target_row - row

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
	if source_map.is_empty() or row < 0 or row >= source_map.size():
		return -1
	if col < 0 or col >= source_map[row].size():
		return -1
	var source: Vector2i = source_map[row][col]
	if source.y != -2:
		return -1
	return source.x

func _wall_slide_target_path(path_map: Array, row: int, col: int) -> Array:
	if path_map.is_empty() or row < 0 or row >= path_map.size():
		return []
	if col < 0 or col >= path_map[row].size():
		return []
	return path_map[row][col]

func _wall_slide_visual_start_position(source_map: Array, path_map: Array, row: int, col: int) -> Vector2:
	if not source_map.is_empty() and row >= 0 and row < source_map.size() and col >= 0 and col < source_map[row].size():
		var source: Vector2i = source_map[row][col]
		if source.y >= 0 and source.x >= 0:
			return _cell_center(source.y, source.x)
		if source.y == -2:
			return _wall_refill_start_position(row, col, source_map)
	var path: Array = _wall_slide_target_path(path_map, row, col)
	if not path.is_empty():
		var first: Vector2i = path[0]
		if first.y >= 0 and first.x >= 0:
			return _cell_center(first.y, first.x)
	return _wall_refill_start_position(row, col, source_map)

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
				var node_time := _tween_wall_slide_node(node, target, _wall_slide_target_path(path_map, row, col))
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
