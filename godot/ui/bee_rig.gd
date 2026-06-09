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
	"wing_L": {"pos": Vector2(205, 306), "scale": 0.72, "rot": -8.0, "z": -8},
	"wing_R": {"pos": Vector2(435, 306), "scale": 0.72, "rot": 8.0, "z": -8},
	"leg_L": {"pos": Vector2(272, 484), "scale": 0.48, "rot": -7.0, "z": -3},
	"leg_R": {"pos": Vector2(372, 486), "scale": 0.48, "rot": 7.0, "z": -3},
	"body": {"pos": Vector2(320, 418), "scale": 0.62, "rot": 0.0, "z": 0},
	"arm_R": {"pos": Vector2(438, 370), "scale": 0.58, "rot": 7.0, "z": 2},
	"arm_L_raised": {"pos": Vector2(218, 332), "scale": 0.58, "rot": -8.0, "z": 2},
	"antenna_L": {"pos": Vector2(250, 126), "scale": 0.50, "rot": -9.0, "z": 3},
	"antenna_R": {"pos": Vector2(390, 126), "scale": 0.50, "rot": 9.0, "z": 3},
	"face_base": {"pos": Vector2(320, 252), "scale": 0.62, "rot": 0.0, "z": 4},
	"eyes_open": {"pos": Vector2(320, 238), "scale": 0.62, "rot": 0.0, "z": 5},
	"eyes_half": {"pos": Vector2(320, 238), "scale": 0.62, "rot": 0.0, "z": 5},
	"eyes_closed": {"pos": Vector2(320, 238), "scale": 0.62, "rot": 0.0, "z": 5},
	"mouth": {"pos": Vector2(320, 318), "scale": 0.56, "rot": 0.0, "z": 6},
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
		_add_part(part, String(part_paths.get(part, "%s/%s.png" % [DEFAULT_DIR, part])))
	_update_eye_state(_elapsed)


func _process(delta: float) -> void:
	_elapsed += delta
	if _content == null:
		return
	_set_part_rotation("wing_L", -8.0 + sin(_elapsed * 18.0) * 5.0)
	_set_part_rotation("wing_R", 8.0 - sin(_elapsed * 18.0) * 5.0)
	_set_part_rotation("arm_L_raised", -8.0 + sin(_elapsed * 3.2) * 2.0)
	_content.position = _content_base_position + Vector2(0, sin(_elapsed * 2.4) * 8.0)
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


func _add_part(part: String, path: String) -> void:
	var tex := _load_texture(path)
	if tex == null:
		return
	var spec: Dictionary = PART_LAYOUT[part]
	var sprite := Sprite2D.new()
	sprite.name = "BeePart_%s" % part
	sprite.texture = tex
	sprite.centered = true
	sprite.position = spec["pos"]
	var s := float(spec["scale"])
	sprite.scale = Vector2(s, s)
	sprite.rotation_degrees = float(spec["rot"])
	sprite.z_index = int(spec["z"])
	_content.add_child(sprite)


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
	tex.resource_path = path
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
