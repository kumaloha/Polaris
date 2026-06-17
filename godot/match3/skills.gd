class_name LevelSkills
extends Node
## 技能栏子控制器（契约 A 消费者 + 契约 C 协作, docs/11 §2 / §4.7 / 附录A）。
##
## 从 level.gd 抽出技能栏簇：SKILLS 表、4 头像按钮、冷却条、充能、置灰、时兔头像隐藏/恢复。
## 行为零变化——按钮几何/充能逻辑/置灰规则原样平移自旧 level.gd。
##
## 分工(§4.7)：本类管"栏"(按钮/冷却/充能/置灰)；PetCast 管"演出+落地"。
##   按钮 pressed → emit skill_pressed(idx) → level._on_skill_pressed(忙/结算闸门 + dispatch)。
##   状态闸门 _busy/_settled 只住 level(铁律1); 本类只读 board / 只渲染 skill_bar。
##
## 生命周期：作为 level 的子 Node(铁律2)。_pulse 的 tween 绑在按钮节点上(随 skill_bar 清理而死)。

const LevelLayout := preload("res://match3/level_layout.gd")

signal skill_pressed(idx: int)

# ── 技能表(迁自 level.gd SKILLS) ──
const SKILLS := [
	# gem: 该萌宠对应的宝石颜色(消该色宝石→给该萌宠加进度条), 决定冷却条颜色
	{"av": "res://assets/pets/timerewind/rabbit_avatar.png", "name": "时兔", "skill": "时间回退", "gem": "purple"},
	{"av": "res://assets/avatars/av_raccoon_miner.png", "name": "矿工程", "skill": "破障", "gem": "blue"},
	{"av": "res://assets/pets/dragon_baby/frames/dragon_00.png", "name": "龙宝宝", "skill": "龙息大招", "gem": "red"},
	{"av": "res://assets/avatars/av_ladybug.png", "name": "瓢虫", "skill": "幸运祝福", "gem": "red"},
]

# ── 充能 / 槽位布局常量(迁自 level.gd) ──
const SKILL_CHARGE_REQ := 10.0                  # 满充能所需消除数(20 * 0.5)
const GEM_KEYS := ["red", "blue", "green", "gold", "purple", "pink"]  # species 顺序→宝石色
const GEM_COLORS := {
	# 从宝石贴图实采的主体色(高饱和中亮像素均值), 与宝石一致
	"red": Color(0.691, 0.108, 0.048), "blue": Color(0.052, 0.297, 0.789),
	"green": Color(0.373, 0.635, 0.045), "gold": Color(0.746, 0.426, 0.058),
	"purple": Color(0.326, 0.061, 0.728), "pink": Color(0.780, 0.120, 0.411),
}

const DESIGN_W := LevelLayout.DESIGN_W
const SKILL_AV_Y := LevelLayout.SKILL_AV_Y
const SKILL_AV_W := LevelLayout.SKILL_AV_W
const SKILL_CD_Y := 1440.0
const SKILL_NAME_Y := 1472.0

# ── 时兔头像槽相框常量(迁自 level.gd RABBIT_REWIND_AVATAR*; §4.7 与相框常量一起迁入 skills.gd) ──
const RABBIT_REWIND_AVATAR := "res://assets/pets/timerewind/rabbit_avatar.png"
const RABBIT_REWIND_AVATAR_FRAME := "res://assets/level/pet_avatar_frame.png"
const RABBIT_REWIND_AVATAR_FRAME_NODE := "TimeRabbitAvatarFrame"
const RABBIT_REWIND_AVATAR_FRAME_BG_NODE := "TimeRabbitAvatarFrameBg"
const RABBIT_REWIND_AVATAR_FRAME_BG_COLOR := Color(0.96, 0.84, 0.62, 0.48)
const RABBIT_REWIND_AVATAR_FRAME_BG_BACK_Z := 0
const RABBIT_REWIND_AVATAR_FRAME_Z := 200
const RABBIT_REWIND_AVATAR_FRAME_BG_COVER_Z := 230

# ── 注入上下文 ──
var _level = null   # level.gd 实例(读 live skill_bar/board + 共享 helper)

# ── 技能栏状态 ──
var _skill_charge := [0.0, 0.0, 0.0, 0.0]      # 各技能当前充能数(消对应色宝石累加, 满=可用)
var _skill_btns: Array = []                     # 4 个 TextureButton 引用(随 disabled/置灰)
var _skill_bar_fills: Array = []                # 4 个冷却条填充 Panel 引用(随 ratio 改宽)
var _skill_bar_geo: Array = []                  # 每条 {center,w,h,inset,ih}: 改填充宽度复用

func setup(level) -> void:
	_level = level

# ───────── 对外接口 ─────────

## 渲染技能栏(换关/重试)。在 skill_bar 上重建 4 头像 + 冷却条 + 名字 + 时兔相框。
func build() -> void:
	if _level == null:
		return
	_render_skillbar()

## 契约 A 消费者: 消对应色宝石→技能充能(现 _charge_skills 的 by_species 逻辑)。
func on_step(report: Dictionary) -> void:
	var account: Dictionary = report.get("account", {})
	_charge_skills(account.get("by_species", {}))

## 直接充能入口(彩球/融合等非级联路径用; 它们自带 acc, 不组装 StepReport)。
func charge(by_species: Dictionary) -> void:
	_charge_skills(by_species)

## 换关重置充能(level.load_level 调)。
func reset_charge() -> void:
	_skill_charge = [0.0, 0.0, 0.0, 0.0]

## 刷新冷却填充宽度 + 置灰(对外名)。
func refresh_visual() -> void:
	_update_skill_cd_visual()

# ── level._on_skill_pressed 查询/操作(状态闸门留 level, 这里只读充能+board) ──

func is_ready(idx: int) -> bool:
	return _skill_ready(idx)

func is_clickable(idx: int) -> bool:
	return _skill_clickable(idx)

func uses_charge(idx: int) -> bool:
	return _skill_uses_charge(idx)

func clear_charge(idx: int) -> void:
	if idx >= 0 and idx < _skill_charge.size():
		_skill_charge[idx] = 0.0

func pulse(idx: int) -> void:
	_pulse_skill_button(idx)

func set_time_rabbit_avatar_casting(is_casting: bool) -> void:
	_set_time_rabbit_avatar_casting(is_casting)

# ───────── 技能栏渲染(迁自 level.gd, 行为零变化) ─────────

func _render_skillbar() -> void:
	var skill_bar: CanvasLayer = _level.skill_bar
	# v0.02: 去掉底部宠物区的背景托盘 + 流光动效, 仅保留萌宠头像/技能。
	# 阶段7: 头像改 TextureButton(吃点击触发技能); 冷却条持有填充节点引用, 随 _process 改宽。
	_clear_layer(skill_bar)
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

## 可点技能头像: TextureButton(品红抠像), 按宽等比缩放, Control 左上角定位(中心-半尺寸)。
## 存进 _skill_btns 供 _process 置灰/禁用。pressed → emit skill_pressed(idx) 交 level。
func _skill_button(path: String, center: Vector2, width: float, idx: int) -> void:
	var skill_bar: CanvasLayer = _level.skill_bar
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
	btn.pressed.connect(_on_skill_button_pressed.bind(idx))
	skill_bar.add_child(btn)
	_skill_btns.append(btn)

# 按钮点击 → 转发给 level(忙/结算闸门 + PetCast dispatch 留在 level, 铁律1/§4.7)。
func _on_skill_button_pressed(idx: int) -> void:
	emit_signal("skill_pressed", idx)

func _skill_avatar_frame(center: Vector2, width: float) -> void:
	var skill_bar: CanvasLayer = _level.skill_bar
	var bg := Polygon2D.new()
	bg.name = RABBIT_REWIND_AVATAR_FRAME_BG_NODE
	bg.polygon = _ellipse_points(Vector2.ZERO, width * 0.44, width * 0.44, 56)
	bg.color = RABBIT_REWIND_AVATAR_FRAME_BG_COLOR
	bg.position = center
	bg.z_index = RABBIT_REWIND_AVATAR_FRAME_BG_BACK_Z
	skill_bar.add_child(bg)

	var frame_tex := _load_texture(RABBIT_REWIND_AVATAR_FRAME)
	if frame_tex == null:
		return
	var frame := Sprite2D.new()
	frame.name = RABBIT_REWIND_AVATAR_FRAME_NODE
	frame.texture = frame_tex
	frame.position = center
	frame.scale = _fit_scale(frame_tex, width * 1.12)
	frame.z_index = RABBIT_REWIND_AVATAR_FRAME_Z
	skill_bar.add_child(frame)

## 冷却条(圆角胶囊): 持有填充 Panel 引用(存 _skill_bar_fills), 记录几何供改宽。ratio 0..1。
func _cd_bar(idx: int, center: Vector2, w: float, h: float, ratio: float, fill_color: Color, bg_color: Color) -> void:
	var skill_bar: CanvasLayer = _level.skill_bar
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
	var board = _level.board if _level != null else null
	match String(SKILLS[idx].get("skill", "")):
		"时间回退":
			return board != null and board.skill == "timerewind" and not board.rewind_used and not _level._time_rewind_cast_pending and not board.is_over()
		_:
			return _skill_ready(idx)

func _skill_ready(idx: int) -> bool:
	if idx < 0 or idx >= SKILLS.size():
		return false
	var board = _level.board if _level != null else null
	match String(SKILLS[idx].get("skill", "")):
		"时间回退":
			return board != null and board.skill == "timerewind" and not board.rewind_used and not _level._time_rewind_cast_pending and not board.move_history.is_empty() and not board.is_over()
		_:
			return _skill_charge[idx] >= SKILL_CHARGE_REQ

func _pulse_skill_button(idx: int) -> void:
	if idx < 0 or idx >= _skill_btns.size():
		return
	var btn: Control = _skill_btns[idx]
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var t: Tween = btn.create_tween()   # 绑按钮节点(铁律6): skill_bar 清理即死
	t.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _time_rabbit_skill_button() -> TextureButton:
	if _skill_btns.is_empty():
		return null
	var btn = _skill_btns[0]
	if btn == null or not is_instance_valid(btn) or not (btn is TextureButton):
		return null
	return btn as TextureButton

# 底栏 slot 0 时兔头像按钮: 施法中隐藏贴图(让活体兔子演出代替), 结束复原。
# 仅管按钮(技能栏域, §4.7); 空框背景 frame_bg 的置顶由 TimeRabbitCast 处理(它持有 skill_bar)。
func _set_time_rabbit_avatar_casting(is_casting: bool) -> void:
	var btn := _time_rabbit_skill_button()
	if btn == null:
		return
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

# ───────── 共享渲染 helper 转发(实现留 level.gd) ─────────

func _clear_layer(layer: CanvasLayer) -> void:
	_level._clear_layer(layer)

func _label(layer: CanvasLayer, text: String, center: Vector2, font_size: int, color: Color, box_w: float, outline_size: int = 5, outline_color: Color = Color(0, 0, 0, 0.7)) -> Label:
	return _level._label(layer, text, center, font_size, color, box_w, outline_size, outline_color)

func _load_texture(path: String) -> Texture2D:
	return _level._load_texture(path)

func _magenta_material() -> ShaderMaterial:
	return _level._magenta_material()

func _fit_scale(tex: Texture2D, target: float) -> Vector2:
	return _level._fit_scale(tex, target)

func _ellipse_points(center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	return _level._ellipse_points(center, rx, ry, steps)
