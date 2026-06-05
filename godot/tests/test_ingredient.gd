extends "res://tests/test_lib.gd"
# 运原料（Ingredients）机制测试：原料随重力下落 / 不可消 / 不可换 / 落到底部出口被收集 / 确定性。
# 与 choco 的关键区别：原料【随重力下落】（choco 固定切段）——下面多条断言专测这点。
# 两端镜像：engine/tests/test_match_engine.cpp 有对应 C++ 断言。

const ME := preload("res://core/match_engine.gd")
const Board := preload("res://core/board.gd")

# 全 0 的 H×W 整型层（ing 模板）。
func _blank(w: int, h: int) -> Array:
	var m := []
	for y in h:
		var row := []
		for x in w:
			row.append(0)
		m.append(row)
	return m

# 整最底行的出口列 [0..w-1]。
func _bottom_exits(w: int) -> Array:
	var c := []
	for x in w:
		c.append(x)
	return c

# ───────────── 不参与 match：原料格断开同色串（不可消）─────────────

func test_ingredient_not_matched() -> void:
	var grid := [
		[0, 0, 0, 1],
		[2, 3, 4, 2],
		[3, 4, 2, 3],
	]
	assert_eq(ME.find_matches(grid).size(), 3, "no ingredient -> top row is a 3-match")
	var ing := [
		[0, 1, 0, 0],  # 原料盖住顶行中间格 (1,0)
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	assert_true(ME.find_matches(grid, [], [], ing).is_empty(), "ingredient cell breaks the run -> no match")

func test_ingredient_classify_skips() -> void:
	# classify_matches 也跳过原料格（fx 路径一致）。
	var grid := [
		[0, 0, 0, 0, 1],
		[1, 2, 3, 2, 3],
		[2, 3, 1, 3, 1],
	]
	var ing := _blank(5, 3)
	ing[0][1] = 1  # 原料盖住四连中一格 → 断成 0 [I] 0 0 → 无三连
	var c := ME.classify_matches(grid, [], [], ing)
	assert_true(c["clear"].is_empty() and c["spawns"].is_empty(), "ingredient breaks the run in classify too")

# ───────────── 不可交换 ─────────────

func test_ingredient_blocks_swap() -> void:
	var grid := [[0, 0, 1], [1, 2, 0], [3, 4, 5]]  # (2,0)<->(2,1) 本来合法
	var ing := [[0, 0, 1], [0, 0, 0], [0, 0, 0]]   # (2,0) 被原料覆盖
	assert_false(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(2, 1), [], 1, [], ing), "ingredient cell can't be swapped")
	assert_true(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(2, 1)), "without ingredient -> legal")

# ───────────── 随重力下落（与 choco 最大不同）─────────────

func test_ingredient_falls_under_gravity() -> void:
	# 列：[原料, 空, 空] → 原料随重力沉到列底（choco 会固定不动，原料必须落）。
	var E := ME.EMPTY
	var grid := [[5], [E], [E]]
	var ing := [[1], [0], [0]]
	ME.apply_gravity(grid, [], [], false, [], ing)
	assert_eq(grid[2][0], 5, "ingredient tile fell to the column bottom")
	assert_eq(ing[2][0], 1, "ing layer moved with the tile (now at bottom)")
	assert_eq(grid[0][0], E, "top is now empty")
	assert_eq(ing[0][0], 0, "ing layer cleared at the old top cell")

func test_ingredient_sinks_one_after_clear_below() -> void:
	# 原料正下方棋子被消除 → 原料下沉一格（断言①）。
	# 原料在 (1,1)；其正下方 (1,2) 属于第2行横向三连 (0,2),(1,2),(2,2)=7,7,7。
	# 消除该三连 → (1,2) 腾空 → 原料 (1,1) 下沉到 (1,2)。do_refill=false、无出口 → 只看下沉一格。
	var E := ME.EMPTY
	var grid := [
		[0, 1, 2, 3],
		[4, 9, 6, 0],   # (1,1)=9 被原料覆盖
		[7, 7, 7, 1],   # 第2行 0..2 = 7,7,7 三连（原料正下方 (1,2) 在其中）
		[2, 3, 4, 5],
	]
	var ing := _blank(4, 4)
	ing[1][1] = 1
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	# do_refill=false、无出口(exit_cols=[]) → 只看下沉、不收集、不补充。
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7, 9], rng, [], [], [], [], false, null, [], ing, [])
	assert_eq(ing[2][1], 1, "ingredient sank exactly one row (from y=1 to y=2)")
	assert_eq(grid[2][1], 9, "ingredient-covered tile moved down with it (species 9 preserved)")
	assert_eq(ing[1][1], 0, "old ingredient cell cleared")
	assert_eq(r.get("ingredient_collected", -1), 0, "no exit configured -> nothing collected")

# ───────────── 落到底部出口 → 被收集 ─────────────

func test_collect_at_exit_pure() -> void:
	# 纯函数：最底行出口列若是原料 → 收集（grid 清空、ing 归 0）。
	var grid := [
		[0, 1, 2],
		[3, 4, 5],
		[6, 7, 8],   # 最底行
	]
	var ing := _blank(3, 3)
	ing[2][0] = 1   # (0,2) 原料，在最底行出口
	ing[2][2] = 1   # (2,2) 原料，在最底行出口
	var got := ME.collect_ingredients_at_exit(grid, ing, [0, 2])  # 只列0、列2是出口
	assert_eq(got, 2, "two ingredients at exit collected")
	assert_eq(grid[2][0], ME.EMPTY, "collected cell cleared to EMPTY")
	assert_eq(ing[2][0], 0, "ing layer zeroed at collected cell")
	assert_eq(ME.count_ingredients(ing), 0, "no ingredients remain")

func test_collect_respects_exit_cols() -> void:
	# 非出口列的底行原料不被收集。
	var grid := [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
	var ing := _blank(3, 3)
	ing[2][1] = 1   # (1,2) 在最底行但列1不是出口
	var got := ME.collect_ingredients_at_exit(grid, ing, [0, 2])
	assert_eq(got, 0, "ingredient in non-exit column not collected")
	assert_eq(ing[2][1], 1, "ingredient stays")

func test_ingredient_sinks_to_bottom_and_collected() -> void:
	# 原料连续下沉到最底行 → 被收集，ingredient_collected+1，grid 该格清空（断言②）。
	# 列0：[原料, 空, 空, 空]，整列下方全空 → 原料一路沉到 (0,3) 出口被收。
	var E := ME.EMPTY
	var grid := [
		[5, 0, 1, 2],
		[E, 3, 4, 0],
		[E, 1, 2, 3],
		[E, 4, 0, 1],   # 列0 全空，原料从顶 (0,0) 落到底 (0,3)
	]
	var ing := _blank(4, 4)
	ing[0][0] = 1   # 原料在列0顶
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var exits := _bottom_exits(4)
	# do_refill=false：避免补充填回列0；专测下沉到出口收集。
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5], rng, [], [], [], [], false, null, [], ing, exits)
	assert_eq(r.get("ingredient_collected", -1), 1, "ingredient sank to bottom exit and got collected")
	assert_eq(ME.count_ingredients(ing), 0, "ingredient removed from board")
	assert_eq(grid[3][0], E, "exit cell cleared after collection")

# ───────────── board 集成：try_swap 推进收集 + OBJ_COLLECT_INGREDIENT 胜负 ─────────────

func test_board_collect_via_swap() -> void:
	# board 一步合法消除清掉出口列底部棋子 → 列0空通 → 原料一路沉到出口被收 → ingredient_collected 累加。
	# 出口只设列0；原料在 (0,0)，列0下方 (0,1)/(0,2) 空、(0,3) 待被消除腾空。
	# 合法交换 (2,2)<->(2,3) 使底行成 7,7,7（含出口列 (0,3)），消除后列0全空 → 原料触底出口。
	var b := Board.new(4, 4, [0, 1, 2, 3, 4, 5, 7], 999999, 10, 1)
	b.exit_cols = [0]
	b.grid = [
		[5, 1, 2, 0],
		[ME.EMPTY, 3, 4, 1],
		[ME.EMPTY, 2, 7, 1],   # (2,2)=7
		[7, 7, 2, 3],          # 底行 (0,3),(1,3)=7,7，(2,3)=2；交换 (2,2)<->(2,3) → 底行 7,7,7
	]
	b.fx = b._blank_fx()
	b.ing = b._blank_fx()   # 复用 _blank_fx 造同维全 0 层
	b.ing[0][0] = 1
	var before := b.ingredient_collected
	var r := b.try_swap(Vector2i(2, 2), Vector2i(2, 3))   # 底行 → 7,7,7
	assert_true(r["ok"], "legal swap forms bottom-row 7,7,7")
	assert_true(b.ingredient_collected > before, "ingredient fell through emptied column to exit and got collected")
	assert_eq(ME.count_ingredients(b.ing), 0, "ingredient consumed at exit")

func test_collect_ingredient_objective_win() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 0, 30, 7, [], [{"type": "COLLECT_INGREDIENT", "species": -1, "target": 1}])
	assert_false(b.is_won(), "fresh COLLECT_INGREDIENT level not won")
	b.ingredient_collected = 1
	assert_true(b.is_won(), "won when ingredient_collected reaches target")

func test_collect_ingredient_objective_not_won_below_target() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 0, 30, 7, [], [{"type": "COLLECT_INGREDIENT", "species": -1, "target": 3}])
	b.ingredient_collected = 2
	assert_false(b.is_won(), "below target -> not won")

# ───────────── 确定性：同 seed 一致（断言④）─────────────

func test_ingredient_deterministic_same_seed() -> void:
	# 同 seed 两次完整 resolve（含下落+收集+补充）结果一致。
	var exits := _bottom_exits(4)
	var g1 := _seed_grid()
	var g2 := _seed_grid()
	var i1 := _blank(4, 4); i1[0][2] = 1
	var i2 := _blank(4, 4); i2[0][2] = 1
	var r1 := RandomNumberGenerator.new(); r1.seed = 24680
	var r2 := RandomNumberGenerator.new(); r2.seed = 24680
	var res1 := ME.resolve(g1, [0, 1, 2, 3, 4, 5], r1, [], [], [], [], true, null, [], i1, exits)
	var res2 := ME.resolve(g2, [0, 1, 2, 3, 4, 5], r2, [], [], [], [], true, null, [], i2, exits)
	assert_eq(g1, g2, "same seed -> identical grid after resolve")
	assert_eq(i1, i2, "same seed -> identical ing layer after resolve")
	assert_eq(res1.get("ingredient_collected", -1), res2.get("ingredient_collected", -2), "same seed -> identical collected count")

func _seed_grid() -> Array:
	return [
		[0, 1, 9, 3],   # (2,0)=9 占位将被原料盖
		[4, 5, 0, 1],
		[2, 3, 4, 5],
		[1, 2, 3, 4],
	]
