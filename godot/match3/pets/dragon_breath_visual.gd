class_name DragonBreathVisual
extends Node2D
## 龙宠「龙息大招」演出层。
##
## 这里只管视觉：清盘/坍塌/连锁由 DragonBreathCast 施法控制器结算。
## 摆位使用“可见内容左边 + 脚底基线”，不使用 1440×1440 透明画布中心，
## 避免大龙和小龙/底栏支点看起来错位。

const LevelLayout := preload("res://match3/level_layout.gd")

signal visual_retired

const CAST_NODE := "DragonBreathCast"
const FRAME_NODE := "DragonBreathFrame"
const FPS := 24.0
const CAST_Z := 245

const BABY_FRAME_DIR := "res://assets/pets/dragon_baby/frames"
const BABY_FRAME_PATTERN := "%s/dragon_%02d.png"
const BABY_FRAME_FIRST := 0
const BABY_FRAME_LAST := 63

const YOUTH_FRAME_DIR := "res://assets/pets/dragon_youth/frames"
const YOUTH_FRAME_PATTERN := "%s/frame_%03d.png"
const YOUTH_FRAME_FIRST := 1
const YOUTH_FRAME_LAST := 280

# frame_001 清理后非透明像素可见包围盒(PNG 仍保留完整 1440 画布)。
const FRAME_DIR := YOUTH_FRAME_DIR
const FRAME_PATTERN := YOUTH_FRAME_PATTERN
const FRAME_FIRST := YOUTH_FRAME_FIRST
const FRAME_LAST := YOUTH_FRAME_LAST
const FRAME_VISIBLE_BBOX := Rect2(Vector2(279.0, 434.0), Vector2(883.0, 571.0))
const YOUTH_TARGET_VISIBLE_W := 430.0
const YOUTH_TARGET_VISIBLE_W_MIN := 360.0
const YOUTH_TARGET_VISIBLE_W_MAX := 430.0
const BABY_TEXTURE_SIZE := Vector2(512.0, 512.0)
const BABY_VISIBLE_BBOX := Rect2(Vector2(44.0, 41.0), Vector2(387.0, 418.0))
const BABY_TARGET_VISIBLE_W := 250.0
const BABY_TARGET_VISIBLE_W_MIN := 220.0
const BABY_TARGET_VISIBLE_W_MAX := 300.0

const DESIGN_W := LevelLayout.DESIGN_W
const SKILL_AV_Y := LevelLayout.SKILL_AV_Y
const SKILL_AV_W := LevelLayout.SKILL_AV_W
const DRAGON_BOOK_GAP := 10.0
const SLOT_COUNT := 2
const YOUTH_FLIGHT_RISE_START_FRAME := 100
const YOUTH_FLIGHT_DESCENT_START_FRAME := 247
const YOUTH_FLIGHT_LAND_FRAME := 262

static var _frame_cache: Dictionary = {}
static var _preload_requests: Dictionary = {}
static var _preload_paths: Dictionary = {}
static var _preload_indices: Dictionary = {}
static var _preload_frames: Dictionary = {}

var skill_bar: CanvasLayer = null
var board = null
var cell_size: float = 0.0
var board_origin: Vector2 = Vector2.ZERO
var variant: String = "youth"
var slot_index: int = 1
var flip_h: bool = false


func setup(ctx: Dictionary) -> void:
	skill_bar = ctx.get("skill_bar", null)
	board = ctx.get("board", null)
	cell_size = float(ctx.get("cell_size", 0.0))
	board_origin = ctx.get("board_origin", Vector2.ZERO)
	variant = _normalized_variant(String(ctx.get("variant", "youth")))
	slot_index = clampi(int(ctx.get("slot_index", 1)), 0, SLOT_COUNT - 1)
	flip_h = bool(ctx.get("flip_h", false))


func play_and_retire() -> void:
	_build_visuals()
	var sprite := get_node_or_null(FRAME_NODE) as AnimatedSprite2D
	if sprite == null:
		_retire_visual()
		return
	sprite.play("cast")
	if not is_inside_tree():
		return
	_start_flight_motion()
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(0.10, _animation_duration() - 0.20))
	t.tween_property(self, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(Callable(self, "_retire_visual"))


func _retire_visual() -> void:
	emit_signal("visual_retired")
	queue_free()


func _build_visuals() -> void:
	name = CAST_NODE
	z_index = CAST_Z
	position = Vector2.ZERO
	for child in get_children():
		_detach_and_free_later(child)
	var frames := _build_sprite_frames()
	if frames == null:
		return
	var cfg := variant_config(variant)
	var bbox: Rect2 = cfg["bbox"]
	var sprite := AnimatedSprite2D.new()
	sprite.name = FRAME_NODE
	sprite.sprite_frames = frames
	sprite.animation = "cast"
	sprite.centered = false
	sprite.z_index = 0
	var placement: Dictionary = _placement_for_visible_left_baseline(
		_visible_left_baseline_anchor(),
		bbox,
		_visible_width(),
		flip_h
	)
	var s: float = float(placement["scale"])
	sprite.position = placement["position"]
	sprite.scale = Vector2(-s if flip_h else s, s)
	sprite.set_meta("anchor", "visible_left_baseline")
	sprite.set_meta("asset_dir", String(cfg["dir"]))
	sprite.set_meta("frame_range", Vector2i(int(cfg["first"]), int(cfg["last"])))
	sprite.set_meta("variant", variant)
	sprite.set_meta("visible_bbox", bbox)
	add_child(sprite)


func _build_sprite_frames() -> SpriteFrames:
	var key := _normalized_variant(variant)
	if _frame_cache.has(key):
		return _frame_cache[key]
	if _preload_paths.has(key):
		process_preload_budget(99999)
		if _frame_cache.has(key):
			return _frame_cache[key]
	var cfg := variant_config(key)
	var frames := SpriteFrames.new()
	frames.add_animation("cast")
	frames.set_animation_loop("cast", false)
	frames.set_animation_speed("cast", FPS)
	for i in range(int(cfg["first"]), int(cfg["last"]) + 1):
		var path := String(cfg["pattern"]) % [String(cfg["dir"]), i]
		var tex := _load_texture_static(path)
		if tex != null:
			frames.add_frame("cast", tex)
	if frames.get_frame_count("cast") == 0:
		return null
	_frame_cache[key] = frames
	return frames


static func request_variant_preload(raw_variant: String) -> void:
	var key := _normalized_variant(raw_variant)
	if _frame_cache.has(key) or _preload_requests.has(key):
		return
	var cfg := variant_config(key)
	var paths := []
	for i in range(int(cfg["first"]), int(cfg["last"]) + 1):
		var path := String(cfg["pattern"]) % [String(cfg["dir"]), i]
		paths.append(path)
	_preload_paths[key] = paths
	_preload_indices[key] = 0
	_preload_requests[key] = true


static func process_preload_budget(frame_budget: int = 3) -> void:
	var remaining := maxi(1, frame_budget)
	for key in _preload_paths.keys():
		if remaining <= 0:
			return
		if _frame_cache.has(key):
			_clear_preload_work(key)
			continue
		var paths: Array = _preload_paths[key]
		var frames: SpriteFrames = _preload_frames.get(key, null)
		if frames == null:
			frames = SpriteFrames.new()
			frames.add_animation("cast")
			frames.set_animation_loop("cast", false)
			frames.set_animation_speed("cast", FPS)
			_preload_frames[key] = frames
		var idx := int(_preload_indices.get(key, 0))
		while idx < paths.size() and remaining > 0:
			var tex := _load_texture_static(String(paths[idx]))
			if tex != null:
				frames.add_frame("cast", tex)
			idx += 1
			remaining -= 1
		_preload_indices[key] = idx
		if idx >= paths.size():
			if frames.get_frame_count("cast") > 0:
				_frame_cache[key] = frames
			_clear_preload_work(key)


static func release_frame_cache() -> void:
	_frame_cache.clear()
	_preload_requests.clear()
	_preload_paths.clear()
	_preload_indices.clear()
	_preload_frames.clear()


func is_variant_preload_requested(raw_variant: String) -> bool:
	var key := _normalized_variant(raw_variant)
	return _preload_requests.has(key) or _frame_cache.has(key)


func clear_frame_cache_for_tests() -> void:
	release_frame_cache()


static func _clear_preload_work(key: String) -> void:
	_preload_paths.erase(key)
	_preload_indices.erase(key)
	_preload_frames.erase(key)


func _apply_frame_geometry(frame_index: int) -> void:
	var sprite := get_node_or_null(FRAME_NODE) as AnimatedSprite2D
	if sprite == null:
		return
	var cfg := variant_config(variant)
	var bbox: Rect2 = cfg["bbox"]
	var placement: Dictionary = _placement_for_visible_left_baseline(
		_visible_left_baseline_anchor(),
		bbox,
		_visible_width(),
		flip_h
	)
	var s: float = float(placement["scale"])
	sprite.position = placement["position"]
	sprite.scale = Vector2(-s if flip_h else s, s)
	sprite.set_meta("visible_bbox", bbox)


func _start_flight_motion() -> void:
	if variant != "youth":
		return
	var offset := _airborne_offset()
	if offset.length() <= 0.1:
		return
	var timing := _flight_timing()
	var rise := float(timing["rise"])
	var hold := float(timing["hold"])
	var fall := float(timing["fall"])
	if rise <= 0.0 or fall <= 0.0:
		return
	position = Vector2.ZERO
	var flight := create_tween()
	var pre_rise := float(timing.get("pre_rise", 0.0))
	if pre_rise > 0.0:
		flight.tween_interval(pre_rise)
	flight.tween_property(self, "position", offset, rise).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		flight.tween_interval(hold)
	flight.tween_property(self, "position", Vector2.ZERO, fall).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _airborne_offset() -> Vector2:
	if variant != "youth":
		return Vector2.ZERO
	var current_center := _visual_center_with_offset(Vector2.ZERO)
	return Vector2(0.0, _current_board_rect().get_center().y - current_center.y)


func _visual_center_with_offset(offset: Vector2) -> Vector2:
	var sprite := get_node_or_null(FRAME_NODE) as AnimatedSprite2D
	if sprite == null:
		return position + offset
	var cfg := variant_config(variant)
	var bbox: Rect2 = sprite.get_meta("visible_bbox", cfg["bbox"])
	var scale := sprite.scale
	var center_offset := Vector2(bbox.get_center().x * scale.x, bbox.get_center().y * scale.y)
	return position + offset + sprite.position + center_offset


func _flight_timing() -> Dictionary:
	var duration := _animation_duration()
	var pre_rise := _time_at_frame(YOUTH_FLIGHT_RISE_START_FRAME)
	var descent_start := _time_at_frame(YOUTH_FLIGHT_DESCENT_START_FRAME)
	var landed := _time_at_frame(YOUTH_FLIGHT_LAND_FRAME)
	pre_rise = clampf(pre_rise, 0.0, duration)
	descent_start = clampf(descent_start, pre_rise, duration)
	landed = clampf(landed, descent_start, duration)
	var rise := maxf(0.0, descent_start - pre_rise)
	var fall := maxf(0.0, landed - descent_start)
	var post_fall := maxf(0.0, duration - landed)
	return {
		"pre_rise": pre_rise,
		"rise": rise,
		"hold": 0.0,
		"fall": fall,
		"post_fall": post_fall,
	}


func _time_at_frame(frame_number: int) -> float:
	var cfg := variant_config(variant)
	return float(frame_number - int(cfg["first"])) / FPS


func _placement_for_visible_left_baseline(anchor: Vector2, bbox: Rect2, visible_width: float, flipped: bool) -> Dictionary:
	var safe_w := maxf(1.0, visible_width)
	var scale := safe_w / maxf(1.0, bbox.size.x)
	var pos: Vector2
	if flipped:
		pos = Vector2(anchor.x + bbox.end.x * scale, anchor.y - bbox.end.y * scale)
	else:
		pos = anchor - Vector2(bbox.position.x, bbox.end.y) * scale
	return {
		"position": pos,
		"scale": scale,
	}


func _visible_left_baseline_anchor() -> Vector2:
	var baseline_y := avatar_baseline_y()
	var dragon_slot_center_x := DESIGN_W * (float(slot_index) + 0.5) / float(SLOT_COUNT)
	var left := clampf(dragon_slot_center_x - _visible_width() * 0.50, 20.0, DESIGN_W - _visible_width() - 12.0)
	return Vector2(left, baseline_y)


static func avatar_baseline_y() -> float:
	var button_top := SKILL_AV_Y - SKILL_AV_W * 0.5
	var baby_scale := SKILL_AV_W / maxf(1.0, BABY_TEXTURE_SIZE.x)
	return button_top + BABY_VISIBLE_BBOX.end.y * baby_scale


func _visible_width() -> float:
	return visible_width_for_layout(variant, _current_board_rect(), _book_frame_rect())


static func visible_width_for_layout(raw_variant: String, board_rect: Rect2, book_rect: Rect2) -> float:
	var cfg := variant_config(raw_variant)
	var width := float(cfg["target_w"])
	if board_rect.size.x <= 0.0:
		width = float(cfg["target_w"])
	else:
		width = clampf(board_rect.size.x * float(cfg["board_scale"]), float(cfg["min_w"]), float(cfg["max_w"]))
	if book_rect.size.y > 0.0:
		var bbox: Rect2 = cfg["bbox"]
		var available_h := avatar_baseline_y() - (book_rect.end.y + DRAGON_BOOK_GAP)
		if available_h > 0.0:
			var height_cap_w := available_h * bbox.size.x / maxf(1.0, bbox.size.y)
			width = minf(width, height_cap_w)
	return maxf(1.0, width)


func _animation_duration() -> float:
	var sprite := get_node_or_null(FRAME_NODE) as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return duration_for_variant(variant)
	var count := sprite.sprite_frames.get_frame_count("cast")
	return float(maxi(1, count)) / FPS


static func duration_for_variant(raw_variant: String) -> float:
	var cfg := variant_config(raw_variant)
	return float(int(cfg["last"]) - int(cfg["first"]) + 1) / FPS


static func variant_config(raw_variant: String) -> Dictionary:
	var normalized := _normalized_variant(raw_variant)
	if normalized == "baby":
		return {
			"dir": BABY_FRAME_DIR,
			"pattern": BABY_FRAME_PATTERN,
			"first": BABY_FRAME_FIRST,
			"last": BABY_FRAME_LAST,
			"bbox": BABY_VISIBLE_BBOX,
			"target_w": BABY_TARGET_VISIBLE_W,
			"min_w": BABY_TARGET_VISIBLE_W_MIN,
			"max_w": BABY_TARGET_VISIBLE_W_MAX,
			"board_scale": 0.42,
		}
	return {
		"dir": YOUTH_FRAME_DIR,
		"pattern": YOUTH_FRAME_PATTERN,
		"first": YOUTH_FRAME_FIRST,
		"last": YOUTH_FRAME_LAST,
		"bbox": FRAME_VISIBLE_BBOX,
		"target_w": YOUTH_TARGET_VISIBLE_W,
		"min_w": YOUTH_TARGET_VISIBLE_W_MIN,
		"max_w": YOUTH_TARGET_VISIBLE_W_MAX,
		"board_scale": 0.68,
	}


static func _normalized_variant(raw_variant: String) -> String:
	var key := raw_variant.strip_edges().to_lower()
	return "baby" if key == "baby" else "youth"


func _current_board_rect() -> Rect2:
	if board == null:
		return Rect2(Vector2(DESIGN_W * 0.18, 1520.0 * 0.36), Vector2(DESIGN_W * 0.64, 1520.0 * 0.32))
	return Rect2(board_origin, Vector2(float(board.width) * cell_size, float(board.height) * cell_size))


func _book_frame_rect() -> Rect2:
	if board == null:
		return _current_board_rect()
	return LevelLayout.book_frame_rect(board.height, cell_size, board_origin)


func _load_texture(path: String) -> Texture2D:
	return _load_texture_static(path)


static func _load_texture_static(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	var tex := ImageTexture.create_from_image(image)
	tex.resource_path = path
	return tex


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
