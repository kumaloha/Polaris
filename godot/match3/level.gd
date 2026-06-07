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
	"res://assets/gems/gem_ruby.png", "res://assets/gems/gem_water.png",
	"res://assets/gems/gem_clover.png", "res://assets/gems/gem_star.png",
	"res://assets/gems/gem_orb.png", "res://assets/gems/gem_heart.png",
]
# 特殊棋子(阶段5) shine 贴图：横/竖直线、3x3爆炸(叠在宝石上)。
# 彩球(SP_COLORBOMB)用专用整张贴图 extra.png(彩虹星河球)直接替换宝石，不叠 shine。
const SHINE_LINE_H := "res://assets/gems/shine/fx2_horizontal.png"
const SHINE_LINE_V := "res://assets/gems/shine/fx2_vertical.png"
const SHINE_BOMB := "res://assets/gems/shine/fx2_cross.png"
const EXTRA_TEXTURE := "res://assets/gems/colorbomb.png"  # 彩球(5连)专用贴图(透明底, 用户提供)
const FX_TEXTURES := {
	ME.SP_LINE_H: SHINE_LINE_H,
	ME.SP_LINE_V: SHINE_LINE_V,
	ME.SP_BOMB: SHINE_BOMB,
}
const CELL_TEXTURE := "res://assets/board/board_cell.png"
const BOARD_PANEL_TEXTURE := "res://assets/board/bg_board.png"
const BG_TEXTURE := "res://assets/ui/bg_scene.png"
const BARRIER_ICE_ICON := "res://assets/obstacles/ob_ice.png"  # synced from resources/barrier/ob_ice.png
const BARRIER_MARKER_NAME := "CoatBarrierSprite"
const BARRIER_FILL := 0.86
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
const FALL_TIME := 0.22
const ELIM_HOLD := 0.20  # 消除后停顿(等魔法特效炸裂完)再下落
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
const COLORBOMB_FILL := 0.66  # 彩球比普通宝石小一点, 四周留适度缝
const TRAY_TOP := 1236.0  # 技能栏顶(棋盘底锚定于此); 下移让棋盘整体下移, 露出更多角色
const SKILL_AV_Y := 1306.0
const SKILL_AV_W := 132.0
const SKILL_CD_Y := 1372.0
const SKILL_NAME_Y := 1404.0
const SKILL_SKILLNAME_Y := 1438.0

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
var _coat_nodes: Array = []
var _sel := Vector2i(-1, -1)
var _sel_node: Sprite2D = null  # 当前选中的棋子节点(放大提亮置顶)
var _sel_node_scale := Vector2.ONE
var _sel_node_mod := Color.WHITE
var _hl_markers: Array = []
var _busy := false
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

func load_level(idx: int) -> void:
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
	_busy = false
	_settled = false
	_skill_charge = [0.0, 0.0, 0.0, 0.0]   # 新关重置技能充能
	_compute_layout()
	_render_background()
	_render_board()
	_render_chrome(cfg)
	print("[阶段6] 关卡 #%d  %d×%d  cell=%d  目标=%s  步数=%d  合法移动=%s"
		% [cfg["id"], board.width, board.height, int(cell_size), str(board.objectives), board.moves_left, str(ME.has_legal_move(board.grid, board._layers()))])

func _compute_layout() -> void:
	# 预留边框外凸: 角花顶点离格角 = 紫条中线偏移 + 角花半径; 取与紫条厚度的较大值
	var frame_out: float = maxf(BAND_T, BAND_T * 0.5 + CORNER_DISPLAY * 0.5)
	var avail_w: float = DESIGN_W - 2.0 * BOARD_EDGE - 2.0 * frame_out
	cell_size = floor(avail_w / float(board.width))  # 占满屏宽(留边框+角花外凸)
	var board_w: float = board.width * cell_size
	var board_h: float = board.height * cell_size
	# 水平居中; 边框外缘底贴技能栏(消下方灰)
	var frame_bottom: float = TRAY_TOP - 6.0
	var y: float = frame_bottom - frame_out - board_h  # 按角花外凸锚定, 底部角花不被托盘切
	board_origin = Vector2((DESIGN_W - board_w) * 0.5, y)

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
	# 棋盘深紫实底,覆盖格区+边框区(盖住边框转角后面,避免露背景灰)
	var board_w: float = board.width * cell_size
	var board_h: float = board.height * cell_size
	var bg := ColorRect.new()
	bg.color = BOARD_BG_COLOR
	bg.position = board_origin - Vector2(BAND_T, BAND_T)
	bg.size = Vector2(board_w + BAND_T * 2.0, board_h + BAND_T * 2.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 棋盘实底,勿吞格点击(否则点棋盘无反应)
	board_layer.add_child(bg)

# 棋盘金边框：4 边(edge拉伸) + 4 角(corner翻转复用同一张)。在格子之上渲染。
func _render_board_frame() -> void:
	var bx: float = board_origin.x
	var by: float = board_origin.y
	var bw: float = board.width * cell_size
	var bh: float = board.height * cell_size
	# 紫条(横边正常,竖边旋转90°使光泽方向一致),中心在棋盘各边外侧 BAND_T/2 处
	_frame_strip(FRAME_BAND, Vector2(bx + bw * 0.5, by - BAND_T * 0.5), bw, BAND_T, false)
	_frame_strip(FRAME_BAND, Vector2(bx + bw * 0.5, by + bh + BAND_T * 0.5), bw, BAND_T, false)
	_frame_strip(FRAME_BAND, Vector2(bx - BAND_T * 0.5, by + bh * 0.5), bh, BAND_T, true)
	_frame_strip(FRAME_BAND, Vector2(bx + bw + BAND_T * 0.5, by + bh * 0.5), bh, BAND_T, true)
	# 金线(在紫条正中央,一条) —— 原样保留, 做边框
	_frame_strip(FRAME_LINE, Vector2(bx + bw * 0.5, by - BAND_T * 0.5), bw, LINE_T, false)
	_frame_strip(FRAME_LINE, Vector2(bx + bw * 0.5, by + bh + BAND_T * 0.5), bw, LINE_T, false)
	_frame_strip(FRAME_LINE, Vector2(bx - BAND_T * 0.5, by + bh * 0.5), bh, LINE_T, true)
	_frame_strip(FRAME_LINE, Vector2(bx + bw + BAND_T * 0.5, by + bh * 0.5), bh, LINE_T, true)
	# 四角紫钻小角花: 中心放在金线交叉点(紫条中线角), 使金线连到菱形宝石的顶点
	var hb: float = BAND_T * 0.5
	_frame_corner(Vector2(bx - hb, by - hb))
	_frame_corner(Vector2(bx + bw + hb, by - hb))
	_frame_corner(Vector2(bx - hb, by + bh + hb))
	_frame_corner(Vector2(bx + bw + hb, by + bh + hb))

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

func _render_board() -> void:
	_clear_layer(board_layer)
	_clear_layer(gem_layer)
	_coat_nodes = []
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
			var gnode: Sprite2D = _make_gem(board.grid[r][c], center)
			# 阶段5: 若该格已是特效棋子(交换后/续局), 叠 shine 标记
			if gnode != null and board.fx[r][c] != ME.SP_NONE:
				_apply_fx_overlay(gnode, board.fx[r][c])
			node_row.append(gnode)
		_gem_nodes.append(node_row)
	_render_coat_visuals()
	_render_board_frame()  # 金边框(最上层,盖格子边缘)

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
	marker.position = _cell_center(row, col)
	marker.scale = _fit_scale(tex, cell_size * BARRIER_FILL)
	marker.z_index = 8
	gem_layer.add_child(marker)
	return marker

## 阶段5: 给宝石节点叠/移 shine 子节点(命名"shine"), 标记其为特效棋子。
## 作为子 Sprite2D 居中铺满格, 父节点下落 tween 时自动跟随。kind==SP_NONE 则移除。
func _apply_fx_overlay(node: Sprite2D, kind: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	var old: Node = node.get_node_or_null("shine")
	if old != null:
		old.queue_free()
	# 彩球(5连): 整张换成 extra.png 彩虹球, 不叠 shine
	if kind == ME.SP_COLORBOMB:
		var et: Texture2D = load(EXTRA_TEXTURE)
		if et != null:
			node.texture = et
			node.scale = _fit_scale(et, cell_size * COLORBOMB_FILL)  # 比格子小一圈
		return
	if kind == ME.SP_NONE or not FX_TEXTURES.has(kind):
		return
	var path: String = FX_TEXTURES[kind]
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
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

# ───────── 整页 UI（对齐参考图） ─────────

func _render_chrome(cfg: Dictionary) -> void:
	_cur_cfg = cfg
	_clear_layer(character_layer)
	_clear_layer(ui_layer)
	_clear_layer(skill_bar)
	_render_characters()
	_render_ui_layer()
	_render_skillbar()

# 阶段6: ui_layer(顶栏+吊坠绳+目标卡+步数徽章+星级)整层重画。
# HUD 刷新只动 ui_layer(不重画角色/技能栏/棋盘), 目标进度/步数随每步更新。
func _render_ui_layer() -> void:
	_render_topbar(_cur_cfg)
	_render_title_connector()
	_render_objective_panel()
	_render_step_badge()
	_render_stars()

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
			return "果冻"
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
	# 深色托盘
	var tray := ColorRect.new()
	tray.color = Color(0.04, 0.02, 0.09, 0.92)
	tray.size = Vector2(DESIGN_W, DESIGN_H - TRAY_TOP)
	tray.position = Vector2(0, TRAY_TOP)
	skill_bar.add_child(tray)
	# 流光层: 金色柔和光带缓慢横向飘移(背景氛围光), 在托盘之上 / 头像之下
	var flow := ColorRect.new()
	flow.name = "FlowLight"
	flow.size = Vector2(DESIGN_W, DESIGN_H - TRAY_TOP)
	flow.position = Vector2(0, TRAY_TOP)
	var fm := ShaderMaterial.new()
	fm.shader = load(FLOW_SHADER)
	flow.material = fm
	skill_bar.add_child(flow)
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
		_label(skill_bar, str(sk["skill"]), Vector2(cx, SKILL_SKILLNAME_Y), 19, Color(0.85, 0.8, 0.95), SKILL_AV_W + 20)
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
	var mv: Array = ME.best_moves(board.grid, 1, board.coat, board.objectives)
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
		_show_result(true)
	elif board.is_lost():
		_show_result(false)

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
	await _resolve_cascades()
	# 阶段6: 合法交换并完成 resolve 后扣 1 步(非法换回不减, 上面已 return)。
	board.moves_left -= 1
	_refresh_hud()        # 重画目标卡进度 + 步数徽章
	_check_settlement()   # 通关/失败结算
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
	board.moves_left -= 1
	# 算账(在清空前读 species/fx): 目标计数 + 计分 + 技能充能。复用 board 累加逻辑。
	var acc: Dictionary = ME.account_clears(board.grid, cells, board.fx, board.rng, board.species, board._layers())
	board._accumulate(acc.get("by_species", {}))
	board._accumulate_progress(acc)
	_refresh_coat_visuals()
	_charge_skills(acc.get("by_species", {}))
	var locked := {}
	for p in acc.get("locked", []):
		locked[p] = true
	var scored: int = 0
	for p in cells:
		if not locked.has(p):
			scored += 1
	board._gain(ME.score_for_clear(scored, 1))
	# 表现: 彩球本体大爆发(白金) + 对清除格放特效(限量精细, 避免一次太多卡顿)。
	Fx.spawn_explosion(_cell_center(cb_pos.y, cb_pos.x), Color(1.0, 0.95, 0.7), 3.0)
	var fine_budget: int = 36   # 精细特效上限(超出只清不放, 防卡顿)
	for p in cells:
		if p == cb_pos:
			continue
		var fk: int = board.fx[p.y][p.x]
		var vk: int = int(virtual_fx.get(p, ME.SP_NONE))
		if fk != ME.SP_NONE:
			_play_special_fx(p, fk)   # 卷入的条纹/十字/彩球放几何特效
		elif vk != ME.SP_NONE:
			_play_special_fx(p, vk)   # 彩球+十字星/条纹: 目标色格按虚拟特效播同几何动画
		elif visual_species.has(p):
			Fx.spawn_shatter(_cell_center(p.y, p.x), _gem_raw_color(int(visual_species[p])))
		elif fine_budget > 0:
			var sp: int = board.grid[p.y][p.x]
			if sp >= 0 and sp < GEM_KEYS.size():
				Fx.spawn_elimination(GEM_KEYS[sp], _cell_center(p.y, p.x), cell_size * 0.72)
				fine_budget -= 1
	await get_tree().create_timer(0.30).timeout   # 让爆发可见
	# 清除: grid/fx 置空, 删节点。
	for p in cells:
		board.grid[p.y][p.x] = ME.EMPTY
		board.fx[p.y][p.x] = ME.SP_NONE
		var n: Sprite2D = _gem_nodes[p.y][p.x]
		if n != null and is_instance_valid(n):
			n.queue_free()
		_gem_nodes[p.y][p.x] = null
	await _collapse_and_refill()
	await _resolve_cascades()   # 收尾连锁(下落后可能形成新匹配)
	_refresh_hud()
	_check_settlement()
	_busy = false


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
		board.moves_left -= 1
		_refresh_hud()
		_check_settlement()
		_busy = false
		return
	var acc: Dictionary = ME.account_clears(board.grid, cells, board.fx, board.rng, board.species, board._layers())
	board._accumulate(acc.get("by_species", {}))
	board._accumulate_progress(acc)
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
	await _resolve_cascades()
	board.moves_left -= 1
	_refresh_hud()
	_check_settlement()
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
		Fx.spawn_explosion(_cell_center(a_after.y, a_after.x), _fx_color(board.grid[a_after.y][a_after.x]), 2.0)
		Fx.spawn_explosion(_cell_center(b_after.y, b_after.x), _fx_color(board.grid[b_after.y][b_after.x]), 2.0)


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
func _resolve_cascades() -> void:
	var guard: int = 0
	var cascade_level: int = 0   # 连锁级数(1起): 越深计分倍率越高, 与引擎 resolve 同口径
	while guard < 30:
		guard += 1
		var c: Dictionary = ME.collect_clears(board.grid, board.fx, board._layers())
		var to_clear: Array = c["to_clear"]
		var spawns: Array = c["spawns"]
		if to_clear.is_empty():
			break
		cascade_level += 1
		# spawn_set: 这些格变特效棋子(节点不删/不淡出, 只叠 shine)
		var spawn_set := {}
		for s in spawns:
			spawn_set[s["pos"]] = true
		# 阶段6: 目标计数(路线A 手动累加)。account_clears 须在 _apply_clears 之前调(要读未清空的 species),
		# 它会原地递减 board 的障碍层数组(经 _layers() 引用), 与 board.try_swap 路径同口径。
		# 严格复用 board 内部累加逻辑(_accumulate / _accumulate_progress), 字段名/key 类型完全一致, 杜绝分叉。
		var acc: Dictionary = ME.account_clears(board.grid, to_clear, board.fx, board.rng, board.species, board._layers())
		board._accumulate(acc.get("by_species", {}))   # collected[species] 累加(key=int)
		board._accumulate_progress(acc)                # 果冻/涂层/巧克力/炸弹/爆米花/蛋糕/神秘糖累加
		_refresh_coat_visuals()                       # 同步已破冰锁, 避免数据清了画面还在
		_charge_skills(acc.get("by_species", {}))      # 问题1: 消对应色宝石→技能充能
		# 计分: 锁住格(coat/choco/popcorn/mystery)不计入清除数, 与 board 直清路径同口径。
		var locked := {}
		for p in acc.get("locked", []):
			locked[p] = true
		var scored: int = 0
		for p in to_clear:
			if not locked.has(p):
				scored += 1
		board._gain(ME.score_for_clear(scored, cascade_level))
		await _play_clear(to_clear, spawns, spawn_set)
		# 引擎执行清除: spawn 格落特效(保留 species), 其余格 grid=EMPTY/fx=SP_NONE
		ME._apply_clears(board.grid, board.fx, to_clear, spawns)
		# 节点同步: 非 spawn 格删节点置 null; spawn 格给节点叠 shine(此时 board.fx 已是新 kind)
		for p in to_clear:
			if spawn_set.has(p):
				_apply_fx_overlay(_gem_nodes[p.y][p.x], board.fx[p.y][p.x])
			else:
				var n: Sprite2D = _gem_nodes[p.y][p.x]
				if n != null and is_instance_valid(n):
					n.queue_free()
				_gem_nodes[p.y][p.x] = null
		await _collapse_and_refill()

## 阶段5 消除表现: 遍历 to_clear——被触发的已存在特效格放对应 Fx; 普通格碎裂; 非 spawn 格淡出。
func _play_clear(to_clear: Array, spawns: Array, spawn_set: Dictionary) -> void:
	# 行/列横扫、十字星爆炸：路径棋子碎成触发特效的原色粒子，避免按各格颜色炸成彩虹。
	var visual_species: Dictionary = ClearVisuals.special_clear_species_overrides(board.grid, board.fx, to_clear, spawn_set)
	var t := create_tween().set_parallel(true)
	var any := false
	for p in to_clear:
		var fx_kind: int = board.fx[p.y][p.x]
		# 被卷入消除的【已存在】特效棋子(它不在本级 spawn_set): 放对应 Fx 表现
		if fx_kind != ME.SP_NONE and not spawn_set.has(p):
			_play_special_fx(p, fx_kind)
		else:
			var sp: int = board.grid[p.y][p.x]
			if sp >= 0 and sp < GEM_KEYS.size():
				if visual_species.has(p):
					# 横竖横扫/十字星: 不叠加三帧, 路径棋子碎成触发特效的纯色粒子
					Fx.spawn_shatter(_cell_center(p.y, p.x), _gem_raw_color(int(visual_species[p])))
				else:
					# 普通消除: 染色后的三帧基础爆炸特效(蓄力→炸裂→消散)
					Fx.spawn_elimination(GEM_KEYS[sp], _cell_center(p.y, p.x), cell_size * 0.72)
		# spawn 格不淡出(它要变特效棋子, 留住节点); 非 spawn 格缩放淡出
		if not spawn_set.has(p):
			var n: Sprite2D = _gem_nodes[p.y][p.x]
			if n != null and is_instance_valid(n):
				t.tween_property(n, "scale", n.scale * 0.1, CLEAR_TIME)
				t.tween_property(n, "modulate:a", 0.0, CLEAR_TIME)
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

## 每列下落填空 + 顶部补新棋子，节点 Tween 落入。
func _collapse_and_refill() -> void:
	var t := create_tween().set_parallel(true)
	var moved := false
	for col in range(board.width):
		var write: int = board.height - 1
		for row in range(board.height - 1, -1, -1):
			if board.grid[row][col] != ME.EMPTY:
				if row != write:
					board.grid[write][col] = board.grid[row][col]
					board.grid[row][col] = ME.EMPTY
					# 阶段5: fx 随 grid 同步搬运(特效棋子下落后标记不与真身错位)
					board.fx[write][col] = board.fx[row][col]
					board.fx[row][col] = ME.SP_NONE
					var n: Sprite2D = _gem_nodes[row][col]
					_gem_nodes[write][col] = n
					_gem_nodes[row][col] = null
					if n != null and is_instance_valid(n):
						t.tween_property(n, "position", _cell_center(write, col), FALL_TIME)
						moved = true
				write -= 1
		var spawn_i: int = 0
		for row in range(write, -1, -1):
			var sp: int = board.species[board.rng.randi() % board.species.size()]
			board.grid[row][col] = sp
			board.fx[row][col] = ME.SP_NONE  # 新补格无特效
			var center: Vector2 = _cell_center(row, col)
			var n: Sprite2D = _make_gem(sp, center)
			_gem_nodes[row][col] = n
			if n != null:
				n.position = center - Vector2(0, float(spawn_i + 1) * cell_size)
				t.tween_property(n, "position", center, FALL_TIME)
				moved = true
			spawn_i += 1
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
