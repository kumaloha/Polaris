class_name LevelSkills
extends Node
## 技能栏子控制器（契约 A 消费者 + 契约 C 协作, docs/11 §2 / §4.7 / 附录A）。
##
## 从 level.gd 抽出技能栏簇：SKILLS 表、2 个龙头像按钮、冷却条、充能、置灰。
##
## 分工(§4.7)：本类管"栏"(按钮/冷却/充能/置灰)；PetCast 管"演出+落地"。
##   按钮 pressed → emit skill_pressed(idx) → level._on_skill_pressed(忙/结算闸门 + dispatch)。
##   状态闸门 _busy/_settled 只住 level(铁律1); 本类只读 board / 只渲染 skill_bar。
##
## 生命周期：作为 level 的子 Node(铁律2)。_pulse 的 tween 绑在按钮节点上(随 skill_bar 清理而死)。

const LevelLayout := preload("res://match3/level_layout.gd")
const DragonBreathVisual := preload("res://match3/pets/dragon_breath_visual.gd")

signal skill_pressed(idx: int)

# ── 技能表 ──
const SKILLS := [
	# gem: 该萌宠对应的宝石颜色(消该色宝石→给该萌宠加进度条), 决定冷却条颜色
	{"av": "res://assets/pets/dragon_baby/frames/dragon_00.png", "name": "小龙", "skill": "龙息大招", "gem": "red", "variant": "baby", "slot_index": 0, "flip_h": false},
	{"av": "res://assets/pets/dragon_youth/frames/frame_001.png", "name": "大龙", "skill": "龙息大招", "gem": "red", "variant": "youth", "slot_index": 1, "flip_h": true},
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
const MAGENTA_KEY_EPS := 0.08

# ── 注入上下文 ──
var _level = null   # level.gd 实例(读 live skill_bar/board + 共享 helper)

# ── 技能栏状态 ──
var _skill_charge := [0.0, 0.0]                 # 各技能当前充能数(消对应色宝石累加, 满=可用)
var _skill_btns: Array = []                     # TextureButton 引用(随 disabled/置灰)
var _skill_bar_fills: Array = []                # 冷却条填充 Panel 引用(随 ratio 改宽)
var _skill_bar_geo: Array = []                  # 每条 {center,w,h,inset,ih}: 改填充宽度复用
var _click_mask_cache: Dictionary = {}

func setup(level) -> void:
	_level = level

func _exit_tree() -> void:
	release_frame_cache()

func release_frame_cache() -> void:
	DragonBreathVisual.release_frame_cache()

func _process(_delta: float) -> void:
	DragonBreathVisual.process_preload_budget(3)

# ───────── 对外接口 ─────────

## 渲染技能栏(换关/重试)。在 skill_bar 上重建 2 个龙头像 + 冷却条 + 名字。
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
	_skill_charge = [0.0, 0.0]

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

## 施法动画占用该槽位时隐藏静态首帧, 退出后恢复为技能头像。
func set_slot_casting(idx: int, is_casting: bool) -> void:
	if idx < 0 or idx >= _skill_btns.size():
		return
	var btn = _skill_btns[idx]
	if btn == null or not is_instance_valid(btn) or not (btn is TextureButton):
		return
	var tex_btn := btn as TextureButton
	tex_btn.visible = true
	tex_btn.set_meta("slot_casting", is_casting)
	if is_casting:
		if tex_btn.texture_normal != null:
			tex_btn.set_meta("avatar_texture", tex_btn.texture_normal)
		tex_btn.texture_normal = null
	else:
		var tex = tex_btn.get_meta("avatar_texture", null)
		if tex is Texture2D:
			tex_btn.texture_normal = tex
		else:
			var path := String(tex_btn.get_meta("avatar_texture_path", SKILLS[idx].get("av", "")))
			tex_btn.texture_normal = _load_texture(path)
		tex_btn.modulate.a = 1.0 if _skill_ready(idx) else 0.82

# ───────── 技能栏渲染 ─────────

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
		_skill_button(String(sk["av"]), Vector2(cx, SKILL_AV_Y), SKILL_AV_W, i)
		DragonBreathVisual.request_variant_preload(String(sk.get("variant", "")))
		# 充能条(圆角胶囊): 颜色 = 该萌宠对应宝石色, 槽为其暗化版; 初始 ratio 按当前充能数。
		var gem_col: Color = GEM_COLORS.get(sk.get("gem", "purple"), Color(0.82, 0.45, 1.0))
		var track_col: Color = gem_col.darkened(0.72)
		track_col.a = 0.95
		var ratio0: float = clampf(_skill_charge[i] / SKILL_CHARGE_REQ, 0.0, 1.0)
		_cd_bar(i, Vector2(cx, SKILL_CD_Y + 4.0), SKILL_AV_W * 0.56, 18.0, ratio0, gem_col, track_col)
		_label(skill_bar, str(sk["name"]), Vector2(cx, SKILL_NAME_Y), 22, Color(1, 0.95, 0.8), SKILL_AV_W + 20)
		# v0.02: 去掉最下方技能解释文字(sk.skill)
	_update_skill_cd_visual()  # 同步初始置灰/宽度(重画 ui 后冷却态仍在时保持一致)

## 可点技能头像: TextureButton(品红抠像), 按可见宠物本体缩放, Control 左上角定位。
## 存进 _skill_btns 供 _process 置灰/禁用。pressed → emit skill_pressed(idx) 交 level。
func _skill_button(path: String, center: Vector2, width: float, idx: int) -> void:
	var skill_bar: CanvasLayer = _level.skill_bar
	var tex := _load_texture(path)
	if tex == null:
		_skill_btns.append(null)
		return
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.texture_click_mask = _texture_click_mask(tex)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var placement := _avatar_button_placement(tex, center, width, idx)
	btn.size = placement["size"]
	btn.position = placement["position"]
	btn.z_index = 2
	btn.material = _magenta_material()        # 品红抠像(与静态头像一致)
	if bool(SKILLS[idx].get("flip_h", false)):
		btn.pivot_offset = btn.size * 0.5
		btn.scale.x = -1.0
	btn.set_meta("avatar_texture_path", path)
	btn.set_meta("avatar_texture", tex)
	btn.pressed.connect(_on_skill_button_pressed.bind(idx))
	skill_bar.add_child(btn)
	_skill_btns.append(btn)

func _texture_click_mask(tex: Texture2D) -> BitMap:
	if tex == null:
		return null
	var key := tex.resource_path
	if key != "" and _click_mask_cache.has(key):
		return _click_mask_cache[key]
	var image := tex.get_image()
	if image == null or image.is_empty():
		return null
	image = image.duplicate()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a <= 0.08 or _is_magenta_key(c):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				image.set_pixel(x, y, Color(1, 1, 1, 1))
	var mask := BitMap.new()
	mask.create_from_image_alpha(image, 0.1)
	if key != "":
		_click_mask_cache[key] = mask
	return mask

func _is_magenta_key(c: Color) -> bool:
	return c.r >= 1.0 - MAGENTA_KEY_EPS and c.g <= MAGENTA_KEY_EPS and c.b >= 1.0 - MAGENTA_KEY_EPS

func _avatar_button_placement(tex: Texture2D, center: Vector2, fallback_width: float, idx: int) -> Dictionary:
	var sz: Vector2 = tex.get_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return {"size": Vector2(fallback_width, fallback_width), "position": center - Vector2(fallback_width, fallback_width) * 0.5}
	var variant := String(SKILLS[idx].get("variant", ""))
	if variant == "":
		var fallback_h := fallback_width * (sz.y / sz.x)
		var fallback_size := Vector2(fallback_width, fallback_h)
		return {"size": fallback_size, "position": center - fallback_size * 0.5}
	var cfg: Dictionary = DragonBreathVisual.variant_config(variant)
	var bbox: Rect2 = cfg["bbox"]
	var visible_w := _avatar_visible_width(variant)
	var scale := visible_w / maxf(1.0, bbox.size.x)
	var size := sz * scale
	var baseline_y := _dragon_avatar_baseline_y()
	var left := clampf(center.x - visible_w * 0.50, 20.0, DESIGN_W - visible_w - 12.0)
	var position_y := baseline_y - bbox.end.y * scale
	var position_x := left - bbox.position.x * scale
	if bool(SKILLS[idx].get("flip_h", false)):
		position_x = left - size.x + bbox.end.x * scale
	return {"size": size, "position": Vector2(position_x, position_y)}

func _avatar_visible_width(variant: String) -> float:
	var board = _level.board if _level != null else null
	var board_rect := Rect2()
	var book_rect := Rect2()
	if board != null:
		board_rect = Rect2(_level.board_origin, Vector2(float(board.width) * float(_level.cell_size), float(board.height) * float(_level.cell_size)))
		book_rect = LevelLayout.book_frame_rect(board.height, float(_level.cell_size), _level.board_origin)
	return DragonBreathVisual.visible_width_for_layout(variant, board_rect, book_rect)

func _dragon_avatar_baseline_y() -> float:
	return DragonBreathVisual.avatar_baseline_y()

# 按钮点击 → 转发给 level(忙/结算闸门 + PetCast dispatch 留在 level, 铁律1/§4.7)。
func _on_skill_button_pressed(idx: int) -> void:
	emit_signal("skill_pressed", idx)

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
		btn.modulate.a = 1.0 if ready else 0.82

func _skill_uses_charge(idx: int) -> bool:
	if idx < 0 or idx >= SKILLS.size():
		return false
	return true

func _skill_charge_ratio(idx: int) -> float:
	if idx < 0 or idx >= _skill_charge.size():
		return 0.0
	return clampf(_skill_charge[idx] / SKILL_CHARGE_REQ, 0.0, 1.0)

func _skill_clickable(idx: int) -> bool:
	if idx < 0 or idx >= SKILLS.size():
		return false
	var board = _level.board if _level != null else null
	return board != null and not board.is_over() and _skill_ready(idx)

func _skill_ready(idx: int) -> bool:
	if idx < 0 or idx >= SKILLS.size():
		return false
	return _skill_charge[idx] >= SKILL_CHARGE_REQ

func _pulse_skill_button(idx: int) -> void:
	if idx < 0 or idx >= _skill_btns.size():
		return
	var btn: Control = _skill_btns[idx]
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var base_scale: Vector2 = btn.scale
	var t: Tween = btn.create_tween()   # 绑按钮节点(铁律6): skill_bar 清理即死
	t.tween_property(btn, "scale", Vector2(base_scale.x * 1.08, base_scale.y * 1.08), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", base_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

# ───────── 共享渲染 helper 转发(实现留 level.gd) ─────────

func _clear_layer(layer: CanvasLayer) -> void:
	_level._clear_layer(layer)

func _label(layer: CanvasLayer, text: String, center: Vector2, font_size: int, color: Color, box_w: float, outline_size: int = 5, outline_color: Color = Color(0, 0, 0, 0.7)) -> Label:
	return _level._label(layer, text, center, font_size, color, box_w, outline_size, outline_color)

func _load_texture(path: String) -> Texture2D:
	return _level._load_texture(path)

func _magenta_material() -> ShaderMaterial:
	return _level._magenta_material()
