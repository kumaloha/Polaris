extends Node2D
# level.gd — 对局主场景（GAME_SPEC 新视图体系）。逻辑复用 core/board.gd + match_engine.gd。
#
# 当前布局：
#   顶部：透明源图裁剪后的关卡/步数/目标/星级 HUD。
#   中部：魔法书棋盘，可变尺寸，障碍和棋子按数据层增量同步。
#   底部：2 个龙宠技能头像 + 充能条。

# 契约D(P9) app 接线：有外部连接者(game_root)时结算交回壳层, 无连接者保持现行为(直接翻关)。
# game_root 鸭子调用 receive_session_config(config) 注入开局 + 连 session_ended 收结算。
signal session_ended(result: Dictionary)

const ME := preload("res://core/match_engine.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const ClearVisuals := preload("res://match3/clear_visuals.gd")
const LevelLayout := preload("res://match3/level_layout.gd")
const LevelMotion := preload("res://match3/level_motion.gd")
const PetCast := preload("res://match3/pets/pet_cast.gd")
const PetRegistry := preload("res://match3/pets/pet_registry.gd")

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
# v0.02: 各棋子图案占整图比例不同(PIL实测), 按 1/max(宽高占比) 补偿 scale, 统一视觉大小。
# species 顺序: 0红方块 1蓝水滴 2绿四叶 3金星 4紫月 5粉心
# 5合1 = 独立分层水晶球，不套普通阴影。(4合1 站立特效见下方 _start_combo_idle)
const COLORBOMB_INNER_LIGHT_NAME := "InnerLight"
# v0.02: 特殊棋子站立特效(替换旧 shine 静态光贴图) —— 姿态循环动画 + 本体高光。
# 消除方向=运动轴: 横=左右挤压摇头 / 纵=上下挤压点头 / 十字(SP_BOMB)=全向脉冲(最强)。
# 动画相对棋子"基础 scale"做乘法；十字只提亮棋子本体，不额外加外圈白光。
# 横/纵 挤压摇摆(单轴): 慢悠悠 idle, 相对 base 的幅度
# 十字(SP_BOMB): 心跳节奏(lub-dub-rest)。第一下更大, 第二下更小, 都是快起快落, 最后留休止。
# v0.02: 十字站立特效用「暖金提亮」(同点击选中 _select 的发光), 放大时亮、缩回原色。
# 横/纵: 方向性中性白高光(光在哪侧=朝哪侧转), 取代无方向感的整体提亮。
const BG_TEXTURE := "res://assets/level/background.png"  # v0.02 新天空背景(941×1672, 按宽铺满)
# UI 素材
const KEY_SHADER := "res://match3/magenta_key.gdshader"

# ── v0.02 顶部状态栏新素材(米黄风格, 设计稿换皮; 替换旧紫金分散顶栏) ──

# 关卡目标(占位) 与 技能(占位)

const DESIGN_W := LevelLayout.DESIGN_W
const DESIGN_H := 1520.0
const COLORBOMB_ABSORB_TARGET_BUDGET := 18
const COLORBOMB_FINE_CLEAR_BUDGET := 12
const COLORBOMB_CLEAR_FX_BATCH_SIZE := 6
const LINE_CLEAR_STAGGER := 0.026  # 横/竖炸路径碎裂按触发点向外错峰, 0.02s * 1.3
const BOARD_INPUT_BOTTOM_PAD_CELLS := 0.62  # 底行棋子/阴影可见下缘仍算底行点击, 防止落到宠物技能按钮

# ── 布局锚点（对齐参考图；截图后微调） ──

var board
var board_origin: Vector2
var cell_size: float = 0.0
var _levels_path: String = LevelLibrary.DEFAULT_LEVELS_PATH
var _levels: Array = []          # 当前生成关卡库的 levels 数组
var _playable: Array = []        # 可玩关索引(跳过 objectives 为空的关), 元素是 _levels 的下标
var _play_pos: int = 0           # 当前在 _playable 列表中的位置(翻关用)
var _level_idx: int = 0          # 当前 _levels 下标(=_playable[_play_pos])
var _settled := false            # 本关已结算(通关/失败), 锁输入直到点击下一关/重试
var _cur_cfg: Dictionary = {}    # 当前关顶部显示用 cfg(只含 id), HUD 刷新重画 ui_layer 时复用
# 棋子节点所有权迁至 board_view(契约 E)。外界经 board_view.node_at(cell) 访问。
var _sel := Vector2i(-1, -1)     # 选中坐标(输入路由用); 选中视觉在 board_view
var _hl_markers: Array = []
var _busy := false
var _level_generation: int = 0
var _key_mat: ShaderMaterial = null
var _time_rewind_cast_pending := false
var _active_cast: PetCast = null               # 当前在途宠物施法控制器(契约 C); 换关/退场时 cancel + free
# 契约D(P9): receive_session_config 注入的开局参数; load_level 后据此补步数。
var _session_extra_moves: int = 0              # loadout.extra_moves(独立运行=0)
var _session_pets: Array = []                  # 出战宠物注册表 key(空=skills 用默认 SKILLS)

@onready var background_layer: CanvasLayer = $BackgroundLayer
@onready var board_layer: CanvasLayer = $BoardLayer
@onready var gem_layer: CanvasLayer = $GemLayer
@onready var character_layer: CanvasLayer = $CharacterLayer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var skill_bar: CanvasLayer = $SkillBar

# ── 子控制器(契约 A/E 消费者 + P6 directors, 铁律2 挂 level 子树)。公开供测试经 level.hud / .skills / .board_view / .opening / .endgame 断言。──
const LevelHud := preload("res://match3/hud.gd")
const LevelSkills := preload("res://match3/skills.gd")
const BoardViewScript := preload("res://match3/board_view.gd")
const LevelOpeningScript := preload("res://match3/directors/opening.gd")
const LevelEndgameScript := preload("res://match3/directors/endgame.gd")
var hud: LevelHud = null
var skills: LevelSkills = null
var board_view: BoardView = null   # 契约 E: 棋子节点所有权 + 渲染 + 增量同步 + 墙滑视觉
var opening: LevelOpening = null    # P6: 开局掉落 + freeze reveal 演出
var endgame: LevelEndgame = null    # P6: 通关奖励连锁演出

# _init 在 .new()/instantiate 时即运行(早于 _ready), 保证不入树的测试也拿到 level.hud / level.skills / level.board_view / level.opening / level.endgame。
func _init() -> void:
	board_view = BoardViewScript.new()
	board_view.name = "BoardView"
	add_child(board_view)
	board_view.setup(self)
	hud = LevelHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(self)
	skills = LevelSkills.new()
	skills.name = "Skills"
	add_child(skills)
	skills.setup(self)
	skills.skill_pressed.connect(_on_skill_pressed)
	opening = LevelOpeningScript.new()
	opening.name = "Opening"
	add_child(opening)
	opening.setup(self)
	opening.opening_finished.connect(_on_opening_finished)
	endgame = LevelEndgameScript.new()
	endgame.name = "Endgame"
	add_child(endgame)
	endgame.setup(self)

func _ready() -> void:
	# 图层顺序：背景(0) < 棋盘格(2)/棋子(3) < 角色层(4) < UI(5) < 技能栏(6)
	character_layer.layer = 4
	board_layer.layer = 2
	gem_layer.layer = 3
	$FXLayer.layer = 4
	Fx.attach($FXLayer, gem_layer)  # 特效挂 FXLayer, 震动抖棋子层
	# 接当前生成关卡库。可用 --levels/--level-library 指向指定生成包。
	# 构建"可玩关索引"(跳过空 objectives 关, 避免空目标关进关即赢)。
	_levels_path = _levels_path_from_args(OS.get_cmdline_user_args())
	_levels = LevelLibrary.load_file(_levels_path)
	if _levels.is_empty():
		push_error("Level: generated level library is missing or empty: %s" % _levels_path)
		return
	_playable = []
	for i in range(_levels.size()):
		var objs = _levels[i].get("objectives", [])
		if objs is Array and not objs.is_empty():
			_playable.append(i)
	var launch_level_idx := _launch_level_idx_from_args(OS.get_cmdline_user_args(), _levels.size())
	_play_pos = 0
	_level_idx = _playable[0] if not _playable.is_empty() else 0
	if launch_level_idx >= 0 and (_playable.has(launch_level_idx) or _playable.is_empty()):
		_level_idx = launch_level_idx
		_play_pos = _playable.find(launch_level_idx) if not _playable.is_empty() else launch_level_idx
	load_level(_level_idx)

func _exit_tree() -> void:
	_level_generation += 1
	opening.kill_drop_tween()
	_cancel_active_cast()
	if skills != null:
		skills.release_frame_cache()

# P6: 开局演出收尾 → 释放输入锁(状态闸门只住 level, 铁律1)。
func _on_opening_finished() -> void:
	_busy = false

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

func _levels_path_from_args(args: Array) -> String:
	return LevelLibrary.levels_path_from_args(args)

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
	opening.kill_drop_tween()
	_cancel_active_cast()
	_level_generation += 1
	var generation := _level_generation
	# cfg 仅用于顶部标题"第 N 关"显示(生成库 level_id 不是展示序号 → 用关序号)。
	var cfg: Dictionary
	if _levels.is_empty():
		push_error("Level: cannot load level %d because the generated level library is empty: %s" % [idx, _levels_path])
		return
	if idx < 0 or idx >= _levels.size():
		push_error("Level: level index %d is outside generated library size %d" % [idx, _levels.size()])
		return
	board = LevelLibrary.to_board(_levels[idx])
	cfg = {"id": _display_level_number(idx)}
	board.skill = "timerewind"
	if _session_extra_moves > 0:
		board.moves_left += _session_extra_moves   # 契约D(P9): loadout.extra_moves 加进步数
	_sel = Vector2i(-1, -1)
	board_view.clear_selected()   # 旧选中节点引用随重建释放, 先清 board_view 侧引用
	_hl_markers = []
	_busy = true
	_settled = false
	skills.reset_charge()   # 新关重置技能充能
	_compute_layout()
	_render_background()
	board_view.rebuild(board, cell_size, board_origin, true)
	_render_chrome(cfg)
	opening.play_drop(generation)   # P6: 开局掉落+施石(收尾经 opening_finished 解锁 _busy)
	print("[阶段6] 关卡 #%d  %d×%d  cell=%d  目标=%s  步数=%d  合法移动=%s"
		% [cfg["id"], board.width, board.height, int(cell_size), str(board.objectives), board.moves_left, str(ME.has_legal_move(board.grid, board._layers()))])

func _compute_layout() -> void:
	# 预留边框外凸: 角花顶点离格角 = 紫条中线偏移 + 角花半径; 取与紫条厚度的较大值
	# v0.02: 棋盘落"书页内金线框"(book_frame 内边线), 与书页边缘留页边距(像书的正文区)。
	# v0.02: 书本左右贴屏幕边(满屏宽,间距0); playable 棋盘优先填满书内镶边宽度。
	var layout: Dictionary = LevelLayout.compute_layout(board.width, board.height)
	cell_size = float(layout["cell_size"])
	board_origin = layout["board_origin"]
	board_view.sync_geometry(board, cell_size, board_origin)   # board_view 渲染计算用自己的几何副本

func _cell_center(row: int, col: int) -> Vector2:
	return LevelLayout.cell_center(row, col, cell_size, board_origin)

func _pos_to_cell(p: Vector2) -> Vector2i:
	return LevelLayout.pos_to_cell(p, board.width, board.height, cell_size, board_origin)

func _board_input_rect() -> Rect2:
	if board == null or cell_size <= 0.0:
		return Rect2()
	return Rect2(
		board_origin,
		Vector2(float(board.width) * cell_size, float(board.height) * cell_size + cell_size * BOARD_INPUT_BOTTOM_PAD_CELLS)
	)

func _board_pointer_hit_cell(position: Vector2) -> Vector2i:
	if board == null or cell_size <= 0.0:
		return Vector2i(-1, -1)
	var strict_cell: Vector2i = _pos_to_cell(position)
	if strict_cell.x >= 0:
		return strict_cell
	if not _board_input_rect().has_point(position):
		return Vector2i(-1, -1)
	var col: int = int(floor((position.x - board_origin.x) / cell_size))
	if col < 0 or col >= board.width:
		return Vector2i(-1, -1)
	var board_bottom: float = board_origin.y + float(board.height) * cell_size
	var bottom_pad: float = cell_size * BOARD_INPUT_BOTTOM_PAD_CELLS
	if position.y < board_bottom or position.y > board_bottom + bottom_pad:
		return Vector2i(-1, -1)
	return Vector2i(col, board.height - 1)

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

# 棋盘整盘渲染 / 棋子节点创建 / 站立特效 / 增量同步 / 墙滑视觉 → board_view.gd(契约 E)。
# 开局掉落+施石 → directors/opening.gd; 通关奖励连锁 → directors/endgame.gd(P6)。
# 状态闸门 _busy/_level_generation 只住 level(铁律1); director 经信号/参数请求, 不写闸门。

# ───────── 整页 UI（对齐参考图） ─────────

# HUD/技能栏抽至 match3/hud.gd + match3/skills.gd(契约 A 消费者, docs/11 §2 / 附录A)。
# level 仅经子控制器编排, 状态闸门 _busy/_settled 仍只住 level(铁律1)。
func _render_chrome(cfg: Dictionary) -> void:
	_cur_cfg = cfg
	# v0.02: 设计稿为纯三消, 移除 Boss 对战区(狐狸/Boss/道具书)。score 计分逻辑不受影响。
	_clear_layer(skill_bar)
	hud.render_chrome(cfg)   # 清角色层 + ui_layer, 渲染顶栏
	skills.build()           # 技能栏(2 个龙头像 + 冷却条)

# 阶段6: 每步 resolve/swap 后刷新 HUD(目标卡进度 + 步数徽章)——只重画 ui_layer。
func _refresh_hud() -> void:
	hud.refresh()

func _display_moves_left() -> int:
	return hud.display_moves_left()

func _set_moves_display_override(value: int) -> void:
	hud.set_moves_display_override(value)

func _clear_moves_display_override() -> void:
	hud.clear_moves_display_override()


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
	cast.set_meta("skill_slot_index", idx)
	var skill_cfg: Dictionary = LevelSkills.SKILLS[idx]
	# 头像显隐/相框置顶 + 冷却刷新经 skills 子控制器(§4.7); 锁的读写仍只在 level 侧(铁律1)。
	cast.setup({
		"skill_bar": skill_bar,
		"board": board,
		"board_view": board_view,
		"cell_size": cell_size,
		"board_origin": board_origin,
		"cast_effect": cast_effect,
		"variant": String(skill_cfg.get("variant", "youth")),
		"slot_index": int(skill_cfg.get("slot_index", idx)),
		"flip_h": bool(skill_cfg.get("flip_h", false)),
		"load_texture": Callable(self, "_load_texture"),
		"account_clears": Callable(self, "_account_resolution_clears"),
		"refresh_skill_ui": Callable(skills, "refresh_visual"),
		"resolve_cascades": Callable(self, "_resolve_cascades"),
		"fx_color": Callable(self, "_fx_color"),
	})
	cast.cast_started.connect(_on_pet_cast_started)
	cast.cast_committed.connect(_on_pet_cast_committed)
	cast.cast_finished.connect(_on_pet_cast_finished.bind(cast))
	_active_cast = cast
	skills.set_slot_casting(idx, true)
	if not cast.start_cast():
		skills.set_slot_casting(idx, false)
		_cancel_active_cast()
		return false
	return true

func _on_pet_cast_started() -> void:
	# 施法全程锁盘(PB 修复语义): 演出+落地+归位整段禁止棋盘/键盘交互。
	_busy = true
	_time_rewind_cast_pending = true

func _on_pet_cast_committed() -> void:
	# 效果已落地(board 已 rewind), 同步棋盘视图 + HUD。
	# 直摸点#3(契约 E): 时兔 commit 重渲染改走 board_view.rebuild。
	_sel = Vector2i(-1, -1)
	board_view.clear_selected()
	_clear_highlights()
	board_view.rebuild(board)
	_refresh_hud()

func _on_pet_cast_finished(cast: PetCast) -> void:
	# 演出全部结束(含归位/取消) → 释放锁。
	# 技能栏静态头像显隐由 level 统一配对管理: start 前隐藏, finish/cancel 后恢复。
	var was_active := cast != null and cast == _active_cast
	_time_rewind_cast_pending = false
	if cast != null and is_instance_valid(cast):
		var slot_idx := int(cast.get_meta("skill_slot_index", -1))
		if slot_idx >= 0:
			skills.set_slot_casting(slot_idx, false)
	if was_active:
		_active_cast = null
	if cast != null and is_instance_valid(cast):
		cast.queue_free()
	if was_active:
		var settled_now: bool = await _check_settlement()
		if not settled_now:
			_busy = false
	else:
		_busy = false

# 取消在途施法并回收控制器(换关/退场)。幂等: 无在途施法时 no-op。
func _cancel_active_cast() -> void:
	_time_rewind_cast_pending = false
	var cast := _active_cast
	_active_cast = null
	if cast != null and is_instance_valid(cast):
		var slot_idx := int(cast.get_meta("skill_slot_index", -1))
		if slot_idx >= 0:
			skills.set_slot_casting(slot_idx, false)
		cast.cancel()
		cast.queue_free()

# ───────── 阶段6: 结算(通关/失败) ─────────

# 一步完整结算后判定: 赢→通关面板 / 输→失败面板。须在扣步+刷HUD之后调。
## 判定并进入结算。返回"是否已进入结算"——调用链据此跳过尾部解锁, 保住 _show_result 上的 _busy 锁。
func _check_settlement() -> bool:
	if _settled:
		return true
	if board.is_won():
		_settled = true
		_busy = true
		# P6: 奖励连锁演出经 endgame director; 刷 HUD + 弹结算面板(状态闸门/面板只住 level)留这。
		await endgame.run_win_bonus()
		_refresh_hud()
		_show_result(true)
		return true
	elif board.is_lost():
		_show_result(false)
		return true
	return false

# 程序绘制居中半透明遮罩 + 结算面板(标题 + 下一关/重试按钮)。无现成素材, 纯绘制。
# 锁输入(_settled=true), 按钮: 通关→下一关 / 失败→重试本关。
# 结算: 上状态闸门(铁律1只住 level) + 经 hud 渲染面板; 按钮回调 Callable 注入连回 level。
func _show_result(win: bool) -> void:
	_settled = true
	_busy = true
	hud.show_result(win, Callable(self, "_on_result_button"))

# 结算按钮点击: 有外部连接者(game_root)→交回壳层结算; 无连接者→保持现行为(直接翻关)。
# 契约D(P9): 用 session_ended.get_connections().is_empty() 判断是否独立运行。
func _on_result_button(win: bool) -> void:
	_settled = false
	_busy = false
	if not session_ended.get_connections().is_empty():
		session_ended.emit(_session_result(win))   # 壳层接管: bank_result + record_clear + 推关
		return
	if win:
		_goto_relative(1)   # 独立运行: 下一关(可玩关循环)
	else:
		load_level(_level_idx)   # 重试本关

# 契约D(P9): 组装 SessionResult = board 结算数据 + collected + level_index。字段与 bank_result 入参对齐。
func _session_result(win: bool) -> Dictionary:
	var result: Dictionary = board.result() if board != null else {"won": win}
	result["collected"] = board.collected.duplicate() if board != null else {}
	result["level_index"] = _level_idx
	result["level_coordinate"] = _display_level_number(_level_idx)
	result["assigned_instance_id"] = _current_instance_id()
	result["levels_path"] = _levels_path
	if board != null:
		result["move_limit"] = int(board.move_limit) + _session_extra_moves
		result["moves_used"] = max(0, int(result["move_limit"]) - int(board.moves_left))
		result["board_size"] = {"w": board.width, "h": board.height}
		result["colors"] = board.species.size()
		result["objectives"] = board.objectives.duplicate(true)
		result["objective_progress"] = _objective_progress_snapshot()
		result["mechanism_activation_rate"] = _objective_completion_rate(result["objective_progress"])
	return result

func _current_level_record() -> Dictionary:
	if not _levels.is_empty() and _level_idx >= 0 and _level_idx < _levels.size() and _levels[_level_idx] is Dictionary:
		return _levels[_level_idx]
	return {}

func _current_instance_id() -> String:
	var rec := _current_level_record()
	var direct := String(rec.get("level_id", rec.get("id", "")))
	if not direct.is_empty():
		return direct
	return "level_%03d_library_%d" % [_display_level_number(_level_idx), _level_idx]

func _objective_progress_snapshot() -> Array:
	var out: Array = []
	if board == null:
		return out
	for obj in board.objectives:
		if not (obj is Dictionary):
			continue
		var typ := String(obj.get("type", ""))
		var sp := int(obj.get("species", -1))
		var target := int(obj.get("target", 0))
		var current := 0
		match typ:
			"COLLECT":
				current = int(board.collected.get(sp, 0))
			"CLEAR_JELLY":
				current = int(board.jelly_cleared)
			"CLEAR_BLOCKER":
				current = int(board.blocker_cleared)
			"CLEAR_CHOCO":
				current = int(board.choco_cleared)
			"COLLECT_INGREDIENT":
				current = int(board.ingredient_collected)
			"DEFUSE_BOMB":
				current = int(board.bomb_defused)
			"POP_POPCORN":
				current = int(board.popcorn_hit)
			"DESTROY_CAKE":
				current = int(board.cake_destroyed)
			"REVEAL_MYSTERY":
				current = int(board.mystery_revealed)
			"SCORE":
				current = int(board.score)
			_:
				current = 0
		out.append({"type": typ, "species": sp, "current": current, "target": target})
	return out

func _objective_completion_rate(progress: Array) -> float:
	var current := 0.0
	var target := 0.0
	for item in progress:
		if item is Dictionary:
			current += float(item.get("current", 0.0))
			target += max(0.0, float(item.get("target", 0.0)))
	if target <= 0.0:
		return 1.0
	return clampf(current / target, 0.0, 1.0)

# 契约D(P9): game_root 鸭子调用注入开局配置。读 loadout.extra_moves 加步数、pets 交 skills(无则默认)。
# main_scene 不切——Level.tscn 仍可独立运行(无 config 时走现行为)。
func receive_session_config(config: Dictionary) -> void:
	var loadout: Dictionary = config.get("loadout", {})
	_session_extra_moves = int(loadout.get("extra_moves", 0))
	var pets = config.get("pets", [])
	_session_pets = pets.duplicate() if pets is Array else []
	var idx: int = int(config.get("level_index", _level_idx))
	load_level(idx)   # 重新载入指定关(load_level 据 _session_extra_moves 补步数)

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

func _clear_layer(layer: CanvasLayer) -> void:
	for ch in layer.get_children():
		ch.queue_free()

# ───────── 交互（阶段2） ─────────

func _input(event: InputEvent) -> void:
	if _handle_board_pointer_event(event):
		get_viewport().set_input_as_handled()


# 翻到相对当前的第 step 关(+1下一关/-1上一关), 在可玩关列表里循环。
func _goto_relative(step: int) -> void:
	if not _playable.is_empty():
		_play_pos = (_play_pos + step + _playable.size()) % _playable.size()
		_level_idx = _playable[_play_pos]
	else:
		var n: int = _levels.size()
		if n <= 0:
			push_error("Level: cannot switch levels because the generated level library is empty")
			return
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
		_handle_board_pointer_press(event.position)

func _handle_board_pointer_event(event: InputEvent) -> bool:
	if _busy or _settled or _time_rewind_cast_pending:
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return _handle_board_pointer_press(event.position)
	if event is InputEventScreenTouch and event.pressed:
		return _handle_board_pointer_press(event.position)
	return false

func _handle_board_pointer_press(position: Vector2) -> bool:
	if board == null or cell_size <= 0.0:
		return false
	var cell: Vector2i = _board_pointer_hit_cell(position)
	if cell.x < 0:
		return false
	_on_cell_clicked(cell)
	return true

func _on_cell_clicked(cell: Vector2i) -> void:
	if board_view.node_at(cell) == null:
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

# 选中坐标/路由住 level(铁律1); 选中视觉(放大提亮置顶/复原)经 board_view(契约 E)。
func _select(cell: Vector2i) -> void:
	_sel = cell
	board_view.set_selected(cell)

func _deselect() -> void:
	_sel = Vector2i(-1, -1)
	board_view.clear_selected()

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
	var na: Sprite2D = board_view.node_at(a)
	var nb: Sprite2D = board_view.node_at(b)
	var pa: Vector2 = _cell_center(a.y, a.x)
	var pb: Vector2 = _cell_center(b.y, b.x)
	await board_view.play_swap(na, nb, pa, pb)
	if not legal:
		await board_view.play_swap(na, nb, pb, pa)  # 非法换回
		_busy = false
		return
	_remember_time_rewind_snapshot()
	# 提交交换(数据 + 节点引用)
	ME._swap_cells(board.grid, a, b)
	ME._swap_cells(board.fx, a, b)
	board_view.swap_nodes(a, b)
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


func _account_resolution_clears(cells: Array) -> Dictionary:
	var acc: Dictionary = ME.account_clears(board.grid, cells, board.fx, board.rng, board.species, board._layers())
	board._accumulate(acc.get("by_species", {}))
	board._accumulate_progress(acc)
	return acc


func _filtered_clear_cells(cells: Array, acc: Dictionary) -> Array:
	var locked := {}
	for p in acc.get("locked", []):
		locked[p] = true
	var to_clear := []
	for p in cells:
		if not locked.has(p):
			to_clear.append(p)
	for bp in acc.get("cake_blast", []):
		to_clear.append(bp)
	return to_clear


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
	var acc: Dictionary = _account_resolution_clears(cells)
	board_view.refresh_jelly_coat_visuals()
	skills.charge(acc.get("by_species", {}))
	var to_clear: Array = _filtered_clear_cells(cells, acc)
	board._gain(ME.score_for_clear(to_clear.size(), 1))
	# 表现: 彩球吸收预览 + 对清除格放特效(限量精细, 避免一次太多卡顿)。
	await _play_colorbomb_absorb_preview(cb_pos, cells, virtual_fx.keys())
	var has_conversion := ClearVisuals.colorbomb_combo_has_conversion_phase(virtual_fx)
	await _show_colorbomb_virtual_conversion(virtual_fx)
	var fine_budget: int = COLORBOMB_FINE_CLEAR_BUDGET
	if has_conversion:
		await _play_colorbomb_combo_blast(cells, to_clear, virtual_fx)
	else:
		var fx_batch_count := 0
		for p in cells:
			if p == cb_pos:
				continue
			var spawned_fx := false
			var fk: int = board.fx[p.y][p.x]
			if fk != ME.SP_NONE:
				board_view.play_special_fx(p, fk)   # 卷入的条纹/十字/彩球放几何特效
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
		board_view.clear_node_at(p)
	await board_view.collapse_and_refill()
	var settle: Dictionary = await _resolve_cascades()   # 收尾连锁(下落后可能形成新匹配)
	var settled_now: bool = await _finish_consumed_move(int(acc.get("choco_cleared", 0)) + int(settle.get("choco_cleared", 0)), int(settle.get("cascades", 0)))
	if not settled_now:
		_busy = false


func _play_colorbomb_combo_blast(cells: Array, to_clear: Array, virtual_fx: Dictionary) -> void:
	var raw_special_fx_cells: Dictionary = _special_fx_cells_for_clear_visuals(cells, virtual_fx)
	var clear_visual_timing: Dictionary = _clear_visual_timing_for_triggers(virtual_fx.keys(), virtual_fx)
	var previous_fx: Dictionary = _apply_colorbomb_virtual_fx_for_blast(virtual_fx)
	await board_view.play_clear(to_clear, [], {}, raw_special_fx_cells, clear_visual_timing)
	_restore_colorbomb_virtual_fx_after_blast(previous_fx)


func _apply_colorbomb_virtual_fx_for_blast(virtual_fx: Dictionary) -> Dictionary:
	var previous := {}
	if board == null or board.fx.is_empty():
		return previous
	for raw_pos in virtual_fx:
		if not (raw_pos is Vector2i):
			continue
		var p: Vector2i = raw_pos
		if p.y < 0 or p.y >= board.fx.size() or p.x < 0 or p.x >= board.fx[p.y].size():
			continue
		previous[p] = board.fx[p.y][p.x]
		board.fx[p.y][p.x] = int(virtual_fx[p])
	return previous


func _restore_colorbomb_virtual_fx_after_blast(previous_fx: Dictionary) -> void:
	if board == null or board.fx.is_empty():
		return
	for raw_pos in previous_fx:
		if not (raw_pos is Vector2i):
			continue
		var p: Vector2i = raw_pos
		if p.y < 0 or p.y >= board.fx.size() or p.x < 0 or p.x >= board.fx[p.y].size():
			continue
		board.fx[p.y][p.x] = int(previous_fx[p])


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
		if board_view.node_at(p) == null:
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
	var root: Sprite2D = board_view.node_at(cb_pos)
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
		var n: Sprite2D = board_view.node_at(p)
		if n == null or not is_instance_valid(n):
			continue
		board_view.apply_fx_overlay(n, kind)
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
	var na: Sprite2D = board_view.node_at(a)
	var nb: Sprite2D = board_view.node_at(b)
	var pa: Vector2 = _cell_center(a.y, a.x)
	var pb: Vector2 = _cell_center(b.y, b.x)
	_remember_time_rewind_snapshot()
	await board_view.play_swap(na, nb, pa, pb)
	ME._swap_cells(board.grid, a, b)
	ME._swap_cells(board.fx, a, b)
	board_view.swap_nodes(a, b)
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
	var acc: Dictionary = _account_resolution_clears(cells)
	board_view.refresh_jelly_coat_visuals()
	skills.charge(acc.get("by_species", {}))
	var to_clear: Array = _filtered_clear_cells(cells, acc)
	board._gain(ME.score_for_clear(to_clear.size(), 1))
	_play_fusion_fx_after_swap(a, b, ka, kb)
	board.fx[a.y][a.x] = ME.SP_NONE
	board.fx[b.y][b.x] = ME.SP_NONE
	fusion_special_fx_cells.erase(a)
	fusion_special_fx_cells.erase(b)
	await board_view.play_clear(to_clear, [], {}, fusion_special_fx_cells, fusion_clear_timing)
	ME._apply_clears(board.grid, board.fx, to_clear, [])
	for p in to_clear:
		board_view.clear_node_at(p)
	await board_view.collapse_and_refill()
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
		board_view.play_special_fx(a_after, ka)
		board_view.play_special_fx(b_after, kb)
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


# 交换/回弹动画迁至 board_view.play_swap(契约 E)。

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
		var acc: Dictionary = _account_resolution_clears(to_clear)
		step_choco += int(acc.get("choco_cleared", 0))
		# 障碍底片(果冻/冰锁)视觉刷新不能早于 play_step：
		# account_clears 已把刚破掉的冰格置 EMPTY；若此处先删冰层，collapse/refill 前会露出裸空洞。
		# board_view.play_step 的 collapse/refill 收口会在补位后刷新 jelly/coat。
		# 计分: 锁住格(coat/choco/popcorn/mystery)不计入清除数, 与 board 直清路径同口径。
		to_clear = _filtered_clear_cells(to_clear, acc)
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
			"triggered_spawns": triggered_spawn_set,    # _apply_clears 用(spawn 格保留 species)
			"triggered_spawn_fx": triggered_spawn_fx,
			"account": acc,                             # account_clears 原样(9 计数器/by_species/locked/cake_blast)
			"score_gained": score_gained,
		}
		hud.on_step(report)                            # 目标进度/步数(读 report.account)
		skills.on_step(report)                         # by_species 充能(现 _charge_skills)
		# 唯一 await 点(契约A §2.3): board_view 播消除动画 + overlays 广播 + 落特效/清格节点同步 + 下落补充。
		await board_view.play_step(report, raw_special_fx_cells, clear_visual_timing)
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
	var before_ing: Array = board.ing.duplicate(true)
	var old_nodes: Array = board_view.snapshot_gem_nodes()
	board._settle_consumed_move(step_choco, cascades)
	if before_grid != board.grid or before_fx != board.fx or before_ing != board.ing:
		await board_view.animate_board_changes_from_snapshot(before_grid, old_nodes, before_ing)
	else:
		board_view.refresh_jelly_coat_visuals()
	_refresh_hud()
	skills.refresh_visual()
	var settled_now: bool = await _check_settlement()
	if is_inside_tree():
		await get_tree().process_frame
	return settled_now
