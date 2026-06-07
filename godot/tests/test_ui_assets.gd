extends "res://tests/test_lib.gd"

const CharacterData := preload("res://ui/character_data.gd")
const AppScript := preload("res://ui/app.gd")
const Board := preload("res://core/board.gd")
const BARRIER_ICE_SOURCE := "resources/barrier/ob_ice.png"
const BARRIER_ICE_SYNCED := "res://assets/obstacles/ob_ice.png"


func _filled_layer(w: int, h: int, value: int) -> Array:
	var out := []
	for y in range(h):
		var row := []
		for x in range(w):
			row.append(value)
		out.append(row)
	return out


func _repo_path(path: String) -> String:
	return ProjectSettings.globalize_path("res://../%s" % path).simplify_path()


func test_character_manifest_loads_available_png_characters() -> void:
	var characters := CharacterData.load_characters()
	var image_paths := CharacterData.discover_character_images()
	assert_eq(characters.size(), image_paths.size(), "one playable character per PNG")
	var ids := []
	for character in characters:
		ids.append(character["id"])
	assert_eq(ids[0], "lucky", "default mascot follows docs order")
	assert_true(ids.has("longswap"), "new flat character resources are loaded")
	assert_true(ids.has("gravityflip"), "new flat character resources are loaded")
	assert_true(ids.has("timerewind"), "new flat character resources are loaded")


func test_character_image_paths_exist() -> void:
	for character in CharacterData.load_characters():
		var card_path := CharacterData.resolve_file_path(character["card"])
		var portrait_path := CharacterData.resolve_file_path(character["portrait"])
		assert_true(FileAccess.file_exists(card_path), "card exists: %s" % card_path)
		assert_true(FileAccess.file_exists(portrait_path), "portrait exists: %s" % portrait_path)
		assert_false(String(character["portrait"]).contains("/portraits/"), "flat character path")
		assert_false(String(character["card"]).contains("/cards/"), "flat character path")


func test_character_metadata_comes_from_docs() -> void:
	var by_id := {}
	for character in CharacterData.load_characters():
		by_id[character["id"]] = character
	assert_eq(by_id["lucky"]["name"], "默认精灵", "doc row #0")
	assert_eq(by_id["lucky"]["playable"], false, "default mascot is not playable")
	assert_eq(by_id["borrrower"]["skill_desc"], "借一个特效(4连直线/T·L爆炸/5连彩球效果),本关内必须还;不还不算过关。", "borrower skill from docs")
	assert_eq(by_id["chainbonus"]["type"], "被动型·整局生效", "passive type from docs")


func test_main_scene_uses_app_shell() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var root := scene.instantiate()
	assert_eq(root.name, "App", "main scene root is UI app")
	assert_eq(root.get_script(), AppScript, "main scene uses app.gd")
	root.free()


func test_app_home_builds_when_added_to_tree() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var root := scene.instantiate()
	root._ready()
	assert_true(root.get_child_count() >= 8, "home screen builds visible UI nodes in _ready")
	root.free()


func test_app_launch_level_arg_is_one_based() -> void:
	var app: AppScript = AppScript.new()
	assert_true(app.has_method("_launch_level_index_from_args"), "app parses direct level launch args")
	if not app.has_method("_launch_level_index_from_args"):
		app.free()
		return
	assert_eq(app.call("_launch_level_index_from_args", ["--level", "5"], 126), 4, "--level 5 opens the fifth player-facing level")
	assert_eq(app.call("_launch_level_index_from_args", ["--level=5"], 126), 4, "--level=5 opens the fifth player-facing level")
	assert_eq(app.call("_launch_level_index_from_args", ["--level", "0"], 126), -1, "level numbers are one-based")
	assert_eq(app.call("_launch_level_index_from_args", ["--level", "127"], 126), -1, "out of range levels are ignored")
	app.free()


func test_level_scene_launch_level_arg_is_one_based() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_launch_level_idx_from_args"), "Level.tscn path parses direct level launch args")
	if not level.has_method("_launch_level_idx_from_args"):
		level.free()
		return
	assert_eq(level.call("_launch_level_idx_from_args", ["--level", "5"], 126), 4, "--level 5 opens raw exported level 5")
	assert_eq(level.call("_launch_level_idx_from_args", ["--level=5"], 126), 4, "--level=5 opens raw exported level 5")
	assert_eq(level.call("_launch_level_idx_from_args", ["--level", "0"], 126), -1, "Level.tscn level numbers are one-based")
	assert_eq(level.call("_launch_level_idx_from_args", ["--level", "127"], 126), -1, "out of range Level.tscn levels are ignored")
	level.free()


func test_level_objective_view_names_clear_jelly() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var objs := [{"type": "CLEAR_JELLY", "species": -1, "target": 65}]
	level.board = Board.new(8, 9, [0, 1, 2, 3, 4, 5], 0, 25, 1, [], objs, _filled_layer(8, 9, 1))
	var view: Array = level.call("_objectives_view")
	assert_eq(view.size(), 1, "one objective card")
	assert_eq(view[0].get("label", ""), "果冻", "jelly objective is named in the Level.tscn HUD data")
	assert_eq(view[0].get("progress", -1), 0, "jelly starts at zero progress")
	assert_eq(view[0].get("target", -1), 65, "fifth-level jelly target is shown")
	level.free()


func test_level_blocker_objective_uses_resources_barrier_ice_icon() -> void:
	assert_true(FileAccess.file_exists(_repo_path(BARRIER_ICE_SOURCE)), "source barrier image exists")
	assert_true(FileAccess.file_exists(BARRIER_ICE_SYNCED), "synced Godot barrier image exists")
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var objs := [{"type": "CLEAR_BLOCKER", "species": -1, "target": 9}]
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1, [], objs, [], _filled_layer(3, 3, 1))
	var view: Array = level.call("_objectives_view")
	assert_eq(view.size(), 1, "one objective card")
	assert_eq(view[0].get("icon", ""), BARRIER_ICE_SYNCED, "blocker objective uses resources/barrier synced art")
	level.free()
