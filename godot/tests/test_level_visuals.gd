extends "res://tests/test_lib.gd"

const ClearVisuals := preload("res://match3/clear_visuals.gd")
const Board := preload("res://core/board.gd")
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


func test_colorbomb_idle_does_not_tween_board_position() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_colorbomb_idle")
	assert_true(start >= 0, "_play_colorbomb_idle exists")
	if start < 0:
		return
	var end: int = src.find("# ───────── 整页 UI", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_false(body.contains("root, \"position\""), "colorbomb idle must not tween root.position; fall/swap owns board position")
	assert_true(body.contains("\"offset\""), "colorbomb bob uses visual offset instead of board position")


func test_colorbomb_absorb_preview_leaves_residue_and_pulses_crystal() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_colorbomb_absorb_preview")
	assert_true(start >= 0, "_play_colorbomb_absorb_preview exists")
	if start < 0:
		return
	var end: int = src.find("func _show_colorbomb_virtual_conversion", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("Fx.spawn_absorb_residue"), "each absorbed gem leaves residue stardust at its source cell")
	assert_true(body.contains("_pulse_colorbomb_gold_glow"), "orb impact pulses the gold ground glow")
	assert_true(body.contains("_pulse_colorbomb_inner_stars"), "absorbed batch lights the crystal ball inner stars")


func test_colorbomb_resolve_has_no_final_particle_burst() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _resolve_colorbomb")
	assert_true(start >= 0, "_resolve_colorbomb exists")
	if start < 0:
		return
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("await _play_colorbomb_absorb_preview"), "colorbomb still plays the absorb sequence")
	assert_false(body.contains("Fx.spawn_explosion"), "colorbomb absorb should not add a final generic particle burst")

func test_level_colorbomb_filters_locked_direct_clears() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _resolve_colorbomb")
	assert_true(start >= 0, "_resolve_colorbomb exists")
	if start < 0:
		return
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("to_clear"), "colorbomb direct clear path filters account_clears locked cells")
	assert_true(body.contains("cake_blast"), "colorbomb direct clear path includes cake blast cells after filtering")
	assert_true(body.contains("ME._apply_clears(board.grid, board.fx, to_clear, [])"), "colorbomb direct clear applies only filtered cells")
	assert_false(body.contains("board.grid[p.y][p.x] = ME.EMPTY"), "colorbomb must not manually clear locked cells")

func test_level_consumed_move_paths_share_board_settlement() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _finish_consumed_move("), "Level exposes one consumed-move finish path")
	for name in ["func _try_swap", "func _resolve_colorbomb", "func _resolve_fusion"]:
		var start: int = src.find(name)
		assert_true(start >= 0, "%s exists" % name)
		if start < 0:
			continue
		var end: int = src.find("\nfunc ", start + 1)
		if end < 0:
			end = src.length()
		var body: String = src.substr(start, end - start)
		assert_true(body.contains("await _finish_consumed_move("), "%s uses Board settlement instead of local move-only bookkeeping" % name)

func test_level_collapse_refill_uses_core_layers_and_feed() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _collapse_and_refill")
	assert_true(start >= 0, "_collapse_and_refill exists")
	if start < 0:
		return
	var end: int = src.find("func debug_first_legal_swap", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("ME.apply_gravity(board.grid, board.fx, false, board._layers())"), "visual collapse uses core gravity so all movable layers stay aligned")
	assert_true(body.contains("ME.refill(board.grid, board.species, board.rng, board.fx"), "visual refill delegates to core refill")
	assert_true(body.contains("board.feed"), "visual refill respects scrolling feed")
	assert_true(body.contains("_sync_collapse_segment"), "visual collapse moves existing gem nodes instead of rebuilding the whole board")
	assert_true(src.contains("tween.tween_property"), "incremental collapse helper animates moved/refilled gem nodes")
	assert_false(body.contains("_sync_visuals_to_board()"), "visual collapse must not full-rerender the board after every clear")
	assert_false(body.contains("board.rng.randi() % board.species.size()"), "visual collapse must not hand-roll random refill")

func test_level_finish_consumed_move_does_not_full_rerender() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _finish_consumed_move")
	assert_true(start >= 0, "_finish_consumed_move exists")
	if start < 0:
		return
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("board._settle_consumed_move"), "finish path still delegates move settlement to Board")
	assert_false(body.contains("_sync_visuals_to_board()"), "move finish must not full-rerender the board after every ordinary clear")


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


func test_opening_drop_starts_gems_above_the_board() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_opening_drop_start_position"), "Level exposes opening drop start calculation")
	assert_true(level.has_method("_opening_drop_delay"), "Level exposes opening drop delay calculation")
	if not level.has_method("_opening_drop_start_position") or not level.has_method("_opening_drop_delay"):
		level.free()
		return
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var top_center := Vector2(125, 455)
	var low_center := Vector2(125, 455 + 5.0 * level.cell_size)
	var top_start: Vector2 = level.call("_opening_drop_start_position", top_center, 0)
	var low_start: Vector2 = level.call("_opening_drop_start_position", low_center, 5)
	assert_true(top_start.y < level.board_origin.y, "top-row gem begins above the board")
	assert_true(low_start.y < level.board_origin.y, "lower-row gem also begins above the board")
	assert_eq(top_start.y, low_start.y, "all opening gems enter from the same empty-board line")
	var top_delay: float = level.call("_opening_drop_delay", 0, 10)
	var bottom_delay: float = level.call("_opening_drop_delay", 9, 10)
	assert_true(bottom_delay < top_delay, "bottom row starts first so the board fills from bottom to top")
	assert_true(top_delay - bottom_delay >= 0.25, "opening drop is slow enough to read")
	level.free()


func test_opening_drop_uses_temporary_gems_for_ice_cells() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_opening_visual_species"), "Level exposes opening visual species calculation")
	if not level.has_method("_opening_visual_species"):
		level.free()
		return
	var coat := [
		[1, 0],
		[0, 0],
	]
	level.board = Board.new(2, 2, [0, 1], 0, 10, 1, [], [], [], coat)
	assert_eq(level.board.grid[0][0], ME.EMPTY, "ice logic cell still has no hidden gem")
	var visual_sp: int = level.call("_opening_visual_species", 0, 0)
	assert_true(level.board.species.has(visual_sp), "ice opening visual uses a temporary falling gem species")
	level.free()


func test_opening_freeze_casts_from_boss_before_unlock() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var freeze_start: int = src.find("func _play_opening_freeze")
	assert_true(freeze_start >= 0, "opening freeze phase exists")
	if freeze_start < 0:
		return
	var finish_idx: int = src.find("_finish_opening_drop(generation)", freeze_start)
	var beam_idx: int = src.find("Fx.spawn_beam(BOSS_C", freeze_start)
	var marker_idx: int = src.find("_show_opening_coat_marker", freeze_start)
	assert_true(beam_idx > freeze_start, "opening freeze casts beams from the boss position")
	assert_true(marker_idx > beam_idx, "ice marker appears after the boss beam")
	assert_true(finish_idx > marker_idx, "input unlock waits until freezing is done")
