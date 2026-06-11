class_name TimeRabbitCast
extends "res://match3/pets/pet_cast.gd"
## 时兔「时间回退」施法控制器（契约 C, docs/11 §4.4-4.5）。
##
## 数据(帧序列/锚点/时长/沙漏几何) + 特有钩子(沙漏/跳跃/眼线锚)。机制在 PetCast 基类。
## 行为零变化：所有帧序列/锚点/时长/z序原样平移自旧 level.gd 时兔簇
##   (K1 眼线锚、K2-K4 框沿锚、底边裁剪表、跳跃12段、沙漏、回袋对称等近期调好的细节一处不改)。
##
## 注入上下文(经 setup(): 禁止反摸 level 内部)：
##   skill_bar       — 演出节点(rig/沙漏/特效)的父层(CanvasLayer, 设计坐标空间)
##   board           — core/board.gd 实例(只读, 落地时调 skill_rewind())
##   cell_size / board_origin — 当前关布局(算施法/沙漏/特效锚点)
##   load_texture    — level._load_texture 的 Callable(共享纹理缓存)
##   set_avatar_casting — Callable(bool): level 侧切换底部头像按钮显隐 + 空框背景置顶
##   refresh_skill_ui   — Callable(): level._update_skill_cd_visual()(冷却/置灰)

const LevelLayout := preload("res://match3/level_layout.gd")

# ── 节点名 / 资源 / z 序（迁自 level.gd RABBIT_REWIND_*）──
const CAST_NODE := "TimeRabbitRewindCast"
const CAST_EFFECT_NODE := "TimeRewindCastEffect"
const FRAME_NODE := "RabbitFrame"
const HOURGLASS_NODE := "RabbitHourglass"
const AVATAR_FRAME_BG_NODE := "TimeRabbitAvatarFrameBg"
const AVATAR_FRAME_BG_BACK_Z := 0
const AVATAR_FRAME_BG_COVER_Z := 230
const CAST_Z := 240
const AVATAR := "res://assets/pets/timerewind/rabbit_avatar.png"
const K1 := "res://assets/pets/timerewind/rabbit_k1_peektop.png"
const K2 := "res://assets/pets/timerewind/rabbit_k2_peek.png"
const K25 := "res://assets/pets/timerewind/rabbit_k25_pushup.png"
const K3 := "res://assets/pets/timerewind/rabbit_k3_climb.png"
const K4 := "res://assets/pets/timerewind/rabbit_k4_crouch.png"
const K5 := "res://assets/pets/timerewind/rabbit_k5_leap.png"
const K55 := "res://assets/pets/timerewind/rabbit_k55_fall.png"
const K6 := "res://assets/pets/timerewind/rabbit_k6_idle.png"
const K7 := "res://assets/pets/timerewind/rabbit_k7_charge.png"
const K75 := "res://assets/pets/timerewind/rabbit_k75_castclosed.png"
const K8 := "res://assets/pets/timerewind/rabbit_k8_cast.png"
const HOURGLASS := "res://assets/pets/timerewind/rabbit_prop_hourglass.png"
const CAST_SEQUENCE := [K1, K2, K25, K3, K4, K5, K55, K6, K7, K75, K8]
const PEEK_SEQUENCE := [K1, K2, K25, K3, K4, K6]
const AVATAR_EYE_DISTANCE := 242.5
const FRAME_EYE_DISTANCE := {
	K1: 288.6,
	K2: 203.4,
	K25: 172.5,
	K3: 182.4,
	K4: 157.7,
	K5: 176.1,
	K55: 149.3,
	K6: 147.9,
	K8: 195.2,
}
const FRAME_FIXED_WIDTH := {
	K7: 116.0,
	K75: 119.0,
}
const HOME_W := 138.0
const PEEK_W := 172.0
const LEAP_W := 232.0
const CAST_W := 220.0
const CAST_MIN_W := 96.0
const CAST_VISIBLE_ASPECT := 1191.0 / 908.0
const FRAME_BOTTOM_CROP := {
	K1: 22.0,
	K2: 24.0,
	K25: 18.0,
}
const FIRST_PEEK_Y_OFFSET := -24.0
const CAST_TOP_GAP := 8.0
const CAST_AVATAR_GAP := 18.0
const CAST_GAP_BIAS := 36.0
const HOURGLASS_W := 44.0
const HOURGLASS_OFFSET := Vector2(28.0, -86.0)
const HOURGLASS_BOARD_Y := 0.24
const HOURGLASS_FLOAT_SCALE := 1.5
const TIME_SCALE := 2.75
const CAST_HOLD := 0.82

# ── 倒流棋盘特效（迁自 level.gd TIME_REWIND_*）──
const RING_STEPS := 64
const FLASH_COLOR := Color(0.52, 0.84, 1.0, 0.38)
const RING_COLOR := Color(0.56, 0.88, 1.0, 0.82)
const EFFECT_TIME := 0.58

# ── 头像槽布局（迁自 level.gd 的 SKILL_AV_* / DESIGN_W；时兔在 slot 0）──
const DESIGN_W := LevelLayout.DESIGN_W
const SKILL_AV_Y := LevelLayout.SKILL_AV_Y
const SKILL_AV_W := LevelLayout.SKILL_AV_W
const SLOT_COUNT := 4   # 底栏 4 个宠物槽(时兔占 slot 0)

# ── 注入上下文 ──
var skill_bar: CanvasLayer = null
var board = null
var cell_size: float = 0.0
var board_origin: Vector2 = Vector2.ZERO
var _load_texture_cb: Callable = Callable()
var _set_avatar_casting_cb: Callable = Callable()
var _refresh_skill_ui_cb: Callable = Callable()

# 是否播完整施法特效(true=点亮可用; false=未充满的点击反馈 peek)。
var _cast_effect: bool = true

## 注入 level 上下文。必须在 add_child + start_cast 之前调用。
func setup(ctx: Dictionary) -> void:
	skill_bar = ctx.get("skill_bar", null)
	board = ctx.get("board", null)
	cell_size = float(ctx.get("cell_size", 0.0))
	board_origin = ctx.get("board_origin", Vector2.ZERO)
	_load_texture_cb = ctx.get("load_texture", Callable())
	_set_avatar_casting_cb = ctx.get("set_avatar_casting", Callable())
	_refresh_skill_ui_cb = ctx.get("refresh_skill_ui", Callable())
	_cast_effect = bool(ctx.get("cast_effect", true))

# ───────── PetCast 钩子实现 ─────────

func _can_cast() -> bool:
	if board == null:
		return false
	if board.skill != "timerewind":
		board.skill = "timerewind"
	# peek(反馈)路径无需历史; 完整施法需有可回退历史且未用过。
	if not _cast_effect:
		return true
	return not board.rewind_used and not board.move_history.is_empty()

func _build_visuals() -> void:
	if skill_bar == null:
		return
	var old := skill_bar.get_node_or_null(CAST_NODE)
	if old != null:
		old.name = "%sOld" % CAST_NODE
		_detach_and_free_later(old)
	var old_hourglass := skill_bar.get_node_or_null(HOURGLASS_NODE)
	if old_hourglass != null:
		_detach_and_free_later(old_hourglass)
	_set_avatar_casting(true)
	var rig := Node2D.new()
	rig.name = CAST_NODE
	rig.z_index = CAST_Z
	rig.position = _home_anchor()
	var sequence: Array = CAST_SEQUENCE if _cast_effect else PEEK_SEQUENCE
	rig.set_meta("frame_sequence", PackedStringArray(sequence))
	skill_bar.add_child(rig)
	var rabbit := _make_avatar_sprite(FRAME_NODE, SKILL_AV_W)
	rabbit.z_index = 2
	rig.add_child(rabbit)
	var hourglass := _make_prop_sprite(HOURGLASS_NODE, HOURGLASS, HOURGLASS_W)
	hourglass.position = _cast_anchor() + HOURGLASS_OFFSET
	hourglass.modulate.a = 0.0
	hourglass.visible = false
	hourglass.z_index = 260
	hourglass.set_meta("base_scale", hourglass.scale)
	skill_bar.add_child(hourglass)

func _run_cast(t: Tween) -> void:
	if skill_bar == null:
		return
	var rig := skill_bar.get_node_or_null(CAST_NODE) as Node2D
	var hourglass := skill_bar.get_node_or_null(HOURGLASS_NODE) as Sprite2D
	if rig == null:
		return
	var rabbit := rig.get_node_or_null(FRAME_NODE) as Sprite2D
	if rabbit == null:
		return
	_build_cast_tween(t, rig, rabbit, hourglass, _cast_effect)

func _apply_effect() -> bool:
	var did := false
	if board != null:
		did = board.skill_rewind()
	if did:
		_spawn_cast_effect()
	return did

func _restore_avatar() -> void:
	# 顺序与旧 _retire_time_rabbit_rig 一致: 先刷技能栏冷却/置灰(可能把按钮压到 0.82),
	# 再复原头像(末尾 _set_avatar_casting 把按钮 modulate.a 拉回 1.0) —— 收尾后头像总是满亮。
	if not _refresh_skill_ui_cb.is_null():
		_refresh_skill_ui_cb.call()
	_set_avatar_casting(false)

# 取消/兜底全量清：rig + 沙漏 + 倒流棋盘特效一起回收(换关时不留残影)。
func _dispose_visuals() -> void:
	_dispose_rig_and_prop()
	var effect := skill_bar.get_node_or_null(CAST_EFFECT_NODE) if skill_bar != null else null
	if effect != null:
		_detach_and_free_later(effect)

# ───────── 头像切换 / 节点回收 ─────────

func _set_avatar_casting(is_casting: bool) -> void:
	if not _set_avatar_casting_cb.is_null():
		_set_avatar_casting_cb.call(is_casting)
	var frame_bg := skill_bar.get_node_or_null(AVATAR_FRAME_BG_NODE) if skill_bar != null else null
	if frame_bg is CanvasItem:
		(frame_bg as CanvasItem).z_index = AVATAR_FRAME_BG_COVER_Z if is_casting else AVATAR_FRAME_BG_BACK_Z

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

# ───────── 演出收尾（旧 _retire_time_rabbit_rig 语义：复原头像 + 回收 rig/沙漏 + 发收尾信号）─────────
# 正常收尾只回收 rig/沙漏；倒流特效自带 0.58s 退场 tween 自行 free(旧 _retire 也不动它), 换关取消才连它一起清。

func _finish() -> void:
	if _finished_emitted:
		return
	_restore_avatar()
	_dispose_rig_and_prop()
	_state = State.RETIRED
	_finished_emitted = true
	emit_signal("cast_finished")

func _dispose_rig_and_prop() -> void:
	if skill_bar == null:
		return
	var rig := skill_bar.get_node_or_null(CAST_NODE)
	if rig is CanvasItem:
		(rig as CanvasItem).visible = false   # 防最后一帧残留
	var hourglass := skill_bar.get_node_or_null(HOURGLASS_NODE)
	if hourglass != null:
		_detach_and_free_later(hourglass)
	if rig != null:
		_detach_and_free_later(rig)

# ───────── 纹理 / 精灵工厂（迁自 level.gd）─────────

func _load_texture(path: String) -> Texture2D:
	if not _load_texture_cb.is_null():
		return _load_texture_cb.call(path) as Texture2D
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

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

func _make_avatar_sprite(node_name: String, width: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	_set_avatar_frame(sprite, width)
	return sprite

func _make_prop_sprite(node_name: String, path: String, width: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	var tex := _load_texture(path)
	if tex != null:
		sprite.texture = tex
		sprite.scale = _scale_to_width(tex, width)
	return sprite

func _set_frame(sprite: Sprite2D, path: String, width: float, flip_h: bool = false) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var tex := _load_texture(path)
	if tex == null:
		return
	sprite.texture = tex
	var display_size := tex.get_size()
	var bottom_crop := float(FRAME_BOTTOM_CROP.get(path, 0.0))
	if bottom_crop > 0.0 and bottom_crop < display_size.y:
		display_size.y -= bottom_crop
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, display_size)
	else:
		sprite.region_enabled = false
		sprite.region_rect = Rect2(Vector2.ZERO, display_size)
	sprite.scale = _scale_to_width(tex, _frame_width(path, width))
	var display_h: float = display_size.y * sprite.scale.y
	sprite.position = Vector2(0.0, -display_h * 0.5)
	sprite.flip_h = flip_h
	sprite.set_meta("anchor", "bottom")

func _target_eye_distance() -> float:
	var tex := _load_texture(AVATAR)
	if tex == null:
		return AVATAR_EYE_DISTANCE * (SKILL_AV_W / 1254.0)
	var sz := tex.get_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return AVATAR_EYE_DISTANCE * (SKILL_AV_W / 1254.0)
	return AVATAR_EYE_DISTANCE * (SKILL_AV_W / maxf(sz.x, sz.y))

func _frame_width(path: String, width: float) -> float:
	var source_eye := float(FRAME_EYE_DISTANCE.get(path, 0.0))
	if source_eye > 0.0:
		var tex := _load_texture(path)
		if tex != null and tex.get_size().x > 0.0:
			return minf(tex.get_size().x * (_target_eye_distance() / source_eye), width)
	if FRAME_FIXED_WIDTH.has(path):
		return minf(float(FRAME_FIXED_WIDTH[path]), width)
	return width

func _set_avatar_frame(sprite: Sprite2D, width: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var tex := _load_texture(AVATAR)
	if tex == null:
		return
	sprite.texture = tex
	sprite.region_enabled = false
	sprite.region_rect = Rect2(Vector2.ZERO, tex.get_size())
	sprite.scale = _fit_scale(tex, width)
	sprite.position = Vector2.ZERO
	sprite.flip_h = false
	sprite.rotation = 0.0
	sprite.modulate.a = 1.0
	sprite.set_meta("anchor", "center")

# ───────── 锚点几何（迁自 level.gd）─────────

func _home_anchor() -> Vector2:
	return Vector2(DESIGN_W * 0.5 / float(SLOT_COUNT), SKILL_AV_Y)

func _avatar_frame_bottom_offset() -> float:
	return SKILL_AV_W * 0.5

func _avatar_frame_bottom_anchor() -> Vector2:
	return _home_anchor() + Vector2(0.0, _avatar_frame_bottom_offset())

func _first_peek_anchor() -> Vector2:
	return _home_anchor() + Vector2(0.0, FIRST_PEEK_Y_OFFSET)

func _book_frame_rect() -> Rect2:
	return LevelLayout.book_frame_rect(board.height, cell_size, board_origin)

func _current_board_rect() -> Rect2:
	if board == null:
		return Rect2(Vector2(DESIGN_W * 0.18, 1520.0 * 0.36), Vector2(DESIGN_W * 0.64, 1520.0 * 0.32))
	return Rect2(board_origin, Vector2(float(board.width) * cell_size, float(board.height) * cell_size))

func _cast_anchor() -> Vector2:
	var home := _home_anchor()
	if board != null:
		var book_rect := _book_frame_rect()
		var board_rect := _current_board_rect()
		var avatar_top := SKILL_AV_Y - SKILL_AV_W * 0.5
		var min_y := maxf(
			book_rect.end.y + 28.0,
			board_rect.end.y + 8.0 + CAST_MIN_W * CAST_VISIBLE_ASPECT + CAST_TOP_GAP
		)
		var max_y := avatar_top - CAST_AVATAR_GAP
		var desired_y := (book_rect.end.y + avatar_top) * 0.5 + CAST_GAP_BIAS
		var cast_y := max_y if max_y < min_y else clampf(maxf(desired_y, min_y), min_y, max_y)
		return Vector2(book_rect.get_center().x, cast_y)
	return home + Vector2(0.0, -150.0)

func _cast_width() -> float:
	if board == null:
		return CAST_W
	var cast := _cast_anchor()
	var board_rect := _current_board_rect()
	var cast_bottom := cast.y - 8.0
	var available_h: float = cast_bottom - board_rect.end.y - CAST_TOP_GAP
	var safe_w: float = available_h / CAST_VISIBLE_ASPECT
	return clampf(safe_w, CAST_MIN_W, CAST_W)

func _leap_width(cast_w: float) -> float:
	var crouch_w := _frame_width(K4, PEEK_W)
	var leap_w := _frame_width(K5, LEAP_W)
	return minf(LEAP_W, maxf(maxf(crouch_w, leap_w), cast_w * 1.18))

func _effect_anchor() -> Vector2:
	return _current_board_rect().get_center()

func _rewind_time(seconds: float) -> float:
	return seconds * TIME_SCALE

func _jump_points(home: Vector2, cast: Vector2) -> Array:
	var start := home + Vector2(0.0, _avatar_frame_bottom_offset() - 24.0)
	var control := Vector2(lerpf(home.x, cast.x, 0.42), minf(home.y, cast.y) - 170.0)
	var points := []
	for t in [0.0, 0.08, 0.16, 0.24, 0.32, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 1.0]:
		var k := float(t)
		var u := 1.0 - k
		points.append(start * (u * u) + control * (2.0 * u * k) + cast * (k * k))
	return points

func _jump_durations() -> Array:
	return [0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06]

func _hourglass_float_anchor(cast: Vector2) -> Vector2:
	if board == null:
		return cast + Vector2(0.0, -170.0)
	var board_rect := _current_board_rect()
	return Vector2(board_rect.get_center().x, board_rect.position.y + board_rect.size.y * HOURGLASS_BOARD_Y)

# ───────── 主时间线编排（迁自 _start_time_rabbit_tween, 帧序列一处不改）─────────

func _build_cast_tween(t: Tween, rig: Node2D, rabbit: Sprite2D, hourglass: Sprite2D, cast_effect: bool) -> void:
	var home := _home_anchor()
	var cast := _cast_anchor()
	var cast_w := _cast_width()
	var leap_w := _leap_width(cast_w)
	var emerge_bottom := _avatar_frame_bottom_anchor()
	var first_peek := _first_peek_anchor()
	t.tween_interval(_rewind_time(0.08))
	_queue_frame(t, rig, rabbit, K1, HOME_W, first_peek, _rewind_time(0.06))
	_queue_frame(t, rig, rabbit, K2, PEEK_W, emerge_bottom, _rewind_time(0.08))
	_queue_frame(t, rig, rabbit, K25, PEEK_W, emerge_bottom, _rewind_time(0.08))
	_queue_frame(t, rig, rabbit, K3, PEEK_W, emerge_bottom, _rewind_time(0.08))
	_queue_frame(t, rig, rabbit, K4, PEEK_W, emerge_bottom, _rewind_time(0.08))
	if cast_effect:
		_queue_jump(t, rig, rabbit, home, cast, leap_w, cast_w)
		t.tween_callback(Callable(self, "_show_hourglass").bind(hourglass))
		t.tween_property(hourglass, "modulate:a", 0.96, _rewind_time(0.20)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(hourglass, "position", _hourglass_float_anchor(cast), _rewind_time(0.20)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(hourglass, "scale", hourglass.scale * HOURGLASS_FLOAT_SCALE, _rewind_time(0.20)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_queue_frame(t, rig, rabbit, K7, cast_w, cast, _rewind_time(0.11))
		_queue_frame(t, rig, rabbit, K75, cast_w, cast + Vector2(0.0, -4.0), _rewind_time(0.12))
		t.parallel().tween_property(hourglass, "rotation", TAU, _rewind_time(0.30)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_queue_frame(t, rig, rabbit, K8, cast_w, cast + Vector2(0.0, -8.0), _rewind_time(0.20))
		t.tween_interval(CAST_HOLD)
		t.tween_callback(Callable(self, "_commit"))
		t.tween_property(hourglass, "modulate:a", 0.0, _rewind_time(0.18))
		_queue_frame(t, rig, rabbit, K55, leap_w, home + Vector2(0.0, -118.0), _rewind_time(0.14), true)
		_queue_frame(t, rig, rabbit, K5, leap_w, home + Vector2(0.0, -72.0), _rewind_time(0.14), true)
	else:
		_queue_frame(t, rig, rabbit, K6, cast_w, home + Vector2(0.0, -20.0), _rewind_time(0.12))
		t.tween_property(rabbit, "rotation", 0.08, _rewind_time(0.06)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(rabbit, "rotation", -0.08, _rewind_time(0.06)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(rabbit, "rotation", 0.0, _rewind_time(0.06)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_queue_frame(t, rig, rabbit, K4, PEEK_W, home + Vector2(0.0, -38.0), _rewind_time(0.07), true)
	_queue_frame(t, rig, rabbit, K3, PEEK_W, home + Vector2(0.0, -22.0), _rewind_time(0.07), true)
	_queue_frame(t, rig, rabbit, K25, PEEK_W, home + Vector2(0.0, -12.0), _rewind_time(0.07), true)
	_queue_frame(t, rig, rabbit, K2, PEEK_W, home + Vector2(0.0, 4.0), _rewind_time(0.07), true)
	_queue_frame(t, rig, rabbit, K1, HOME_W, first_peek, _rewind_time(0.07), true)
	_queue_avatar_frame(t, rig, rabbit, home, _rewind_time(0.08))
	t.tween_callback(Callable(self, "_finish"))

func _queue_jump(t: Tween, rig: Node2D, rabbit: Sprite2D, home: Vector2, cast: Vector2, leap_w: float, cast_w: float) -> void:
	var points := _jump_points(home, cast)
	var durations := _jump_durations()
	for i in range(points.size()):
		var width := leap_w if i < points.size() - 1 else cast_w
		var path := K5 if i < points.size() - 1 else K6
		_queue_jump_frame(t, rig, rabbit, path, width, points[i], _rewind_time(float(durations[i])))

func _queue_jump_frame(t: Tween, rig: Node2D, rabbit: Sprite2D, path: String, width: float, target: Vector2, seconds: float) -> void:
	t.tween_callback(Callable(self, "_set_frame").bind(rabbit, path, width, false))
	t.tween_property(rig, "position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _queue_frame(t: Tween, rig: Node2D, rabbit: Sprite2D, path: String, width: float, target: Vector2, seconds: float, flip_h: bool = false) -> void:
	t.tween_callback(Callable(self, "_set_frame").bind(rabbit, path, width, flip_h))
	t.tween_property(rig, "position", target, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _queue_avatar_frame(t: Tween, rig: Node2D, rabbit: Sprite2D, target: Vector2, seconds: float) -> void:
	t.tween_callback(Callable(self, "_set_avatar_frame").bind(rabbit, SKILL_AV_W))
	t.tween_property(rig, "position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_hourglass(hourglass: Sprite2D) -> void:
	if hourglass == null or not is_instance_valid(hourglass):
		return
	hourglass.visible = true
	hourglass.modulate.a = 0.96
	hourglass.rotation = 0.0

# ───────── 倒流棋盘特效（迁自 _spawn_time_rewind_cast_effect, 居中锚点一处不改）─────────

func _spawn_cast_effect() -> void:
	if skill_bar == null:
		return
	var old := skill_bar.get_node_or_null(CAST_EFFECT_NODE)
	if old != null:
		if old.is_inside_tree():
			old.queue_free()
		else:
			old.free()
	var effect := Node2D.new()
	effect.name = CAST_EFFECT_NODE
	effect.z_index = 180
	effect.position = _effect_anchor()
	effect.set_meta("effect", "time_rewind")
	skill_bar.add_child(effect)
	var board_rect := _current_board_rect()
	var flash := ColorRect.new()
	flash.name = "TimeRewindBoardFlash"
	flash.position = board_rect.position - effect.position
	flash.size = board_rect.size
	flash.color = FLASH_COLOR
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.add_child(flash)
	var base_radius := maxf(board_rect.size.x, board_rect.size.y) * 0.36
	for i in range(3):
		var ring := Line2D.new()
		ring.name = "TimeRewindRing%d" % i
		ring.closed = true
		ring.width = 4.0 - float(i) * 0.6
		var col := RING_COLOR
		col.a = 0.78 - float(i) * 0.16
		ring.default_color = col
		var rx := base_radius * (1.0 + float(i) * 0.22)
		var ry := rx * 0.56
		ring.points = _ellipse_points(Vector2.ZERO, rx, ry, RING_STEPS)
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
				t.tween_property(child, "modulate:a", 0.0, EFFECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if child is ColorRect and String(child.name).begins_with("TimeRewindSand"):
				t.tween_property(child, "position:y", child.position.y - 96.0, EFFECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(clock, "rotation", -TAU * 0.85, EFFECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(effect, "scale", Vector2(1.22, 1.22), EFFECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.finished.connect(_detach_and_free_later.bind(effect), CONNECT_ONE_SHOT)

func _ellipse_points(center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = maxi(8, steps)
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
