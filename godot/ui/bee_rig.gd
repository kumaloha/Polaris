extends Node2D

const CANVAS_SIZE := Vector2(640, 640)
const DEFAULT_DIR := "res://art/characters/bee_rig"
const PART_ORDER := [
	"wing_L",
	"wing_R",
	"leg_L",
	"leg_R",
	"body",
	"arm_R",
	"arm_L_raised",
	"antenna_L",
	"antenna_R",
	"face_base",
	"eyes_open",
	"eyes_half",
	"eyes_closed",
	"mouth",
]

const PART_LAYOUT := {
	"wing_L": {"pos": Vector2(152, 334), "scale": 1.10, "rot": -12.0, "z": -8, "alpha": 0.78},
	"wing_R": {"pos": Vector2(488, 334), "scale": 1.10, "rot": 12.0, "z": -8, "alpha": 0.78},
	"leg_L": {"pos": Vector2(278, 512), "scale": 0.56, "rot": -5.0, "z": -3},
	"leg_R": {"pos": Vector2(362, 512), "scale": 0.56, "rot": 5.0, "z": -3},
	"body": {"pos": Vector2(320, 438), "scale": 0.77, "rot": 0.0, "z": 0},
	"arm_R": {"pos": Vector2(434, 414), "scale": 0.76, "rot": 24.0, "z": 2},
	"arm_L_raised": {"source": "arm_R", "flip_h": true, "pos": Vector2(206, 414), "scale": 0.76, "rot": -24.0, "z": 2},
	"antenna_L": {"pos": Vector2(242, 120), "scale": 0.70, "rot": -10.0, "z": 3},
	"antenna_R": {"pos": Vector2(398, 120), "scale": 0.70, "rot": 10.0, "z": 3},
	"face_base": {"pos": Vector2(320, 246), "scale": 0.74, "rot": 0.0, "z": 4},
	"eyes_open": {"pos": Vector2(320, 260), "scale": 1.02, "rot": 0.0, "z": 5},
	"eyes_half": {"pos": Vector2(320, 260), "scale": 1.02, "rot": 0.0, "z": 5},
	"eyes_closed": {"pos": Vector2(320, 260), "scale": 1.02, "rot": 0.0, "z": 5},
	"mouth": {"pos": Vector2(320, 318), "scale": 0.56, "rot": 0.0, "z": 6, "visible": false},
}

const BLINK_START_OFFSET := 0.24

var _elapsed := BLINK_START_OFFSET
var _content: Node2D
var _content_base_position := Vector2.ZERO


static func supports(character: Dictionary) -> bool:
	return String(character.get("rig", "")) == "bee"


static func default_part_paths() -> Array:
	var paths := []
	for part in PART_ORDER:
		paths.append("%s/%s.png" % [DEFAULT_DIR, part])
	return paths


func setup(character: Dictionary, display_size: Vector2) -> void:
	name = "BeeRig"
	_clear_children()
	_elapsed = BLINK_START_OFFSET
	_content = Node2D.new()
	_content.name = "BeeRigContent"
	var fit: float = minf(display_size.x / CANVAS_SIZE.x, display_size.y / CANVAS_SIZE.y)
	_content.scale = Vector2(fit, fit)
	_content.position = Vector2(
		(display_size.x - CANVAS_SIZE.x * fit) * 0.5,
		(display_size.y - CANVAS_SIZE.y * fit) * 0.5
	)
	_content_base_position = _content.position
	add_child(_content)

	var part_paths := _part_paths(character)
	for part in PART_ORDER:
		_add_part(part, part_paths)
	_add_face_expression()
	_update_eye_state(_elapsed)


func _process(delta: float) -> void:
	_elapsed += delta
	if _content == null:
		return
	_set_part_rotation("wing_L", -12.0 + sin(_elapsed * 22.0) * 7.0)
	_set_part_rotation("wing_R", 12.0 - sin(_elapsed * 22.0) * 7.0)
	_set_part_rotation("arm_L_raised", -24.0 + sin(_elapsed * 3.2) * 1.6)
	_set_part_rotation("arm_R", 24.0 - sin(_elapsed * 3.2) * 1.6)
	_content.position = _content_base_position + Vector2(0, sin(_elapsed * 2.4) * 6.0)
	_update_eye_state(_elapsed)


func _part_paths(character: Dictionary) -> Dictionary:
	var paths := {}
	for path in default_part_paths():
		paths[String(path).get_file().get_basename()] = path
	var raw = character.get("rig_parts", [])
	if raw is Array:
		for path in raw:
			var part_path := String(path)
			paths[part_path.get_file().get_basename()] = part_path
	return paths


func _add_part(part: String, part_paths: Dictionary) -> void:
	var spec: Dictionary = PART_LAYOUT[part]
	var source_part := String(spec.get("source", part))
	var path := String(part_paths.get(source_part, "%s/%s.png" % [DEFAULT_DIR, source_part]))
	var tex := _load_texture(path)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "BeePart_%s" % part
	sprite.texture = tex
	sprite.centered = true
	sprite.position = spec["pos"]
	var s := float(spec["scale"])
	sprite.scale = Vector2(s, s)
	sprite.rotation_degrees = float(spec["rot"])
	sprite.flip_h = bool(spec.get("flip_h", false))
	sprite.visible = bool(spec.get("visible", true))
	sprite.modulate = Color(1, 1, 1, float(spec.get("alpha", 1.0)))
	sprite.z_index = int(spec["z"])
	_content.add_child(sprite)


func _add_face_expression() -> void:
	var nose := Polygon2D.new()
	nose.name = "BeeNose"
	nose.position = Vector2(320, 300)
	nose.polygon = PackedVector2Array([
		Vector2(-7, -3),
		Vector2(0, -6),
		Vector2(7, -3),
		Vector2(4, 3),
		Vector2(0, 5),
		Vector2(-4, 3),
	])
	nose.color = Color(0.70, 0.28, 0.16, 1.0)
	nose.z_index = 7
	_content.add_child(nose)

	var smile := Line2D.new()
	smile.name = "BeeSmile"
	smile.width = 5.0
	smile.default_color = Color(0.35, 0.14, 0.08, 1.0)
	smile.joint_mode = Line2D.LINE_JOINT_ROUND
	smile.begin_cap_mode = Line2D.LINE_CAP_ROUND
	smile.end_cap_mode = Line2D.LINE_CAP_ROUND
	smile.z_index = 7
	var points := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		var x := lerpf(296.0, 344.0, t)
		var y := 308.0 + sin(t * PI) * 11.0
		points.append(Vector2(x, y))
	smile.points = points
	_content.add_child(smile)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded
	var fs_path := path
	if fs_path.begins_with("res://"):
		fs_path = ProjectSettings.globalize_path(fs_path)
	var image := Image.new()
	if image.load(fs_path) != OK:
		push_warning("Unable to load bee rig texture: %s" % path)
		return null
	var tex := ImageTexture.create_from_image(image)
	tex.take_over_path(path)
	return tex


func _set_part_rotation(part: String, degrees: float) -> void:
	var sprite := _content.get_node_or_null("BeePart_%s" % part) as Sprite2D
	if sprite != null:
		sprite.rotation_degrees = degrees


func _update_eye_state(t: float) -> void:
	var blink := fmod(t, 4.2)
	_set_part_visible("eyes_open", blink >= 0.18)
	_set_part_visible("eyes_half", blink >= 0.09 and blink < 0.18)
	_set_part_visible("eyes_closed", blink < 0.09)


func _set_part_visible(part: String, visible: bool) -> void:
	if _content == null:
		return
	var sprite := _content.get_node_or_null("BeePart_%s" % part) as Sprite2D
	if sprite != null:
		sprite.visible = visible


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
