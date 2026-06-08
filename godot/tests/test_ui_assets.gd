extends "res://tests/test_lib.gd"

const CharacterData := preload("res://ui/character_data.gd")
const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const ME := preload("res://core/match_engine.gd")
const BARRIER_ICE_SOURCE := "resources/barrier/ob_ice.png"
const BARRIER_ICE_SYNCED := "res://assets/obstacles/ob_ice.png"
const BARRIER_MARKER_NAME := "CoatBarrierSprite"
const JELLY_GOAL_ICON := "res://assets/obstacles/ob_bubble.png"
const JELLY_MARKER_NAME := "JellyGoalSprite"
const WALL_STONE_SYNCED := "res://assets/obstacles/ob_stone.png"
const WALL_MARKER_NAME := "WallStoneSprite"
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


func _count_grid_value(grid: Array, expected: int) -> int:
	var count := 0
	for row in grid:
		for value in row:
			if int(value) == expected:
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
	assert_eq(view[0].get("label", ""), "清果冻", "jelly objective says what action clears the level")
	assert_eq(view[0].get("icon", ""), JELLY_GOAL_ICON, "jelly objective uses a readable jelly/bubble icon instead of a placeholder")
	assert_eq(view[0].get("progress", -1), 0, "jelly starts at zero progress")
	assert_eq(view[0].get("target", -1), 65, "fifth-level jelly target is shown")
	level.free()


func test_twelfth_playable_level_shows_jelly_goal_and_board_markers() -> void:
	assert_true(FileAccess.file_exists(JELLY_GOAL_ICON), "jelly goal icon exists")
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "12"], level._levels.size())
	assert_eq(raw_idx, 17, "player level 12 maps to raw exported lvl_17 after score-only gaps are skipped")
	level.load_level(raw_idx)
	var view: Array = level.call("_objectives_view")
	assert_eq(view.size(), 1, "twelfth playable level has one objective card")
	assert_eq(view[0].get("label", ""), "清果冻", "twelfth playable level explicitly asks the player to clear jelly tiles")
	assert_eq(view[0].get("icon", ""), JELLY_GOAL_ICON, "twelfth playable level uses the jelly goal icon")
	assert_eq(view[0].get("target", -1), 63, "twelfth playable level target count is shown")
	var expected := _count_positive_layer(level.board.jelly)
	assert_true(expected > 0, "twelfth playable level has jelly cells")
	assert_eq(_count_group_nodes(level, JELLY_MARKER_NAME), expected, "every remaining jelly cell renders a visible board marker")
	level.free()

func test_jelly_board_markers_do_not_use_round_goal_icon() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "12"], level._levels.size())
	level.load_level(raw_idx)
	var marker := _find_named_node(level, JELLY_MARKER_NAME)
	assert_true(marker != null, "jelly board marker exists")
	if marker is Sprite2D:
		var sprite := marker as Sprite2D
		assert_true(sprite.texture == null or sprite.texture.resource_path != JELLY_GOAL_ICON, "board jelly marker must not reuse the round goal icon under gems")
	level.free()


func test_sixth_playable_level_objective_view_shows_collect_goal() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "6"], level._levels.size())
	assert_eq(raw_idx, 7, "player level 6 maps to raw exported lvl_7 after score-only gaps are skipped")
	level.load_level(raw_idx)
	var view: Array = level.call("_objectives_view")
	assert_eq(view.size(), 1, "sixth playable level has one objective card")
	assert_eq(view[0].get("label", ""), "收集", "sixth playable level is a collect goal")
	assert_eq(view[0].get("icon", ""), "res://art/gems/base/gem_heart.png", "sixth playable level collects the pink heart gem")
	assert_eq(view[0].get("target", -1), 42, "sixth playable level target is shown")
	level.free()


func test_score_fallback_level_objective_view_shows_score_target() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.board = Board.new(3, 3, [0, 1, 2], 5119, 25, 1)
	var view: Array = level.call("_objectives_view")
	assert_eq(view.size(), 1, "score-only levels still show one real objective card")
	if view.is_empty():
		level.free()
		return
	assert_eq(view[0].get("label", ""), "分数", "score-only level is labeled as score")
	assert_eq(view[0].get("progress", -1), 0, "score-only level starts at zero score progress")
	assert_eq(view[0].get("target", -1), 5119, "score-only level target score is shown")
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
		# ob_ice 实体冰晶仅占贴图~0.69(四周透明边), 放大补偿使可见实体≈cell*0.86 在格内;
		# 整图(含透明边)尺寸=cell*1.26, 故阈值按实体0.90对应的整图(0.90/0.686≈1.31)放宽。
		var drawn_size: Vector2 = sprite.texture.get_size() * sprite.scale
		assert_true(drawn_size.x <= level.cell_size * 1.31 and drawn_size.y <= level.cell_size * 1.31, "barrier visible art stays inside one board cell")
	level.free()


func test_level_scene_renders_wall_cells_as_stone_sprites() -> void:
	assert_true(FileAccess.file_exists(WALL_STONE_SYNCED), "wall stone art exists")
	var level := _prepare_level_scene()
	level.load_level(13)
	var expected := _count_grid_value(level.board.grid, ME.WALL)
	assert_true(expected > 0, "raw level 9 contains wall cells")
	assert_eq(_count_group_nodes(level, WALL_MARKER_NAME), expected, "every wall cell renders one visible stone sprite")
	var marker := _find_named_node(level, WALL_MARKER_NAME)
	assert_true(marker is Sprite2D, "wall marker is a sprite")
	if marker is Sprite2D:
		var sprite := marker as Sprite2D
		assert_eq(sprite.texture.resource_path, WALL_STONE_SYNCED, "walls use stone obstacle art")
		var drawn_size: Vector2 = sprite.texture.get_size() * sprite.scale
		assert_true(drawn_size.x <= level.cell_size * 0.92 and drawn_size.y <= level.cell_size * 0.92, "wall art stays inside one board cell")
	level.free()


func test_wall_slide_source_map_replays_gravity_order() -> void:
	var level := _prepare_level_scene()
	level.board = Board.new(3, 4, [0, 1, 2], 0, 25, 1)
	level.board.is_scrolling = true
	var E := ME.EMPTY
	var W := ME.WALL
	var before_grid := [
		[10, W, 11],
		[5, E, 6],
		[7, E, 9],
		[1, 2, 3],
	]
	assert_true(level.has_method("_build_wall_slide_source_map"), "wall slide visuals can replay gravity to map targets to exact old sources")
	if not level.has_method("_build_wall_slide_source_map"):
		level.free()
		return
	var source_map: Array = level.call("_build_wall_slide_source_map", before_grid)
	assert_eq(source_map[2][1], Vector2i(2, 1), "lower blocked slot uses the immediate right-above tile, matching gravity order")
	assert_eq(source_map[1][1], Vector2i(2, 0), "upper blocked slot then uses the top right tile after the lower move")
	level.free()


func test_wall_slide_source_map_tracks_spawn_source_column() -> void:
	var level := _prepare_level_scene()
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	var E := ME.EMPTY
	var W := ME.WALL
	var before_grid := [
		[E, W, E],
		[5, E, 6],
		[7, 8, 9],
	]
	assert_true(level.has_method("_build_wall_slide_source_map"), "wall slide visuals can replay spawned sources")
	if not level.has_method("_build_wall_slide_source_map"):
		level.free()
		return
	var source_map: Array = level.call("_build_wall_slide_source_map", before_grid)
	var source: Vector2i = source_map[1][1]
	assert_eq(source.x, 2, "new piece filling the wall pocket should enter from the right top column, matching gravity's right-above priority")
	assert_true(source.y < 0, "spawned source is marked as a new piece rather than an old board node")
	level.free()


func test_wall_slide_path_map_preserves_delayed_diagonal_step() -> void:
	var level := _prepare_level_scene()
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board.is_scrolling = true
	var E := ME.EMPTY
	var W := ME.WALL
	var before_grid := [
		[E, E, 11],
		[E, W, E],
		[7, E, 9],
	]
	assert_true(level.has_method("_build_wall_slide_path_map"), "wall slide visuals record each gravity step, not just final source")
	if not level.has_method("_build_wall_slide_path_map"):
		level.free()
		return
	var path_map: Array = level.call("_build_wall_slide_path_map", before_grid)
	assert_eq(path_map[2][1], [Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 2)], "piece falls vertically first, then diagonally into the wall pocket")
	level.free()


func test_wall_slide_tracking_maps_stress_paths_are_contiguous() -> void:
	var level := _prepare_level_scene()
	level.board = Board.new(6, 7, [0, 1, 2, 3], 0, 25, 1)
	assert_true(level.has_method("_build_wall_slide_tracking_maps"), "wall slide visuals expose source/path tracking maps for stress validation")
	if not level.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	for seed in range(48):
		level.board.is_scrolling = seed % 2 == 0
		var before_grid := []
		for row in range(level.board.height):
			var out_row := []
			for col in range(level.board.width):
				var roll: int = int((seed * 31 + row * 17 + col * 13 + row * col * 7) % 12)
				if roll == 0 and row > 0 and row < level.board.height - 1:
					out_row.append(ME.WALL)
				elif roll <= 3:
					out_row.append(ME.EMPTY)
				else:
					out_row.append(seed * 100 + row * level.board.width + col)
			before_grid.append(out_row)
		var maps: Dictionary = level.call("_build_wall_slide_tracking_maps", before_grid)
		var source_map: Array = maps["source"]
		var path_map: Array = maps["path"]
		for row in range(level.board.height):
			for col in range(level.board.width):
				var path: Array = path_map[row][col]
				if path.is_empty():
					continue
				assert_eq(path[path.size() - 1], Vector2i(col, row), "path ends at its visual target for seed %d cell (%d,%d)" % [seed, col, row])
				var source: Vector2i = source_map[row][col]
				if source.y >= 0:
					assert_eq(path[0], source, "old piece path starts at the exact source for seed %d cell (%d,%d)" % [seed, col, row])
				elif source.y == -2:
					assert_eq(path[0], Vector2i(source.x, 0), "spawned path starts at the top entry column for seed %d cell (%d,%d)" % [seed, col, row])
				for idx in range(1, path.size()):
					var prev: Vector2i = path[idx - 1]
					var next: Vector2i = path[idx]
					assert_eq(next.y - prev.y, 1, "gravity path never skips a row for seed %d cell (%d,%d)" % [seed, col, row])
					assert_true(absi(next.x - prev.x) <= 1, "gravity path never jumps across columns for seed %d cell (%d,%d)" % [seed, col, row])
	level.free()
