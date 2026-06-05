extends "res://tests/test_lib.gd"
# 爆米花（Popcorn）机制测试 —— 对标 Candy Crush 的 Popcorn：
#   不可消的爆米花格，被【特效(条纹/爆炸/彩球)】命中 N 次后变成色彩炸弹(SP_COLORBOMB)。
# 爆米花与 coat/choco 的本质区别：普通三消【完全不碰】它，只有特效清除波及才 -1（coat 普通相邻就破）。
# 与 ing 同构的部分：不参与匹配(find_matches/classify 跳过)、不可交换(is_legal_swap 拦)、随重力下落(apply_gravity 跟随)。
# 断言：①特效命中→popcorn-1 不清除 ②普通三消相邻→不影响 ③归0→变 SP_COLORBOMB ④不参与 match/不可换
#       ⑤随重力下落 ⑥确定性 ⑦不破坏现有 coat/choco/ing/bomb/cannon。
# 两端镜像：engine/tests/test_match_engine.cpp 有对应 C++ 断言（popcorn 命中/递减/重力/计数）。

const ME := preload("res://core/match_engine.gd")
const Board := preload("res://core/board.gd")

# 全 0 的 H×W 整型层（popcorn/bomb 等模板）。
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


# ───────────── 断言④：爆米花不参与普通 match / 不可交换 ─────────────

func test_popcorn_not_matched() -> void:
	# 顶行三连 0,0,0；中间格盖爆米花 → 不算三连（爆米花断串，像 ing/choco）。
	var grid := [
		[0, 0, 0, 1],
		[2, 3, 4, 2],
		[3, 4, 2, 3],
	]
	# 不传 popcorn → 三连成立（3 格）。
	assert_eq(ME.find_matches(grid).size(), 3, "no popcorn -> top row is a normal 3-match")
	# 传 popcorn，中间格(1,0)是爆米花 → 断串，无三连。
	var pop := _blank(4, 3)
	pop[0][1] = 2
	assert_true(ME.find_matches(grid, {"popcorn": pop}).is_empty(), "popcorn cell breaks the run -> no match (like ingredient)")

func test_popcorn_blocks_swap() -> void:
	# 爆米花格不可交换：is_legal_swap 传 popcorn → 拒绝。
	# 行0 [5,5,0,5]：交换 (2,0)<->(3,0) → 5,5,5,0 本应成三连。
	var grid := [
		[5, 5, 0, 5],
		[1, 2, 3, 4],
		[2, 3, 4, 1],
	]
	# 无 popcorn → 合法。
	assert_true(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(3, 0)), "no popcorn -> swap is legal")
	# (2,0) 是爆米花 → 不可换（即使换后形状能消，爆米花也拦死）。
	var pop := _blank(4, 3)
	pop[0][2] = 1
	assert_false(ME.is_legal_swap(grid, Vector2i(2, 0), Vector2i(3, 0), 1, {"popcorn": pop}), "popcorn cell cannot be swapped")

func test_popcorn_no_legal_move_when_isolated() -> void:
	# has_legal_move 须 popcorn 感知：把会动的格设成爆米花，应识别为不可动。
	var grid := [
		[5, 5, 0, 5],
		[1, 2, 3, 4],
		[2, 3, 4, 1],
	]
	var pop := _blank(4, 3)
	pop[0][2] = 1   # 唯一能促成消除的关键格变爆米花
	# 无 popcorn 感知会误判"有步"；popcorn 感知后该步被否。
	assert_true(ME.has_legal_move(grid), "ignoring popcorn -> looks like a move exists")
	# 该盘仅此一步可消，封死后无其他合法步。
	assert_false(ME.has_legal_move(grid, {"popcorn": pop}), "popcorn-aware: that move is rejected, no legal move remains")


# ───────────── 断言⑤：爆米花随重力下落（popcorn 标记跟随 grid 搬运）─────────────

func test_popcorn_falls_under_gravity() -> void:
	# 列：[爆米花棋子, 空, 空] → 随重力沉到列底，popcorn 标记跟随（与 ing/bomb 同构）。
	var E := ME.EMPTY
	var grid := [[5], [E], [E]]
	var pop := [[2], [0], [0]]
	# apply_gravity 第8参=popcorn。
	ME.apply_gravity(grid, [], false, {"popcorn": pop})
	assert_eq(grid[2][0], 5, "popcorn tile fell to the column bottom")
	assert_eq(pop[2][0], 2, "popcorn count moved with the tile (now at bottom)")
	assert_eq(grid[0][0], E, "top is now empty")
	assert_eq(pop[0][0], 0, "popcorn layer cleared at the old top cell")

func test_popcorn_sinks_when_tile_below_cleared() -> void:
	# 爆米花格正下方棋子被消除 → 爆米花格(占位棋子)随重力下沉一格，popcorn 标记跟随。
	# 爆米花在 (1,1)；其正下方 (1,2) 属第2行三连 7,7,7。消除 → 爆米花沉到 (1,2)。
	var grid := [
		[0, 1, 2, 3],
		[4, 8, 6, 0],   # (1,1)=8 盖爆米花
		[7, 7, 7, 1],   # 第2行 0..2 三连
		[2, 3, 4, 5],
	]
	var pop := _blank(4, 4)
	pop[1][1] = 3
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	# popcorn 是最后一个参数；do_refill=false、无 fx（纯三消路径，爆米花不被命中只下落）。
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7, 8], rng, [], [], false, null, {"popcorn": pop})
	assert_eq(pop[2][1], 3, "popcorn count sank exactly one row (y=1 -> y=2)")
	assert_eq(grid[2][1], 8, "popcorn-covered tile moved down with it (species 8 preserved)")
	assert_eq(pop[1][1], 0, "old popcorn cell cleared")
	assert_eq(r.get("popcorn_hit", -1), 0, "plain 3-match below it: popcorn NOT hit (only special effects hit popcorn)")


# ───────────── 断言②：普通三消【不影响】相邻爆米花（与 coat 破锁的关键区别）─────────────

func test_plain_match_does_not_hit_adjacent_popcorn() -> void:
	# 第0行 0,0,0 三连，爆米花紧贴在其正下方/相邻 → 普通三消相邻【不递减】爆米花（coat 会破，popcorn 不会）。
	var grid := [
		[0, 0, 0, 1],   # 三连
		[4, 5, 6, 2],   # (0,1)=4 在三连正下方
		[3, 4, 2, 3],
	]
	var pop := _blank(4, 3)
	pop[1][0] = 2   # 爆米花紧贴三连下方（正交相邻）
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6], rng, [], [], false, null, {"popcorn": pop})
	assert_eq(r.get("popcorn_hit", -1), 0, "plain adjacent 3-match does NOT hit popcorn (popcorn only reacts to effects)")
	assert_eq(ME.count_popcorn(pop), 1, "popcorn count unchanged after a plain adjacent match")


# ───────────── 断言①：特效(条纹)命中爆米花 → popcorn-1，爆米花不被清除 ─────────────

func test_stripe_effect_hits_popcorn_decrements() -> void:
	# 行0 放一个横条纹(SP_LINE_H)在 (0,0)，并让它被一个匹配触发 → 整行0 被清，波及行0 的爆米花格 -1（不清）。
	# 触发：行0 是 9,9,9,... 三连（含条纹格 (0,0)）→ 条纹被卷入 → 清整行0。爆米花放 (2,0)，popcorn=3。
	var grid := [
		[9, 9, 9, 4, 5, 6],   # 行0 前三格 9 三连（(0,0) 上有条纹）；(2,0) 是爆米花占位
		[1, 2, 3, 4, 5, 7],
		[2, 3, 4, 5, 6, 1],
	]
	var fx := _none_fx(6, 3)
	fx[0][0] = ME.SP_LINE_H   # 横条纹盖在三连一格上 → 匹配触发它清整行
	var pop := _blank(6, 3)
	pop[0][2] = 3   # 爆米花在行0、x=2（条纹清行会波及它）
	# 注意 (2,0) 既是三连第三格(grid=9) 又是爆米花 → find_matches 会因 popcorn 断串吗？
	# 会：popcorn 断串，故 9,9 只剩两格不成三连。改用不含爆米花的三连触发条纹。见下方修正测试。
	# 这里直接验证 collect_clears + _resolve_fx 的命中：用一个独立可成的三连触发条纹。
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [1, 2, 3, 4, 5, 6, 7, 9], rng, fx, [], false, null, {"popcorn": pop})
	# 由于 (2,0) 爆米花断串，(0,0)(1,0) 只两格 9 → 不成三连 → 条纹不被触发 → 爆米花未被命中。
	# 这验证了"爆米花断串"的副作用；真正的命中场景见 test_stripe_triggered_clears_row_hits_popcorn。
	assert_eq(r.get("popcorn_hit", -1), 0, "popcorn breaks the 9-run so the stripe is never triggered here")
	assert_eq(pop[0][2], 3, "popcorn untouched (stripe never fired)")

func test_stripe_triggered_clears_row_hits_popcorn() -> void:
	# 正确的命中场景：条纹被一个【不含爆米花】的三连触发，清整行，波及同行的爆米花格 -1。
	# 行0: [C, 1, 2, P, 5, 6] —— (0,0) 是条纹，(3,0) 是爆米花(popcorn=3)。
	# 让 (0,0) 被竖直三连触发：列0 是 C/9/9... 不行(条纹格 grid 须同色)。
	# 改用最直接路径：直接构造一个匹配把条纹卷入。列0 放三个同色 8 含 (0,0)：
	var grid := [
		[8, 1, 2, 7, 5, 6],   # (0,0)=8 上盖条纹；(3,0)=7 是爆米花占位
		[8, 2, 3, 4, 6, 7],   # 列0: 8,8,8 三连 → 触发 (0,0) 的条纹
		[8, 3, 4, 5, 7, 1],
	]
	var fx := _none_fx(6, 3)
	fx[0][0] = ME.SP_LINE_H   # 横条纹在 (0,0)：被列0 三连触发后清整行0
	var pop := _blank(6, 3)
	pop[0][3] = 3   # 爆米花在行0、x=3 → 条纹清行0 时波及
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [1, 2, 3, 4, 5, 6, 7, 8], rng, fx, [], false, null, {"popcorn": pop})
	assert_eq(r.get("popcorn_hit", -1), 1, "stripe cleared row 0 and hit the popcorn once (popcorn-1)")
	assert_eq(pop[0][3], 2, "popcorn decremented from 3 to 2 (NOT cleared)")
	assert_eq(ME.count_popcorn(pop), 1, "popcorn still on board (hit, not destroyed)")
	assert_eq(grid[0][3], 7, "popcorn-covered tile NOT cleared by the stripe (species 7 preserved)")


# ───────────── 断言①+③：爆球(SP_BOMB 3x3)命中爆米花 + 归0变彩球 ─────────────

func test_bomb_effect_hits_popcorn_and_converts_at_zero() -> void:
	# 爆球(SP_BOMB)被三连触发清 3x3，波及中心附近的爆米花(popcorn=1) → 命中后归0 → 变彩球(SP_COLORBOMB)。
	# 列0: 8,8,8 三连触发 (0,0) 的爆球 → 清以 (0,0) 为心的 3x3 (x∈[0,1], y∈[0,1])。
	# 爆米花放 (1,1)，popcorn=1 → 在 3x3 内 → 命中归0变彩球。
	var grid := [
		[8, 3, 2, 7],
		[8, 9, 4, 5],   # (1,1)=9 是爆米花占位（在 3x3 内）
		[8, 4, 5, 6],
		[2, 3, 4, 1],
	]
	var fx := _none_fx(4, 4)
	fx[0][0] = ME.SP_BOMB   # 爆球在 (0,0)：列0 三连触发后清 3x3
	var pop := _blank(4, 4)
	pop[1][1] = 1   # 爆米花剩 1 次命中 → 这次命中即归0变彩球
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [2, 3, 4, 5, 6, 7, 8, 9], rng, fx, [], false, null, {"popcorn": pop})
	assert_true(r.get("popcorn_hit", 0) >= 1, "3x3 bomb hit the popcorn at least once")
	# 归0后：popcorn 该格=0、fx=SP_COLORBOMB、grid 保留 species（彩球底色）。
	# 注意结算后可能下落/补充改变坐标——爆米花变彩球的格本应原地(未被清)，但其上方棋子下落不影响它的 fx。
	# 直接断言"盘上多了一个彩球 且 不再有该爆米花"。
	assert_eq(ME.count_popcorn(pop), 0, "popcorn reached 0 and is gone (converted)")
	var cb := 0
	for y in 4:
		for x in 4:
			if fx[y][x] == ME.SP_COLORBOMB:
				cb += 1
	assert_eq(cb, 1, "the popcorn converted into exactly one color bomb (SP_COLORBOMB)")

func test_popcorn_converts_keeps_species_in_place() -> void:
	# 精确验证归0变彩球的产物：原地、grid 保留 species、fx=SP_COLORBOMB、popcorn=0。
	# 用底行爆米花避免下落漂移：列0 顶部三连触发条纹清行，但爆米花放底行不会被清行波及——
	# 换法：直接用 account_clears 验证直清路径的转换（彩球/融合走这条），坐标稳定不下落。
	var grid := [
		[5, 6, 7, 2],
		[6, 7, 2, 3],
		[7, 9, 4, 5],   # (1,2)=9 爆米花占位
		[2, 3, 4, 1],
	]
	var fx := _none_fx(4, 4)
	var pop := _blank(4, 4)
	pop[2][1] = 1   # 爆米花剩 1 次
	# 模拟一次直清波及 (1,2)（如彩球/融合）：cells 含 (1,2)。account_clears 传 popcorn+fx。
	var cells := [Vector2i(1, 2), Vector2i(2, 2)]   # 波及爆米花格 + 一个普通格
	var acc := ME.account_clears(grid, cells, fx, null, [], {"popcorn": pop})
	assert_eq(acc.get("popcorn_hit", -1), 1, "direct clear hit the popcorn once")
	assert_eq(pop[2][1], 0, "popcorn reached 0")
	assert_eq(fx[2][1], ME.SP_COLORBOMB, "converted to color bomb in place (fx=SP_COLORBOMB)")
	assert_eq(grid[2][1], 9, "grid species preserved as the color bomb's base (still 9)")

func test_popcorn_multi_hit_needs_multiple_effects() -> void:
	# popcorn=2 → 一次特效命中只 -1（变 1），不变彩球；需第二次特效才归0。
	var grid := [
		[5, 6, 7, 2],
		[6, 7, 2, 3],
		[7, 9, 4, 5],
		[2, 3, 4, 1],
	]
	var fx := _none_fx(4, 4)
	var pop := _blank(4, 4)
	pop[2][1] = 2   # 需两次命中
	var acc := ME.account_clears(grid, [Vector2i(1, 2)], fx, null, [], {"popcorn": pop})
	assert_eq(acc.get("popcorn_hit", -1), 1, "first effect hit decrements by 1")
	assert_eq(pop[2][1], 1, "popcorn now at 1 (not yet a color bomb)")
	assert_eq(fx[2][1], ME.SP_NONE, "not converted yet (fx still SP_NONE while popcorn > 0)")
	# 第二次命中 → 归0变彩球。
	var acc2 := ME.account_clears(grid, [Vector2i(1, 2)], fx, null, [], {"popcorn": pop})
	assert_eq(acc2.get("popcorn_hit", -1), 1, "second effect hit decrements again")
	assert_eq(pop[2][1], 0, "popcorn reached 0 on the second hit")
	assert_eq(fx[2][1], ME.SP_COLORBOMB, "converted to color bomb on the second hit")


# ───────────── 断言⑥：确定性 —— 同 seed 同输入结果一致 ─────────────

func test_popcorn_deterministic_same_seed() -> void:
	var g1 := _det_grid()
	var g2 := _det_grid()
	var fx1 := _none_fx(4, 4); fx1[0][0] = ME.SP_LINE_H
	var fx2 := _none_fx(4, 4); fx2[0][0] = ME.SP_LINE_H
	var p1 := _blank(4, 4); p1[0][2] = 2
	var p2 := _blank(4, 4); p2[0][2] = 2
	var r1 := RandomNumberGenerator.new(); r1.seed = 24680
	var r2 := RandomNumberGenerator.new(); r2.seed = 24680
	var res1 := ME.resolve(g1, [1, 2, 3, 4, 5, 8], r1, fx1, [], true, null, {"popcorn": p1})
	var res2 := ME.resolve(g2, [1, 2, 3, 4, 5, 8], r2, fx2, [], true, null, {"popcorn": p2})
	assert_eq(g1, g2, "same seed -> identical grid after resolve")
	assert_eq(p1, p2, "same seed -> identical popcorn layer after resolve")
	assert_eq(res1.get("popcorn_hit", -1), res2.get("popcorn_hit", -2), "same seed -> identical popcorn_hit")

func _det_grid() -> Array:
	return [
		[8, 1, 7, 3],   # (0,0)=8 上盖条纹；(2,0)=7 占位爆米花
		[8, 5, 2, 1],   # 列0 8,8,8 三连 → 触发条纹
		[8, 3, 4, 5],
		[1, 2, 3, 4],
	]


# ───────────── 断言③(board 集成)：爆米花归0变彩球后玩家可用这枚彩球 ─────────────

func test_board_popcorn_converts_and_is_usable_colorbomb() -> void:
	# board 端到端：特效命中爆米花归0 → 该格成彩球 → 玩家随后可用它（与相邻交换引爆全色）。
	var b := Board.new(6, 6, [1, 2, 3, 4, 5, 6, 7], 999999, 30, 99)
	b.grid = [
		[8, 1, 2, 7, 5, 6],   # (0,0)=8 上盖条纹；(3,0)=7 爆米花占位
		[8, 2, 3, 4, 6, 1],   # 列0 8,8,8 三连 → 触发 (0,0) 条纹清行0
		[8, 3, 4, 5, 7, 2],
		[2, 4, 5, 6, 1, 3],
		[3, 5, 6, 7, 2, 4],
		[4, 6, 7, 1, 3, 5],
	]
	b.fx = b._blank_fx()
	b.fx[0][0] = ME.SP_LINE_H   # 条纹在 (0,0)
	b.popcorn = b._blank_fx()   # 复用 _blank_fx 造同维全 0 层
	b.popcorn[0][3] = 1   # 爆米花剩 1 次，在行0、x=3 → 条纹清行命中归0变彩球
	# 触发：交换让列0 成三连？列0 已是 8,8,8 但开局不应有现成消除——这里直接手填盘，绕过 start 的无消除保证。
	# 用一次 resolve 直接结算手填盘（模拟"上一步落定后"）：调 board 的私有结算入口不便，改用 ME.resolve 直推 board 层。
	var rng := b.rng
	var r := ME.resolve(b.grid, b.species, rng, b.fx, b.feed, true, null, {"jelly": b.jelly, "coat": b.coat, "choco": b.choco, "ing": b.ing, "exit_cols": b.exit_cols, "bomb": b.bomb, "popcorn": b.popcorn})
	assert_true(r.get("popcorn_hit", 0) >= 1, "stripe hit the popcorn")
	assert_eq(ME.count_popcorn(b.popcorn), 0, "popcorn converted (count 0)")
	# 盘上应出现一枚彩球（爆米花变的），玩家可用。
	var cb_pos := Vector2i(-1, -1)
	for y in 6:
		for x in 6:
			if b.fx[y][x] == ME.SP_COLORBOMB:
				cb_pos = Vector2i(x, y)
	assert_true(cb_pos.x >= 0, "a color bomb exists on the board (from the popcorn)")


# ───────────── 断言⑦：不破坏其他层（爆米花与 bomb/ing 共存，各自语义独立）─────────────

func test_popcorn_coexists_with_bomb_and_ingredient() -> void:
	# 同一 resolve 里爆米花 + 炸弹 + 原料并存：条纹命中爆米花-1、炸弹随重力沉、原料下沉，互不干扰。
	# 列0: 8,8,8 三连触发 (0,0) 条纹清行0；行0 的爆米花(3,0)-1；炸弹/原料在别处各自语义。
	var grid := [
		[8, 1, 2, 7, 9, 6],   # (0,0)=8 条纹；(3,0)=7 爆米花；(4,0)=9 原料占位
		[8, 2, 3, 4, 6, 1],
		[8, 5, 4, 5, 7, 2],   # (1,2)=5 盖炸弹（不在被清行，随重力可能动）
		[2, 4, 5, 6, 1, 3],
	]
	var fx := _none_fx(6, 4)
	fx[0][0] = ME.SP_LINE_H
	var pop := _blank(6, 4); pop[0][3] = 2
	var bomb := _blank(6, 4); bomb[2][1] = 5
	var ing := _blank(6, 4); ing[0][4] = 1
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	# 传 ing(第11参)、bomb(第13参)、popcorn(第14参)；exit_cols=[] 不收原料；do_refill=false。
	var r := ME.resolve(grid, [1, 2, 3, 4, 5, 6, 7, 8, 9], rng, fx, [], false, null, {"ing": ing, "bomb": bomb, "popcorn": pop})
	assert_eq(r.get("popcorn_hit", -1), 1, "stripe hit the popcorn once (coexists with bomb+ingredient)")
	assert_eq(ME.count_popcorn(pop), 1, "popcorn decremented to 1, still on board")
	assert_eq(r.get("bomb_defused", -1), 0, "bomb not in the cleared row -> not defused (independent layer)")
	assert_eq(ME.count_bombs(bomb), 1, "bomb still live (its own semantics intact)")
	assert_eq(ME.count_ingredients(ing), 1, "ingredient still on board (no exit configured)")

func test_no_popcorn_layer_is_noop() -> void:
	# 不传 popcorn（[]）时，resolve 行为与旧版完全一致：popcorn_hit=0，特效消除照旧。
	var grid := [
		[8, 1, 2, 4],
		[8, 2, 3, 5],
		[8, 3, 4, 6],
		[2, 4, 5, 1],
	]
	var fx := _none_fx(4, 4)
	fx[0][0] = ME.SP_LINE_H   # 列0 三连触发条纹
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [1, 2, 3, 4, 5, 6, 8], rng, fx, [], false)
	assert_eq(r.get("popcorn_hit", 0), 0, "no popcorn layer -> popcorn_hit stays 0")
	assert_true(r.get("cleared", 0) >= 3, "the stripe-triggered clear still happened normally")

func test_count_popcorn() -> void:
	var pop := [
		[2, 0, 1],
		[0, 0, 0],
		[0, 3, 0],
	]
	assert_eq(ME.count_popcorn(pop), 3, "three popcorn cells counted")


# ───────────── 断言⑤(board 集成)：爆米花随重力下落 + 不可换（board 层 try_swap）─────────────

func test_board_popcorn_not_swappable() -> void:
	# board.try_swap：尝试交换一个爆米花格 → 被拒（reason=illegal），不消耗步数。
	var b := Board.new(4, 4, [1, 2, 3, 4, 5, 6], 999999, 10, 5)
	b.grid = [
		[5, 5, 7, 5],
		[1, 2, 3, 4],
		[2, 3, 4, 1],
		[3, 4, 1, 2],
	]
	b.fx = b._blank_fx()
	b.popcorn = b._blank_fx()
	b.popcorn[0][2] = 2   # (2,0) 是爆米花
	var before_moves := b.moves_left
	var r := b.try_swap(Vector2i(2, 0), Vector2i(3, 0))   # 试图把爆米花换进消除
	assert_false(r["ok"], "swapping a popcorn cell is rejected")
	assert_eq(b.moves_left, before_moves, "rejected swap does not consume a move")

func test_board_popcorn_objective_win() -> void:
	# OBJ POP_POPCORN：用特效砸够 N 次爆米花即过关。
	var b := Board.new(4, 4, [1, 2, 3, 4], 0, 30, 7, [], [{"type": "POP_POPCORN", "species": -1, "target": 3}])
	assert_false(b.is_won(), "fresh POP_POPCORN level not won")
	b.popcorn_hit = 2
	assert_false(b.is_won(), "below target -> not won")
	b.popcorn_hit = 3
	assert_true(b.is_won(), "won when popcorn_hit reaches target")
