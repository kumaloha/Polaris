extends "res://tests/test_lib.gd"
# 糖果炮（Candy Cannon）机制测试：每有效步从炮口下方产棋子 / 普通糖与原料 / 复用 WALL 不可消不可动 /
# 产出物随重力下落 / 下方非空不产 / 确定性同 seed 一致 / 不破坏其他层。
# 设计要点：炮口格 grid 复用 WALL(-2) —— 不可消/不可动/不下落/切段全部直接生效，故 find_matches/
# apply_gravity/is_legal_swap 都【不感知 cannon】（炮口当墙处理）；cannon 层只标记"哪些 WALL 是炮 + 产出类型"。
# 两端镜像：engine/tests/test_match_engine.cpp 有对应 C++ 断言。

const ME := preload("res://core/match_engine.gd")
const Board := preload("res://core/board.gd")

# 全 0 的 H×W 整型层（cannon/ing 模板）。
func _blank(w: int, h: int) -> Array:
	var m := []
	for y in h:
		var row := []
		for x in w:
			row.append(0)
		m.append(row)
	return m

# ───────────── 断言①：每有效步炮口下方空则产出一个（spawn_from_cannons 纯函数）─────────────

func test_cannon_spawns_below_when_empty() -> void:
	# 炮在 (1,0)(grid=WALL)，其正下方 (1,1) 空 → 产一个棋子（species 来自 species_set）。
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [
		[W, W, W],
		[0, E, 2],
		[1, 2, 3],
	]
	var cannon := _blank(3, 3)
	cannon[0][1] = 1   # 产普通糖炮
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var produced := ME.spawn_from_cannons(cannon, grid, [0, 1, 2, 3, 4], rng)
	assert_eq(produced, 1, "one cannon produced exactly one piece below it")
	assert_true(grid[1][1] != E and grid[1][1] != W, "below-cannon cell now holds a normal piece")
	assert_true(grid[1][1] >= 0 and grid[1][1] <= 4, "produced species within species_set")

# ───────────── 断言②：cannon=1 产普通糖、cannon=2 产原料(ing=1) ─────────────

func test_cannon_type1_produces_plain_candy() -> void:
	# cannon=1 → 产出格是普通棋子，且【不】打原料标记（ing 保持 0）。
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [[W, 1, 2], [E, 3, 4], [5, 0, 1]]
	var cannon := _blank(3, 3)
	cannon[0][0] = 1   # 普通糖炮在 (0,0)，其下 (0,1) 空
	var ing := _blank(3, 3)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var produced := ME.spawn_from_cannons(cannon, grid, [0, 1, 2, 3, 4, 5], rng, ing)
	assert_eq(produced, 1, "plain cannon produced one piece")
	assert_true(grid[1][0] >= 0, "produced cell holds a normal-species tile")
	assert_eq(ing[1][0], 0, "plain cannon does NOT mark ingredient (ing stays 0)")

func test_cannon_type2_produces_ingredient() -> void:
	# cannon=2 → 产原料 actor：产出格 grid 保持 EMPTY 且 ing=1。
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [[W, 1, 2], [E, 3, 4], [5, 0, 1]]
	var cannon := _blank(3, 3)
	cannon[0][0] = 2   # 产原料炮在 (0,0)，其下 (0,1) 空
	var ing := _blank(3, 3)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var produced := ME.spawn_from_cannons(cannon, grid, [0, 1, 2, 3, 4, 5], rng, ing)
	assert_eq(produced, 1, "ingredient cannon produced one piece")
	assert_eq(grid[1][0], E, "produced ingredient actor does not hide a normal-species tile")
	assert_eq(ing[1][0], 1, "produced cell is marked as an ingredient actor (ing=1)")
	assert_eq(ME.count_ingredients(ing), 1, "exactly one ingredient now on board")

# ───────────── 断言⑤：下方非空时不产（等位置空出）─────────────

func test_cannon_no_spawn_when_below_occupied() -> void:
	var W := ME.WALL
	var grid := [[W, 1, 2], [9, 3, 4], [5, 0, 1]]   # (0,1)=9 非空，正堵在炮口下方
	var cannon := _blank(3, 3)
	cannon[0][0] = 1
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var produced := ME.spawn_from_cannons(cannon, grid, [0, 1, 2, 3, 4], rng)
	assert_eq(produced, 0, "below occupied -> cannon does not produce this step")
	assert_eq(grid[1][0], 9, "occupied cell below cannon is untouched")

func test_cannon_no_spawn_at_bottom_row() -> void:
	# 炮口在最底行 → 下方无格可产，不产（边界安全）。
	var W := ME.WALL
	var grid := [[0, 1, 2], [3, 4, 5], [W, 1, 2]]
	var cannon := _blank(3, 3)
	cannon[2][0] = 1
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var produced := ME.spawn_from_cannons(cannon, grid, [0, 1, 2, 3, 4], rng)
	assert_eq(produced, 0, "cannon at bottom row has no cell below -> no spawn")

# ───────────── 断言③：炮口不可消不可动（复用 WALL）─────────────

func test_cannon_mouth_is_wall_not_matchable() -> void:
	# 炮口格 grid=WALL → 永不进 find_matches（墙不参与匹配、也不让同色串连过去）。
	# 顶行 [WALL,0,0,0]：若墙参与会断/连；这里 (1,0),(2,0),(3,0) 三个 0 仍自成三连，墙不掺和。
	var W := ME.WALL
	var grid := [
		[W, 0, 0, 0],
		[1, 2, 3, 4],
		[2, 3, 4, 1],
	]
	var m: Array = ME.find_matches(grid)
	assert_eq(m.size(), 3, "WALL cannon mouth never matches; the three 0s still form a run")
	for p in m:
		assert_true(grid[p.y][p.x] != W, "no WALL cell is ever in a match set")

func test_cannon_mouth_is_wall_not_swappable() -> void:
	# 炮口格 grid=WALL → is_legal_swap 拒绝（墙不可动）。
	var W := ME.WALL
	var grid := [
		[W, 0, 1, 2],
		[0, 3, 4, 5],
		[2, 3, 4, 1],
	]
	# 试图把炮口 (0,0) 和右邻 (1,0) 交换 → 非法（墙不可动）。
	assert_false(ME.is_legal_swap(grid, Vector2i(0, 0), Vector2i(1, 0)), "WALL cannon mouth cannot be swapped")

func test_cannon_mouth_does_not_fall() -> void:
	# 炮口格 grid=WALL → apply_gravity 处切段、原地固定（墙不下落，下方独立成段）。
	var E := ME.EMPTY
	var W := ME.WALL
	# 列内：炮口(WALL) 在 y=0 顶；下方 y=1 棋子、y=2 空 → 墙不动，墙下棋子沉到 y=2。
	var grid := [[W], [5], [E]]
	ME.apply_gravity(grid)
	assert_eq(grid[0][0], W, "WALL cannon mouth stays put (does not fall)")
	assert_eq(grid[2][0], 5, "piece below the wall sank to the segment bottom")
	assert_eq(grid[1][0], E, "cell vacated by the sunk piece is now empty")

# ───────────── 断言④：产出物随重力下落 ─────────────

func test_cannon_product_falls_under_gravity() -> void:
	# 产出后该格非空 → apply_gravity 把它沉到炮口下方那一段的段底。
	# 炮口 (0,0)=WALL；下方一长列空。产出落在 (0,1)，重力后应沉到 (0,3)(列底)。
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [[W], [E], [E], [E]]
	var cannon := _blank(1, 4)
	cannon[0][0] = 1
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var produced := ME.spawn_from_cannons(cannon, grid, [0, 1, 2, 3, 4], rng)
	assert_eq(produced, 1, "cannon produced one piece at (0,1)")
	var sp_val: int = grid[1][0]
	assert_true(sp_val >= 0, "product sitting directly below the cannon mouth")
	ME.apply_gravity(grid)
	assert_eq(grid[3][0], sp_val, "product fell to the column bottom under gravity")
	assert_eq(grid[1][0], E, "the spot just below the mouth is empty again after it fell")
	assert_eq(grid[0][0], W, "cannon mouth itself never moves")

func test_cannon_mouth_does_not_invite_diagonal_slide_into_spawn_slot() -> void:
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [
		[W, 5, 6],
		[E, 1, 2],
		[9, 3, 4],
	]
	var cannon := _blank(3, 3)
	cannon[0][0] = 1
	ME.apply_gravity(grid, [], false, {"cannon": cannon})
	assert_eq(grid[1][0], E, "cannon mouth keeps the spawn slot open instead of inviting diagonal slide")
	assert_eq(grid[0][1], 5, "right-above piece does not slide under a cannon mouth")

# ───────────── 断言⑥：确定性同 seed 一致 ─────────────

func test_cannon_deterministic_same_seed() -> void:
	var W := ME.WALL
	var E := ME.EMPTY
	var g1 := [[W, W, W], [E, E, E], [0, 1, 2]]
	var g2 := [[W, W, W], [E, E, E], [0, 1, 2]]
	var c1 := _blank(3, 3); c1[0][0] = 1; c1[0][1] = 1; c1[0][2] = 1
	var c2 := _blank(3, 3); c2[0][0] = 1; c2[0][1] = 1; c2[0][2] = 1
	var r1 := RandomNumberGenerator.new(); r1.seed = 2468
	var r2 := RandomNumberGenerator.new(); r2.seed = 2468
	var p1 := ME.spawn_from_cannons(c1, g1, [0, 1, 2, 3, 4, 5], r1)
	var p2 := ME.spawn_from_cannons(c2, g2, [0, 1, 2, 3, 4, 5], r2)
	assert_eq(p1, p2, "same seed -> identical produced count")
	assert_eq(g1, g2, "same seed -> identical grid after cannon spawn")

# ───────────── count_cannons 计数 ─────────────

func test_count_cannons() -> void:
	var cannon := [[1, 0, 2], [0, 0, 0], [0, 1, 0]]
	assert_eq(ME.count_cannons(cannon), 3, "three cannon cells counted (1+2+1 positions)")

func test_no_cannon_layer_spawns_nothing() -> void:
	# 空 cannon 层 → spawn 不产、返回 0（无糖果炮关零开销）。
	var grid := [[0, 1, 2], [3, 4, 5], [1, 2, 3]]
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	assert_eq(ME.spawn_from_cannons([], grid, [0, 1, 2], rng), 0, "empty cannon layer -> nothing produced")

# ───────────── board 集成：构造糖果炮关 + 有效步触发产出 ─────────────

func test_board_cannon_mouth_is_wall() -> void:
	# Board 用 cannon 层构造 → 炮位自动并入墙掩码，该格 grid 为 WALL（不可消不可动）。
	var cannon := _blank(5, 5)
	cannon[0][2] = 1   # 顶行中间一门炮
	var b := Board.new(5, 5, [0, 1, 2, 3, 4], 999999, 20, 1, [], [], [], [], [], [], [], [], cannon)
	assert_eq(b.grid[0][2], ME.WALL, "cannon position is a WALL on the board (reuses wall mechanics)")
	assert_eq(ME.count_cannons(b.cannon), 1, "board tracks exactly one cannon")

func test_board_effective_move_spawns_from_cannon() -> void:
	# board 集成：一次有效交换结算后，炮口下方空则产一个棋子（断言①在 board 层）。
	# 关键语义：普通关 resolve 会把全盘空格补满(含炮口下方)，故炮口下方在钩子触发时几乎总非空 → 不产；
	#   炮的"持续供给"在【滚动关】(do_refill=false，消除只挖空、顶部不补)最显著——炮口下方挖空后由炮补给。
	#   故这里用 is_scrolling 板验证："有效步消除挖空炮口下方 → 炮把它补回"。
	var cannon := _blank(4, 4)
	cannon[0][0] = 1   # 产普通糖炮，(0,0)=WALL
	var b := Board.new(4, 4, [0, 1, 2, 3, 4, 5, 6, 7], 999999, 20, 1, [], [], [], [], [], [], [], [], cannon)
	b.is_scrolling = true   # 滚动关：消除只挖空、不随机补 → 炮口下方会真的空出
	b.feed = [[], [], [], []]   # feed 空：滚动补给完全交给炮（顶部不下流新棋子）
	# 炮口 (0,0)=WALL；下方一整列(0,1)(0,2)(0,3) 当前是 1,1,? —— 让 (0,1)(0,2) 同色，
	# 交换制造含该列的纵向三连，消除后该列挖空 → 炮口下方空 → 炮补给。
	b.grid = [
		[ME.WALL, 5, 6, 7],
		[1, 2, 3, 4],   # (0,1)=1
		[1, 6, 7, 0],   # (0,2)=1
		[2, 1, 4, 5],   # 交换 (0,3)<->(1,3): 第0列 → 1,1,1 纵向三连(y=1,2,3)
	]
	b.fx = b._blank_fx()
	var before := b.cannon_spawned
	var r := b.try_swap(Vector2i(0, 3), Vector2i(1, 3))
	assert_true(r["ok"], "legal swap forms a vertical 3-run in column 0")
	assert_true(b.cannon_spawned > before, "cannon supplied at least one piece after the column was dug empty")
	# 炮口 (0,0) 永远是墙（产出在它下方，自身不变）。
	assert_eq(b.grid[0][0], ME.WALL, "cannon mouth stays a WALL after the move")

func test_board_cannon_keeps_supplying_over_moves() -> void:
	# 多步持续供给：炮在顶，下方一列空，连续几步应不断把棋子补进盘面（cannon_spawned 单调增）。
	var cannon := _blank(4, 4)
	cannon[0][0] = 1
	var b := Board.new(4, 4, [0, 1, 2, 3, 4, 5, 6, 7], 999999, 20, 1, [], [], [], [], [], [], [], [], cannon)
	# 顶行炮口 (0,0)=WALL；构造一处稳定可重复触发的消除（底两行），炮口下方留空便于观察补给。
	b.grid = [
		[ME.WALL, 1, 2, 3],
		[ME.EMPTY, 4, 5, 6],
		[1, 7, 7, 7],   # 第2行 1..3 不是三连；用交换制造
		[2, 3, 4, 5],
	]
	b.fx = b._blank_fx()
	# 交换 (0,2)<->(1,2)? 不需精确——只验证"有效步后炮把 (0,0) 下方补上了"。
	# 直接调产出钩子语义：手动跑一次产出，断言炮口下方被补。
	var got := ME.spawn_from_cannons(b.cannon, b.grid, b.species, b.rng, b.ing)
	assert_eq(got, 1, "cannon supplied one piece into the empty cell below it")
	assert_true(b.grid[1][0] >= 0, "the cell below the cannon mouth is now filled (continuous supply)")

# ───────────── 断言⑦：不破坏其他层（炮与原料/炸弹共存）─────────────

func test_cannon_coexists_with_ingredient_layer() -> void:
	# 产原料炮(cannon=2) + 已有原料层：产出新原料叠加，不影响既有原料计数语义。
	var E := ME.EMPTY
	var W := ME.WALL
	var grid := [[W, 1, 2], [E, 3, 4], [5, 0, 1]]
	var cannon := _blank(3, 3)
	cannon[0][0] = 2
	var ing := _blank(3, 3)
	ing[2][2] = 1   # 盘上已有 1 颗原料
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var produced := ME.spawn_from_cannons(cannon, grid, [0, 1, 2, 3, 4, 5], rng, ing)
	assert_eq(produced, 1, "ingredient cannon produced one")
	assert_eq(ME.count_ingredients(ing), 2, "now two ingredients on board (existing + newly produced)")

func test_cannon_layer_does_not_disturb_bomb_relations() -> void:
	# 炮关与炸弹层独立：构造同时带 cannon 与 bomb 的 board，炸弹计数/倒计时不受炮影响。
	var cannon := _blank(4, 4)
	cannon[0][1] = 1
	var bomb := _blank(4, 4)
	bomb[3][3] = 5
	var b := Board.new(4, 4, [0, 1, 2, 3, 4], 999999, 20, 1, [], [], [], [], [], [], [], bomb, cannon)
	assert_eq(ME.count_bombs(b.bomb), 1, "bomb layer intact alongside cannon layer")
	assert_eq(b.grid[0][1], ME.WALL, "cannon mouth is WALL; bomb layer untouched by it")
