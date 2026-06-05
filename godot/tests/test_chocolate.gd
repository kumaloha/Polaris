extends "res://tests/test_lib.gd"
# 巧克力蔓延（Chocolate）机制测试：占格/不可消/不可换/不下落/相邻啃食/零啃食蔓延/确定性。
# 两端镜像：engine/tests/test_match_engine.cpp 有对应 C++ 断言。

const ME := preload("res://core/match_engine.gd")
const Board := preload("res://core/board.gd")

# 全 0 的 H×W 整型层（choco 模板）。
func _blank(w: int, h: int) -> Array:
	var m := []
	for y in h:
		var row := []
		for x in w:
			row.append(0)
		m.append(row)
	return m

# ───────────── 不参与 match：巧克力格断开同色串 ─────────────

func test_choco_not_matched() -> void:
	var grid := [
		[0, 0, 0, 1],
		[2, 3, 4, 2],
		[3, 4, 2, 3],
	]
	assert_eq(ME.find_matches(grid).size(), 3, "no choco -> top row is a 3-match")
	var choco := [
		[0, 1, 0, 0],  # 巧克力盖住顶行中间格 (1,0)
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	assert_true(ME.find_matches(grid, [], choco).is_empty(), "chocolate cell breaks the run -> no match")

func test_choco_classify_skips() -> void:
	# classify_matches 也要跳过巧克力格（fx 路径一致）。
	var grid := [
		[0, 0, 0, 0, 1],
		[1, 2, 3, 2, 3],
		[2, 3, 1, 3, 1],
	]
	var choco := _blank(5, 3)
	choco[0][1] = 1  # 巧克力盖住四连中的一格 → 断成 0 [C] 0 0 → 仅右侧无三连
	var c := ME.classify_matches(grid, [], choco)
	assert_true(c["clear"].is_empty() and c["spawns"].is_empty(), "chocolate breaks the run in classify too")

# ───────────── 不可交换 ─────────────

func test_choco_blocks_swap() -> void:
	var grid := [[0, 0, 1], [1, 2, 0], [3, 4, 5]]  # (2,0)<->(2,1) 本来合法
	var choco := [[0, 0, 1], [0, 0, 0], [0, 0, 0]]  # (2,0) 被巧克力覆盖
	assert_false(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(2, 1), [], 1, choco), "chocolate cell can't be swapped")
	assert_true(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(2, 1)), "without choco -> legal")

# ───────────── 不下落：巧克力在重力下原地固定、切段 ─────────────

func test_choco_blocks_gravity() -> void:
	var E := ME.EMPTY
	var grid := [[0], [6], [E]]   # 列：[0, 6(巧克力), EMPTY]
	var choco := [[0], [1], [0]]  # (0,1) 是巧克力
	ME.apply_gravity(grid, [], [], false, choco)
	assert_eq(grid[0][0], 0, "tile above chocolate stays (can't fall through)")
	assert_eq(grid[1][0], 6, "chocolate cell stays put under gravity")
	assert_eq(grid[2][0], E, "below-chocolate empty stays empty")

# ───────────── 相邻啃食：被消除格相邻的巧克力 -1（巧克力本身不被清）─────────────

func test_choco_eaten_by_adjacent_clear() -> void:
	var grid := [
		[0, 0, 0, 1],
		[2, 1, 3, 2],  # (0,1)=2 被巧克力覆盖，紧邻顶行消除（其正下方）
		[3, 4, 2, 3],
	]
	var choco := [
		[0, 0, 0, 0],
		[2, 0, 0, 0],  # (0,1) 巧克力厚度 2（确保啃 1 后仍在）
		[0, 0, 0, 0],
	]
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [0, 1, 2, 3], rng, [], [], [], [], false, null, choco)
	assert_true(r["choco_cleared"] >= 1, "adjacent clear eats >=1 chocolate")
	assert_true(choco[1][0] < 2 and choco[1][0] > 0, "chocolate decreased but still present")
	assert_eq(grid[1][0], 2, "chocolate-covered tile preserved (not cleared/moved)")

func test_eat_chocolate_direct() -> void:
	# 啃食纯函数：被清除格内/相邻的巧克力 -1。
	var choco := [
		[1, 0, 1],
		[0, 1, 0],
		[0, 0, 0],
	]
	var cleared := {Vector2i(1, 0): true}  # 清 (1,0)：相邻 (0,0)[左]、(2,0)[右]、(1,1)[下]
	var eaten := ME._eat_chocolate(choco, cleared)
	assert_eq(eaten, 3, "three adjacent/covered chocolates eaten")
	assert_eq(choco[0][0], 0, "(0,0) 1->0")
	assert_eq(choco[0][2], 0, "(2,0) 1->0")
	assert_eq(choco[1][1], 0, "(1,1) 1->0")

# ───────────── 蔓延纯函数：注入 rng、可侵占格、确定性 ─────────────

func test_spread_adds_one() -> void:
	# 一块巧克力居中，四周都是普通棋子 → 蔓延必 +1。
	var grid := [
		[0, 1, 2],
		[3, 0, 4],
		[1, 2, 3],
	]
	var choco := _blank(3, 3)
	choco[1][1] = 1
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var before := ME.count_chocolate(choco)
	var ok := ME.spread_chocolate(choco, grid, rng)
	assert_true(ok, "spread succeeds when there is an invadable neighbor")
	assert_eq(ME.count_chocolate(choco), before + 1, "exactly one new chocolate cell")

func test_spread_skips_wall_empty_and_existing() -> void:
	# 巧克力四正交邻全是 墙/空 → 无可侵占格（只侵占普通棋子 species>=0）→ 蔓延失败、计数不变。
	var W := ME.WALL
	var E := ME.EMPTY
	var grid := [
		[W, E, W],
		[E, 5, E],
		[W, E, W],
	]
	var choco := _blank(3, 3)
	choco[1][1] = 1  # 中心巧克力，四正交邻 (1,0)=E (1,2)=E (0,1)=E (2,1)=E → 无可侵占
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var before := ME.count_chocolate(choco)
	var ok := ME.spread_chocolate(choco, grid, rng)
	assert_false(ok, "no invadable neighbor (all EMPTY) -> spread fails")
	assert_eq(ME.count_chocolate(choco), before, "count unchanged when spread fails")

func test_spread_skips_existing_chocolate() -> void:
	# 可侵占格须 choco==0：已是巧克力的相邻格不被重复选。
	var grid := [
		[0, 1, 2],
		[3, 0, 4],
		[1, 2, 3],
	]
	var choco := _blank(3, 3)
	choco[1][0] = 1   # 左
	choco[1][2] = 1   # 右（两块巧克力相邻一列普通棋子）
	# (1,0) 的右邻是 (1,1)=普通；(1,2) 的左邻也是 (1,1) → 候选去重后仍有非巧克力候选
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var ok := ME.spread_chocolate(choco, grid, rng)
	assert_true(ok, "spreads onto a normal neighbor")
	# 新增的格必是普通棋子格、且原 choco==0；不会落在已有巧克力上。
	assert_eq(ME.count_chocolate(choco), 3, "exactly one added (no double-claim of existing chocolate)")

func test_spread_deterministic_same_seed() -> void:
	# 同 seed 两次蔓延结果一致（确定性）。
	var grid := [
		[0, 1, 2, 3],
		[4, 0, 1, 2],
		[3, 4, 0, 1],
		[2, 3, 4, 0],
	]
	var c1 := _blank(4, 4); c1[1][1] = 1; c1[2][2] = 1
	var c2 := _blank(4, 4); c2[1][1] = 1; c2[2][2] = 1
	var r1 := RandomNumberGenerator.new(); r1.seed = 12345
	var r2 := RandomNumberGenerator.new(); r2.seed = 12345
	ME.spread_chocolate(c1, grid, r1)
	ME.spread_chocolate(c2, grid, r2)
	assert_eq(c1, c2, "same seed -> identical spread result")

# ───────────── board 回合钩子：零啃食蔓延 / 啃到则不蔓延 ─────────────

# 造一个 4x4 board，注入受控 grid+choco，模拟一步合法消除（不啃到巧克力）→ 断言巧克力 +1。
func test_board_spreads_when_no_choco_eaten() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 1)
	# 远端一步消除：交换 (3,0)<->(3,1) 让顶行右段凑 1,1,1（远离巧克力，不啃食）。
	b.grid = [
		[2, 1, 1, 3],
		[0, 3, 0, 1],
		[2, 0, 3, 0],
		[3, 2, 0, 2],
	]
	b.fx = b._blank_fx()
	b.choco = [
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		[1, 0, 0, 0],  # 角落一块巧克力，四邻无消除发生 → 不被啃
	]
	# 找一步合法且不挨着 (0,3) 巧克力的消除：交换 (3,0)<->(3,1)：列3 顶 3,1→ 行0 变 2,1,1,1 ✓
	var before := ME.count_chocolate(b.choco)
	var r := b.try_swap(Vector2i(3, 0), Vector2i(3, 1))
	assert_true(r["ok"], "legal swap accepted")
	assert_eq(b.choco_cleared, 0, "no chocolate eaten this step")
	assert_eq(ME.count_chocolate(b.choco), before + 1, "zero-eat step -> chocolate spreads +1")

# 造一个 board，让一步消除紧邻巧克力 → 啃到 → 断言 choco_cleared>0 且不蔓延（净计数：-1啃 +0蔓延）。
func test_board_no_spread_when_choco_eaten() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, 1)
	b.grid = [
		[0, 0, 0, 3],
		[2, 1, 3, 1],   # (0,1)=2 被巧克力盖，紧邻顶行将发生的消除（其正下方）
		[3, 2, 1, 2],
		[1, 3, 2, 3],
	]
	b.fx = b._blank_fx()
	b.choco = [
		[0, 0, 0, 0],
		[3, 0, 0, 0],   # (0,1) 厚 3：啃 1 后仍在，便于断言"减少但未消失"
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	# 顶行已是 0,0,0 三连(无需交换即可消)；但 try_swap 要求合法交换。
	# 用一步不影响顶行的合法消除会绕开啃食；这里改为：先放一个差一点的顶行，交换凑三连且紧邻巧克力。
	b.grid = [
		[0, 0, 1, 3],   # 交换 (2,0)<->(2,1) 让顶行成 0,0,0
		[2, 1, 0, 1],   # (0,1)=2 巧克力，正下方紧邻 (0,0) 消除
		[3, 2, 1, 2],
		[1, 3, 2, 3],
	]
	var choco_before := ME.count_chocolate(b.choco)
	var r := b.try_swap(Vector2i(2, 0), Vector2i(2, 1))  # 顶行 → 0,0,0
	assert_true(r["ok"], "legal swap forms top-row 0,0,0")
	assert_true(b.choco_cleared >= 1, "the clear is adjacent to chocolate -> eaten >=1")
	assert_true(b.choco[1][0] < 3 and b.choco[1][0] > 0, "chocolate thinned but still present")
	# 啃到 → 不蔓延：本步净变化只有啃食(该格-1)，无新增格。
	assert_eq(ME.count_chocolate(b.choco), choco_before, "ate chocolate this step -> no spread (count unchanged: same cell still >0)")

# board 蔓延也用 board.rng → 确定性：同 seed 两个 board 同样一步后 choco 一致。
func test_board_spread_deterministic() -> void:
	var seeds := 20260605
	var b1 := _spread_board(seeds)
	var b2 := _spread_board(seeds)
	b1.try_swap(Vector2i(3, 0), Vector2i(3, 1))
	b2.try_swap(Vector2i(3, 0), Vector2i(3, 1))
	assert_eq(b1.choco, b2.choco, "same seed board -> identical chocolate after spreading step")

func _spread_board(seed_val: int) -> Board:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 10, seed_val)
	b.grid = [
		[2, 1, 1, 3],
		[0, 3, 0, 1],
		[2, 0, 3, 0],
		[3, 2, 0, 2],
	]
	b.fx = b._blank_fx()
	b.choco = [
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 1, 0, 0],  # 居中巧克力，四周普通 → 蔓延有多个候选，靠 rng 选 → 测确定性
		[0, 0, 0, 0],
	]
	return b

# ───────────── CLEAR_CHOCO objective：啃够 N 个巧克力 → 过关 ─────────────

func test_clear_choco_objective_win() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 0, 30, 7, [], [{"type": "CLEAR_CHOCO", "species": -1, "target": 1}])
	assert_false(b.is_won(), "fresh CLEAR_CHOCO level not won")
	b.choco_cleared = 1
	assert_true(b.is_won(), "won when choco_cleared reaches target")

func test_clear_choco_objective_not_won_below_target() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 0, 30, 7, [], [{"type": "CLEAR_CHOCO", "species": -1, "target": 5}])
	b.choco_cleared = 3
	assert_false(b.is_won(), "below target -> not won")
