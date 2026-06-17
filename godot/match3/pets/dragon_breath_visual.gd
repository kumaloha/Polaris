class_name DragonBreathVisual
extends Node2D
## 龙宝宝「龙息大招」的大龙演出层。
##
## 这里只管视觉：清盘/坍塌/连锁由 DragonBreathCast 施法控制器结算。
## 摆位使用“可见内容左边 + 脚底基线”，不使用 1440×1440 透明画布中心，
## 避免大龙和小龙/底栏支点看起来错位。

const LevelLayout := preload("res://match3/level_layout.gd")

const CAST_NODE := "DragonBreathCast"
const FRAME_NODE := "DragonBreathFrame"
const FRAME_DIR := "res://assets/pets/dragon_youth/frames"
const FRAME_PATTERN := "%s/frame_%03d.png"
const FRAME_FIRST := 1
const FRAME_LAST := 36
const FPS := 24.0
const CAST_Z := 245

# frame_001 清理后非透明像素可见包围盒(PNG 仍保留完整 1440 画布)。
const FRAME_VISIBLE_BBOX := Rect2(Vector2(279.0, 434.0), Vector2(883.0, 571.0))
const TARGET_VISIBLE_W := 430.0
const TARGET_VISIBLE_W_MIN := 360.0
const TARGET_VISIBLE_W_MAX := 430.0
const BABY_TEXTURE_SIZE := Vector2(512.0, 512.0)
const BABY_VISIBLE_BBOX := Rect2(Vector2(44.0, 41.0), Vector2(387.0, 418.0))

const DESIGN_W := LevelLayout.DESIGN_W
const SKILL_AV_Y := LevelLayout.SKILL_AV_Y
const SKILL_AV_W := LevelLayout.SKILL_AV_W
const DRAGON_SLOT_INDEX := 2
const SLOT_COUNT := 4

var skill_bar: CanvasLayer = null
var board = null
var cell_size: float = 0.0
var board_origin: Vector2 = Vector2.ZERO


func setup(ctx: Dictionary) -> void:
	skill_bar = ctx.get("skill_bar", null)
	board = ctx.get("board", null)
	cell_size = float(ctx.get("cell_size", 0.0))
	board_origin = ctx.get("board_origin", Vector2.ZERO)


func play_and_retire() -> void:
	_build_visuals()
	var sprite := get_node_or_null(FRAME_NODE) as AnimatedSprite2D
	if sprite == null:
		queue_free()
		return
	sprite.play("cast")
	if not is_inside_tree():
		return
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(0.10, _animation_duration() - 0.20))
	t.tween_property(self, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(Callable(self, "queue_free"))


func _build_visuals() -> void:
	name = CAST_NODE
	z_index = CAST_Z
	for child in get_children():
		_detach_and_free_later(child)
	var frames := _build_sprite_frames()
	if frames == null:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.name = FRAME_NODE
	sprite.sprite_frames = frames
	sprite.animation = "cast"
	sprite.centered = false
	sprite.z_index = 0
	var placement: Dictionary = _placement_for_visible_left_baseline(
		_visible_left_baseline_anchor(),
		FRAME_VISIBLE_BBOX,
		_visible_width()
	)
	var s: float = float(placement["scale"])
	sprite.position = placement["position"]
	sprite.scale = Vector2.ONE * s
	sprite.set_meta("anchor", "visible_left_baseline")
	sprite.set_meta("asset_dir", FRAME_DIR)
	sprite.set_meta("frame_range", Vector2i(FRAME_FIRST, FRAME_LAST))
	add_child(sprite)


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("cast")
	frames.set_animation_loop("cast", false)
	frames.set_animation_speed("cast", FPS)
	for i in range(FRAME_FIRST, FRAME_LAST + 1):
		var path := FRAME_PATTERN % [FRAME_DIR, i]
		var tex := _load_texture(path)
		if tex != null:
			frames.add_frame("cast", tex)
	if frames.get_frame_count("cast") == 0:
		return null
	return frames


func _placement_for_visible_left_baseline(anchor: Vector2, bbox: Rect2, visible_width: float) -> Dictionary:
	var safe_w := maxf(1.0, visible_width)
	var scale := safe_w / maxf(1.0, bbox.size.x)
	return {
		"position": anchor - Vector2(bbox.position.x, bbox.end.y) * scale,
		"scale": scale,
	}


func _visible_left_baseline_anchor() -> Vector2:
	var baseline_y := _baby_dragon_visible_foot_y()
	var dragon_slot_center_x := DESIGN_W * (float(DRAGON_SLOT_INDEX) + 0.5) / float(SLOT_COUNT)
	var left := clampf(dragon_slot_center_x - _visible_width() * 0.50, 20.0, DESIGN_W - _visible_width() - 12.0)
	return Vector2(left, baseline_y)


func _baby_dragon_visible_foot_y() -> float:
	var button_top := SKILL_AV_Y - SKILL_AV_W * 0.5
	var baby_scale := SKILL_AV_W / maxf(1.0, BABY_TEXTURE_SIZE.x)
	return button_top + BABY_VISIBLE_BBOX.end.y * baby_scale


func _visible_width() -> float:
	var board_rect := _current_board_rect()
	if board_rect.size.x <= 0.0:
		return TARGET_VISIBLE_W
	return clampf(board_rect.size.x * 0.68, TARGET_VISIBLE_W_MIN, TARGET_VISIBLE_W_MAX)


func _animation_duration() -> float:
	var sprite := get_node_or_null(FRAME_NODE) as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return float(FRAME_LAST - FRAME_FIRST + 1) / FPS
	var count := sprite.sprite_frames.get_frame_count("cast")
	return float(maxi(1, count)) / FPS


func _current_board_rect() -> Rect2:
	if board == null:
		return Rect2(Vector2(DESIGN_W * 0.18, 1520.0 * 0.36), Vector2(DESIGN_W * 0.64, 1520.0 * 0.32))
	return Rect2(board_origin, Vector2(float(board.width) * cell_size, float(board.height) * cell_size))


func _book_frame_rect() -> Rect2:
	if board == null:
		return _current_board_rect()
	return LevelLayout.book_frame_rect(board.height, cell_size, board_origin)


func _load_texture(path: String) -> Texture2D:
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
