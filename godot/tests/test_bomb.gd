extends "res://tests/test_lib.gd"
# 倒计时炸弹（Bomb）机制测试：每步递减 / 归零判负 / 消除拆弹 / 随重力下落 / OBJ_DEFUSE_BOMB 胜负 / 不破坏其他层。
# 炸弹与 coat/choco/ing 本质不同：炸弹格的 grid 是【普通棋子】(可消可换)，bomb 只是叠加的倒计时标记。
# 故 find_matches/is_legal_swap 不感知 bomb（炸弹照常参与匹配/交换）；消除炸弹格 = 拆弹。
# 两端镜像：engine/tests/test_match_engine.cpp 有对应 C++ 断言。

const ME := preload("res://core/match_engine.gd")
const Board := preload("res://core/board.gd")

# 全 0 的 H×W 整型层（bomb 模板）。
func _blank(w: int, h: int) -> Array:
	var m := []
	for y in h:
		var row := []
		for x in w:
			row.append(0)
		m.append(row)
	return m

# ───────────── 炸弹格是普通棋子：照常参与匹配 / 交换（与 coat/choco/ing 关键区别）─────────────

func test_bomb_cell_still_matches() -> void:
	# 顶行三连 0,0,0；中间格盖炸弹 → 仍算三连（炸弹不断串，炸弹格是普通棋子可消）。
	var grid := [
		[0, 0, 0, 1],
		[2, 3, 4, 2],
		[3, 4, 2, 3],
	]
	var bomb := _blank(4, 3)
	bomb[0][1] = 3   # 炸弹盖住顶行中间格 (1,0)
	# bomb 不作为 find_matches 参数（炸弹格当普通棋子）→ 三连照旧成立。
	assert_eq(ME.find_matches(grid).size(), 3, "bomb cell does NOT break the run (bomb tile is a normal piece)")

func test_bomb_cell_still_swappable() -> void:
	# 炸弹格可参与交换：is_legal_swap 不接受 bomb 参数 → 炸弹是叠加标记、不锁交换。
	# 行0 [5,5,0,5]：交换 (2,0)<->(3,0) → 5,5,5,0，(0,0),(1,0),(2,0) 成三连。
	var grid := [
		[5, 5, 0, 5],
		[1, 2, 3, 4],
		[2, 3, 4, 1],
	]
	# 炸弹盖在参与交换的格上也不影响合法性（与无炸弹时结果一致）。
	assert_true(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(3, 0)), "bomb cell is still swappable (bomb does not lock the tile)")

# ───────────── 断言④：炸弹随重力下落（bomb 标记跟随 grid 搬运）─────────────

func test_bomb_falls_under_gravity() -> void:
	# 列：[炸弹棋子, 空, 空] → 炸弹棋子随重力沉到列底，bomb 标记跟随（与原料同构的"标记跟随"）。
	var E := ME.EMPTY
	var grid := [[5], [E], [E]]
	var bomb := [[3], [0], [0]]
	ME.apply_gravity(grid, [], false, {"bomb": bomb})
	assert_eq(grid[2][0], 5, "bomb tile fell to the column bottom")
	assert_eq(bomb[2][0], 3, "bomb countdown moved with the tile (now at bottom)")
	assert_eq(grid[0][0], E, "top is now empty")
	assert_eq(bomb[0][0], 0, "bomb layer cleared at the old top cell")

func test_bomb_sinks_when_tile_below_cleared() -> void:
	# 炸弹格正下方棋子被消除 → 炸弹格(普通棋子)随重力下沉一格，bomb 标记跟随。
	# 炸弹在 (1,1)；其正下方 (1,2) 属第2行三连 7,7,7。消除 → 炸弹沉到 (1,2)。do_refill=false 只看下沉。
	var grid := [
		[0, 1, 2, 3],
		[4, 8, 6, 0],   # (1,1)=8 盖炸弹
		[7, 7, 7, 1],   # 第2行 0..2 三连
		[2, 3, 4, 5],
	]
	var bomb := _blank(4, 4)
	bomb[1][1] = 5
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	# bomb 是最后一个参数；do_refill=false、无 ing/exit。
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7, 8], rng, [], [], false, null, {"bomb": bomb})
	assert_eq(bomb[2][1], 5, "bomb countdown sank exactly one row (y=1 -> y=2)")
	assert_eq(grid[2][1], 8, "bomb-covered tile moved down with it (species 8 preserved)")
	assert_eq(bomb[1][1], 0, "old bomb cell cleared")
	assert_eq(r.get("bomb_defused", -1), 0, "tile below cleared, but bomb tile itself NOT cleared -> not defused")

# ───────────── 断言③：消除炸弹格 → 拆弹（bomb→0, bomb_defused+1, 不再递减）─────────────

func test_bomb_defused_when_matched() -> void:
	# 炸弹格本身在三连里 → 被消除拆弹（bomb→0），bomb_defused 计数。
	# 第0行 0,0,0 三连，炸弹盖在 (1,0)（三连中一格）。
	var grid := [
		[0, 0, 0, 1],
		[2, 3, 4, 2],
		[3, 4, 2, 3],
	]
	var bomb := _blank(4, 3)
	bomb[0][1] = 4   # 炸弹在三连里
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [0, 1, 2, 3, 4], rng, [], [], false, null, {"bomb": bomb})
	assert_eq(r.get("bomb_defused", -1), 1, "bomb in the match got defused")
	assert_eq(ME.count_bombs(bomb), 0, "no bombs remain on board (defused)")

func test_defused_bomb_does_not_tick() -> void:
	# 拆掉的炸弹 bomb=0 → tick_bombs 不再递减它（已拆除不会再引爆）。
	var bomb := _blank(3, 3)
	bomb[0][0] = 0   # 已拆（0）
	bomb[1][1] = 2   # 仍存活
	var exploded := ME.tick_bombs(bomb)
	assert_eq(bomb[0][0], 0, "defused bomb stays at 0 (does not go negative / re-arm)")
	assert_eq(bomb[1][1], 1, "live bomb ticked down by 1")
	assert_eq(exploded, 0, "nothing reached 0 this tick")

# ───────────── 断言①：有效交换后所有存活 bomb 全 -1 ─────────────

func test_tick_decrements_all_live_bombs() -> void:
	var bomb := [
		[3, 0, 5],
		[0, 2, 0],
		[1, 0, 4],
	]
	var exploded := ME.tick_bombs(bomb)
	assert_eq(bomb[0][0], 2, "bomb -1")
	assert_eq(bomb[0][2], 4, "bomb -1")
	assert_eq(bomb[1][1], 1, "bomb -1")
	assert_eq(bomb[2][0], 0, "bomb 1 -> 0 (this one explodes)")
	assert_eq(bomb[2][2], 3, "bomb -1")
	assert_eq(exploded, 1, "exactly one bomb reached 0")

func test_board_swap_ticks_bombs() -> void:
	# board 集成：一次有效交换结算后，所有未被消除的炸弹 -1（断言①）。
	# 炸弹放底行(第3行)：消除发生在第1行，底行棋子不下落 → bomb 坐标稳定，可直接断言。
	# （炸弹在第0行会随重力下落到别处——那是正确行为，由 test_bomb_falls_under_gravity 专测；
	#   此处只想验证"tick 全 -1"，故选不动的底行避免坐标漂移干扰。）
	var b := Board.new(4, 4, [0, 1, 2, 3, 4, 5, 6, 7], 999999, 10, 1)
	b.grid = [
		[0, 1, 2, 3],
		[7, 7, 2, 7],   # 交换 (2,1)<->(3,1): 第1行 → 7,7,7,2 三连
		[4, 5, 6, 0],
		[1, 2, 3, 4],   # 底行：炸弹安家于此，消除后不下落
	]
	b.fx = b._blank_fx()
	b.bomb = b._blank_fx()   # 复用 _blank_fx 造同维全 0 层
	b.bomb[3][0] = 3   # 炸弹A（底行，不在被消除处、不下落）
	b.bomb[3][3] = 5   # 炸弹B（底行，不在被消除处、不下落）
	var r := b.try_swap(Vector2i(2, 1), Vector2i(3, 1))
	assert_true(r["ok"], "legal swap forms 7,7,7 in row 1")
	assert_eq(b.bomb[3][0], 2, "bomb A ticked down after the effective swap")
	assert_eq(b.bomb[3][3], 4, "bomb B ticked down after the effective swap")
	assert_false(b.bomb_exploded, "no bomb hit 0 -> not exploded")
	assert_false(b.is_over(), "game continues")

# ───────────── 断言②：bomb 归零 → board 失败（is_over 且 result 为负）─────────────

func test_board_bomb_zero_loses() -> void:
	# 炸弹剩 1 步且不在被消除处 → 一次有效交换 tick 到 0 → 引爆 → board 失败。
	var b := Board.new(4, 4, [0, 1, 2, 3, 4, 5, 6, 7], 999999, 10, 1)
	b.grid = [
		[0, 1, 2, 3],
		[4, 5, 6, 0],
		[7, 7, 2, 7],   # 交换 (2,2)<->(3,2): 第2行 → 7,7,7,2 三连
		[1, 2, 3, 4],
	]
	b.fx = b._blank_fx()
	b.bomb = b._blank_fx()
	b.bomb[0][0] = 1   # 炸弹剩 1 步，不在被消除处 → 这步必引爆
	assert_false(b.is_over(), "not over before the move")
	var r := b.try_swap(Vector2i(2, 2), Vector2i(3, 2))
	assert_true(r["ok"], "the swap itself is a legal, resolving move")
	assert_true(b.bomb_exploded, "bomb counted down to 0 and exploded")
	assert_true(b.is_over(), "board is over after the explosion")
	assert_false(b.is_won(), "exploded -> cannot be a win")
	assert_true(b.is_lost(), "exploded -> lost")
	var res := b.result()
	assert_true(res["lost"], "result reports a loss")
	assert_false(res["won"], "result is not a win")

func test_board_defusing_bomb_same_step_does_not_explode() -> void:
	# 关键边界：炸弹剩 1 步，但这步【正好消除掉它】→ 拆弹(bomb_defused+1)，不引爆（消除优先于递减）。
	# 第0行 0,0,0 三连本就成立? 不行，开局不能有现成消除。用交换触发：(0,0)<->(0,1) 不动；
	# 构造：交换 (3,0)<->(3,1) 让第0行成含炸弹格的三连。
	var b := Board.new(4, 4, [0, 1, 2, 3, 4, 5, 6, 7], 999999, 10, 1)
	b.grid = [
		[0, 0, 1, 0],   # 交换 (2,0)<->(3,0)? 让 (0..2) 成 0,0,0：需 (2,0)=0
		[2, 3, 4, 5],
		[3, 4, 5, 6],
		[4, 5, 6, 7],
	]
	# 设计：现状第0行 0,0,1,0 无三连；交换 (2,0)<->(3,0) → 0,0,0,1 → (0,0),(1,0),(2,0) 三连。
	b.fx = b._blank_fx()
	b.bomb = b._blank_fx()
	b.bomb[0][1] = 1   # 炸弹剩 1 步，盖在 (1,0) —— 正好在将形成的三连里
	var before_defused := b.bomb_defused
	var r := b.try_swap(Vector2i(2, 0), Vector2i(3, 0))   # → 第0行 0,0,0 三连含炸弹格
	assert_true(r["ok"], "swap forms 0,0,0 including the bomb cell")
	assert_eq(b.bomb_defused - before_defused, 1, "bomb defused by the match this same step")
	assert_false(b.bomb_exploded, "defused this step -> NOT exploded (clear beats countdown)")
	assert_false(b.is_lost(), "not lost: bomb was defused, not detonated")

# ───────────── 断言⑤：OBJ_DEFUSE_BOMB 拆够 N 过关 ─────────────

func test_defuse_bomb_objective_win() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 0, 30, 7, [], [{"type": "DEFUSE_BOMB", "species": -1, "target": 3}])
	assert_false(b.is_won(), "fresh DEFUSE_BOMB level not won")
	b.bomb_defused = 2
	assert_false(b.is_won(), "below target -> not won")
	b.bomb_defused = 3
	assert_true(b.is_won(), "won when bomb_defused reaches target")

func test_defuse_bomb_objective_lost_if_exploded() -> void:
	# 即使拆够了目标，只要有炸弹引爆过 → 永不算赢（核心张力：炸了就输）。
	var b := Board.new(4, 4, [0, 1, 2, 3], 0, 30, 7, [], [{"type": "DEFUSE_BOMB", "species": -1, "target": 3}])
	b.bomb_defused = 5   # 远超目标
	b.bomb_exploded = true
	assert_false(b.is_won(), "exploded overrides objective completion -> not won")
	assert_true(b.is_lost(), "exploded -> lost regardless of defuse count")

# ───────────── 断言⑥：不破坏其他层（炸弹与 ing 共存：各自语义独立）─────────────

func test_bomb_coexists_with_ingredient() -> void:
	# 同一 resolve 里炸弹 + 原料并存：炸弹格被消除拆弹，原料随重力下沉，互不干扰。
	# 第2行 7,7,7 三连；炸弹盖在 (0,2)（三连里 → 拆弹）；原料在 (3,0) 上方待下沉。
	var grid := [
		[3, 1, 2, ME.EMPTY],   # (3,0) 是原料 actor
		[4, 5, 6, 0],
		[7, 7, 7, 1],   # 第2行 0..2 三连，(0,2) 盖炸弹
		[2, 3, 4, 5],
	]
	var bomb := _blank(4, 4)
	bomb[2][0] = 3   # 炸弹在三连里 → 应被拆
	var ing := _blank(4, 4)
	ing[0][3] = 1    # 原料在 (3,0)
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	# 同时传 ing(第11参) 和 bomb(第13参)，exit_cols=[] 不收集，do_refill=false。
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7, 9], rng, [], [], false, null, {"ing": ing, "bomb": bomb})
	assert_eq(r.get("bomb_defused", -1), 1, "bomb in the match got defused (coexists with ingredient)")
	assert_eq(ME.count_bombs(bomb), 0, "bomb removed")
	# 原料(3,0) 正下方 (3,1)=0 空 → 原料下沉至少一格；原料层仍计 1 颗（未到出口，未收集）。
	assert_eq(ME.count_ingredients(ing), 1, "ingredient still on board (not collected, no exit)")
	assert_eq(r.get("ingredient_collected", -1), 0, "no exit -> ingredient not collected")

func test_no_bomb_layer_is_noop() -> void:
	# 不传 bomb（[]）时，resolve 行为与旧版完全一致：bomb_defused=0，普通消除照旧。
	var grid := [
		[0, 0, 0, 1],
		[2, 3, 4, 2],
		[3, 4, 2, 3],
	]
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [0, 1, 2, 3, 4], rng, [], [], false)
	assert_eq(r.get("bomb_defused", 0), 0, "no bomb layer -> bomb_defused stays 0")
	assert_true(r.get("cleared", 0) >= 3, "the 3-match still cleared normally")

# ───────────── 确定性：同 seed 一致 ─────────────

func test_bomb_deterministic_same_seed() -> void:
	var g1 := _seed_grid()
	var g2 := _seed_grid()
	var b1 := _blank(4, 4); b1[0][2] = 4
	var b2 := _blank(4, 4); b2[0][2] = 4
	var r1 := RandomNumberGenerator.new(); r1.seed = 13579
	var r2 := RandomNumberGenerator.new(); r2.seed = 13579
	var res1 := ME.resolve(g1, [0, 1, 2, 3, 4, 5], r1, [], [], true, null, {"bomb": b1})
	var res2 := ME.resolve(g2, [0, 1, 2, 3, 4, 5], r2, [], [], true, null, {"bomb": b2})
	assert_eq(g1, g2, "same seed -> identical grid after resolve")
	assert_eq(b1, b2, "same seed -> identical bomb layer after resolve")
	assert_eq(res1.get("bomb_defused", -1), res2.get("bomb_defused", -2), "same seed -> identical bomb_defused")

func _seed_grid() -> Array:
	return [
		[0, 1, 8, 3],   # (2,0)=8 占位将被炸弹盖
		[4, 5, 0, 1],
		[2, 3, 4, 5],
		[1, 2, 3, 4],
	]
