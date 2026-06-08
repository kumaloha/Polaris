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


func test_colorbomb_clear_fx_has_bounded_final_burst_budget() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("COLORBOMB_ABSORB_TARGET_BUDGET"), "colorbomb absorb preview has an explicit fanout budget")
	assert_true(src.contains("COLORBOMB_FINE_CLEAR_BUDGET"), "colorbomb final clear has an explicit fine FX budget")
	assert_true(src.contains("COLORBOMB_CLEAR_FX_BATCH_SIZE"), "colorbomb final clear work is batched across frames")
	assert_true(src.contains("mini(targets.size(), COLORBOMB_ABSORB_TARGET_BUDGET)"), "absorb preview uses the named fanout budget")
	assert_true(src.contains("COLORBOMB_FINE_CLEAR_BUDGET") and not src.contains("fine_budget: int = 36"), "final clear no longer bursts dozens of basic pops in one frame")
	assert_true(src.contains("await get_tree().process_frame"), "final clear FX yields between batches to avoid a last-frame spike")
	var start: int = src.find("func _resolve_colorbomb")
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("if ClearVisuals.colorbomb_combo_has_conversion_phase(virtual_fx):\n\t\tawait _show_colorbomb_virtual_conversion(virtual_fx)\n\tvar fine_budget"), "final clear FX budget runs for plain colorbombs too, not only conversion combos")


func test_level_clear_pops_gem_body_before_fade() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("CLEAR_POP_SCALE"), "level defines a visible gem-body clear pop scale")
	assert_true(src.contains("CLEAR_POP_TIME"), "level defines a short gem-body clear pop phase")
	var start: int = src.find("func _play_clear")
	assert_true(start >= 0, "_play_clear exists")
	if start < 0:
		return
	var end: int = src.find("## 某已存在特效棋子", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("\n\t\tif not spawn_set.has(p):"), "all cleared non-spawn gems pop/fade, including existing special gems")
	assert_true(body.contains("base_scale * CLEAR_POP_SCALE"), "clearing gem body first swells above its base scale")
	assert_true(body.contains("base_scale * 0.1"), "clearing gem body still collapses out after the swell")
	assert_true(body.find("base_scale * CLEAR_POP_SCALE") < body.find("base_scale * 0.1"), "gem body swell is scheduled before collapse")

func test_level_clear_batches_vfx_creation_across_frames() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("CLEAR_FX_BATCH_SIZE"), "level defines a clear VFX batch size")
	var start: int = src.find("func _play_clear")
	assert_true(start >= 0, "_play_clear exists")
	if start < 0:
		return
	var end: int = src.find("## 某已存在特效棋子", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("spawned_fx_count"), "_play_clear tracks spawned VFX per batch")
	assert_true(body.contains("CLEAR_FX_BATCH_SIZE"), "_play_clear uses the named batch size")
	assert_true(body.contains("await get_tree().process_frame"), "large clears yield between VFX batches instead of allocating every effect in one frame")

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

func test_double_bomb_fusion_plays_both_burst_centers() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _play_double_bomb_fusion_fx"), "Level has an explicit two-center double-bomb fusion visual")
	var fusion_start: int = src.find("func _play_fusion_fx_after_swap")
	var fusion_end: int = src.find("func _play_wide_line_fx", fusion_start)
	assert_true(fusion_start >= 0 and fusion_end > fusion_start, "_play_fusion_fx_after_swap can be inspected")
	if fusion_start < 0 or fusion_end <= fusion_start:
		return
	var fusion_body: String = src.substr(fusion_start, fusion_end - fusion_start)
	assert_true(fusion_body.contains("_play_double_bomb_fusion_fx(a_after, b_after)"), "double cross fusion delegates to a two-center burst helper")
	var helper_start: int = src.find("func _play_double_bomb_fusion_fx")
	var helper_end: int = src.find("func _play_wide_line_fx", helper_start)
	assert_true(helper_start >= 0 and helper_end > helper_start, "_play_double_bomb_fusion_fx can be inspected")
	if helper_start < 0 or helper_end <= helper_start:
		return
	var helper_body: String = src.substr(helper_start, helper_end - helper_start)
	assert_true(helper_body.contains("_cell_center(a_after.y, a_after.x)"), "first swapped bomb center gets a visible burst")
	assert_true(helper_body.contains("_cell_center(b_after.y, b_after.x)"), "second swapped bomb center gets a visible burst")
	assert_true(helper_body.count("Fx.spawn_local_burst") >= 2, "double cross fusion must emit two local burst effects")

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

func test_level_collapse_refill_repairs_missing_visual_gems() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _repair_missing_gem_nodes_from_board"), "Level exposes a targeted visual hole repair helper")
	var start: int = src.find("func _collapse_and_refill")
	assert_true(start >= 0, "_collapse_and_refill exists")
	if start < 0:
		return
	var end: int = src.find("func debug_first_legal_swap", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var assign_idx: int = body.find("_gem_nodes = new_nodes")
	var repair_idx: int = body.find("_repair_missing_gem_nodes_from_board()", assign_idx)
	var coat_idx: int = body.find("_refresh_coat_visuals()", assign_idx)
	assert_true(assign_idx >= 0, "collapse stores the incremental visual grid")
	assert_true(repair_idx > assign_idx, "collapse repairs missing gem sprites after storing the incremental visual grid")
	assert_true(coat_idx > repair_idx, "layer overlays refresh after visual hole repair")

func test_level_wall_collapse_uses_cross_column_slide_visuals() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _sync_wall_slide_visuals"), "Level has a wall-aware cross-column visual collapse helper")
	assert_true(src.contains("func _grid_has_fall_obstacle"), "Level detects all gravity-blocking cells, not only stone walls")
	var start: int = src.find("func _collapse_and_refill")
	assert_true(start >= 0, "_collapse_and_refill exists")
	if start < 0:
		return
	var end: int = src.find("func debug_first_legal_swap", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("_grid_has_fall_obstacle(before_grid)"), "collapse detects obstacle boards before visual syncing")
	assert_true(body.contains("_grid_has_fall_obstacle(board.grid)"), "collapse keeps tracking visuals active after refill")
	assert_true(body.contains("_sync_wall_slide_visuals(before_grid, old_nodes"), "obstacle boards use cross-column slide visuals instead of per-column segment-only syncing")


func test_wall_slide_tracking_maps_include_coat_blockers() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_build_wall_slide_tracking_maps"), "Level can replay visual gravity routes")
	if not level.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board.grid = [
		[0, ME.EMPTY, 2],
		[0, ME.EMPTY, 3],
		[0, 0, 0],
	]
	level.board.fx = _none_fx(3, 3)
	level.board.coat = [
		[0, 1, 0],
		[0, 0, 0],
		[0, 0, 0],
	]
	var maps: Dictionary = level.call("_build_wall_slide_tracking_maps", level.board.grid.duplicate(true))
	var source_map: Array = maps["source"]
	var path_map: Array = maps["path"]
	assert_eq(source_map[1][1], Vector2i(2, 0), "coat blocker above a target replays the same diagonal source as core gravity")
	assert_true(path_map[1][1].size() >= 2, "coat-assisted slide keeps a visible step path")
	if path_map[1][1].size() >= 2:
		assert_eq(path_map[1][1][0], Vector2i(2, 0), "path starts at the diagonal source")
		assert_eq(path_map[1][1][path_map[1][1].size() - 1], Vector2i(1, 1), "path ends at the opened slot")
	level.free()


func test_wall_slide_tracking_waits_for_vertical_chain_before_diagonal() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_build_wall_slide_tracking_maps"), "Level can replay visual gravity routes")
	if not level.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	level.board = Board.new(3, 4, [0, 1, 2], 0, 25, 1)
	level.board.grid = [
		[ME.EMPTY, ME.WALL, ME.EMPTY],
		[10, 12, 11],
		[5, ME.EMPTY, 6],
		[7, ME.EMPTY, 9],
	]
	level.board.fx = _none_fx(3, 4)
	var maps: Dictionary = level.call("_build_wall_slide_tracking_maps", level.board.grid.duplicate(true))
	var source_map: Array = maps["source"]
	var path_map: Array = maps["path"]
	assert_eq(source_map[3][1], Vector2i(1, 1), "visual gravity keeps the lower pocket on the same-column source while vertical fill is possible")
	assert_false(source_map[3][1] == Vector2i(2, 2), "visual gravity must not steal the right-above candidate before the vertical chain resolves")
	assert_eq(path_map[3][1], [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)], "visual path shows a continuous vertical fall, not a diagonal jump")
	level.free()

func test_level_wall_slide_visuals_tween_cell_steps() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("WALL_SLIDE_STEP_TIME"), "wall slide animation has a per-cell step duration")
	assert_true(src.contains("func _wall_slide_path_points"), "Level exposes a path builder for wall slide visuals")
	assert_true(src.contains("func _wall_slide_position_at"), "Level samples wall slide paths continuously")
	assert_true(src.contains("func _tween_wall_slide_node"), "Level tweens wall slide nodes through path steps")
	var start: int = src.find("func _sync_wall_slide_visuals")
	assert_true(start >= 0, "_sync_wall_slide_visuals exists")
	if start < 0:
		return
	var end: int = src.find("func _collapse_and_refill", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("_tween_wall_slide_node(node"), "wall slide sync delegates movement to stepped tween helper")
	assert_false(body.contains("tween.tween_property(node, \"position\", target, FALL_TIME)"), "wall slide must not jump directly to the final target in one tween")
	var tween_start: int = src.find("func _tween_wall_slide_node")
	var tween_end: int = src.find("func _take_wall_slide_source", tween_start)
	var tween_body: String = src.substr(tween_start, tween_end - tween_start)
	assert_true(tween_body.contains("tween_method"), "wall slide uses one continuous tween across the stepped path instead of restarting at every cell")
	assert_false(tween_body.contains("tween_property(node, \"position\""), "wall slide helper should not chain per-cell position tweens")

func test_wall_slide_spawned_piece_enters_vertically_before_sliding() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_path_points"), "Level exposes wall slide path calculation")
	if not level.has_method("_wall_slide_path_points"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var start := Vector2(90 + 2.5 * level.cell_size, level.board_origin.y - 2.0 * level.cell_size)
	var target := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y + 2.5 * level.cell_size)
	var points: Array = level.call("_wall_slide_path_points", start, target)
	assert_false(points.is_empty(), "spawn path has points")
	if points.is_empty():
		level.free()
		return
	var first: Vector2 = points[0]
	assert_eq(first.x, start.x, "spawned wall-slide piece first falls vertically in its source column")
	assert_true(first.y > start.y, "spawned wall-slide piece enters downward before any sideways movement")
	level.free()


func test_wall_slide_visual_path_uses_recorded_gravity_route() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_cell_path_points"), "Level can convert recorded gravity cells into visual path points")
	if not level.has_method("_wall_slide_cell_path_points"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var start := Vector2(90 + 2.5 * level.cell_size, level.board_origin.y + 0.5 * level.cell_size)
	var target := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y + 2.5 * level.cell_size)
	var route := [Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 2)]
	var points: Array = level.call("_wall_slide_cell_path_points", start, route, target)
	assert_true(points.size() >= 2, "recorded route has at least the intermediate and target points")
	if points.size() < 2:
		level.free()
		return
	var first: Vector2 = points[0]
	assert_eq(first, Vector2(90 + 2.5 * level.cell_size, level.board_origin.y + 1.5 * level.cell_size), "visual follows the actual first vertical gravity step")
	assert_eq(points[points.size() - 1], target, "visual ends at the target cell")
	level.free()


func test_wall_slide_long_paths_keep_per_cell_pacing() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_duration_for_points"), "Level exposes wall slide duration calculation")
	if not level.has_method("_wall_slide_duration_for_points"):
		level.free()
		return
	var points := []
	for idx in range(10):
		points.append(Vector2(0, float(idx) * 70.0))
	var duration: float = level.call("_wall_slide_duration_for_points", points)
	assert_true(duration >= 0.65, "ten cell-steps must not be compressed under the per-cell pacing budget")
	level.free()


func test_wall_slide_replacement_node_starts_at_recorded_source() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_visual_start_position"), "Level can place replacement visuals at the recorded source")
	if not level.has_method("_wall_slide_visual_start_position"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var N := Vector2i(-1, -1)
	var source_map := [
		[N, N, N],
		[N, N, N],
		[N, Vector2i(2, 0), N],
	]
	var path_map := [
		[[], [], []],
		[[], [], []],
		[[], [Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 2)], []],
	]
	var start: Vector2 = level.call("_wall_slide_visual_start_position", source_map, path_map, 2, 1)
	assert_eq(start, Vector2(90 + 2.5 * level.cell_size, level.board_origin.y + 0.5 * level.cell_size), "replacement node starts where the logical source was, not above the target column")
	level.free()


func test_ordinary_long_falls_keep_per_cell_pacing() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_fall_duration_for_positions"), "Level exposes ordinary fall duration calculation")
	if not level.has_method("_fall_duration_for_positions"):
		level.free()
		return
	level.cell_size = 70.0
	var duration: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 700))
	assert_true(duration >= 0.65, "ordinary ten-cell fall must not be squeezed into the one-cell fall duration")
	level.free()


func test_fall_durations_scale_with_each_cell_step() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.cell_size = 70.0
	var one_cell: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 70))
	var two_cells: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 140))
	var ten_cells: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 700))
	assert_true(one_cell >= 0.19, "one-cell fall should not feel instant")
	assert_true(two_cells > one_cell, "a two-cell fall still reads as a longer fall")
	assert_true(two_cells < one_cell * 1.6, "fall timing accelerates instead of adding a full duration per cell")
	assert_true(ten_cells >= 0.80, "long falls should remain readable")
	assert_true(ten_cells <= 0.95, "long falls must not feel sluggish")
	var wall_one: float = level.call("_wall_slide_duration_for_points", [Vector2(0, 70)])
	var wall_three: float = level.call("_wall_slide_duration_for_points", [Vector2(0, 70), Vector2(0, 140), Vector2(70, 210)])
	assert_true(wall_three > wall_one, "multi-step wall slide still takes longer than one step")
	assert_true(wall_three < wall_one * 2.5, "multi-step wall slide also accelerates")
	level.free()

func test_level_fall_animation_timing_is_slightly_slower() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("const FALL_TIME := 0.20"), "ordinary one-cell falling is readable without dragging")
	assert_true(src.contains("const FALL_EXTRA_CELL_TIME := 0.075"), "longer falls add a moderate accelerated increment per extra cell")
	assert_true(src.contains("const WALL_SLIDE_STEP_TIME := 0.065"), "wall slide timing is a little slower than the too-fast pass")
	assert_true(src.contains("const WALL_SLIDE_MAX_TIME := 0.85"), "wall slide wait cap prevents long obstacle paths from dragging")

func test_level_wall_slide_visuals_only_cross_columns_under_fall_obstacles() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _wall_slide_target_has_fall_obstacle_above"), "Level can tell whether a target is under a gravity-blocking obstacle")
	var take_start: int = src.find("func _take_wall_slide_source")
	var take_end: int = src.find("func _free_unused_wall_slide_sources", take_start)
	assert_true(take_start >= 0 and take_end > take_start, "_take_wall_slide_source body can be inspected")
	if take_start < 0 or take_end <= take_start:
		return
	var take_body: String = src.substr(take_start, take_end - take_start)
	assert_true(take_body.contains("allow_cross_column"), "source matching receives a per-target cross-column gate")
	assert_true(take_body.contains("col != target_col"), "non-wall targets reject adjacent-column visual sources")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	assert_true(sync_body.contains("_wall_slide_target_has_fall_obstacle_above(before_grid, row, col)"), "only cells below actual fall blockers may use diagonal visual sourcing")

func test_level_wall_slide_source_prefers_right_above_before_left_above() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _wall_slide_source_priority"), "wall slide visuals expose a deterministic source priority helper")
	var start: int = src.find("func _wall_slide_source_priority")
	var end: int = src.find("func _take_wall_slide_source", start)
	assert_true(start >= 0 and end > start, "wall slide source priority body can be inspected")
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("col == target_col + 1"), "right-above source has an explicit priority branch")
	assert_true(body.contains("col == target_col - 1"), "left-above source has an explicit priority branch")
	assert_true(body.find("col == target_col + 1") < body.find("col == target_col - 1"), "right-above branch is checked before left-above")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	assert_true(sync_start >= 0 and sync_end > sync_start, "_sync_wall_slide_visuals can be inspected")
	if sync_start < 0 or sync_end <= sync_start:
		return
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	assert_true(sync_body.contains("_build_wall_slide_tracking_maps(before_grid)"), "wall slide visuals build source and path maps by replaying gravity")
	assert_true(sync_body.contains("_take_wall_slide_source(before_grid, old_nodes, used, row, col, sp, allow_cross_column, source_map)"), "wall slide visuals pick old nodes from the replayed source map")


func test_level_wall_refill_start_uses_spawn_source_map() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _wall_slide_spawn_source_col"), "wall slide visuals can recover the spawned top source column")
	var refill_start: int = src.find("func _wall_refill_start_position")
	var refill_end: int = src.find("func _wall_slide_target_has_fall_obstacle_above", refill_start)
	assert_true(refill_start >= 0 and refill_end > refill_start, "_wall_refill_start_position can be inspected")
	if refill_start < 0 or refill_end <= refill_start:
		return
	var refill_body: String = src.substr(refill_start, refill_end - refill_start)
	assert_true(refill_body.contains("_wall_slide_spawn_source_col(source_map, row, col)"), "new wall-slide pieces start from the exact spawned source column")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	assert_true(sync_start >= 0 and sync_end > sync_start, "_sync_wall_slide_visuals can be inspected")
	if sync_start < 0 or sync_end <= sync_start:
		return
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	assert_true(sync_body.contains("_wall_slide_visual_start_position(source_map, path_map, row, col)"), "wall-slide visual refill passes the replayed source and path maps into start-position calculation")
	var start_pos_start: int = src.find("func _wall_slide_visual_start_position")
	var start_pos_end: int = src.find("func _free_unused_wall_slide_sources", start_pos_start)
	assert_true(start_pos_start >= 0 and start_pos_end > start_pos_start, "_wall_slide_visual_start_position can be inspected")
	if start_pos_start >= 0 and start_pos_end > start_pos_start:
		var start_pos_body: String = src.substr(start_pos_start, start_pos_end - start_pos_start)
		assert_true(start_pos_body.contains("_wall_refill_start_position(row, col, source_map)"), "spawned replacement pieces still use the source-map-aware off-board start")
	assert_false(sync_body.contains("_wall_refill_start_position(row, col, allow_cross_column)"), "wall-slide visual refill must not guess the start column from allow_cross_column alone")


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
	assert_false(body.contains("_sync_changed_visuals_to_board()"), "move finish must not snap changed board visuals to their final cells")
	assert_true(body.contains("await _animate_board_changes_from_snapshot"), "move finish animates post-settlement board changes instead of jumping")


func test_level_swap_passes_moved_position_to_first_cascade() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var swap_start: int = src.find("func _try_swap")
	assert_true(swap_start >= 0, "_try_swap exists")
	var swap_end: int = src.find("\n\t## 问题2", swap_start)
	if swap_end < 0:
		swap_end = src.find("\nfunc ", swap_start + 1)
	if swap_start < 0:
		return
	var swap_body: String = src.substr(swap_start, swap_end - swap_start)
	assert_false(swap_body.contains("_line_kind_from_swap"), "swap direction must not override generated line-special kind")
	assert_true(swap_body.contains("_resolve_cascades(b)"), "first cascade still receives the moved piece's new position")

	var resolve_start: int = src.find("func _resolve_cascades")
	assert_true(resolve_start >= 0, "_resolve_cascades exists")
	if resolve_start < 0:
		return
	var resolve_end: int = src.find("\nfunc ", resolve_start + 1)
	if resolve_end < 0:
		resolve_end = src.length()
	var resolve_body: String = src.substr(resolve_start, resolve_end - resolve_start)
	assert_true(resolve_body.contains("ME.collect_clears(board.grid, board.fx, board._layers(), cascade_preferred)"), "collect_clears receives the first-cascade spawn position")
	assert_false(resolve_body.contains("cascade_preferred_line_kind"), "line-special kind is decided by the 4-match rule, not swap direction")


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


func test_opening_drop_uses_temporary_gems_for_wall_cells() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_opening_visual_species"), "Level exposes opening visual species calculation")
	if not level.has_method("_opening_visual_species"):
		level.free()
		return
	var wall_mask := [
		[true, false],
		[false, false],
	]
	level.board = Board.new(2, 2, [0, 1], 0, 10, 1, wall_mask)
	assert_eq(level.board.grid[0][0], ME.WALL, "stone logic cell is still a wall")
	var visual_sp: int = level.call("_opening_visual_species", 0, 0)
	assert_true(level.board.species.has(visual_sp), "stone opening visual uses a temporary falling gem species")
	level.free()


func test_opening_obstacle_markers_replace_temporary_gems() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var wall_start: int = src.find("func _show_opening_wall_marker")
	var wall_end: int = src.find("func _show_opening_coat_marker", wall_start)
	assert_true(wall_start >= 0 and wall_end > wall_start, "wall opening marker function can be inspected")
	if wall_start < 0 or wall_end <= wall_start:
		return
	var wall_body: String = src.substr(wall_start, wall_end - wall_start)
	assert_true(wall_body.contains("_clear_gem_node_at(pos.y, pos.x)"), "stone cast removes the temporary gem before showing the stone")

	var coat_start: int = src.find("func _show_opening_coat_marker")
	var coat_end: int = src.find("func _play_opening_freeze", coat_start)
	assert_true(coat_start >= 0 and coat_end > coat_start, "ice opening marker function can be inspected")
	if coat_start < 0 or coat_end <= coat_start:
		return
	var coat_body: String = src.substr(coat_start, coat_end - coat_start)
	assert_true(coat_body.contains("_clear_gem_node_at(pos.y, pos.x)"), "ice cast removes the temporary gem before showing the ice")


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


func test_opening_boss_casts_stones_before_ice() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var render_start: int = src.find("func _render_board")
	var render_end: int = src.find("func _blank_visual_rows", render_start)
	assert_true(render_start >= 0 and render_end > render_start, "_render_board can be inspected")
	if render_start < 0 or render_end <= render_start:
		return
	var render_body: String = src.substr(render_start, render_end - render_start)
	assert_true(render_body.contains("if opening_drop:\n\t\t_wall_nodes = _blank_visual_rows()\n\telse:\n\t\t_render_wall_visuals()"), "opening drop keeps wall stones hidden until the boss casts them")

	var freeze_start: int = src.find("func _play_opening_freeze")
	var freeze_end: int = src.find("func _apply_opening_freeze_instant", freeze_start)
	assert_true(freeze_start >= 0 and freeze_end > freeze_start, "opening freeze phase can be inspected")
	if freeze_start < 0 or freeze_end <= freeze_start:
		return
	var freeze_body: String = src.substr(freeze_start, freeze_end - freeze_start)
	var wall_cells_idx: int = freeze_body.find("_opening_wall_cells()")
	var coat_cells_idx: int = freeze_body.find("_opening_coat_cells()")
	var wall_beam_idx: int = freeze_body.find("OPENING_STONE_COLOR")
	var wall_marker_idx: int = freeze_body.find("_show_opening_wall_marker(p, true)")
	var coat_marker_idx: int = freeze_body.find("_show_opening_coat_marker(p, true)")
	assert_true(wall_cells_idx >= 0, "opening freeze gathers wall stone cells")
	assert_true(coat_cells_idx > wall_cells_idx, "ice cells are gathered after stone cells")
	assert_true(wall_beam_idx >= 0, "stone generation uses a boss beam color")
	assert_true(wall_marker_idx > wall_beam_idx, "stone marker appears after the boss beam")
	assert_true(coat_marker_idx > wall_marker_idx, "ice marker appears after all stone markers")
