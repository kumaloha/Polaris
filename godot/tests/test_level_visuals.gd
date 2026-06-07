extends "res://tests/test_lib.gd"

const ClearVisuals := preload("res://match3/clear_visuals.gd")
const ME := preload("res://core/match_engine.gd")


func _none_fx(w: int, h: int) -> Array:
	var fx := []
	for y in h:
		var row := []
		for x in w:
			row.append(ME.SP_NONE)
		fx.append(row)
	return fx


func test_bomb_blast_cells_use_trigger_gem_species() -> void:
	var grid := [
		[0, 1, 2, 3, 4],
		[1, 2, 3, 4, 5],
		[2, 3, 1, 5, 0],  # center (2,2)=blue trigger gem
		[3, 4, 5, 0, 1],
		[4, 5, 0, 1, 2],
	]
	var fx := _none_fx(5, 5)
	fx[2][2] = ME.SP_BOMB
	var cells: Array = ME.special_effect_cells(grid, Vector2i(2, 2), ME.SP_BOMB)
	var species: Dictionary = ClearVisuals.special_clear_species_overrides(grid, fx, cells)
	var kinds: Dictionary = ClearVisuals.special_clear_kind_overrides(grid, fx, cells)
	for p in cells:
		assert_eq(species.get(p, -1), 1, "3x3 cell %s uses trigger bomb species" % str(p))
		assert_eq(kinds.get(p, ME.SP_NONE), ME.SP_BOMB, "3x3 cell %s is marked as bomb-shaped visual clear" % str(p))


func test_virtual_colorbomb_bombs_color_their_3x3_blast_area() -> void:
	var grid := [
		[2, 3, 4, 5, 6],
		[3, 4, 5, 6, 7],
		[4, 5, 1, 7, 2],  # virtual bomb target at (2,2)=blue
		[5, 6, 7, 2, 3],
		[6, 7, 2, 3, 4],
	]
	var fx := _none_fx(5, 5)
	var virtual_fx := {Vector2i(2, 2): ME.SP_BOMB}
	var cells: Array = ME.special_effect_cells(grid, Vector2i(2, 2), ME.SP_BOMB)
	var species: Dictionary = ClearVisuals.special_clear_species_overrides(grid, fx, cells, {}, virtual_fx)
	var kinds: Dictionary = ClearVisuals.special_clear_kind_overrides(grid, fx, cells, {}, virtual_fx)
	assert_eq(species.get(Vector2i(1, 1), -1), 1, "virtual bomb corner uses target species")
	assert_eq(species.get(Vector2i(3, 3), -1), 1, "virtual bomb corner uses target species")
	assert_eq(kinds.get(Vector2i(1, 1), ME.SP_NONE), ME.SP_BOMB, "virtual bomb corner uses bounded bomb visual")
	assert_eq(kinds.get(Vector2i(3, 3), ME.SP_NONE), ME.SP_BOMB, "virtual bomb corner uses bounded bomb visual")
