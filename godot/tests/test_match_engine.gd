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
	assert_eq(c["spawns"][0]["kind"], ME.SP_LINE_V, "horizontal 4 -> LINE_V (垂直约定:横连生成竖特效)")
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
	assert_eq(c["spawns"][0]["kind"], ME.SP_LINE_H, "vertical 4 -> LINE_H (垂直约定:竖连生成横特效)")
	assert_eq(c["clear"].size(), 3, "4 matched minus 1 spawn = 3 cleared")

func test_classify_t_shape_spawns_bomb() -> void:
	var grid := [[0, 0, 0], [1, 0, 2], [3, 0, 4]]  # row0 三连 + col1 三连，交于 (1,0)
	var c := ME.classify_matches(grid)
	assert_eq(c["spawns"].size(), 1, "one special (bomb)")
	assert_eq(c["spawns"][0]["kind"], ME.SP_BOMB, "T/L -> BOMB")
	assert_eq(c["spawns"][0]["pos"], Vector2i(1, 0), "bomb at the intersection")
	assert_eq(c["clear"].size(), 4, "5 matched minus 1 bomb spawn = 4")

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
	assert_eq(c["spawns"][0]["kind"], ME.SP_LINE_V, "h4 -> LINE_V (垂直约定)")

func test_collect_triggers_line_clears_whole_row() -> void:
	var grid := [[9, 8, 5, 9, 8], [5, 5, 5, 7, 6], [8, 7, 4, 6, 9]]  # 仅 row1 的 5,5,5 三连
	var fx := _none_fx(5, 3)
	fx[1][2] = ME.SP_LINE_H  # (2,1) 是直线特效
	var c := ME.collect_clears(grid, fx)
	var tc: Array = c["to_clear"]
	assert_eq(tc.size(), 5, "line trigger expands to whole row 1")
	assert_true(tc.has(Vector2i(3, 1)) and tc.has(Vector2i(4, 1)), "row cells beyond the 3-match added by the line")

func test_apply_clears_spawns_line_and_empties_others() -> void:
	var grid := [[0, 0, 0, 0, 1], [1, 2, 3, 2, 3], [2, 3, 1, 3, 1]]
	var fx := _none_fx(5, 3)
	var c := ME.collect_clears(grid, fx)
	ME._apply_clears(grid, fx, c["to_clear"], c["spawns"])
	var sp: Vector2i = c["spawns"][0]["pos"]
	assert_eq(fx[sp.y][sp.x], ME.SP_LINE_V, "spawn cell becomes LINE_V (h4→竖特效)")
	assert_ne(grid[sp.y][sp.x], ME.EMPTY, "spawn cell keeps its species (not emptied)")
	var empties := 0
	for x in 5:
		if grid[0][x] == ME.EMPTY:
			empties += 1
	assert_eq(empties, 3, "3 of the 4 matched cells emptied (1 became the special)")

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
	var grid := [[0], [6], [ME.EMPTY]]   # 列：[0, 6(锁), EMPTY]
	var coat := [[0], [1], [0]]          # (0,1) 锁住
	ME.apply_gravity(grid, [], false, {"coat": coat})
	assert_eq(grid[0][0], 0, "tile above lock stays (can't fall through)")
	assert_eq(grid[1][0], 6, "locked cell stays put under gravity")
	assert_eq(grid[2][0], ME.EMPTY, "below-lock empty stays empty")

func test_resolve_locked_broken_by_adjacency() -> void:
	var grid := [
		[0, 0, 0, 1],
		[2, 1, 3, 2],
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
	assert_eq(grid[1][0], 2, "locked tile preserved (not cleared/moved)")

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
