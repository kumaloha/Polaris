extends SceneTree
# UI shell screenshot helper.
# Saves the current main scene to res://_shot_ui.png.
# Set UI_SCREEN=character to capture res://_shot_ui_character.png.
# Run: godot --path godot -s res://tools/ui_screenshot.gd

var _frames := 0
var _app: Node
var _target_screen := "home"
var _output_path := "res://_shot_ui.png"


func _initialize() -> void:
	var env_screen := OS.get_environment("UI_SCREEN").strip_edges().to_lower()
	if env_screen == "character":
		_target_screen = env_screen
		_output_path = "res://_shot_ui_character.png"
	_app = load("res://main.tscn").instantiate()
	get_root().add_child(_app)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and _target_screen == "character" and _app.has_method("_show_character"):
		_app.call("_show_character")
	if _frames == 12:
		var img := get_root().get_texture().get_image()
		if img != null:
			img.save_png(_output_path)
			print("saved %s" % _output_path)
		else:
			print("no image (renderer unavailable)")
		quit()
	return false
