extends "res://tests/test_lib.gd"

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")

func _make(target := 100, moves := 20, seed_val := 1) -> Board:
	return Board.new(8, 8, [0, 1, 2, 3, 4], target, moves, seed_val)

func _find_legal_move(grid: Array, coat: Array = []) -> Array:
	if grid.is_empty():
		return []
	var h := grid.size()
	var w: int = grid[0].size()
	for y in h:
		for x in w:
			if x + 1 < w and ME.is_legal_swap(grid, Vector2i(x, y), Vector2i(x + 1, y), coat):
				return [Vector2i(x, y), Vector2i(x + 1, y)]
			if y + 1 < h and ME.is_legal_swap(grid, Vector2i(x, y), Vector2i(x, y + 1), coat):
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

func test_board_clears_jelly_objective() -> void:
	var jelly_layer := []
	for y in 8:
		var row := []
		for x in 8:
			row.append(1)
		jelly_layer.append(row)
	var objs := [{"type": "CLEAR_JELLY", "species": -1, "target": 8}]
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 0, 30, 7, [], objs, jelly_layer)
	for i in 30:
		if b.is_over():
			break
		var mv := _find_legal_move(b.grid)
		if mv.size() != 2:
			break
		b.try_swap(mv[0], mv[1])
	assert_true(b.jelly_cleared >= 8, "cleared >= 8 jelly layers")
	assert_true(b.is_won(), "won via CLEAR_JELLY objective")

func test_board_clears_blocker_objective() -> void:
	var coat_layer := []
	for y in 8:
		var row := []
		for x in 8:
			row.append(0)
		coat_layer.append(row)
	for i in 8:
		coat_layer[i][i] = 1  # 对角线 8 个锁
	var objs := [{"type": "CLEAR_BLOCKER", "species": -1, "target": 5}]
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 0, 40, 7, [], objs, [], coat_layer)
	for i in 40:
		if b.is_over():
			break
		var mv := _find_legal_move(b.grid, b.coat)
		if mv.size() != 2:
			break
		b.try_swap(mv[0], mv[1])
	assert_true(b.blocker_cleared >= 5, "broke >= 5 coat layers")
	assert_true(b.is_won(), "won via CLEAR_BLOCKER objective")

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

# ───────────────────────────── P1 回归（运行时 bug）─────────────────────────────

func test_objective_level_loses_when_moves_exhausted() -> void:
	# P1#1：纯目标关(target_score=0)，目标高到打不完、步数耗尽 → 必须判负。
	# 旧 is_lost() 只看 score<target_score，target_score=0 时 score<0 恒假 → 卡死，既不胜也不负。
	var objs := [{"type": "COLLECT", "species": 0, "target": 99999}]
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 0, 1, 3, [], objs)  # target_score=0，仅 1 步
	var mv := _find_legal_move(b.grid)
	assert_true(mv.size() == 2, "sanity: found legal move")
	if mv.size() != 2:
		return
	b.try_swap(mv[0], mv[1])
	assert_eq(b.moves_left, 0, "moves exhausted")
	assert_false(b.is_won(), "objective not met")
	assert_true(b.is_lost(), "P1#1: must be LOST when moves gone and objective unmet")
	assert_true(b.is_over(), "game is over")

func test_reshuffle_keeps_walls_in_place() -> void:
	# P1#2：异形棋盘洗牌只应重排可动棋子；墙(WALL)必须原地不动、数量不变。
	# 旧 reshuffle 把 WALL 也收进 tiles 一起 Fisher-Yates → 墙被洗到随机位置，棋盘损毁。
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var grid := []
	for y in 6:
		var row := []
		for x in 6:
			row.append((x + y) % 4)
		grid.append(row)
	var walls := [Vector2i(0, 0), Vector2i(5, 0), Vector2i(2, 3), Vector2i(1, 5)]
	for wpos in walls:
		grid[wpos.y][wpos.x] = ME.WALL
	ME.reshuffle(grid, rng)
	for wpos in walls:
		assert_eq(grid[wpos.y][wpos.x], ME.WALL, "P1#2: wall stays put at %s" % str(wpos))
	var wall_count := 0
	for y in 6:
		for x in 6:
			if grid[y][x] == ME.WALL:
				wall_count += 1
	assert_eq(wall_count, walls.size(), "P1#2: wall count unchanged (none teleported)")

func test_colorbomb_counts_toward_collect_objective() -> void:
	# P1#3：彩球直清的格也要计入 COLLECT/果冻/涂层，否则目标关白清。
	# 旧 _activate_colorbomb 只 _accumulate 了其后级联；彩球本体清掉的目标色没算。
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 1)  # 大目标 → 不会因分数胜
	b.grid = [
		[0, 1, 2, 3],
		[1, 0, 3, 2],
		[5, 1, 2, 3],  # (0,2)=5 占位彩球
		[4, 1, 2, 3],
	]
	b.fx = b._blank_fx()
	b.fx[2][0] = ME.SP_COLORBOMB
	# 与上方 species-1 交换 → 直清全部 species-1：(1,0)(0,1)(1,2)(1,3) 共 4 个
	b.try_swap(Vector2i(0, 2), Vector2i(0, 1))
	assert_true(b.collected.get(1, 0) >= 4,
		"P1#3: colorbomb direct clears must count toward COLLECT (>=4 of species 1), got %d" % b.collected.get(1, 0))

func test_colorbomb_spares_locked_cell() -> void:
	# 经典锁：彩球清同色时，锁住的同色格只破锁、不被清除。
	var coat_layer := []
	for y in 4:
		var row := []
		for x in 4:
			row.append(0)
		coat_layer.append(row)
	coat_layer[0][1] = 5  # 锁住 (1,0)=species 1，5 层（确保级联中仍锁住）
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 1, [], [], [], coat_layer)
	b.grid = [
		[0, 1, 2, 3],
		[1, 0, 3, 2],
		[5, 1, 2, 3],  # (0,2)=占位彩球
		[4, 1, 2, 3],
	]
	b.fx = b._blank_fx()
	b.fx[2][0] = ME.SP_COLORBOMB
	b.try_swap(Vector2i(0, 2), Vector2i(0, 1))  # 彩球换 species-1 → 目标清 species-1
	assert_eq(b.grid[0][1], 1, "locked species-1 cell NOT cleared by colorbomb")
	assert_true(b.coat[0][1] < 5 and b.coat[0][1] > 0, "but its lock was broken (still locked)")

# ───────────── Meta 技能：借贷(#1) 垂直切片（10 §7）─────────────

func test_borrow_once_per_game() -> void:
	# 借贷一局一次：第二次借被拒。
	var b := Board.new(4, 4, [0, 1, 2, 3], 999, 20, 5)
	b.skill = "borrow"
	b.grid[0][0] = 0; b.fx[0][0] = ME.SP_NONE
	b.grid[1][1] = 0; b.fx[1][1] = ME.SP_NONE
	assert_true(b.skill_borrow(Vector2i(0, 0), ME.SP_BOMB), "first borrow ok")
	assert_eq(b.fx[0][0], ME.SP_BOMB, "special placed on the cell")
	assert_eq(b.borrow_debt, 1, "one debt incurred")
	assert_false(b.skill_borrow(Vector2i(1, 1), ME.SP_BOMB), "second borrow rejected (一局一次)")
	assert_eq(b.borrow_debt, 1, "still one debt")

func test_borrow_requires_equipped_skill() -> void:
	# 没装借贷技能 → 借不了（裸 Core 无技能）。
	var b := Board.new(4, 4, [0, 1, 2, 3], 999, 20, 5)
	b.grid[0][0] = 0; b.fx[0][0] = ME.SP_NONE
	assert_false(b.skill_borrow(Vector2i(0, 0), ME.SP_LINE_H), "no skill equipped -> borrow rejected")

func test_unpaid_debt_blocks_then_repay_wins() -> void:
	# 借贷铁律：欠债未还不过关，即使目标达成；还债后才算过关。
	var b := Board.new(4, 4, [0, 1, 2, 3], 1, 20, 5)  # target_score=1（易胜）
	b.skill = "borrow"
	b.grid[0][0] = 0; b.fx[0][0] = ME.SP_NONE
	assert_true(b.skill_borrow(Vector2i(0, 0), ME.SP_LINE_H), "borrow at start")
	b.score = 100  # 模拟达成目标
	assert_false(b.is_won(), "objective met but unpaid debt -> NOT won")
	assert_false(b.is_over(), "not over: must repay (moves remain)")
	assert_true(b.skill_repay(Vector2i(0, 0)), "repay: downgrade the special")
	assert_eq(b.borrow_debt, 0, "debt cleared")
	assert_eq(b.fx[0][0], ME.SP_NONE, "special downgraded to normal")
	assert_true(b.is_won(), "after repay -> won")

func test_unpaid_debt_loses_when_moves_out() -> void:
	# 欠债 + 步数耗尽 → 判负（不算过关）。
	var b := Board.new(4, 4, [0, 1, 2, 3], 1, 5, 5)
	b.skill = "borrow"
	b.grid[0][0] = 0; b.fx[0][0] = ME.SP_NONE
	b.skill_borrow(Vector2i(0, 0), ME.SP_COLORBOMB)
	b.score = 100      # 目标达成
	b.moves_left = 0   # 步数耗尽
	assert_false(b.is_won(), "debt blocks win")
	assert_true(b.is_lost(), "moves out + unpaid debt -> lost")
