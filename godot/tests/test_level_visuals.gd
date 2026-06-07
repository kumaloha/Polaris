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
	for p in cells:
		assert_eq(species.get(p, -1), 1, "3x3 cell %s uses trigger bomb species" % str(p))


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
	assert_eq(species.get(Vector2i(1, 1), -1), 1, "virtual bomb corner uses target species")
	assert_eq(species.get(Vector2i(3, 3), -1), 1, "virtual bomb corner uses target species")


func test_colorbomb_virtual_stripes_have_separate_conversion_phase() -> void:
	var virtual_fx := {
		Vector2i(1, 0): ME.SP_LINE_H,
		Vector2i(2, 1): ME.SP_LINE_V,
	}
	assert_true(ClearVisuals.colorbomb_combo_has_conversion_phase(virtual_fx), "colorbomb + 4-match specials first show converted stripes")
	assert_true(ClearVisuals.colorbomb_virtual_conversion_delay(virtual_fx) >= 0.45, "conversion phase is held long enough to read before detonation")
	assert_false(ClearVisuals.colorbomb_combo_has_conversion_phase({}), "plain colorbomb clears do not add a conversion phase")
	assert_eq(ClearVisuals.colorbomb_virtual_conversion_delay({}), 0.0, "plain colorbomb clears have no conversion delay")


func test_endgame_bonus_refills_and_stabilizes_before_result() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_endgame_bonus()")
	assert_true(start >= 0, "_play_endgame_bonus exists")
	if start < 0:
		return
	var end: int = src.find("# 程序绘制", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var clear_idx: int = body.find("ME._apply_clears(board.grid, board.fx, to_clear, [])")
	var collapse_idx: int = body.find("await _collapse_and_refill()", clear_idx)
	var cascade_idx: int = body.find("await _resolve_cascades()", clear_idx)
	var result_idx: int = body.find("ENDGAME_BONUS_RESULT_HOLD", clear_idx)
	assert_true(clear_idx >= 0, "endgame bonus applies clears")
	assert_true(collapse_idx > clear_idx, "endgame bonus refills after reward blasts")
	assert_true(cascade_idx > collapse_idx, "endgame bonus waits for cascades after refill")
	assert_true(result_idx > cascade_idx, "result panel waits until the board is stable")
