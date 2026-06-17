extends AnimatedSprite2D
class_name GemClearVFX

const ANIM_NAME := &"clear"
const FRAME_COUNT := 12
const DEFAULT_FPS := 32.0

const PATH_PATTERNS := {
	"blue_drop": "res://assets/vfx/gem_clear_frames/blue_drop/blue_drop_%02d.png",
	"green_clover": "res://assets/vfx/gem_clear_frames/green_clover/green_clover_%02d.png",
	"pink_heart": "res://assets/vfx/gem_clear_frames/pink_heart/pink_heart_%02d.png",
	"purple_orb": "res://assets/vfx/gem_clear_frames/purple_orb/purple_orb_%02d.png",
	"red_cube": "res://assets/vfx/gem_clear_frames/red_cube/red_cube_%02d.png",
	"yellow_star": "res://assets/vfx/gem_clear_frames/yellow_star/yellow_star_%02d.png",
}

static var _sprite_frames_cache: Dictionary = {}

var _fit_source_px := 0.0

func setup(gem_type: String, playback_fps: float = DEFAULT_FPS) -> bool:
	centered = true
	z_index = 100
	visible = true
	speed_scale = 1.0
	_fit_source_px = 0.0

	var frames: SpriteFrames = _get_sprite_frames(gem_type, playback_fps)
	if frames == null:
		queue_free()
		return false

	sprite_frames = frames
	animation = ANIM_NAME
	frame = 0
	frame_progress = 0.0
	var tex := sprite_frames.get_frame_texture(ANIM_NAME, 0)
	if tex != null:
		_fit_source_px = maxf(float(tex.get_width()), float(tex.get_height()))

	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)

	return true

func play_once(delay_seconds: float = 0.0) -> void:
	if sprite_frames == null or sprite_frames.get_frame_count(ANIM_NAME) == 0:
		return
	frame = 0
	frame_progress = 0.0

	if delay_seconds > 0.0:
		visible = false
		var tween := create_tween()
		tween.tween_interval(delay_seconds)
		tween.tween_callback(_play_now)
	else:
		_play_now()

func fit_to_diameter(target_px: float) -> void:
	if _fit_source_px <= 0.0:
		return
	scale = Vector2.ONE * (target_px / _fit_source_px)

static func spawn(
	parent: Node,
	gem_type: String,
	world_position: Vector2,
	scale_value: Vector2 = Vector2.ONE,
	delay_seconds: float = 0.0,
	playback_fps: float = DEFAULT_FPS
):
	var vfx := GemClearVFX.new()
	parent.add_child(vfx)
	vfx.global_position = world_position
	vfx.scale = scale_value

	if vfx.setup(gem_type, playback_fps):
		vfx.play_once(delay_seconds)

	return vfx

static func _get_sprite_frames(gem_type: String, playback_fps: float = DEFAULT_FPS):
	if not PATH_PATTERNS.has(gem_type):
		push_warning("Unknown gem clear VFX type: %s" % gem_type)
		return null

	var cache_key := "%s_%s" % [gem_type, str(playback_fps)]
	if _sprite_frames_cache.has(cache_key):
		return _sprite_frames_cache[cache_key]

	var frames := SpriteFrames.new()
	frames.add_animation(ANIM_NAME)
	frames.set_animation_loop(ANIM_NAME, false)
	frames.set_animation_speed(ANIM_NAME, playback_fps)

	var pattern: String = PATH_PATTERNS[gem_type]
	for i in range(1, FRAME_COUNT + 1):
		var path := pattern % i
		var tex := _load_frame(path)
		if tex == null:
			continue
		frames.add_frame(ANIM_NAME, tex)

	if frames.get_frame_count(ANIM_NAME) == 0:
		push_warning("No clear VFX frames loaded for gem type: %s" % gem_type)
		return null

	_sprite_frames_cache[cache_key] = frames
	return frames

static func _load_frame(path: String) -> Texture2D:
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex != null:
		return tex
	if not FileAccess.file_exists(path):
		push_warning("Missing gem clear frame: %s" % path)
		return null
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		err = image.load(path)
	if err != OK:
		push_warning("Failed to load gem clear frame: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

func _play_now() -> void:
	visible = true
	play(ANIM_NAME)

func _on_animation_finished() -> void:
	queue_free()
