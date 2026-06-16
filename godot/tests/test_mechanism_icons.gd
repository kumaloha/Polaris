extends "res://tests/test_lib.gd"

const Board := preload("res://core/board.gd")
const ObjectiveIcons := preload("res://match3/objective_icons.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const ME := preload("res://core/match_engine.gd")
const STAR_GOLD := "res://assets/ui/ui_star_gold.png"

func _filled_layer(w: int, h: int, value: int) -> Array:
	var rows := []
	for y in range(h):
		var row := []
		for x in range(w):
			row.append(value)
		rows.append(row)
	return rows

func _prepare_level(width: int, height: int, board: Board = null) -> Node:
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
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(level)
	if board == null:
		board = Board.new(width, height, [0, 1, 2, 3, 4], 999999, 30, 7)
	level.board = board
	level.call("_compute_layout")
	return level

func _find_group(root: Node, group_name: String) -> Node:
	if root.is_in_group(group_name):
		return root
	for child in root.get_children():
		var found := _find_group(child, group_name)
		if found != null:
			return found
	return null

func _find_named(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_named(child, node_name)
		if found != null:
			return found
	return null

func _texture_of(node: Node) -> Texture2D:
	if node is Sprite2D:
		return (node as Sprite2D).texture
	if node is TextureRect:
		return (node as TextureRect).texture
	return null

func test_objective_icons_generate_all_mechanism_textures() -> void:
	for id in ["target_mark", "crystal_shell", "drop_exit", "nest", "line_h_gem", "line_v_gem", "burst_gem", "color_bomb_gem", "drop_relic"]:
		var tex: Texture2D = ObjectiveIcons.texture_for_mechanism(id, 64)
		assert_true(tex != null, "%s has a generated texture" % id)
		if tex != null:
			assert_true(tex.get_width() > 0 and tex.get_height() > 0, "%s texture is non-empty" % id)
		assert_true(String(ObjectiveIcons.asset_key_for_mechanism(id)).begins_with("generated:"), "%s has a generated asset key" % id)

func test_hud_uses_generated_mechanism_fallbacks_not_star_placeholder() -> void:
	var level := _prepare_level(4, 4)
	level.board = Board.new(4, 4, [0, 1, 2], 0, 20, 7, [], [
		{"type": "CLEAR_JELLY", "species": -1, "target": 1},
		{"type": "CLEAR_BLOCKER", "species": -1, "target": 1},
		{"type": "COLLECT_INGREDIENT", "species": -1, "target": 1},
	], _filled_layer(4, 4, 1), _filled_layer(4, 4, 1))
	var view: Array = level.hud.call("_objectives_view")
	assert_eq(view.size(), 3, "three objective cards")
	for i in range(view.size()):
		assert_true(view[i].get("icon_texture", null) is Texture2D, "objective %d uses a generated texture" % i)
		assert_true(String(view[i].get("icon_asset_key", "")).begins_with("generated:"), "objective %d records generated asset key" % i)
		assert_ne(view[i].get("icon", ""), STAR_GOLD, "objective %d does not fall back to the star placeholder" % i)
	level.free()

func test_board_view_creates_visible_mechanism_nodes() -> void:
	var board := Board.new(4, 4, [0, 1, 2], 999999, 30, 7)
	board.jelly = board._blank_fx()
	board.coat = board._blank_fx()
	board.jelly[0][0] = 1
	board.coat[1][1] = 1
	board.grid[1][1] = ME.EMPTY
	board.fx[1][1] = ME.SP_NONE
	board.exit_cols = [2]
	var level := _prepare_level(4, 4, board)
	level.board_view.rebuild(board)
	var jelly := _find_group(level.board_layer, "JellyGoalSprite")
	assert_true(jelly != null and jelly.visible, "target/jelly marker is a visible board node")
	assert_true(_texture_of(jelly) != null, "target/jelly marker has a non-blank generated texture")
	var crystal := _find_group(level.gem_layer, "CoatBarrierSprite")
	assert_true(crystal != null and crystal.visible, "crystal shell marker is a visible board node")
	assert_true(_texture_of(crystal) != null, "crystal shell marker has a non-blank generated texture")
	var exit := _find_group(level.board_layer, "DropExitSprite")
	assert_true(exit != null and exit.visible, "drop exit/nest marker is visible on exit columns")
	assert_true(_texture_of(exit) != null, "drop exit/nest marker has a non-blank generated texture")
	level.free()
