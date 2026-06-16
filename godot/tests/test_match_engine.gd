extends "res://tests/test_lib.gd"

const ME := preload("res://core/match_engine.gd")

# grid[y][x]，坐标 Vector2i(x, y)
func test_find_horizontal_three() -> void:
	var grid := [
		[0, 0, 0, 1],
		[1, 2, 3, 2],
		[2, 3, 1, 0],
	]
	var matched: Array = ME.find_matches(grid)
	assert_eq(matched.size(), 3, "expected exactly 3 matched cells")
	assert_true(matched.has(Vector2i(0, 0)), "missing (0,0)")
	assert_true(matched.has(Vector2i(1, 0)), "missing (1,0)")
	assert_true(matched.has(Vector2i(2, 0)), "missing (2,0)")

func test_find_matches_ignores_walls() -> void:
	var W := ME.WALL
	var grid := [
		[W, W, W, 0],
		[1, 2, 3, 0],
		[1, 2, 3, 0],
	]
	var m: Array = ME.find_matches(grid)
	assert_eq(m.size(), 3, "only the real match; walls never match")
	for p in m:
		assert_true(grid[p.y][p.x] != W, "no wall cell in matches")

func test_gravity_respects_wall_segments() -> void:
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [[1], [E], [W], [E], [2]]
	ME.apply_gravity(grid)
	assert_eq(grid, [[E], [1], [W], [E], [2]], "tiles fall within wall-bounded segments")

func test_refill_does_not_spawn_directly_below_wall() -> void:
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [[W], [E], [0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	ME.refill(grid, [7], rng)
	assert_eq(grid[1][0], E, "refill must not create a piece in an unreachable pocket below a wall")

func test_refill_slides_feed_from_adjacent_top_under_wall() -> void:
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [
		[E, W, E],
		[5, E, 6],
		[7, 8, 9],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var feed := [[10], [], []]
	ME.refill(grid, [1, 2, 3], rng, [], feed)
	assert_eq(grid[1][1], 10, "top-fed piece from the adjacent column slides diagonally into the wall pocket")
	assert_eq(grid[0][0], E, "the fed source column is empty after the piece slid away and feed was exhausted")

func test_wall_gravity_fills_blocked_slot_from_right_above_before_left_above() -> void:
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [
		[10, W, 11],
		[5, E, 6],
		[7, 8, 9],
	]
	ME.apply_gravity(grid)
	assert_eq(grid[1][1], 11, "blocked empty slot fills from right-above before left-above")
	assert_eq(grid[0][2], E, "right-above source moved into the blocked slot")
	assert_eq(grid[0][0], 10, "left-above source waits when right-above can fill first")

func test_wall_gravity_fills_blocked_slot_from_direct_above_before_diagonals() -> void:
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [
		[E, W, E],
		[10, 12, 11],
		[5, E, 6],
		[7, 8, 9],
	]
	ME.apply_gravity(grid)
	assert_eq(grid[2][1], 12, "directly-above source fills a slot before diagonal candidates")
	assert_eq(grid[1][1], E, "directly-above source moved down")

func test_wall_gravity_waits_for_vertical_chain_before_diagonal() -> void:
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [
		[E, W, E],
		[10, 12, 11],
		[5, E, 6],
		[7, E, 9],
	]
	ME.apply_gravity(grid)
	assert_eq(grid[3][1], 12, "lower pocket waits for the same-column tile to fall vertically before taking a diagonal source")
	assert_eq(grid[2][1], 11, "after the lower pocket is filled vertically, the upper pocket may slide from right-above")
	assert_eq(grid[2][2], 6, "lower diagonal candidate stays put while the vertical chain fills the lower pocket")

func test_gravity_with_remote_wall_keeps_open_columns_vertical() -> void:
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [
		[E, 9, E, E, W],
		[1, 2, E, 3, E],
		[4, 5, 6, 7, 8],
		[9, 1, 2, 3, 4],
	]
	ME.apply_gravity(grid)
	assert_eq(grid[0][1], 9, "a tile in an open column must not slide sideways just because a remote wall exists")
	assert_eq(grid[1][2], E, "ordinary empty space without a blocker above is filled only by vertical gravity/refill")

func test_swap_wall_is_illegal() -> void:
	var W := ME.WALL
	var grid := [[0, 0, W], [1, 2, 0], [3, 4, 5]]
	assert_false(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(2, 1)), "moving a WALL is illegal even if tiles would match")

func test_coat_blocks_swap() -> void:
	var grid := [[0, 0, 1], [1, 2, 0], [3, 4, 5]]  # (2,0)<->(2,1) 本来合法
	var coat := [[0, 0, 1], [0, 0, 0], [0, 0, 0]]  # (2,0) 被涂层冻住
	assert_false(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(2, 1), 1, {"coat": coat}), "coated cell can't be swapped")
	assert_true(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(2, 1)), "without coat -> legal")

func test_make_board_with_wall_mask() -> void:
	var W := ME.WALL
	var mask := []
	for y in 6:
		var row := []
		for x in 6:
			row.append(false)
		mask.append(row)
	mask[0][0] = true
	mask[2][3] = true
	mask[5][5] = true
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var g := ME.make_board(6, 6, [0, 1, 2, 3, 4], rng, mask)
	assert_eq(g[0][0], W, "wall at (0,0)")
	assert_eq(g[2][3], W, "wall at masked (3,2)")
	assert_eq(g[5][5], W, "wall at (5,5)")
	assert_true(ME.find_matches(g).is_empty(), "no initial match on irregular board")
	assert_true(ME.has_legal_move(g), "irregular board still has a legal move")

func test_gravity_pulls_tiles_down() -> void:
	var E := ME.EMPTY
	var grid := [
		[1, E, 2],
		[E, E, 3],
		[4, 5, E],
	]
	ME.apply_gravity(grid)
	# col0 [1,_,4]->[_,1,4]; col1 [_,_,5]->[_,_,5]; col2 [2,3,_]->[_,2,3]
	assert_eq(grid, [
		[E, E, E],
		[1, E, 2],
		[4, 5, 3],
	], "gravity should drop tiles to column bottom")

func test_refill_fills_all_empties_within_species_set() -> void:
	var E := ME.EMPTY
	var species := [0, 1, 2, 3]
	var grid := [
		[E, 1, E],
		[2, E, 3],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	ME.refill(grid, species, rng)
	for row in grid:
		for v in row:
			assert_ne(v, E, "no EMPTY should remain after refill")
			assert_true(species.has(v), "filled value must be in species set")
	assert_eq(grid[0][1], 1, "existing tile kept")
	assert_eq(grid[1][0], 2, "existing tile kept")
	assert_eq(grid[1][2], 3, "existing tile kept")

func test_refill_skips_active_coat_cells() -> void:
	var E := ME.EMPTY
	var grid := [
		[E, E],
		[E, E],
	]
	var fx := [
		[ME.SP_LINE_H, ME.SP_LINE_V],
		[ME.SP_BOMB, ME.SP_COLORBOMB],
	]
	var coat := [
		[0, 1],
		[0, 0],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	ME.refill(grid, [0, 1], rng, fx, [], {"coat": coat})
	assert_ne(grid[0][0], E, "normal empty cell refilled")
	assert_eq(grid[0][1], E, "active coat cell remains empty")
	assert_eq(fx[0][1], ME.SP_NONE, "active coat cell keeps no hidden special")
	assert_ne(grid[1][0], E, "other normal cell refilled")

func test_refill_is_deterministic_with_seed() -> void:
	var E := ME.EMPTY
	var species := [0, 1, 2, 3, 4]
	var g1 := [[E, E, E], [E, E, E]]
	var g2 := [[E, E, E], [E, E, E]]
	var r1 := RandomNumberGenerator.new(); r1.seed = 999
	var r2 := RandomNumberGenerator.new(); r2.seed = 999
	ME.refill(g1, species, r1)
	ME.refill(g2, species, r2)
	assert_ne(g1[0][0], E, "refill should actually fill (sanity)")
	assert_eq(g1, g2, "same seed -> identical refill")

func test_score_for_clear_escalates_with_cascade() -> void:
	assert_eq(ME.score_for_clear(3, 1), 30, "3 tiles x10 x cascade1")
	assert_eq(ME.score_for_clear(4, 2), 80, "4 tiles x10 x cascade2")
	assert_eq(ME.score_for_clear(5, 3), 150, "5 tiles x10 x cascade3")

const _SPECIES := [0, 1, 2, 3]
# 含一个横向三连(顶行 0,0,0)的盘面
const _GRID_WITH_MATCH := [
	[0, 0, 0, 1],
	[1, 2, 3, 2],
	[2, 3, 1, 3],
	[3, 1, 2, 1],
]

func test_resolve_stable_grid_scores_zero() -> void:
	var grid := [[0, 1, 0], [1, 0, 1], [0, 1, 0]]  # 棋盘格，无三连
	var before := grid.duplicate(true)
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r: Dictionary = ME.resolve(grid, _SPECIES, rng)
	assert_eq(r["score"], 0, "stable grid scores zero")
	assert_eq(r["cascades"], 0, "stable grid has no cascades")
	assert_eq(grid, before, "stable grid must be unchanged")

func test_resolve_leaves_board_stable() -> void:
	var grid := _GRID_WITH_MATCH.duplicate(true)
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	ME.resolve(grid, _SPECIES, rng)
	assert_true(ME.find_matches(grid).is_empty(), "board must be stable (no matches) after resolve")

func test_resolve_scores_initial_match() -> void:
	var grid := _GRID_WITH_MATCH.duplicate(true)
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var r: Dictionary = ME.resolve(grid, _SPECIES, rng)
	assert_true(r["score"] >= 30, "clearing a 3-match scores at least 30")
	assert_true(r["cascades"] >= 1, "at least one cascade happened")

func test_resolve_reports_by_species() -> void:
	var grid := _GRID_WITH_MATCH.duplicate(true)
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var r: Dictionary = ME.resolve(grid, _SPECIES, rng)
	var sum := 0
	for k in r["by_species"]:
		sum += r["by_species"][k]
	assert_eq(sum, r["cleared"], "by_species sums to total cleared")

func test_resolve_deterministic_with_seed() -> void:
	var g1 := _GRID_WITH_MATCH.duplicate(true)
	var g2 := _GRID_WITH_MATCH.duplicate(true)
	var c1 := RandomNumberGenerator.new(); c1.seed = 7
	var c2 := RandomNumberGenerator.new(); c2.seed = 7
	var r1: Dictionary = ME.resolve(g1, _SPECIES, c1)
	var r2: Dictionary = ME.resolve(g2, _SPECIES, c2)
	assert_true(r1["score"] > 0, "resolve should score (sanity)")
	assert_eq(r1, r2, "same seed+grid -> identical result")
	assert_eq(g1, g2, "same seed+grid -> identical final board")

func test_legal_swap_true_when_creates_match() -> void:
	var grid := [[0, 0, 1], [1, 2, 0], [3, 4, 5]]
	# 交换 (2,0)<->(2,1)：顶行变 0,0,0 → 合法；且相邻
	assert_true(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(2, 1)), "swap forms 0,0,0 in row0")
	assert_eq(grid, [[0, 0, 1], [1, 2, 0], [3, 4, 5]], "is_legal_swap must not mutate grid")

func test_illegal_swap_when_not_adjacent() -> void:
	# (0,0) 与 (0,2) 非相邻(竖距2)；交换会让顶行成 0,0,0，但因非相邻仍非法
	var grid := [[5, 0, 0, 1], [2, 3, 4, 6], [0, 7, 8, 9]]
	assert_false(ME.is_legal_swap(grid, Vector2i(0, 0), Vector2i(0, 2)), "non-adjacent swap is illegal even if it would match")

func test_illegal_swap_when_no_match_formed() -> void:
	var grid := [[0, 1, 2], [3, 4, 5], [6, 7, 8]]  # 全不同，相邻交换也凑不出三连
	assert_false(ME.is_legal_swap(grid, Vector2i(0, 0), Vector2i(1, 0)), "adjacent swap that forms no match is illegal")

func test_has_legal_move_true_when_swap_exists() -> void:
	var grid := [[0, 0, 1], [1, 2, 0], [3, 4, 5]]  # (2,0)<->(2,1) 合法
	assert_true(ME.has_legal_move(grid), "a legal swap exists")

func test_has_legal_move_false_when_deadlock() -> void:
	var grid := [[0, 1, 2], [3, 4, 5], [6, 7, 8]]  # 全不同，任何交换都凑不出消除
	assert_false(ME.has_legal_move(grid), "no legal move -> deadlock")

func test_make_board_no_initial_match_and_has_move() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 123
	var grid := ME.make_board(8, 8, [0, 1, 2, 3, 4], rng)
	assert_eq(grid.size(), 8, "height = 8")
	assert_eq(grid[0].size(), 8, "width = 8")
	assert_true(ME.find_matches(grid).is_empty(), "no pre-existing match at start")
	assert_true(ME.has_legal_move(grid), "start board must have a legal move")

func test_make_board_deterministic_with_seed() -> void:
	var r1 := RandomNumberGenerator.new(); r1.seed = 5
	var r2 := RandomNumberGenerator.new(); r2.seed = 5
	var g1 := ME.make_board(6, 6, [0, 1, 2, 3], r1)
	var g2 := ME.make_board(6, 6, [0, 1, 2, 3], r2)
	assert_eq(g1.size(), 6, "built (sanity)")
	assert_eq(g1, g2, "same seed -> identical board")

# 含一个横向三连(顶行 0,0,0)、且棋子有重复 → 可重排成无消除有合法移动
const _GRID_DEADish := [
	[0, 0, 0, 1],
	[2, 3, 1, 2],
	[3, 1, 2, 3],
	[1, 2, 3, 0],
]

func _flatten_sorted(grid: Array) -> Array:
	var a := []
	for row in grid:
		a.append_array(row)
	a.sort()
	return a

func test_reshuffle_preserves_multiset_and_yields_playable() -> void:
	var grid := _GRID_DEADish.duplicate(true)
	var before := _flatten_sorted(grid)
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	ME.reshuffle(grid, rng)
	assert_eq(_flatten_sorted(grid), before, "reshuffle must preserve the tile multiset")
	assert_true(ME.find_matches(grid).is_empty(), "no pre-existing match after reshuffle")
	assert_true(ME.has_legal_move(grid), "has a legal move after reshuffle")

func test_reshuffle_deterministic_with_seed() -> void:
	var g1 := _GRID_DEADish.duplicate(true)
	var g2 := _GRID_DEADish.duplicate(true)
	var r1 := RandomNumberGenerator.new(); r1.seed = 9
	var r2 := RandomNumberGenerator.new(); r2.seed = 9
	ME.reshuffle(g1, r1)
	ME.reshuffle(g2, r2)
	assert_true(ME.find_matches(g1).is_empty(), "actually reshuffled (sanity)")
	assert_eq(g1, g2, "same seed -> identical reshuffle")

# ---- v1.1 多连特效：分类 ----

func test_classify_four_in_row_spawns_line_v() -> void:
	var grid := [
		[0, 0, 0, 0, 1],
		[1, 2, 3, 2, 3],
		[2, 3, 1, 3, 1],
	]
	var c := ME.classify_matches(grid)
	assert_eq(c["spawns"].size(), 1, "one special spawned")
	assert_eq(c["spawns"][0]["kind"], ME.SP_LINE_V, "horizontal 4 -> vertical special")
	assert_eq(c["clear"].size(), 3, "4 matched minus 1 spawn = 3 cleared")

func test_classify_five_in_row_spawns_colorbomb() -> void:
	var grid := [
		[0, 0, 0, 0, 0],
		[1, 2, 3, 2, 3],
		[2, 3, 1, 3, 1],
	]
	var c := ME.classify_matches(grid)
	assert_eq(c["spawns"].size(), 1, "one special spawned")
	assert_eq(c["spawns"][0]["kind"], ME.SP_COLORBOMB, "5 in a row -> COLORBOMB")
	assert_eq(c["clear"].size(), 4, "5 matched minus 1 spawn = 4 cleared")

func test_classify_three_in_row_no_spawn() -> void:
	var grid := [
		[0, 0, 0, 1, 2],
		[1, 2, 3, 2, 3],
		[2, 3, 1, 3, 1],
	]
	var c := ME.classify_matches(grid)
	assert_eq(c["spawns"].size(), 0, "plain 3-match spawns nothing")
	assert_eq(c["clear"].size(), 3, "all 3 matched cleared")

func test_classify_four_vertical_spawns_line_h() -> void:
	var grid := [
		[0, 1, 2],
		[0, 2, 3],
		[0, 3, 1],
		[0, 1, 2],
	]
	var c := ME.classify_matches(grid)
	assert_eq(c["spawns"].size(), 1, "one special spawned")
	assert_eq(c["spawns"][0]["kind"], ME.SP_LINE_H, "vertical 4 -> horizontal special")
	assert_eq(c["clear"].size(), 3, "4 matched minus 1 spawn = 3 cleared")

func test_classify_t_shape_spawns_bomb() -> void:
	var grid := [[0, 0, 0], [1, 0, 2], [3, 0, 4]]  # row0 三连 + col1 三连，交于 (1,0)
	var c := ME.classify_matches(grid)
	assert_eq(c["spawns"].size(), 1, "one special (bomb)")
	assert_eq(c["spawns"][0]["kind"], ME.SP_BOMB, "T/L -> BOMB")
	assert_eq(c["spawns"][0]["pos"], Vector2i(1, 0), "bomb at the intersection")
	assert_eq(c["clear"].size(), 4, "5 matched minus 1 bomb spawn = 4")

func test_classify_t_shape_ignores_unrelated_preferred_spawn() -> void:
	var grid := [
		[4, 4, 4, 2, 3],
		[0, 2, 1, 3, 4],
		[2, 1, 1, 1, 0],
		[3, 4, 1, 0, 2],
		[0, 2, 3, 4, 1],
	]
	var preferred_from_other_match := Vector2i(1, 0)
	var c := ME.classify_matches(grid, {}, preferred_from_other_match)
	assert_eq(c["spawns"].size(), 1, "only the T shape creates a special")
	assert_eq(c["spawns"][0]["kind"], ME.SP_BOMB, "T/L remains a bomb")
	assert_eq(c["spawns"][0]["pos"], Vector2i(2, 2), "unrelated preferred match must not steal the T/L spawn")

func test_classify_l_shape_spawns_bomb() -> void:
	var grid := [[0, 1, 2], [0, 3, 4], [0, 0, 0]]  # col0 三连 + row2 三连，交于 (0,2)
	var c := ME.classify_matches(grid)
	assert_eq(c["spawns"].size(), 1, "one special (bomb)")
	assert_eq(c["spawns"][0]["kind"], ME.SP_BOMB, "L -> BOMB")
	assert_eq(c["spawns"][0]["pos"], Vector2i(0, 2), "bomb at the corner intersection")

# ---- v1.1 特效层：fx 随重力同步下落 ----

func test_gravity_moves_fx_with_tiles() -> void:
	var E := ME.EMPTY
	var N := ME.SP_NONE
	var grid := [[1, E], [E, 2], [3, E]]
	var fx := [[ME.SP_LINE_H, N], [N, ME.SP_LINE_V], [N, N]]
	ME.apply_gravity(grid, fx)
	assert_eq(grid, [[E, E], [1, E], [3, 2]], "tiles fall")
	assert_eq(fx, [[N, N], [ME.SP_LINE_H, N], [N, ME.SP_LINE_V]], "fx falls in lockstep with tiles")

func test_refill_sets_fx_none_on_new_tiles() -> void:
	var E := ME.EMPTY
	var N := ME.SP_NONE
	var grid := [[E, 1], [2, E]]
	var fx := [[99, ME.SP_LINE_H], [N, 99]]  # EMPTY 处 fx 故意留脏值 99
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	ME.refill(grid, [0, 1, 2, 3], rng, fx)
	assert_eq(fx[0][0], N, "new tile fx set to NONE")
	assert_eq(fx[1][1], N, "new tile fx set to NONE")
	assert_eq(fx[0][1], ME.SP_LINE_H, "existing special's fx preserved")

# ---- v1.1 特效触发清除范围 ----

func _blank(w: int, h: int) -> Array:
	var g := []
	for y in h:
		var row := []
		for x in w:
			row.append(0)
		g.append(row)
	return g

func test_effect_line_h_clears_whole_row() -> void:
	var grid := _blank(5, 4)
	var cells: Array = ME.special_effect_cells(grid, Vector2i(2, 1), ME.SP_LINE_H)
	assert_eq(cells.size(), 5, "whole row of width 5")
	for x in 5:
		assert_true(cells.has(Vector2i(x, 1)), "row cell %d" % x)

func test_effect_line_v_clears_whole_col() -> void:
	var grid := _blank(5, 4)
	var cells: Array = ME.special_effect_cells(grid, Vector2i(3, 0), ME.SP_LINE_V)
	assert_eq(cells.size(), 4, "whole column of height 4")
	for y in 4:
		assert_true(cells.has(Vector2i(3, y)), "col cell %d" % y)

func test_effect_bomb_clears_3x3_and_clamps() -> void:
	var grid := _blank(5, 4)
	assert_eq(ME.special_effect_cells(grid, Vector2i(2, 1), ME.SP_BOMB).size(), 9, "3x3 interior")
	assert_eq(ME.special_effect_cells(grid, Vector2i(0, 0), ME.SP_BOMB).size(), 4, "3x3 clamped at corner")


func _latin_5() -> Array:
	return [
		[0, 1, 2, 3, 4],
		[1, 2, 3, 4, 0],
		[2, 3, 4, 0, 1],
		[3, 4, 0, 1, 2],
		[4, 0, 1, 2, 3],
	]


func _cells_set(cells: Array) -> Dictionary:
	var out := {}
	for c in cells:
		out[c] = true
	return out


func test_special_fusion_two_horizontal_lines_clears_horizontal_rows_only() -> void:
	var cells: Array = ME.special_fusion_cells(_latin_5(), Vector2i(1, 2), Vector2i(2, 2), ME.SP_LINE_H, ME.SP_LINE_H)
	var s := _cells_set(cells)
	assert_eq(cells.size(), 5, "two horizontal line specials on the same row clear that row once")
	for x in 5:
		assert_true(s.has(Vector2i(x, 2)), "horizontal fusion clears row 2 at x=%d" % x)
	assert_false(s.has(Vector2i(2, 0)), "horizontal + horizontal must not add a vertical blast")


func test_special_fusion_horizontal_vertical_uses_each_post_swap_position() -> void:
	var cells: Array = ME.special_fusion_cells(_latin_5(), Vector2i(1, 2), Vector2i(2, 2), ME.SP_LINE_H, ME.SP_LINE_V)
	var s := _cells_set(cells)
	for x in 5:
		assert_true(s.has(Vector2i(x, 2)), "horizontal special clears its post-swap row at x=%d" % x)
	for y in 5:
		assert_true(s.has(Vector2i(1, y)), "vertical special clears its post-swap column at y=%d" % y)
	assert_false(s.has(Vector2i(2, 0)), "vertical special must not stay anchored to the pre-swap column")


func test_special_fusion_bomb_horizontal_makes_three_horizontal_rows() -> void:
	var cells: Array = ME.special_fusion_cells(_latin_5(), Vector2i(1, 2), Vector2i(2, 2), ME.SP_BOMB, ME.SP_LINE_H)
	var s := _cells_set(cells)
	assert_eq(cells.size(), 15, "cross + horizontal clears exactly three full rows on a 5x5 board")
	for y in range(1, 4):
		for x in 5:
			assert_true(s.has(Vector2i(x, y)), "cross + horizontal clears row %d at x=%d" % [y, x])
	assert_false(s.has(Vector2i(1, 0)), "cross + horizontal must not add extra vertical columns")


func test_special_fusion_horizontal_bomb_makes_three_horizontal_rows() -> void:
	var cells: Array = ME.special_fusion_cells(_latin_5(), Vector2i(1, 2), Vector2i(2, 2), ME.SP_LINE_H, ME.SP_BOMB)
	var s := _cells_set(cells)
	assert_eq(cells.size(), 15, "horizontal + cross clears exactly three full rows on a 5x5 board")
	for y in range(1, 4):
		for x in 5:
			assert_true(s.has(Vector2i(x, y)), "horizontal + cross clears row %d at x=%d" % [y, x])
	assert_false(s.has(Vector2i(1, 0)), "horizontal + cross must not add extra vertical columns")


func test_special_fusion_bomb_vertical_makes_three_vertical_columns() -> void:
	var cells: Array = ME.special_fusion_cells(_latin_5(), Vector2i(1, 2), Vector2i(2, 2), ME.SP_BOMB, ME.SP_LINE_V)
	var s := _cells_set(cells)
	assert_eq(cells.size(), 15, "cross + vertical clears exactly three full columns on a 5x5 board")
	for x in range(0, 3):
		for y in 5:
			assert_true(s.has(Vector2i(x, y)), "cross + vertical clears column %d at y=%d" % [x, y])
	assert_false(s.has(Vector2i(4, 2)), "cross + vertical must not add extra horizontal rows")


func test_special_fusion_two_bombs_makes_5x5_blast() -> void:
	var cells: Array = ME.special_fusion_cells(_latin_5(), Vector2i(1, 2), Vector2i(2, 2), ME.SP_BOMB, ME.SP_BOMB)
	var s := _cells_set(cells)
	assert_eq(cells.size(), 25, "cross + cross clears a full 5x5 blast")
	for y in 5:
		for x in 5:
			assert_true(s.has(Vector2i(x, y)), "5x5 blast includes (%d,%d)" % [x, y])


func test_effect_colorbomb_clears_all_of_target() -> void:
	var grid := [[0, 1, 0], [2, 0, 3], [0, 1, 0]]  # 五个 0
	var cells: Array = ME.special_effect_cells(grid, Vector2i(1, 1), ME.SP_COLORBOMB, 0)
	assert_eq(cells.size(), 5, "all five 0-species cells")

# ---- v1.1 汇总清除（匹配 + 特效触发链）----

func _none_fx(w: int, h: int) -> Array:
	var f := []
	for y in h:
		var row := []
		for x in w:
			row.append(ME.SP_NONE)
		f.append(row)
	return f

func test_collect_four_match_marks_line_spawn() -> void:
	var grid := [[0, 0, 0, 0, 1], [1, 2, 3, 2, 3], [2, 3, 1, 3, 1]]
	var fx := _none_fx(5, 3)
	var c := ME.collect_clears(grid, fx)
	assert_eq(c["to_clear"].size(), 4, "all 4 matched cells in clear set")
	assert_eq(c["spawns"].size(), 1, "one line spawned")
	assert_eq(c["spawns"][0]["kind"], ME.SP_LINE_V, "h4 -> LINE_V")

func test_collect_four_match_prefers_moved_piece_new_position() -> void:
	var grid := [
		[0, 0, 0, 0, 1],
		[1, 2, 3, 2, 3],
		[2, 3, 1, 3, 1],
	]
	var fx := _none_fx(5, 3)
	var moved_new_pos := Vector2i(2, 0)
	var c := ME.collect_clears(grid, fx, {}, moved_new_pos)
	assert_eq(c["spawns"].size(), 1, "one line spawned")
	assert_eq(c["spawns"][0]["pos"], moved_new_pos, "special spawns at the moved piece's new cell, not the run midpoint")
	ME._apply_clears(grid, fx, c["to_clear"], c["spawns"])
	assert_ne(grid[moved_new_pos.y][moved_new_pos.x], ME.EMPTY, "spawn cell keeps its tile")
	assert_eq(fx[moved_new_pos.y][moved_new_pos.x], ME.SP_LINE_V, "spawn cell receives the vertical special effect")

func test_collect_four_match_generates_complementary_line_kind() -> void:
	var vertical_four := [
		[1, 0, 2],
		[2, 0, 3],
		[3, 0, 4],
		[4, 0, 5],
	]
	var vertical_fx := _none_fx(3, 4)
	var horizontal_swap_pos := Vector2i(1, 1)
	var c_vertical := ME.collect_clears(vertical_four, vertical_fx, {}, horizontal_swap_pos, ME.SP_LINE_H)
	assert_eq(c_vertical["spawns"].size(), 1, "vertical 4 still creates one line special")
	assert_eq(c_vertical["spawns"][0]["pos"], horizontal_swap_pos, "special lands at the moved piece's new cell")
	assert_eq(c_vertical["spawns"][0]["kind"], ME.SP_LINE_H, "vertical 4 creates a horizontal line special even when the swap was horizontal")

	var horizontal_four := [
		[1, 2, 3, 4, 5],
		[0, 0, 0, 0, 6],
		[2, 3, 4, 5, 1],
	]
	var horizontal_fx := _none_fx(5, 3)
	var vertical_swap_pos := Vector2i(2, 1)
	var c_horizontal := ME.collect_clears(horizontal_four, horizontal_fx, {}, vertical_swap_pos, ME.SP_LINE_V)
	assert_eq(c_horizontal["spawns"].size(), 1, "horizontal 4 still creates one line special")
	assert_eq(c_horizontal["spawns"][0]["pos"], vertical_swap_pos, "special lands at the moved piece's new cell")
	assert_eq(c_horizontal["spawns"][0]["kind"], ME.SP_LINE_V, "horizontal 4 creates a vertical line special even when the swap was vertical")

func test_collect_triggers_line_clears_whole_row() -> void:
	var grid := [[9, 8, 5, 9, 8], [5, 5, 5, 7, 6], [8, 7, 4, 6, 9]]  # 仅 row1 的 5,5,5 三连
	var fx := _none_fx(5, 3)
	fx[1][2] = ME.SP_LINE_H  # (2,1) 是直线特效
	var c := ME.collect_clears(grid, fx)
	var tc: Array = c["to_clear"]
	assert_eq(tc.size(), 5, "line trigger expands to whole row 1")
	assert_true(tc.has(Vector2i(3, 1)) and tc.has(Vector2i(4, 1)), "row cells beyond the 3-match added by the line")

func test_collect_line_hit_triggers_indirect_line() -> void:
	var grid := [
		[9, 8, 7, 6, 5],
		[5, 5, 5, 7, 6],
		[8, 7, 4, 6, 9],
		[9, 6, 3, 5, 8],
	]
	var fx := _none_fx(5, 4)
	fx[1][2] = ME.SP_LINE_H
	fx[1][4] = ME.SP_LINE_V
	var c := ME.collect_clears(grid, fx)
	var tc: Array = c["to_clear"]
	assert_true(tc.has(Vector2i(4, 0)), "indirect vertical line clears above its hit cell")
	assert_true(tc.has(Vector2i(4, 2)), "indirect vertical line clears below its hit cell")
	assert_true(tc.has(Vector2i(4, 3)), "indirect vertical line reaches the column tail")

func test_collect_forms_colorbomb_before_same_step_line_blast_hits_it() -> void:
	var grid := [
		[1, 2, 3, 4, 5],
		[0, 0, 0, 0, 0],
		[1, 2, 3, 4, 5],
		[2, 3, 4, 0, 5],
		[1, 2, 3, 4, 5],
	]
	var fx := _none_fx(5, 5)
	fx[1][0] = ME.SP_LINE_H
	var c := ME.collect_clears(grid, fx)
	var tc: Array = c["to_clear"]
	assert_eq(c["spawns"].size(), 1, "the 5-match still produces one colorbomb")
	assert_eq(c["spawns"][0]["kind"], ME.SP_COLORBOMB, "the 5-match product is a colorbomb")
	assert_true(tc.has(Vector2i(3, 3)), "same-step line blast hits the new colorbomb, then the colorbomb clears other matching species")
	assert_true(c.has("triggered_spawns") and c["triggered_spawns"].has(Vector2i(2, 1)), "the spawn hit by the line is reported as triggered")
	ME._apply_clears(grid, fx, tc, c["spawns"], c["triggered_spawns"])
	assert_eq(grid[1][2], ME.EMPTY, "the newly formed colorbomb is consumed when hit in the same step")
	assert_eq(fx[1][2], ME.SP_NONE, "the consumed colorbomb leaves no effect behind")

func test_same_step_horizontal_four_line_triggers_vertically() -> void:
	var grid := [
		[1, 2, 3, 4, 5],
		[0, 0, 0, 0, 9],
		[1, 2, 3, 4, 5],
		[2, 3, 4, 5, 1],
		[3, 4, 5, 1, 2],
	]
	var fx := _none_fx(5, 5)
	fx[1][0] = ME.SP_BOMB
	var c := ME.collect_clears(grid, fx)
	var spawn_pos := Vector2i(1, 1)
	assert_eq(c["spawns"][0]["kind"], ME.SP_LINE_V, "persistent horizontal 4 product stores a vertical special")
	assert_true(c["triggered_spawns"].has(spawn_pos), "the same-step blast hits the newly formed horizontal 4 special")
	assert_eq(c.get("triggered_spawn_fx", {}).get(spawn_pos, ME.SP_NONE), ME.SP_LINE_V, "same-step trigger follows the generated vertical special")
	assert_true((c["to_clear"] as Array).has(Vector2i(1, 4)), "same-step vertical special clears the column tail")

func test_same_step_vertical_four_line_triggers_horizontally() -> void:
	var grid := [
		[1, 0, 3, 4, 5],
		[2, 0, 4, 5, 1],
		[3, 0, 5, 1, 2],
		[4, 0, 1, 2, 3],
		[5, 9, 2, 3, 4],
	]
	var fx := _none_fx(5, 5)
	fx[0][1] = ME.SP_BOMB
	var c := ME.collect_clears(grid, fx)
	var spawn_pos := Vector2i(1, 1)
	assert_eq(c["spawns"][0]["kind"], ME.SP_LINE_H, "persistent vertical 4 product stores a horizontal special")
	assert_true(c["triggered_spawns"].has(spawn_pos), "the same-step blast hits the newly formed vertical 4 special")
	assert_eq(c.get("triggered_spawn_fx", {}).get(spawn_pos, ME.SP_NONE), ME.SP_LINE_H, "same-step trigger follows the generated horizontal special")
	assert_true((c["to_clear"] as Array).has(Vector2i(4, 1)), "same-step horizontal special clears the row tail")

func test_cross_on_four_match_spawn_cell_becomes_new_vertical_line() -> void:
	var grid := [
		[9, 8, 7, 6, 5],
		[5, 5, 5, 5, 6],
		[8, 7, 4, 6, 9],
	]
	var fx := _none_fx(5, 3)
	var spawn_pos := Vector2i(1, 1)
	fx[spawn_pos.y][spawn_pos.x] = ME.SP_BOMB
	var c := ME.collect_clears(grid, fx)
	assert_eq(c["spawns"].size(), 1, "a cross special completing a plain horizontal 4-match still creates one generated special")
	if c["spawns"].size() > 0:
		assert_eq(c["spawns"][0]["pos"], spawn_pos, "the generated special lands on the cross piece's 4-match spawn cell")
		assert_eq(c["spawns"][0]["kind"], ME.SP_LINE_V, "horizontal 4-match over a cross piece creates a new vertical line special")
	assert_false((c["to_clear"] as Array).has(Vector2i(0, 0)), "the old cross effect is replaced by the 4-match product, not triggered as a 3x3 blast")
	ME._apply_clears(grid, fx, c["to_clear"], c["spawns"], c["triggered_spawns"])
	assert_eq(grid[spawn_pos.y][spawn_pos.x], 5, "the generated vertical line keeps the matched tile")
	assert_eq(fx[spawn_pos.y][spawn_pos.x], ME.SP_LINE_V, "the cross piece is replaced by the new vertical line special")


func test_existing_line_on_spawn_cell_is_triggered_not_respawned() -> void:
	var grid := [
		[9, 8, 7, 6, 5],
		[5, 5, 5, 5, 6],
		[8, 7, 4, 6, 9],
	]
	var fx := _none_fx(5, 3)
	fx[1][1] = ME.SP_LINE_H
	var c := ME.collect_clears(grid, fx)
	ME._apply_clears(grid, fx, c["to_clear"], c["spawns"])
	assert_eq(grid[1][1], ME.EMPTY, "existing line special is consumed instead of protected as a new spawn")
	assert_eq(fx[1][1], ME.SP_NONE, "triggered existing line does not leave a new hidden line effect")

func test_apply_clears_spawns_line_and_empties_others() -> void:
	var grid := [[0, 0, 0, 0, 1], [1, 2, 3, 2, 3], [2, 3, 1, 3, 1]]
	var fx := _none_fx(5, 3)
	var c := ME.collect_clears(grid, fx)
	ME._apply_clears(grid, fx, c["to_clear"], c["spawns"])
	var sp: Vector2i = c["spawns"][0]["pos"]
	assert_eq(fx[sp.y][sp.x], ME.SP_LINE_V, "spawn cell becomes vertical special")
	assert_ne(grid[sp.y][sp.x], ME.EMPTY, "spawn cell keeps its species (not emptied)")
	var empties := 0
	for x in 5:
		if grid[0][x] == ME.EMPTY:
			empties += 1
	assert_eq(empties, 3, "3 of the 4 matched cells emptied (1 became the special)")

func test_apply_clears_keeps_unfiltered_spawn_special() -> void:
	var grid := [
		[0, 1, 2],
		[3, 4, 5],
		[6, 7, 8],
	]
	var fx := _none_fx(3, 3)
	var spawn_pos := Vector2i(1, 0)
	var to_clear := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	var spawns := [{"pos": spawn_pos, "kind": ME.SP_LINE_V}]
	ME._apply_clears(grid, fx, to_clear, spawns)
	assert_eq(grid[0][1], 1, "spawn cell keeps its tile even when filtered out of to_clear")
	assert_eq(fx[0][1], ME.SP_LINE_V, "spawn cell receives the generated 4-match special")

func test_forced_external_spawn_cannot_steal_special_from_actual_match() -> void:
	var grid := [
		[1, 2, 3, 1],
		[0, 0, 0, 0],
		[2, 3, 1, 2],
		[3, 1, 2, 1],
	]
	var fx := _none_fx(4, 4)
	var external_preferred := Vector2i(2, 2)
	var actual_run_midpoint := Vector2i(1, 1)
	var c := ME.collect_clears(grid, fx, {}, external_preferred, ME.SP_NONE, true)
	assert_eq(c["spawns"].size(), 1, "the 4-match still creates exactly one special")
	assert_eq(c["spawns"][0]["pos"], actual_run_midpoint, "preferred target outside the run must not steal the generated special")
	ME._apply_clears(grid, fx, c["to_clear"], c["spawns"])
	assert_eq(grid[actual_run_midpoint.y][actual_run_midpoint.x], 0, "actual spawn keeps the matched tile")
	assert_eq(fx[actual_run_midpoint.y][actual_run_midpoint.x], ME.SP_LINE_V, "actual spawn becomes the generated line special")
	assert_eq(fx[external_preferred.y][external_preferred.x], ME.SP_NONE, "external preferred cell stays ordinary")

# ---- v1.1 resolve 特效版（生成/触发/级联，整合）----

const _GRID_FX := [
	[0, 0, 0, 0, 1, 2],
	[3, 1, 2, 1, 3, 4],
	[4, 2, 3, 2, 4, 1],
	[1, 3, 4, 3, 1, 3],
	[2, 4, 1, 4, 2, 4],
	[3, 1, 2, 1, 3, 1],
]

func test_resolve_fx_scores_and_leaves_board_stable() -> void:
	var grid := _GRID_FX.duplicate(true)
	var fx := _none_fx(6, 6)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var r := ME.resolve(grid, [0, 1, 2, 3, 4], rng, fx)
	assert_true(r["score"] > 0, "resolve-fx scores")
	assert_true(ME.find_matches(grid).is_empty(), "board stable after resolve-fx")

func test_resolve_fx_deterministic_with_seed() -> void:
	var g1 := _GRID_FX.duplicate(true)
	var g2 := _GRID_FX.duplicate(true)
	var f1 := _none_fx(6, 6)
	var f2 := _none_fx(6, 6)
	var c1 := RandomNumberGenerator.new(); c1.seed = 8
	var c2 := RandomNumberGenerator.new(); c2.seed = 8
	var r1 := ME.resolve(g1, [0, 1, 2, 3, 4], c1, f1)
	var r2 := ME.resolve(g2, [0, 1, 2, 3, 4], c2, f2)
	assert_true(r1["score"] > 0, "scored (sanity)")
	assert_eq(r1, r2, "same seed -> identical result")
	assert_eq(g1, g2, "same seed -> identical grid")
	assert_eq(f1, f2, "same seed -> identical fx")

# ---- v1.1 彩球交换引爆 ----

func test_colorbomb_clear_set_targets_partner_species() -> void:
	var grid := [
		[0, 1, 2, 3],
		[1, 0, 3, 2],
		[8, 1, 2, 3],  # (0,2)=彩球；与上方 (0,1) 交换，partner species = grid[1][0] = 1
		[4, 1, 2, 3],
	]
	var fx := _none_fx(4, 4)
	fx[2][0] = ME.SP_COLORBOMB
	var cells: Array = ME.colorbomb_clear_set(grid, fx, Vector2i(0, 2), Vector2i(0, 1))
	# 1 在 (1,0),(0,1),(1,2),(1,3) 共 4 个；+ 彩球 (0,2) = 5
	assert_eq(cells.size(), 5, "all four 1-cells + the colorbomb cell")
	assert_true(cells.has(Vector2i(0, 2)), "colorbomb itself consumed")
	assert_true(cells.has(Vector2i(1, 0)) and cells.has(Vector2i(1, 2)) and cells.has(Vector2i(1, 3)), "every target-species cell")

# ───────────────── P1: 特效不可清墙（异形棋盘契约闭合）─────────────────

func test_special_effect_cells_spare_wall() -> void:
	# 直线/爆炸的清除范围必须跳过墙（墙不可消、不可动、不补充）。
	var grid := [
		[0, ME.WALL, 2, 3],
		[4, 5, 6, 7],
	]
	var line: Array = ME.special_effect_cells(grid, Vector2i(0, 0), ME.SP_LINE_H)
	assert_false(line.has(Vector2i(1, 0)), "LINE_H must skip the wall at (1,0)")
	assert_true(line.has(Vector2i(0, 0)), "LINE_H still clears normal cells")
	var bomb: Array = ME.special_effect_cells(grid, Vector2i(1, 1), ME.SP_BOMB)
	assert_false(bomb.has(Vector2i(1, 0)), "BOMB 3x3 must skip the wall in range")
	assert_true(bomb.has(Vector2i(1, 1)), "BOMB still clears its center")

func test_double_colorbomb_spares_wall() -> void:
	# 双彩球清"全盘非空"时必须排除墙。
	var grid := [
		[0, 1, 2],
		[1, ME.WALL, 0],
		[2, 0, 1],
	]
	var fx := [
		[ME.SP_COLORBOMB, ME.SP_NONE, ME.SP_NONE],
		[ME.SP_NONE, ME.SP_NONE, ME.SP_NONE],
		[ME.SP_NONE, ME.SP_NONE, ME.SP_COLORBOMB],
	]
	var cells: Array = ME.colorbomb_clear_set(grid, fx, Vector2i(0, 0), Vector2i(2, 2))
	assert_false(cells.has(Vector2i(1, 1)), "double colorbomb must NOT clear the wall")

func test_apply_clears_never_empties_wall() -> void:
	# 兜底：即便墙混进 to_clear，也绝不置 EMPTY（契约闭合）。
	var grid := [[0, ME.WALL, 2]]
	var fx := [[ME.SP_NONE, ME.SP_NONE, ME.SP_NONE]]
	ME._apply_clears(grid, fx, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], [])
	assert_eq(grid[0][1], ME.WALL, "wall stays WALL even if listed in to_clear")
	assert_eq(grid[0][0], ME.EMPTY, "normal cell still cleared")

# ───────────────── P2: 死局洗牌须 coat 感知 ─────────────────

func test_reshuffle_coat_aware_leaves_legal_move() -> void:
	# reshuffle 接 coat 后，验收用 coat 感知的 has_legal_move，避免"忽略冰锁看似有步、真实无步"。
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var grid := []
	for y in 6:
		var row := []
		for x in 6:
			row.append((x * 2 + y) % 5)
		grid.append(row)
	var coat := []
	for y in 6:
		var crow := []
		for x in 6:
			crow.append(0)
		coat.append(crow)
	coat[0][0] = 1
	coat[2][3] = 1
	coat[4][1] = 1
	coat[5][5] = 1
	ME.reshuffle(grid, rng, {"coat": coat})
	assert_true(ME.find_matches(grid, {"coat": coat}).is_empty(), "no coat-aware ready match after reshuffle")
	assert_true(ME.has_legal_move(grid, {"coat": coat}), "coat-aware legal move exists after reshuffle")

# ───────────────── P3: 彩球直清的 jelly/coat 计数（account_clears 直测）─────────────────

func test_account_clears_counts_jelly() -> void:
	var grid := [
		[0, 1, 2],
		[3, 4, 5],
		[6, 7, 8],
	]
	var jelly := [
		[1, 0, 2],
		[0, 1, 0],
		[0, 0, 0],
	]
	var cells := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1)]  # 三格均有 jelly
	var acc: Dictionary = ME.account_clears(grid, cells, [], null, [], {"jelly": jelly})
	assert_eq(acc["jelly_cleared"], 3, "one jelly layer per jellied cleared cell")
	assert_eq(jelly[0][0], 0, "(0,0) jelly 1->0")
	assert_eq(jelly[0][2], 1, "(2,0) jelly 2->1")
	assert_eq(jelly[1][1], 0, "(1,1) jelly 1->0")

func test_account_clears_counts_coat() -> void:
	var grid := [
		[0, 1, 2],
		[3, 4, 5],
		[6, 7, 8],
	]
	var coat := [
		[1, 0, 0],
		[0, 2, 0],
		[0, 0, 0],
	]
	var cells := [Vector2i(1, 0)]  # 与 (0,0)[左邻]、(1,1)[上邻] 相邻
	var acc: Dictionary = ME.account_clears(grid, cells, [], null, [], {"coat": coat})
	assert_eq(acc["blocker_cleared"], 2, "both adjacent coats damaged once")
	assert_eq(coat[0][0], 0, "(0,0) coat 1->0")
	assert_eq(coat[1][1], 1, "(1,1) coat 2->1")
	assert_eq(grid[0][0], ME.EMPTY, "destroyed coat leaves no gem underneath")
	assert_eq(grid[1][1], ME.EMPTY, "still-coated cell also has no hidden gem")

func test_account_clears_locks_ingredient_direct_clear() -> void:
	var grid := [
		[0, 1, 2],
		[3, 4, 5],
		[6, 7, 8],
	]
	var fx := [
		[ME.SP_NONE, ME.SP_NONE, ME.SP_NONE],
		[ME.SP_NONE, ME.SP_NONE, ME.SP_NONE],
		[ME.SP_NONE, ME.SP_NONE, ME.SP_NONE],
	]
	var ing := [
		[0, 1, 0],
		[0, 0, 0],
		[0, 0, 0],
	]
	var target := Vector2i(1, 0)
	ME.apply_ingredient_occupancy(grid, fx, ing)
	var acc: Dictionary = ME.account_clears(grid, [target], fx, null, [], {"ing": ing})
	assert_true(acc.get("locked", []).has(target), "direct clears must lock ingredient cells instead of clearing them")
	assert_false(acc.get("by_species", {}).has(1), "ingredient actor has no hidden species to collect by direct clear")
	var locked := {}
	for p in acc.get("locked", []):
		locked[p] = true
	var to_clear := []
	if not locked.has(target):
		to_clear.append(target)
	ME._apply_clears(grid, fx, to_clear, [])
	assert_eq(grid[0][1], ME.EMPTY, "caller filtering keeps the ingredient actor cell grid-empty")
	assert_eq(ing[0][1], 1, "ingredient actor remains in its own layer")

func test_coat_occupancy_removes_underlying_gem() -> void:
	var grid := [
		[0, 1, 2],
		[3, 4, 5],
	]
	var fx := [
		[ME.SP_NONE, ME.SP_LINE_H, ME.SP_NONE],
		[ME.SP_NONE, ME.SP_BOMB, ME.SP_NONE],
	]
	var coat := [
		[0, 1, 0],
		[0, 2, 0],
	]
	ME.apply_blocker_occupancy(grid, fx, coat)
	assert_eq(grid[0][1], ME.EMPTY, "coat cell has no underlying gem at start")
	assert_eq(grid[1][1], ME.EMPTY, "multi-layer coat cell also occupies the tile")
	assert_eq(fx[0][1], ME.SP_NONE, "coat clears any hidden special")
	assert_eq(fx[1][1], ME.SP_NONE, "coat clears any hidden bomb special")
	assert_eq(grid[0][0], 0, "normal cells stay untouched")

# ───────────────── 经典锁(licorice)语义：锁住格不可消、相邻破锁、重力固定 ─────────────────

func test_find_matches_skips_locked() -> void:
	var grid := [
		[0, 0, 0, 1],
		[2, 3, 4, 2],
		[3, 4, 2, 3],
	]
	assert_eq(ME.find_matches(grid).size(), 3, "no coat -> top row is a 3-match")
	var coat := [
		[0, 1, 0, 0],  # 锁住顶行中间格 (1,0)
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	assert_true(ME.find_matches(grid, {"coat": coat}).is_empty(), "locked middle breaks the run")

func test_gravity_blocks_locked() -> void:
	var grid := [[0], [ME.EMPTY], [ME.EMPTY]]   # 列：[0, ice占位, EMPTY]
	var coat := [[0], [1], [0]]          # (0,1) 锁住
	ME.apply_gravity(grid, [], false, {"coat": coat})
	assert_eq(grid[0][0], 0, "tile above lock stays (can't fall through)")
	assert_eq(grid[1][0], ME.EMPTY, "locked blocker cell has no hidden gem")
	assert_eq(grid[2][0], ME.EMPTY, "below-lock empty stays empty")

func test_resolve_locked_broken_by_adjacency() -> void:
	var grid := [
		[0, 0, 0, 1],
		[ME.EMPTY, 1, 3, 2],
		[3, 4, 2, 3],
	]
	var coat := [
		[0, 0, 0, 0],
		[5, 0, 0, 0],  # (0,1) 锁 5 层，紧邻顶行消除
		[0, 0, 0, 0],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r := ME.resolve(grid, [0, 1, 2, 3], rng, [], [], true, null, {"coat": coat})
	assert_true(r["blocker_cleared"] >= 1, "adjacent clear breaks >=1 lock layer")
	assert_true(coat[1][0] < 5 and coat[1][0] > 0, "lock decreased but still locked")
	assert_eq(grid[1][0], ME.EMPTY, "still-locked ice keeps the cell occupied without a gem")

func test_destroyed_coat_slot_fills_by_gravity() -> void:
	var grid := [[9], [ME.EMPTY], [2]]
	var coat := [[0], [1], [0]]
	var acc: Dictionary = ME.account_clears(grid, [Vector2i(0, 0)], [], null, [], {"coat": coat})
	assert_eq(acc["blocker_cleared"], 1, "adjacent clear destroys the one-layer ice")
	assert_eq(coat[1][0], 0, "ice layer gone")
	assert_eq(grid[1][0], ME.EMPTY, "destroyed ice becomes an empty slot before gravity")
	ME.apply_gravity(grid, [], false, {"coat": coat})
	assert_eq(grid[1][0], 9, "tile above drops into the former ice slot")

func test_destroyed_coat_slot_refills_while_other_coats_remain() -> void:
	var grid := [
		[1, 4, 1, 1, 0, 2, 2],
		[1, 1, 3, 3, 1, 2, 0],
		[0, 3, 1, 3, 3, 0, 4],
		[0, 0, 3, 4, 4, 1, 0],
		[2, 0, 4, 4, 0, 0, 1],
		[4, 3, 1, 1, 2, 1, 2],
		[4, 2, 0, 0, 4, 1, 2],
	]
	var coat := [
		[0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0],
		[0, 0, 1, 0, 3, 0, 0],
		[0, 0, 0, 3, 0, 0, 0],
		[0, 0, 3, 0, 3, 0, 0],
		[0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0],
	]
	var fx := []
	for _y in range(grid.size()):
		var row := []
		for _x in range(grid[0].size()):
			row.append(ME.SP_NONE)
		fx.append(row)
	ME.apply_blocker_occupancy(grid, fx, coat)
	var acc: Dictionary = ME.account_clears(grid, [Vector2i(2, 1)], fx, null, [], {"coat": coat})
	assert_eq(acc["blocker_cleared"], 1, "adjacent match destroys the one-layer ice")
	assert_eq(coat[2][2], 0, "destroyed ice is no longer a blocker")
	assert_eq(grid[2][2], ME.EMPTY, "destroyed blocker first exposes an empty slot")
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	ME.apply_gravity(grid, fx, false, {"coat": coat})
	ME.refill(grid, [0, 1, 2, 3, 4], rng, fx, [], {"coat": coat})
	assert_true(grid[2][2] >= 0, "former ice slot must receive a visible gem even while other ice blockers remain")
	assert_eq(coat[4][2], 3, "unrelated remaining blockers still occupy their cells")

# ───────────── Meta 技能原语（10 §7 B 第一批）─────────────

func test_apply_gravity_up_flip() -> void:
	# 重力翻转(#5)：up=true 时非空棋子上浮、空格沉底。
	var grid := [[0], [ME.EMPTY], [1], [ME.EMPTY]]  # 列：[0, _, 1, _]
	ME.apply_gravity(grid, [], true)
	assert_eq(grid[0][0], 0, "tile 0 risen to top")
	assert_eq(grid[1][0], 1, "tile 1 risen below it")
	assert_eq(grid[2][0], ME.EMPTY, "empty sinks")
	assert_eq(grid[3][0], ME.EMPTY, "empty at bottom")

func test_cells_of_species() -> void:
	# 同类消除(#7)：枚举某色全部格。
	var grid := [[0, 1, 0], [2, 0, 3]]
	var cells := ME.cells_of_species(grid, 0)
	assert_eq(cells.size(), 3, "three cells of species 0")
	assert_true(cells.has(Vector2i(0, 0)) and cells.has(Vector2i(2, 0)) and cells.has(Vector2i(1, 1)), "right cells")

func test_break_blockers() -> void:
	# 破障(#9)：清至多 n 个锁住格。
	var coat := [[2, 0], [1, 3]]  # 3 个锁住格
	var broken := ME.break_blockers(coat, 2)
	assert_eq(broken, 2, "broke exactly 2 (n cap)")
	var remaining := 0
	for row in coat:
		for v in row:
			if v > 0:
				remaining += 1
	assert_eq(remaining, 1, "one coated cell remains")

func test_best_moves_finds_clearing_swap() -> void:
	# 预知(#8)：返回最优合法步，top 步必能形成消除。
	var grid := [[0, 0, 1], [1, 2, 0], [3, 4, 5]]
	var moves := ME.best_moves(grid, 3)
	assert_true(moves.size() >= 1, "at least one hinted move")
	if moves.size() >= 1:
		var a: Vector2i = moves[0][0]
		var b: Vector2i = moves[0][1]
		ME._swap_cells(grid, a, b)
		assert_false(ME.find_matches(grid).is_empty(), "top hinted move creates a match")
		ME._swap_cells(grid, a, b)

func test_best_moves_respects_non_coat_layers() -> void:
	var grid := [
		[0, 0, 1],
		[1, 2, 0],
		[3, 4, 5],
	]
	var ing := [
		[0, 0, 1],
		[0, 0, 0],
		[0, 0, 0],
	]
	var moves := ME.best_moves(grid, 1, {"ing": ing})
	assert_true(moves.is_empty(), "hint search must not suggest a swap involving an ingredient blocker")

func test_longswap_distance2() -> void:
	# 隔位对换(#4)：span=2 允许隔一格交换；span=1 时同样的交换不合法。
	var grid := [
		[1, 1, 0, 1],
		[2, 3, 4, 2],
		[3, 4, 2, 3],
	]
	var a := Vector2i(0, 0)
	var b := Vector2i(2, 0)  # 同行，隔一格(|dx|=2)
	assert_false(ME.is_legal_swap(grid, a, b), "span=1 默认：距离2交换不合法")
	assert_true(ME.is_legal_swap(grid, a, b, 2), "span=2：隔位交换合法(换后 x=1,2,3 成 1,1,1)")
