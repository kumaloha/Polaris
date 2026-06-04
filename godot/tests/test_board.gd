extends "res://tests/test_lib.gd"

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")

func _make(target := 100, moves := 20, seed_val := 1) -> Board:
	return Board.new(8, 8, [0, 1, 2, 3, 4], target, moves, seed_val)

func _find_legal_move(grid: Array) -> Array:
	if grid.is_empty():
		return []
	var h := grid.size()
	var w: int = grid[0].size()
	for y in h:
		for x in w:
			if x + 1 < w and ME.is_legal_swap(grid, Vector2i(x, y), Vector2i(x + 1, y)):
				return [Vector2i(x, y), Vector2i(x + 1, y)]
			if y + 1 < h and ME.is_legal_swap(grid, Vector2i(x, y), Vector2i(x, y + 1)):
				return [Vector2i(x, y), Vector2i(x, y + 1)]
	return []

func test_board_start_initializes() -> void:
	var b := _make()
	assert_eq(b.grid.size(), 8, "height = 8")
	assert_eq(b.grid[0].size(), 8, "width = 8")
	assert_eq(b.score, 0, "score starts at 0")
	assert_eq(b.moves_left, 20, "moves_left = move_limit")
	assert_true(ME.find_matches(b.grid).is_empty(), "no initial match")
	assert_true(ME.has_legal_move(b.grid), "start board has a legal move")

func test_board_initializes_fx_layer() -> void:
	var b := _make()
	assert_eq(b.fx.size(), 8, "fx height = 8")
	assert_eq(b.fx[0].size(), 8, "fx width = 8")
	assert_eq(b.fx[0][0], ME.SP_NONE, "fx starts all NONE (no specials at start)")

func test_illegal_swap_costs_nothing() -> void:
	var b := _make()
	var r := b.try_swap(Vector2i(0, 0), Vector2i(7, 7))  # 非相邻 → 非法
	assert_false(r["ok"], "illegal swap rejected")
	assert_eq(b.score, 0, "no score on illegal swap")
	assert_eq(b.moves_left, 20, "no move consumed on illegal swap")

func test_legal_swap_scores_and_consumes_move() -> void:
	var b := _make()
	var mv := _find_legal_move(b.grid)
	assert_true(mv.size() == 2, "found a legal move (sanity)")
	if mv.size() != 2:
		return
	var r := b.try_swap(mv[0], mv[1])
	assert_true(r["ok"], "legal swap accepted")
	assert_true(b.score > 0, "score increased")
	assert_eq(b.moves_left, 19, "exactly one move consumed")
	assert_true(ME.find_matches(b.grid).is_empty(), "board stable after move")

func test_win_when_target_reached() -> void:
	var b := _make(1, 20, 1)  # 目标 1 → 任意得分即胜
	var mv := _find_legal_move(b.grid)
	assert_true(mv.size() == 2, "found a legal move (sanity)")
	if mv.size() != 2:
		return
	b.try_swap(mv[0], mv[1])
	assert_true(b.is_won(), "won after reaching target")

func test_lose_when_moves_exhausted_below_target() -> void:
	var b := _make(999999, 1, 1)  # 不可能的目标 + 仅 1 步
	var mv := _find_legal_move(b.grid)
	assert_true(mv.size() == 2, "found a legal move (sanity)")
	if mv.size() != 2:
		return
	b.try_swap(mv[0], mv[1])
	assert_eq(b.moves_left, 0, "moves exhausted")
	assert_true(b.is_lost(), "lost: out of moves below target")

func test_board_deterministic_with_seed() -> void:
	var b1 := _make(100, 20, 42)
	var b2 := _make(100, 20, 42)
	assert_true(b1.grid.size() > 0, "built (sanity)")
	assert_eq(b1.grid, b2.grid, "same seed -> identical start board")

func test_board_wins_collect_objective() -> void:
	var objs := [{"type": "COLLECT", "species": 0, "target": 5}]
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 0, 30, 7, [], objs)
	for i in 30:
		if b.is_over():
			break
		var mv := _find_legal_move(b.grid)
		if mv.size() != 2:
			break
		b.try_swap(mv[0], mv[1])
	assert_true(b.collected.get(0, 0) >= 5, "collected >= 5 of species 0")
	assert_true(b.is_won(), "won via COLLECT objective")

func test_colorbomb_swap_detonates_and_consumes_move() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 1)  # 大目标 → 不会胜
	b.grid = [
		[0, 1, 2, 3],
		[1, 0, 3, 2],
		[5, 1, 2, 3],  # (0,2)=5 占位彩球
		[4, 1, 2, 3],
	]
	b.fx = b._blank_fx()
	b.fx[2][0] = ME.SP_COLORBOMB
	var r := b.try_swap(Vector2i(0, 2), Vector2i(0, 1))  # 彩球与上方 species-1 交换
	assert_true(r["ok"], "colorbomb swap is always legal (no match required)")
	assert_true(b.score > 0, "detonation scored")
	assert_eq(b.moves_left, 9, "one move consumed")
	assert_true(ME.find_matches(b.grid).is_empty(), "board settled after detonation")
