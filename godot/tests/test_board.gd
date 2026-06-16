extends "res://tests/test_lib.gd"

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")
const LevelLibrary := preload("res://core/level_library.gd")

func _make(target := 100, moves := 20, seed_val := 1) -> Board:
	return Board.new(8, 8, [0, 1, 2, 3, 4], target, moves, seed_val)

func _zeros(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		var row := []
		for x in w:
			row.append(0)
		rows.append(row)
	return rows

func _find_legal_move(grid: Array, coat: Array = []) -> Array:
	if grid.is_empty():
		return []
	var h := grid.size()
	var w: int = grid[0].size()
	for y in h:
		for x in w:
			if x + 1 < w and ME.is_legal_swap(grid, Vector2i(x, y), Vector2i(x + 1, y), 1, {"coat": coat}):
				return [Vector2i(x, y), Vector2i(x + 1, y)]
			if y + 1 < h and ME.is_legal_swap(grid, Vector2i(x, y), Vector2i(x, y + 1), 1, {"coat": coat}):
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


func test_last_move_target_reached_is_won_not_lost() -> void:
	var b := _make(1, 1, 1)
	var mv := _find_legal_move(b.grid)
	assert_true(mv.size() == 2, "found a legal move (sanity)")
	if mv.size() != 2:
		return
	b.try_swap(mv[0], mv[1])
	assert_eq(b.moves_left, 0, "last available move was spent")
	assert_true(b.is_won(), "last-move target completion is still a win")
	assert_false(b.is_lost(), "last-move target completion must not fall through to loss")


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
	var coat_layer := _zeros(4, 4)
	coat_layer[0][3] = 1
	var objs := [{"type": "CLEAR_BLOCKER", "species": -1, "target": 1}]
	var b := Board.new(4, 4, [0, 1, 2, 3], 0, 5, 7, [], objs, [], coat_layer)
	b.grid = [
		[0, 0, 1, ME.EMPTY],
		[1, 2, 0, 3],
		[2, 3, 1, 2],
		[3, 1, 2, 1],
	]
	b.fx = b._blank_fx()
	var r := b.try_swap(Vector2i(2, 1), Vector2i(2, 0))
	assert_true(r.get("ok", false), "swap creates a match adjacent to a blocker")
	assert_true(b.blocker_cleared >= 1, "broke the adjacent coat layer")
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

func test_swap_spawned_special_uses_moved_piece_new_position() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 4)
	b.grid = [
		[0, 0, 1, 0],
		[1, 2, 0, 3],
		[2, 3, 1, 2],
		[3, 1, 2, 1],
	]
	b.fx = b._blank_fx()
	var moved_from := Vector2i(2, 1)
	var moved_to := Vector2i(2, 0)
	var r := b.try_swap(moved_from, moved_to)
	assert_true(r.get("ok", false), "swap creates a horizontal four-match")
	assert_eq(b.fx[moved_to.y][moved_to.x], ME.SP_LINE_V, "horizontal four-match creates a vertical line special where the moved piece arrived")
	assert_eq(b.fx[0][1], ME.SP_NONE, "run midpoint does not receive the special")

func test_swap_spawned_special_uses_other_moved_position_when_target_is_outside_match() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 4)
	b.grid = [
		[1, 2, 3, 1],
		[0, 0, 1, 0],
		[2, 3, 0, 2],
		[3, 1, 2, 1],
	]
	b.fx = b._blank_fx()
	var first_selected := Vector2i(2, 1)
	var second_selected_target := Vector2i(2, 2)
	var r := b.try_swap(first_selected, second_selected_target)
	assert_true(r.get("ok", false), "swap creates a horizontal four-match through the first-selected cell")
	assert_eq(b.fx[first_selected.y][first_selected.x], ME.SP_LINE_V, "the generated 4-match special lands on the other piece's new matched position")
	assert_eq(b.fx[second_selected_target.y][second_selected_target.x], ME.SP_NONE, "the second-selected target must stay ordinary when it is outside the match")

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
	# 冰块占格：彩球清同色时，旁边冰块只破层；冰块下面没有可被清掉的同色宝石。
	var coat_layer := []
	for y in 4:
		var row := []
		for x in 4:
			row.append(0)
		coat_layer.append(row)
	coat_layer[1][1] = 5  # (1,1) 冰块紧邻被彩球清掉的 (0,1)
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 1, [], [], [], coat_layer)
	b.grid = [
		[0, 1, 2, 3],
		[1, 0, 3, 2],
		[5, 1, 2, 3],  # (0,2)=占位彩球
		[4, 1, 2, 3],
	]
	b.fx = b._blank_fx()
	b.fx[2][0] = ME.SP_COLORBOMB
	ME.apply_blocker_occupancy(b.grid, b.fx, b.coat)
	b.try_swap(Vector2i(0, 2), Vector2i(0, 1))  # 彩球换 species-1 → 目标清 species-1
	assert_eq(b.grid[1][1], ME.EMPTY, "ice cell still has no hidden gem after colorbomb")
	assert_true(b.coat[1][1] < 5 and b.coat[1][1] > 0, "adjacent colorbomb clear damages the ice but does not remove all layers")

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

# ───────────── 被动技能 #10/#11 + 状态历史 #2/#3 ─────────────

func test_chainbonus_awards_move() -> void:
	# 连消奖步(#10)：连锁≥阈值奖 1 步。
	var b := Board.new(4, 4, [0, 1, 2, 3], 999, 20, 5)
	b.skill = "chainbonus"
	b.chain_threshold = 3
	b._on_move_resolved(3)
	assert_eq(b.moves_left, 21, "chain>=threshold awards +1 move (20->21)")
	assert_eq(b.bonus_moves, 1, "bonus tracked")
	b._on_move_resolved(2)
	assert_eq(b.moves_left, 21, "below threshold: no award")

func test_collector_collects_fragments() -> void:
	# 连击收集(#11)：连击额外攒铭文碎片。
	var b := Board.new(4, 4, [0, 1, 2, 3], 999, 20, 5)
	b.skill = "collector"
	b._on_move_resolved(3)
	assert_eq(b.fragments, 3, "combo collects fragments = cascades")
	b._on_move_resolved(1)
	assert_eq(b.fragments, 3, "cascades<2: no extra")

func test_rewind_restores_earlier_state() -> void:
	# 时间回退(#2)：回到窗口内最早局面，一局一次。
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 30, 7)
	b.skill = "timerewind"
	var start_grid = b.grid.duplicate(true)
	for i in 2:
		var mv := _find_legal_move(b.grid)
		assert_true(mv.size() == 2, "legal move exists")
		if mv.size() != 2:
			return
		b.try_swap(mv[0], mv[1])
	assert_eq(b.moves_left, 28, "two moves consumed")
	assert_true(b.skill_rewind(), "rewind ok")
	assert_eq(b.moves_left, 30, "rewound to opening (within window)")
	assert_eq(b.grid, start_grid, "board restored to opening")
	assert_false(b.skill_rewind(), "rewind 一局一次")

func test_snapshot_save_and_load() -> void:
	# 存档快照(#3)：存当前局面，跳回，存档被消耗。
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 30, 7)
	b.skill = "snapshot"
	assert_true(b.skill_save(), "save ok")
	var saved_moves := b.moves_left
	var saved_grid = b.grid.duplicate(true)
	for i in 3:
		var mv := _find_legal_move(b.grid)
		if mv.size() != 2:
			break
		b.try_swap(mv[0], mv[1])
	assert_true(b.moves_left < saved_moves, "state changed by play")
	assert_true(b.skill_load(), "load ok")
	assert_eq(b.moves_left, saved_moves, "moves restored")
	assert_eq(b.grid, saved_grid, "board restored")
	assert_false(b.skill_load(), "load consumed the save")

func test_colorbomb_shield_preserves_colorbomb() -> void:
	# 彩球护盾(#6)：引爆时护盾在 → 彩球本体保留、护盾消耗。
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 1)
	b.skill = "colorshield"
	b.grid = [
		[0, 1, 2, 3],
		[1, 0, 3, 2],
		[5, 1, 2, 3],
		[4, 1, 2, 3],
	]
	b.fx = b._blank_fx()
	b.fx[2][0] = ME.SP_COLORBOMB
	assert_true(b.skill_shield(), "shield activated")
	b.try_swap(Vector2i(0, 2), Vector2i(0, 1))  # 引爆彩球
	var cb_count := 0
	for row in b.fx:
		for f in row:
			if f == ME.SP_COLORBOMB:
				cb_count += 1
	assert_true(cb_count >= 1, "colorbomb preserved by shield")
	assert_eq(b.colorbomb_shield, 0, "shield consumed")

# ───────────── 打通两端：关卡库读取（05 数据契约）─────────────

func test_board_from_level_dict() -> void:
	var d := {
		"w": 3, "h": 2,
		"species": [0, 1, 2],
		"init_board": [[0, 1, 2], [2, 0, 1]],
		"target_score": 0,
		"move_limit": 15,
		"seed": 7,
		"objectives": [{"type": "COLLECT", "species": 1, "target": 5}],
		"jelly": [[1, 0, 1], [0, 0, 0]],
		"coat": [],
	}
	var b := LevelLibrary.to_board(d)
	assert_eq(b.grid, [[0, 1, 2], [2, 0, 1]], "exact board loaded (not regenerated)")
	assert_eq(b.move_limit, 15, "move_limit loaded")
	assert_eq(b.objectives.size(), 1, "objective loaded")
	assert_eq(b.objectives[0]["species"], 1, "objective species loaded")
	assert_eq(typeof(b.objectives[0]["species"]), TYPE_INT, "species is int (dict-key safe)")
	assert_eq(b.jelly, [[1, 0, 1], [0, 0, 0]], "jelly layer loaded")
	assert_eq(b.fx.size(), 2, "fx sized to board height")

func test_level_library_parses_and_builds() -> void:
	var json := '{"levels":[{"w":2,"h":2,"species":[0,1],"init_board":[[0,1],[1,0]],"move_limit":10,"objectives":[]}]}'
	var lvls := LevelLibrary.load_string(json)
	assert_eq(lvls.size(), 1, "one level parsed from json")
	var b := LevelLibrary.to_board(lvls[0])
	assert_eq(b.grid, [[0, 1], [1, 0]], "board built from json level")
	assert_eq(b.move_limit, 10, "move_limit from json")
	assert_eq(LevelLibrary.load_string("not json").size(), 0, "bad json -> empty (safe)")

func test_level_library_preserves_compiled_fx_rewards() -> void:
	var d := {
		"w": 2, "h": 2,
		"species": [0, 1],
		"init_board": [[0, 1], [1, 0]],
		"fx": [[ME.SP_LINE_H, ME.SP_NONE], [ME.SP_NONE, ME.SP_BOMB]],
		"move_limit": 10,
		"objectives": [],
	}
	var b := LevelLibrary.to_board(d)
	assert_eq(b.fx[0][0], ME.SP_LINE_H, "compiled horizontal line reward preserved")
	assert_eq(b.fx[1][1], ME.SP_BOMB, "compiled burst reward preserved")


func test_level_library_clears_hidden_tile_under_ingredient_actor() -> void:
	var d := {
		"w": 2, "h": 2,
		"species": [0, 1],
		"init_board": [[0, 1], [1, 0]],
		"move_limit": 10,
		"objectives": [{"type": "COLLECT_INGREDIENT", "species": -1, "target": 1}],
		"ing": [[0, 1], [0, 0]],
		"exits": [1],
	}
	var b := LevelLibrary.to_board(d)
	assert_eq(b.ing[0][1], 1, "ingredient actor layer loaded")
	assert_eq(b.grid[0][1], ME.EMPTY, "loaded ingredient actor does not keep a hidden normal gem underneath")

func test_level_library_resolves_levels_path_from_args() -> void:
	assert_eq(LevelLibrary.levels_path_from_args([]), "res://levels.json", "default level library path")
	assert_eq(LevelLibrary.levels_path_from_args(["--levels", "res://levels.generated.json"]), "res://levels.generated.json", "--levels value selects generated library")
	assert_eq(LevelLibrary.levels_path_from_args(["--levels=res://levels.generated.json"]), "res://levels.generated.json", "--levels=value selects generated library")
	assert_eq(LevelLibrary.levels_path_from_args(["--level-library", "res://custom.json"]), "res://custom.json", "--level-library alias works")
	assert_eq(LevelLibrary.levels_path_from_args(["--levels"]), "res://levels.json", "missing --levels value falls back safely")

func test_generated_level_library_loads() -> void:
	var lvls := LevelLibrary.load_file("res://levels.generated.json")
	assert_eq(lvls.size(), 10, "generated solver-gated library contains first ten levels")
	if lvls.is_empty():
		return
	assert_true(String(lvls[0].get("level_id", "")).begins_with("level_001_base"), "generated library starts with a selected level_001_base candidate")
	assert_eq(int(lvls[0].get("meta", {}).get("level_coordinate", 0)), 1, "generated first level keeps coordinate metadata")
	assert_eq(int(lvls[0].get("w", 0)), 7, "generated first level width")
	assert_eq(int(lvls[0].get("h", 0)), 7, "generated first level height")

func test_level_library_reads_scrolling() -> void:
	# C++ 导出的滚动关：is_scrolling + 每列 feed 队列 → Board
	var d := {
		"w": 2, "h": 2,
		"species": [0, 1, 2],
		"init_board": [[0, 1], [1, 0]],
		"move_limit": 30,
		"objectives": [],
		"is_scrolling": true,
		"feed": [[7, 8], [9]],
	}
	var b := LevelLibrary.to_board(d)
	assert_eq(b.is_scrolling, true, "scroll flag loaded from json")
	assert_eq(b.feed.size(), 2, "feed has one queue per column")
	assert_eq(b.feed[0], [7, 8], "feed col0 loaded front-first")
	assert_eq(b.feed[1], [9], "feed col1 loaded")
	# 普通关默认非滚动
	var d2 := {"w": 2, "h": 2, "species": [0, 1], "init_board": [[0, 1], [1, 0]], "move_limit": 10, "objectives": []}
	var b2 := LevelLibrary.to_board(d2)
	assert_eq(b2.is_scrolling, false, "non-scroll level defaults is_scrolling=false")

func _count_walls(grid: Array) -> int:
	var n := 0
	for row in grid:
		for v in row:
			if v == ME.WALL:
				n += 1
	return n

func test_level_with_walls_survives_start() -> void:
	# P1 回归：带异形墙(init_board 含 WALL=-2)的关，再走 start() 重开后墙必须保留。
	# 旧 bug：to_board 给 Board.new() 传空 wall_mask → start() 的 make_board 重生成无墙盘
	#         → init_board 里的 -2 被覆盖、墙消失（任何走 start() 路径的异形关墙都丢）。
	# 修复(level_library._wall_mask_from)：从 init_board 提取墙掩码传入 → start() 按 mask 铺回墙。
	var init_board := [
		[-2,  0,  1, -2],   # -2 == ME.WALL
		[ 1,  2,  0,  1],
		[ 2,  0,  1,  2],
		[-2,  1,  2, -2],
	]
	var d := {
		"w": 4, "h": 4,
		"species": [0, 1, 2],
		"init_board": init_board,
		"move_limit": 20,
		"objectives": [],
	}
	var b := LevelLibrary.to_board(d)
	assert_eq(_count_walls(b.grid), 4, "walls present right after to_board")
	assert_false(b.wall_mask.is_empty(), "wall_mask extracted from init_board (for start regen)")
	# 关键：重开本关(直接走 start 路径) → 墙必须仍在、位置不变（数量与 init_board 一致）
	b.start()
	assert_eq(_count_walls(b.grid), 4, "P1: walls survive start() (mask-loss regression guard)")
	for y in 4:
		for x in 4:
			if init_board[y][x] == ME.WALL:
				assert_eq(b.grid[y][x], ME.WALL, "wall preserved at (%d,%d) after start" % [x, y])
			else:
				assert_true(b.grid[y][x] >= 0, "non-wall cell is a normal piece at (%d,%d)" % [x, y])

# ───────────── 主动技能 board API（#5/#7/#9/#8，一局一次）─────────────

func test_skill_gravity_flip() -> void:
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 30, 7)
	b.skill = "gravityflip"
	assert_true(b.skill_gravity_flip(), "flip ok")
	assert_true(b.active_used, "active used")
	assert_false(b.skill_gravity_flip(), "one per game")
	assert_true(ME.find_matches(b.grid).is_empty(), "board settled after flip")
	var b2 := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 30, 7)
	assert_false(b2.skill_gravity_flip(), "no skill equipped -> rejected")

func test_skill_clear_species() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 30, 1)
	b.skill = "sametypeclear"
	b.grid = [
		[0, 1, 2, 3],
		[1, 0, 2, 3],
		[2, 3, 0, 1],
		[3, 2, 1, 0],
	]
	b.fx = b._blank_fx()
	assert_true(b.skill_clear_species(0), "clear species 0 ok")
	assert_true(b.score > 0, "scored from clearing 4 cells of species 0")
	assert_true(b.active_used, "active used")
	assert_false(b.skill_clear_species(0), "one per game")

func test_skill_break() -> void:
	var coat_layer := []
	for y in 4:
		var row := []
		for x in 4:
			row.append(0)
		coat_layer.append(row)
	coat_layer[0][0] = 1
	coat_layer[1][1] = 2
	coat_layer[2][2] = 1
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 30, 1, [], [], [], coat_layer)
	b.skill = "breaker"
	assert_true(b.skill_break(2), "break 2 ok")
	assert_true(b.blocker_cleared >= 2, "at least 2 blockers broken counted")
	assert_true(b.active_used, "active used")
	assert_false(b.skill_break(2), "one per game")

func test_skill_foresight() -> void:
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 30, 7)
	b.skill = "foresight"
	var moves := b.skill_foresight(3)
	assert_true(moves.size() >= 1 and moves.size() <= 3, "foresight returns up to 3 best moves")
	assert_true(b.active_used, "active used")
	assert_eq(b.skill_foresight(3).size(), 0, "one per game -> empty")

func test_longswap_via_board() -> void:
	# 隔位对换(#4)：board.longswap_armed 时 try_swap 接受隔一格交换，用后消耗。
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 20, 1)
	b.grid = [
		[1, 1, 0, 1],
		[2, 3, 0, 2],
		[3, 0, 2, 3],
		[0, 2, 3, 0],
	]
	b.fx = b._blank_fx()
	assert_false(b.try_swap(Vector2i(0, 0), Vector2i(2, 0))["ok"], "not armed: distance-2 rejected")
	b.longswap_armed = true
	assert_true(b.try_swap(Vector2i(0, 0), Vector2i(2, 0))["ok"], "armed: distance-2 swap ok")
	assert_false(b.longswap_armed, "armed consumed after use")

# ───────────── 默认提示 / 看广告续用 / 结算数据 ─────────────

func test_hint_returns_moves() -> void:
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 30, 7)
	var h := b.hint(2)
	assert_true(h.size() >= 1 and h.size() <= 2, "hint returns up to k best moves")

func test_consumed_move_settlement_hook_ticks_spreads_and_spawns() -> void:
	var choco := _zeros(4, 4)
	choco[0][0] = 1
	var bomb := _zeros(4, 4)
	bomb[2][2] = 3
	var cannon := _zeros(4, 4)
	cannon[0][3] = 1
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 12, [], [], [], [], choco, [], [], bomb, cannon)
	b.grid = [
		[0, 1, 2, ME.WALL],
		[1, 2, 3, ME.EMPTY],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	]
	b.fx = b._blank_fx()
	var before_moves: int = b.moves_left
	assert_true(b.has_method("_settle_consumed_move"), "view paths need a shared consumed-move settlement hook")
	if not b.has_method("_settle_consumed_move"):
		return
	b.call("_settle_consumed_move", 0, 0)
	assert_eq(b.moves_left, before_moves - 1, "settlement consumes exactly one move")
	assert_eq(b.bomb[2][2], 2, "settlement ticks surviving bombs")
	assert_true(ME.count_chocolate(b.choco) > 1, "zero chocolate cleared this move allows spread")
	assert_true(b.cannon_spawned > 0, "settlement spawns from cannons after a valid move")

func test_ad_continue_resets_skill_with_cap() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 20, 5)
	b.skill = "timerewind"
	b.rewind_used = true
	assert_true(b.ad_continue(), "ad-continue #1 ok")
	assert_false(b.rewind_used, "skill used-flag reset → reusable")
	b.rewind_used = true
	assert_true(b.ad_continue(), "ad-continue #2 ok")
	b.rewind_used = true
	assert_false(b.ad_continue(), "over cap(2) → no more")
	assert_eq(b.ad_continues, 2, "two continues used")

func test_result_summary() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 100, 20, 5)
	b.score = 250
	var r := b.result()
	assert_true(r["won"], "won (250>=100)")
	assert_true(r["stars"] >= 1 and r["stars"] <= 3, "1-3 stars")
	assert_eq(r["score"], 250, "score in summary")
	var b2 := Board.new(4, 4, [0, 1, 2, 3], 100, 1, 5)
	b2.score = 50
	b2.moves_left = 0
	assert_false(b2.result()["won"], "not won")
	assert_true(b2.result()["lost"], "lost (moves out, below target)")

func test_endgame_bonus_converts_remaining_moves_to_lines() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 20, 5)
	b.grid = [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	]
	b.fx = b._blank_fx()
	b.moves_left = 3
	var picks: Array = b.prepare_endgame_bonus_lines()
	assert_eq(picks.size(), 3, "one random line special per remaining move")
	assert_eq(b.moves_left, 0, "remaining moves are spent by the endgame bonus")
	var seen := {}
	for item in picks:
		var p: Vector2i = item["pos"]
		assert_false(seen.has(p), "bonus picks unique cells")
		seen[p] = true
		assert_true(b.fx[p.y][p.x] == ME.SP_LINE_H or b.fx[p.y][p.x] == ME.SP_LINE_V, "picked cell becomes a line special")

func test_endgame_bonus_skips_blockers_and_existing_specials() -> void:
	var coat_layer := []
	for y in 3:
		var row := []
		for x in 3:
			row.append(0)
		coat_layer.append(row)
	coat_layer[0][0] = 1
	var b := Board.new(3, 3, [0, 1, 2], 999999, 20, 9, [], [], [], coat_layer)
	b.grid = [
		[ME.EMPTY, 1, 2],
		[0, 1, 2],
		[0, 1, 2],
	]
	b.fx = b._blank_fx()
	b.fx[0][1] = ME.SP_BOMB
	b.moves_left = 9
	var picks: Array = b.prepare_endgame_bonus_lines()
	assert_eq(picks.size(), 7, "bonus only converts eligible ordinary gem cells")
	assert_eq(b.fx[0][0], ME.SP_NONE, "ice cell is not converted")
	assert_eq(b.fx[0][1], ME.SP_BOMB, "existing special is not overwritten")

func test_special_fusion_line_line() -> void:
	# 两个直线特效相邻交换 → 融合（十字），始终合法、无需普通消除。
	var b := Board.new(5, 5, [0, 1, 2, 3, 4], 999999, 10, 1)
	b.grid = [
		[0, 1, 2, 3, 4],
		[1, 2, 3, 4, 0],
		[2, 3, 4, 0, 1],
		[3, 4, 0, 1, 2],
		[4, 0, 1, 2, 3],
	]  # 对角拉丁方：无现成消除、无普通合法交换
	b.fx = b._blank_fx()
	b.fx[2][2] = ME.SP_LINE_H
	b.fx[2][3] = ME.SP_LINE_V
	var before := b.moves_left
	var r := b.try_swap(Vector2i(2, 2), Vector2i(3, 2))
	assert_true(r["ok"], "two specials swap always legal (fusion)")
	assert_true(r.get("fusion", false), "fusion activated")
	assert_eq(b.moves_left, before - 1, "one move consumed")
	assert_true(b.score > 0, "fusion cleared & scored")

# ───────────── 铭文/养成 喂参（量变 + 技能升级）─────────────

func test_extra_moves_enchant() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 100, 20, 5)
	assert_eq(b.moves_left, 20, "base moves")
	b.extra_moves = 3
	b.start()
	assert_eq(b.moves_left, 23, "铭文 +步数 applied at start (20+3)")

func test_skill_level_scales_break() -> void:
	var coat_layer := []
	for y in 4:
		var row := []
		for x in 4:
			row.append(0)
		coat_layer.append(row)
	coat_layer[0][0] = 1
	coat_layer[1][1] = 1
	coat_layer[2][2] = 1
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 30, 1, [], [], [], coat_layer)
	b.skill = "breaker"
	b.skill_level = 2
	b.skill_break()   # 无参 → 用等级 2
	assert_true(b.blocker_cleared >= 2, "level 2 breaks at least 2 blockers")

func test_score_mult_gain() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999, 20, 5)
	b.score = 0
	b.score_mult = 2.0
	b._gain(100)
	assert_eq(b.score, 200, "积分铭文 score_mult 2.0 doubles gain")

func test_apply_loadout() -> void:
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 100, 20, 7)
	b.apply_loadout({
		"skill": "breaker", "skill_level": 2, "score_mult": 1.5,
		"extra_moves": 2, "extra_skill_uses": 1, "opening_special": 1,
	})
	assert_eq(b.skill, "breaker", "skill set")
	assert_eq(b.skill_level, 2, "level set")
	assert_eq(b.score_mult, 1.5, "score_mult set")
	assert_eq(b.moves_left, 22, "move_limit 20 + extra_moves 2")
	assert_eq(b.ad_continue_cap, 3, "2 + extra_skill_uses 1")
	var cnt := 0
	for row in b.fx:
		for f in row:
			if f == ME.SP_LINE_H:
				cnt += 1
	assert_eq(cnt, 1, "one opening special placed")

func test_scrolling_refill_from_feed() -> void:
	# refill 单元：滚动补充从 feed 每列前端出(非随机)；feed[x] 空 = 该列挖穿 → 留空，不补随机。
	var b := Board.new(3, 3, [0, 1, 2], 999999, 30, 1)
	b.is_scrolling = true
	b.grid[0][0] = ME.EMPTY
	b.grid[0][1] = ME.EMPTY
	ME.refill(b.grid, b.species, b.rng, b.fx, [[7, 8], [7, 8], [7, 8]])
	assert_eq(b.grid[0][0], 7, "top empty filled from feed front (not random)")
	# 挖穿后：feed[x] 空了，顶部不再补新棋子(留空)，不回退随机
	b.grid[1][0] = ME.EMPTY     # 列0 空格(已挖穿)
	b.grid[1][1] = ME.EMPTY     # 列1 空格(还有 feed)
	ME.refill(b.grid, b.species, b.rng, b.fx, [[], [5], []])
	assert_eq(b.grid[1][0], ME.EMPTY, "exhausted column stays EMPTY (no new piece dropped)")
	assert_eq(b.grid[1][1], 5, "column with remaining feed still fills from it")

func test_scrolling_dig_pull_and_win() -> void:
	# 挖矿机制：消除时不补(挖空)；清到一页70%→从 feed 批量拉新页补满；储备空+清70%=挖穿通关。
	var b := Board.new(4, 4, [0, 1, 2], 999999, 30, 1)
	b.is_scrolling = true
	b.feed = [[0], [1], [2], [0]]   # 每列储备1格(顶行拉下来 0,1,2,0 → 不自动消除)
	assert_false(b.is_won(), "fresh scrolling level not won")
	# (1) 没清到70% → 不拉新页(feed 原样)
	b._scroll_advance()
	assert_eq(b.feed[0].size(), 1, "below 70% cleared -> no pull, feed intact")
	# (2) 清到≥70%(全清) + feed 有货 → 拉新页：顶部从 feed 补回、feed 消耗
	for y in b.grid.size():
		for x in b.grid[y].size():
			b.grid[y][x] = ME.EMPTY
	b._scroll_advance()
	assert_eq(b.feed[0].size(), 0, "cleared 70% with feed -> pulled, feed consumed")
	assert_eq(b.grid[0][0], 0, "pulled page fills top from feed front")
	assert_false(b.is_won(), "just pulled a page -> not dug through yet")
	# (3) 仍≥70%空(只补回4/16) + 储备已空 → 挖穿通关
	b._scroll_advance()
	assert_true(b.is_won(), "cleared 70% with empty reserve -> dug through (won)")
