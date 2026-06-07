extends "res://tests/test_lib.gd"

const CharacterData := preload("res://ui/character_data.gd")
const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const ME := preload("res://core/match_engine.gd")
const BARRIER_ICE_SOURCE := "resources/barrier/ob_ice.png"
const BARRIER_ICE_SYNCED := "res://assets/obstacles/ob_ice.png"
const BARRIER_MARKER_NAME := "CoatBarrierSprite"
const MAGIC_ART_REQUIRED := [
	"res://art/gems/base/gem_water.png",
	"res://art/gems/base/gem_clover.png",
	"res://art/gems/base/gem_heart.png",
	"res://art/gems/base/gem_orb.png",
	"res://art/gems/base/gem_ruby.png",
	"res://art/gems/base/gem_star.png",
	"res://art/gems/base/gem_shadow_soft.png",
	"res://art/gems/special_4/special_4_horizontal_overlay.png",
	"res://art/gems/special_4/special_4_vertical_overlay.png",
	"res://art/gems/special_4/special_4_area_overlay.png",
	"res://art/gems/special_5/special_5_core_ball.png",
	"res://art/gems/special_5/special_5_gold_ground_glow.png",
	"res://art/gems/special_5/special_5_inner_swirl.png",
	"res://art/gems/special_5/special_5_inner_stars.png",
	"res://art/gems/special_5/special_5_cube_ring.png",
	"res://art/vfx/basic_pop/vfx_basic_flash_blob.png",
	"res://art/vfx/basic_pop/vfx_basic_flash_star.png",
	"res://art/vfx/basic_pop/vfx_basic_ring_soft.png",
	"res://art/vfx/line_blast/vfx_beam_core.png",
	"res://art/vfx/line_blast/vfx_beam_glow.png",
	"res://art/vfx/line_blast/vfx_beam_cap.png",
	"res://art/vfx/area_blast/vfx_area_square_wave.png",
	"res://art/vfx/area_blast/vfx_area_cube_frame.png",
	"res://art/vfx/area_blast/vfx_area_grid_3x3.png",
	"res://art/vfx/color_absorb/vfx_absorb_orb.png",
	"res://art/vfx/color_absorb/vfx_absorb_trail.png",
	"res://art/vfx/color_absorb/cell_target_outline.png",
	"res://art/vfx/transform/vfx_transform_flash.png",
	"res://art/vfx/reward/vfx_reward_magic_ball.png",
	"res://art/vfx/movement/vfx_landing_ring.png",
]


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


func _count_positive_layer(layer: Array) -> int:
	var count := 0
	for row in layer:
		for value in row:
			if int(value) > 0:
				count += 1
	return count


func _count_group_nodes(root: Node, group_name: String) -> int:
	var count := 0
	if root.is_in_group(group_name):
		count += 1
	for child in root.get_children():
		count += _count_group_nodes(child, group_name)
	return count


func _find_named_node(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_named_node(child, node_name)
		if found != null:
			return found
	return null


func _prepare_level_scene() -> Node:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.background_layer = level.get_node("BackgroundLayer")
	level.board_layer = level.get_node("BoardLayer")
	level.gem_layer = level.get_node("GemLayer")
	level.character_layer = level.get_node("CharacterLayer")
	level.ui_layer = level.get_node("UILayer")
	level.skill_bar = level.get_node("SkillBar")
	level._levels = LevelLibrary.load_file("res://levels.json")
	level._playable = []
	for i in range(level._levels.size()):
		var objs = level._levels[i].get("objectives", [])
		if objs is Array and not objs.is_empty():
			level._playable.append(i)
	return level


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


func test_magic_match_art_pack_is_available_under_res_art() -> void:
	for path in MAGIC_ART_REQUIRED:
		assert_true(ResourceLoader.exists(path) or FileAccess.file_exists(path), "magic art asset exists: %s" % path)


func test_level_can_load_magic_match_pngs_before_import_metadata_exists() -> void:
	var level := _prepare_level_scene()
	assert_true(level.has_method("_load_texture"), "Level has a PNG fallback texture loader")
	var tex := level.call("_load_texture", "res://art/gems/base/gem_ruby.png") as Texture2D
	assert_true(tex != null, "raw magic art PNG loads as Texture2D")
	if tex != null:
		assert_true(tex.get_width() > 0 and tex.get_height() > 0, "loaded magic art texture has dimensions")
	level.free()


func test_project_default_scene_uses_level_entry() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://Level.tscn", "project starts directly in Level.tscn")


func test_main_scene_aliases_level_entry() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var root := scene.instantiate()
	assert_eq(root.name, "Level", "main.tscn aliases the Level entry scene")
	assert_eq(root.get_script().resource_path, "res://match3/level.gd", "main.tscn uses the Level scene script, not the old app shell")
	assert_true(root.has_node("GemLayer"), "main.tscn keeps the Level scene children")
	root.free()


func test_level_scene_launch_level_arg_is_one_based() -> void:
	var level := _prepare_level_scene()
	assert_true(level.has_method("_launch_level_idx_from_args"), "Level.tscn path parses direct level launch args")
	if not level.has_method("_launch_level_idx_from_args"):
		level.free()
		return
	assert_eq(level.call("_launch_level_idx_from_args", ["--level", "5"], level._levels.size()), 5, "--level 5 opens the fifth playable level, raw exported level 6")
	assert_eq(level.call("_launch_level_idx_from_args", ["--level=5"], level._levels.size()), 5, "--level=5 opens the fifth playable level, raw exported level 6")
	assert_eq(level.call("_launch_level_idx_from_args", ["--level", "0"], 126), -1, "Level.tscn level numbers are one-based")
	assert_eq(level.call("_launch_level_idx_from_args", ["--level", "127"], 126), -1, "out of range Level.tscn levels are ignored")
	level.free()


func test_level_scene_displays_playable_level_number() -> void:
	var level := _prepare_level_scene()
	level.load_level(5)
	assert_eq(level._cur_cfg.get("id", -1), 5, "raw exported level 6 is player-facing level 5")
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


func test_level_scene_renders_blockers_as_keyed_barrier_ice_sprites() -> void:
	var level := _prepare_level_scene()
	level.load_level(5)
	var expected := _count_positive_layer(level.board.coat)
	assert_true(expected > 0, "raw level 6 contains blocker coat cells")
	for y in level.board.coat.size():
		for x in level.board.coat[y].size():
			if level.board.coat[y][x] > 0:
				assert_eq(level.board.grid[y][x], ME.EMPTY, "visible blocker has no hidden gem underneath")
	assert_eq(_count_group_nodes(level, BARRIER_MARKER_NAME), expected, "every blocker coat cell renders one visible barrier sprite")
	var marker := _find_named_node(level, BARRIER_MARKER_NAME)
	assert_true(marker is Sprite2D, "barrier marker is a sprite")
	if marker is Sprite2D:
		var sprite := marker as Sprite2D
		assert_eq(sprite.texture.resource_path, BARRIER_ICE_SYNCED, "barriers use resources/barrier synced ice art")
		assert_true(sprite.material is ShaderMaterial, "barriers key out the magenta source background")
		var drawn_size: Vector2 = sprite.texture.get_size() * sprite.scale
		assert_true(drawn_size.x <= level.cell_size * 0.90 and drawn_size.y <= level.cell_size * 0.90, "barrier art stays inside one board cell")
	level.free()
