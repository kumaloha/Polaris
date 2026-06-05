extends "res://tests/test_lib.gd"
# 蛋糕炸弹（Cake Bomb）机制测试 —— 对标 Candy Crush 的 Cake Bomb：
#   固定的大蛋糕障碍，被相邻消除/特效命中时【掉1血并引爆周围一圈(3x3)】，血量归0时【大爆炸清大范围(5x5)+移除】。
# 关键设计：蛋糕格【复用 WALL(grid=WALL=-2)】——不可消/不可动/不下落/切段全部直接生效，
#   故 find_matches/apply_gravity/is_legal_swap 都【不感知 cake】（蛋糕当墙处理）；cake 层只标记"哪些 WALL 是蛋糕 + 血量"。
# 断言：①蛋糕相邻消除→cake-1 且引爆周围一圈 ②归0→蛋糕移除(WALL→EMPTY)+大爆炸 ③蛋糕不可消不可动(WALL)
#       ④每轮最多-1 ⑤OBJ_DESTROY_CAKE 炸够 N 过关 ⑥不破坏现有 coat/choco/ing/bomb/cannon/popcorn。
# 两端镜像：engine/tests/test_match_engine.cpp 有对应 C++ 断言（蛋糕 WALL 机械原语 + 引爆几何 + 递减 + 计数）。

const ME := preload("res://core/match_engine.gd")
const Board := preload("res://core/board.gd")

# 全 0 的 H×W 整型层（cake 等模板）。
func _blank(w: int, h: int) -> Array:
	var m := []
	for y in h:
		var row := []
		for x in w:
			row.append(0)
		m.append(row)
	return m

# 全 SP_NONE 的 H×W 特效层。
func _none_fx(w: int, h: int) -> Array:
	var f := []
	for y in h:
		var row := []
		for x in w:
			row.append(ME.SP_NONE)
		f.append(row)
	return f


# ───────────── 断言③：蛋糕格复用 WALL → 不可消、不可动、不可换、不下落 ─────────────

func test_cake_cell_is_wall_not_matchable() -> void:
	# 蛋糕格 grid=WALL → 永不进 find_matches（墙不参与匹配、也不让同色串连过去）。
	var W := ME.WALL
	var grid := [
		[W, 0, 0, 0],   # (0,0) 是蛋糕墙；(1,0)(2,0)(3,0) 三个 0 仍自成三连，墙不掺和
		[1, 2, 3, 4],
		[2, 3, 4, 1],
	]
	var m: Array = ME.find_matches(grid)
	assert_eq(m.size(), 3, "WALL cake cell never matches; the three 0s still form a run")
	for p in m:
		assert_true(grid[p.y][p.x] != W, "no WALL cake cell is ever in a match set")

func test_cake_cell_is_wall_not_swappable() -> void:
	# 蛋糕格 grid=WALL → is_legal_swap 拒绝（墙不可动）。
	var W := ME.WALL
	var grid := [
		[W, 0, 1, 2],
		[0, 3, 4, 5],
		[2, 3, 4, 1],
	]
	assert_false(ME.is_legal_swap(grid, Vector2i(0, 0), Vector2i(1, 0)), "WALL cake cell cannot be swapped")

func test_cake_cell_does_not_fall() -> void:
	# 蛋糕格 grid=WALL → apply_gravity 处切段、原地固定（墙不下落，下方独立成段）。
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [[W], [5], [E]]   # 蛋糕在 y=0 顶；下方 y=1 棋子、y=2 空 → 墙不动，墙下棋子沉到 y=2
	ME.apply_gravity(grid)
	assert_eq(grid[0][0], W, "WALL cake cell stays put (does not fall)")
	assert_eq(grid[2][0], 5, "piece below the cake sank to the segment bottom")
	assert_eq(grid[1][0], E, "cell vacated by the sunk piece is now empty")


# ───────────── 断言①：蛋糕相邻消除 → cake-1 且引爆周围一圈(3x3) ─────────────

func test_cake_adjacent_match_decrements_and_blasts_ring() -> void:
	# 蛋糕在 (1,1) WALL，血量 3。其正下方 (1,2) 是横向三连的一员 → 相邻被清 → cake-1(→2) + 引爆 (1,1) 为心 3x3。
	# 用 do_refill=false 隔离单轮：引爆清掉的格不补，便于断言。
	var W := ME.WALL
	var grid := [
		[0, 5, 1, 7],   # 行0：3x3 上排 (0,0)(1,0)(2,0) 会被引爆
		[6, W, 8, 7],   # (1,1)=蛋糕墙；(0,1)(2,1) 在 3x3 内会被引爆
		[2, 2, 2, 1],   # 行2：(0,2)(1,2)(2,2) 横向三连 2,2,2 → 触发；(1,2) 与蛋糕正交相邻
		[3, 4, 5, 6],
	]
	var cake := _blank(4, 4)
	cake[1][1] = 3   # 蛋糕血量 3
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	# cake 是 resolve 第15参；无 fx（纯三消路径走 _resolve_plain）、do_refill=false。
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7, 8], rng, [], [], [], [], false, null, [], [], [], [], [], cake)
	assert_eq(cake[1][1], 2, "cake adjacent to the cleared 3-match lost exactly 1 HP (3 -> 2)")
	assert_eq(r.get("cake_destroyed", -1), 0, "cake still alive -> not destroyed this round")
	assert_eq(grid[1][1], ME.WALL, "cake cell is still a WALL (alive, not removed)")
	# 引爆一圈(3x3)：(1,1) 为心的非 WALL 普通格被清空。验证几个角/边格被清。
	assert_eq(grid[0][0], ME.EMPTY, "ring blast cleared (0,0)")
	assert_eq(grid[0][2], ME.EMPTY, "ring blast cleared (2,0)")
	assert_eq(grid[1][0], ME.EMPTY, "ring blast cleared (0,1)")
	assert_eq(grid[1][2], ME.EMPTY, "ring blast cleared (2,1)")

func test_cake_blast_ring_uses_3x3_geometry() -> void:
	# 精确验证引爆几何 = SP_BOMB 的 3x3：蛋糕在 (2,2) 血量 2，相邻被清 → cake-1(→1,存活) + 引爆以 (2,2) 为心 x∈[1,3],y∈[1,3]。
	# 用直清路径(account_clears 返回 cake_blast)精确断言几何，避免重力回填干扰坐标。
	var W := ME.WALL
	var grid := [
		[9, 8, 7, 6, 5],
		[1, 5, 6, 7, 4],   # 行1: (1,1)(2,1)(3,1) 在 3x3 内
		[2, 6, W, 5, 3],   # (2,2)=蛋糕墙；(1,2)(3,2) 在 3x3 内，(0,2)(4,2) 在 3x3 外
		[3, 7, 1, 5, 2],   # 行3: (1,3)(2,3)(3,3) 在 3x3 内
		[4, 8, 2, 6, 1],   # 行4 整行在 3x3 外
	]
	var cake := _blank(5, 5)
	cake[2][2] = 2
	# 清除集 = 蛋糕的一个正交邻格 (2,1)（普通格）→ 蛋糕受击 -1 → 引爆 3x3。account_clears 返回 cake_blast。
	var acc := ME.account_clears(grid, [Vector2i(2, 1)], [], [], [], [], [], [], cake)
	assert_eq(cake[2][2], 1, "cake lost 1 HP from the adjacent cleared cell (2 -> 1)")
	assert_eq(acc.get("cake_destroyed", -1), 0, "cake alive (HP 1) -> not destroyed")
	var blast := {}
	for bp in acc.get("cake_blast", []):
		blast[bp] = true
	# 3x3 内四角 + 边都该在 blast；蛋糕本格 (2,2)=WALL 不在 blast。
	assert_true(blast.has(Vector2i(1, 1)), "3x3 corner (1,1) in blast")
	assert_true(blast.has(Vector2i(3, 1)), "3x3 corner (3,1) in blast")
	assert_true(blast.has(Vector2i(1, 3)), "3x3 corner (1,3) in blast")
	assert_true(blast.has(Vector2i(3, 3)), "3x3 corner (3,3) in blast")
	assert_false(blast.has(Vector2i(2, 2)), "the cake WALL cell itself is not in the blast set")
	# 3x3 外不被波及：(0,2)/(4,2)/行4 的格都不在 blast。
	assert_false(blast.has(Vector2i(0, 2)), "(0,2) is outside the 3x3 ring -> not blasted")
	assert_false(blast.has(Vector2i(4, 2)), "(4,2) is outside the 3x3 ring -> not blasted")
	assert_false(blast.has(Vector2i(2, 4)), "(2,4) is outside the 3x3 ring -> not blasted")

func test_cake_max_one_decrement_per_round() -> void:
	# 每轮最多-1：即便蛋糕同时正交相邻【多个】被清格(上+下+左+右)，本轮也只 -1（与 coat 破锁同节奏）。
	# 蛋糕在 (2,2)，四周用十字三连同时命中其上下左右 → 仍只 -1。
	var W := ME.WALL
	var grid := [
		[0, 1, 6, 3, 4],
		[1, 2, 6, 4, 5],   # 列2: (2,0)(2,1) 上方两个 6 …(2,2)是蛋糕，断开
		[6, 6, W, 7, 7],   # 行2: 左 (0,2)(1,2)=6,6 + 右 (3,2)(4,2)=7,7，蛋糕在中
		[2, 3, 8, 5, 6],   # 列2 下方 (2,3)(2,4)
		[3, 4, 8, 6, 7],
	]
	# 让蛋糕【上下左右】四个正交邻格都进消除：
	#  左：行2 (0,2)(1,2)=6,6 + 上 (2,0)(2,1)=6,6 共享？改为独立三连。
	# 简化：直接构造四条紧贴蛋糕的三连，确保上下左右邻格各属一个三连。
	grid = [
		[5, 6, 6, 6, 5],   # 行0: (1,0)(2,0)(3,0)=6,6,6 三连 → (2,1)上邻… 不直接邻蛋糕
		[1, 2, 9, 4, 5],
		[7, 7, W, 8, 8],   # 行2: 左(0,2)(1,2)=7,7 右(3,2)(4,2)=8,8 —— 需各自成三连
		[1, 2, 9, 4, 5],
		[5, 3, 3, 3, 5],   # 行4: (1,4)(2,4)(3,4)=3,3,3
	]
	# 上邻(2,1)=9、下邻(2,3)=9：让列2 (2,1)(2,3) 与某三连相邻被清。最稳妥：直接把"被清集"用特效引爆控制。
	# 改走最干净路径：用 account_clears 直接给一个同时含蛋糕上下左右邻格的清除集，验证只 -1。
	var cake := _blank(5, 5)
	cake[2][2] = 5
	# 清除集 = 蛋糕 (2,2) 的上下左右四邻格（全部普通格）。account_clears 第9参=cake。
	var cells := [Vector2i(2, 1), Vector2i(2, 3), Vector2i(1, 2), Vector2i(3, 2)]
	var acc := ME.account_clears(grid, cells, [], [], [], [], [], [], cake)
	assert_eq(cake[2][2], 4, "cake adjacent to 4 cleared cells in one round still loses only 1 HP (5 -> 4)")
	assert_eq(acc.get("cake_destroyed", -1), 0, "cake not destroyed (still 4 HP)")


# ───────────── 断言②：血量归0 → 蛋糕移除(WALL→EMPTY) + 大爆炸(5x5) ─────────────

func test_cake_reaches_zero_removed_and_big_blast() -> void:
	# 蛋糕血量 1，相邻被清 → cake 减到 0 → 移除(WALL→EMPTY) + 大爆炸(5x5)。
	# 蛋糕在 (2,2)，大爆炸清 x∈[0,4],y∈[0,4] 全部普通格。用直清路径(account_clears)隔离单次、坐标稳定。
	var W := ME.WALL
	var grid := [
		[0, 1, 2, 3, 4],
		[5, 6, 7, 8, 0],
		[1, 2, W, 3, 4],   # (2,2)=蛋糕墙，血量 1
		[5, 6, 7, 8, 0],
		[1, 2, 3, 4, 5],
	]
	var cake := _blank(5, 5)
	cake[2][2] = 1
	# 清除集含蛋糕的一个正交邻格 (2,3) → 蛋糕受击 → 归0 → 移除 + 5x5 大爆炸。
	var acc := ME.account_clears(grid, [Vector2i(2, 3)], [], [], [], [], [], [], cake)
	assert_eq(cake[2][2], 0, "cake HP reached 0")
	assert_eq(acc.get("cake_destroyed", -1), 1, "exactly one cake destroyed")
	assert_eq(grid[2][2], ME.EMPTY, "destroyed cake removed: WALL -> EMPTY")
	# 大爆炸 5x5：四角 (0,0)(4,0)(0,4)(4,4) 进 cake_blast。account_clears 返回 cake_blast 供调用方清。
	var blast := {}
	for bp in acc.get("cake_blast", []):
		blast[bp] = true
	assert_true(blast.has(Vector2i(0, 0)), "5x5 big blast reaches corner (0,0)")
	assert_true(blast.has(Vector2i(4, 0)), "5x5 big blast reaches corner (4,0)")
	assert_true(blast.has(Vector2i(0, 4)), "5x5 big blast reaches corner (0,4)")
	assert_true(blast.has(Vector2i(4, 4)), "5x5 big blast reaches corner (4,4)")
	# 蛋糕本格不在 blast（它被移除，不计入要清的普通格）。
	assert_false(blast.has(Vector2i(2, 2)), "the cake cell itself is not in the blast clear set (it was removed)")

func test_cake_big_blast_count_is_destroyed() -> void:
	# count_cakes 在归0后减少：盘上两个蛋糕，炸毁一个 → count 从 2 降到 1。
	var cake := [
		[2, 0, 0],
		[0, 0, 0],
		[0, 0, 3],
	]
	assert_eq(ME.count_cakes(cake), 2, "two cakes on board")
	# 模拟一个炸毁：手动归0其中一个（实战由 _blast_cakes 做）。
	cake[0][0] = 0
	assert_eq(ME.count_cakes(cake), 1, "one cake remains after the other is destroyed")


# ───────────── 断言①(特效路径)：特效命中相邻蛋糕 → cake-1 + 引爆 ─────────────

func test_cake_hit_by_stripe_effect_decrements() -> void:
	# 条纹(SP_LINE_H)被三连触发清整行，行内/相邻蛋糕受击 -1 + 引爆一圈。
	# 蛋糕在 (3,1) WALL；条纹在 (0,0) 被列0 三连触发清行0；行0 不直接含蛋糕。
	# 改让条纹清的行【正交相邻】蛋糕：蛋糕在 (3,1)，条纹清行0 的 (3,0) 是蛋糕正上邻 → 蛋糕受击。
	var W := ME.WALL
	var grid := [
		[8, 1, 2, 7, 5, 6],   # (0,0)=8 上盖条纹；(3,0)=7 是蛋糕的正上邻，会被条纹清→蛋糕受击
		[8, 2, 3, W, 6, 1],   # (3,1)=蛋糕墙
		[8, 3, 4, 5, 7, 2],   # 列0: 8,8,8 三连 → 触发 (0,0) 条纹清整行0
		[2, 4, 5, 6, 1, 3],
	]
	var fx := _none_fx(6, 4)
	fx[0][0] = ME.SP_LINE_H
	var cake := _blank(6, 4)
	cake[1][3] = 2
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [1, 2, 3, 4, 5, 6, 7, 8], rng, fx, [], [], [], false, null, [], [], [], [], [], cake)
	assert_eq(cake[1][3], 1, "stripe cleared row 0; cake just below (3,0) lost 1 HP (2 -> 1)")
	assert_eq(grid[1][3], ME.WALL, "cake still a WALL (alive)")
	assert_eq(r.get("cake_destroyed", -1), 0, "cake not destroyed yet")


# ───────────── 断言④(确定性)：同 seed 同输入 → 结果一致 ─────────────

func test_cake_deterministic_same_seed() -> void:
	var g1 := _det_grid()
	var g2 := _det_grid()
	var c1 := _blank(5, 4); c1[2][2] = 3
	var c2 := _blank(5, 4); c2[2][2] = 3
	var r1 := RandomNumberGenerator.new(); r1.seed = 13579
	var r2 := RandomNumberGenerator.new(); r2.seed = 13579
	var res1 := ME.resolve(g1, [1, 2, 3, 4, 5, 6, 7], r1, [], [], [], [], true, null, [], [], [], [], [], c1)
	var res2 := ME.resolve(g2, [1, 2, 3, 4, 5, 6, 7], r2, [], [], [], [], true, null, [], [], [], [], [], c2)
	assert_eq(g1, g2, "same seed -> identical grid after cake resolve")
	assert_eq(c1, c2, "same seed -> identical cake layer after resolve")
	assert_eq(res1.get("cake_destroyed", -1), res2.get("cake_destroyed", -2), "same seed -> identical cake_destroyed")

func _det_grid() -> Array:
	# 列0 三连 5,5,5 紧贴蛋糕 (2,2) 的正左邻 (1,2)? 用一个稳定三消触发引爆。
	return [
		[5, 1, 7, 3, 4],
		[5, 2, 8, 1, 6],   # 列0: 5,5,5 三连
		[5, 6, 0, 7, 2],   # (2,2)=蛋糕(在 c1/c2 里设)；这里 grid 是普通棋子占位但 cake 会让 board 端置 WALL
		[1, 2, 3, 4, 5],
	]


# ───────────── 断言⑥：不破坏其他层（蛋糕与 bomb/ing 共存）─────────────

func test_cake_coexists_with_bomb_and_ingredient() -> void:
	# 同一 resolve 里蛋糕 + 炸弹 + 原料并存：蛋糕相邻消除-1、炸弹随重力沉、原料下沉，互不干扰。
	var W := ME.WALL
	var grid := [
		[0, 1, 2, 9, 4],   # (3,0)=9 原料占位
		[5, 6, 7, 8, 0],
		[2, 2, 2, W, 4],   # 行2 (0,2)(1,2)(2,2)=2,2,2 三连；(3,2)=蛋糕墙，(2,2)是其正左邻 → 蛋糕受击
		[5, 5, 7, 8, 0],   # (0,3)(1,3)=5 盖炸弹之一
		[1, 2, 3, 4, 5],
	]
	var cake := _blank(5, 5)
	cake[2][3] = 2
	var bomb := _blank(5, 5)
	bomb[3][0] = 5   # 炸弹在 (0,3)，远离被清区
	var ing := _blank(5, 5)
	ing[0][3] = 1   # 原料在 (3,0)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	# 传 ing(第12参)、bomb(第14参)、cake(第15参)；exit_cols=[] 不收原料；do_refill=false。
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], rng, [], [], [], [], false, null, [], ing, [], bomb, [], cake)
	assert_eq(cake[2][3], 1, "cake decremented by the adjacent 3-match (2 -> 1), coexists with bomb+ingredient")
	assert_eq(ME.count_cakes(cake), 1, "cake still on board")
	assert_eq(r.get("bomb_defused", -1), 0, "bomb not in the cleared area -> not defused (independent layer)")
	assert_eq(ME.count_bombs(bomb), 1, "bomb still live (its own semantics intact)")
	assert_eq(ME.count_ingredients(ing), 1, "ingredient still on board (no exit configured)")

func test_no_cake_layer_is_noop() -> void:
	# 不传 cake（[]）时，resolve 行为与旧版完全一致：cake_destroyed=0，普通消除照旧。
	var grid := [
		[0, 0, 0, 4],
		[5, 6, 7, 1],
		[2, 3, 4, 5],
	]
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7], rng, [], [], [], [], false)
	assert_eq(r.get("cake_destroyed", 0), 0, "no cake layer -> cake_destroyed stays 0")
	assert_true(r.get("cleared", 0) >= 3, "the plain 3-match still cleared normally")

func test_count_cakes() -> void:
	var cake := [
		[3, 0, 1],
		[0, 0, 0],
		[0, 2, 0],
	]
	assert_eq(ME.count_cakes(cake), 3, "three cake cells counted")


# ───────────── 断言⑤：OBJ_DESTROY_CAKE 炸够 N 过关（board 集成）─────────────

func test_board_cake_objective_win() -> void:
	# OBJ DESTROY_CAKE：炸毁够 N 个蛋糕即过关。
	var b := Board.new(5, 5, [1, 2, 3, 4], 0, 30, 7, [], [{"type": "DESTROY_CAKE", "species": -1, "target": 2}])
	assert_false(b.is_won(), "fresh DESTROY_CAKE level not won")
	b.cake_destroyed = 1
	assert_false(b.is_won(), "below target -> not won")
	b.cake_destroyed = 2
	assert_true(b.is_won(), "won when cake_destroyed reaches target")

func test_board_cake_cell_is_wall() -> void:
	# Board 用 cake 层构造 → 蛋糕位自动并入墙掩码，该格 grid 为 WALL（不可消不可动）。
	var cake := _blank(5, 5)
	cake[2][2] = 4   # 中心一个蛋糕
	var b := Board.new(5, 5, [0, 1, 2, 3, 4], 999999, 20, 1, [], [], [], [], [], [], [], [], [], [], cake)
	assert_eq(b.grid[2][2], ME.WALL, "cake position is a WALL on the board (reuses wall mechanics)")
	assert_eq(ME.count_cakes(b.cake), 1, "board tracks exactly one cake")
	assert_eq(b.cake[2][2], 4, "cake HP preserved on the board (4)")

func test_board_cake_decrement_via_swap() -> void:
	# board.try_swap：一次有效交换在蛋糕旁形成三消 → 蛋糕 cake-1 + 引爆（端到端，含 board 结算）。
	var cake := _blank(5, 5)
	cake[2][2] = 3   # 蛋糕在 (2,2)，血量 3
	var b := Board.new(5, 5, [1, 2, 3, 4, 5, 6], 999999, 20, 1, [], [], [], [], [], [], [], [], [], [], cake)
	# 手填盘：在蛋糕正下方 (2,3) 制造可被交换促成的三连。绕过 start 的无消除保证。
	b.grid = [
		[1, 2, 3, 4, 5],
		[2, 3, 4, 5, 6],
		[3, 4, ME.WALL, 6, 1],   # (2,2)=蛋糕墙（start 已置 WALL，这里保持）
		[4, 5, 6, 1, 2],   # 交换 (2,3)<->(3,3) 让列2 下段成三连？见下构造
		[5, 1, 1, 2, 3],
	]
	# 让列2 的 (2,3)(2,4) + 交换进一个 1 成三连，且 (2,3) 是蛋糕正下邻 → 蛋糕受击。
	# (2,4)=1, (2,3)=6 → 把 (2,3) 换成 1：与 (3,3)? 不相邻同色。改用行3 横三连贴蛋糕下邻。
	b.grid[3][1] = 7; b.grid[3][2] = 1; b.grid[3][3] = 7   # 行3: 把 (2,3)=1 居中
	b.grid[4][2] = 1   # (2,4)=1
	# 列2 下段: (2,3)=1,(2,4)=1 两个；交换 (1,3)<->(2,3)? 需第三个 1。直接放 (2,3) 上邻不行(蛋糕墙)。
	# 最稳：让 (2,3)(2,4) 与交换带入的第三个 1 成竖直三连。把 (3,3)=1，交换 (3,3)<->(2,3) 后列2 = ...,1,1 仅两格。
	# 退一步用 board 私有结算不便；改为：直接放一个现成会因交换成三连的横排，且其一格是蛋糕下邻。
	b.grid = [
		[2, 3, 4, 5, 6],
		[3, 4, 5, 6, 1],
		[4, 5, ME.WALL, 1, 2],   # (2,2)=蛋糕墙
		[1, 1, 5, 1, 2],   # 行3: (0,3)(1,3)=1,1，(2,3)=5(蛋糕正下邻)。交换 (2,3)<->(2,4) 把 1 换上来 → (0,3)(1,3)(2,3)=1,1,1
		[2, 3, 1, 4, 5],   # (2,4)=1
	]
	b.fx = b._blank_fx()
	var before_hp: int = b.cake[2][2]
	var r := b.try_swap(Vector2i(2, 3), Vector2i(2, 4))   # 把 (2,4)=1 换到 (2,3)，行3 成 1,1,1 三连，(2,3) 邻蛋糕
	assert_true(r["ok"], "legal swap forms a 3-run adjacent to the cake")
	assert_eq(b.cake[2][2], before_hp - 1, "cake lost exactly 1 HP from the adjacent match this move")
	assert_eq(b.grid[2][2], ME.WALL, "cake cell stays a WALL after the move (still alive)")
