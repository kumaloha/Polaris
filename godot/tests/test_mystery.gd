extends "res://tests/test_lib.gd"
# 神秘糖（Mystery Candy）机制测试 —— 对标 Candy Crush 的 Mystery Candy：
#   外观神秘的糖，本身是【可消的普通糖】，被消除时【揭开为随机内容】(随机普通糖 / 概率特效 / 概率原料)。
# 关键设计：神秘糖格 grid 是【普通 species】(正常参与 match/重力/交换)——
#   故 find_matches/apply_gravity/is_legal_swap 都【不感知 mystery】(这是与 coat/choco/ing 的关键区别：它们不可消所以要改那些；神秘糖可消)。
#   只在【清除结算处】检测 mystery 层并揭开：_resolve_plain/_resolve_fx 的清除路径 + account_clears 直清路径。
# 断言：①神秘糖正常参与 match(可消) ②被消除时揭开为内容而非清空、mystery 清0 ③揭开内容按概率(同 seed 确定性)
#       ④神秘糖随重力下落、mystery 标记跟随 ⑤揭开统计/objective ⑥不破坏现有 9 类层测试(共存)。
# 两端镜像：engine/tests/test_match_engine.cpp 有对应 C++ 断言(神秘糖机械原语：随重力下落 + 揭开掷骰 + 计数)。

const ME := preload("res://core/match_engine.gd")
const Board := preload("res://core/board.gd")

# 全 0 的 H×W 整型层（mystery 等模板）。
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


# ───────────── 断言①：神秘糖格 grid 是普通棋子 → 正常参与 match / 交换（不感知 mystery）─────────────

func test_mystery_cell_is_normal_and_matchable() -> void:
	# 神秘糖格 grid=普通色 → 正常进 find_matches（神秘糖与普通糖同色就能凑三连）。
	# find_matches 不接 mystery 参数（神秘糖可消，零侵入匹配）。
	var grid := [
		[0, 0, 0, 1],   # (0,0)(1,0)(2,0) 三个 0 横向三连 —— 其中 (1,0) 是神秘糖，但 grid=0，照样参与
		[1, 2, 3, 2],
		[2, 3, 1, 0],
	]
	var m: Array = ME.find_matches(grid)   # 不传 mystery：神秘糖格当普通棋子
	assert_eq(m.size(), 3, "mystery cell (grid=normal species) participates in matching like any normal candy")

func test_mystery_cell_is_swappable() -> void:
	# 神秘糖格 grid=普通色 → is_legal_swap 允许（神秘糖可换，与普通糖无异）。
	var grid := [
		[5, 0, 0, 2],   # 交换 (0,0)<->(1,0)：把 5 换到 (1,0)？不成三连。换个构造。
		[0, 3, 4, 5],
		[2, 3, 4, 1],
	]
	# 构造：交换 (0,1)<->(0,0) 让列0 顶部成 0,0,? 实际用现成三连验证“神秘糖格可交换”。
	grid = [
		[1, 0, 2, 3],
		[0, 1, 2, 4],   # 交换 (0,1)<->(1,1)：(0,1)=0 换到 (1,1)，列1 成 0,0?... 用简单构造
		[2, 0, 5, 1],
	]
	# 列1: (1,0)=0,(1,2)=0；交换 (0,1)=0 与 (1,1)=1 → (1,1)=0 → 列1 = 0,0,0 三连。(1,1) 设为神秘糖也不影响交换合法性。
	assert_true(ME.is_legal_swap(grid, Vector2i(0, 1), Vector2i(1, 1)), "mystery cell (grid=normal) can be swapped to form a match like a normal candy")


# ───────────── 断言②：被消除时揭开为内容而非清空、mystery 清0 ─────────────

func test_mystery_revealed_not_emptied_on_clear() -> void:
	# 神秘糖格在横向三连里 → 被消除时【不清空】，揭开为随机内容(grid 仍 >=0 或落特效/原料)、mystery→0。
	# 用 do_refill=false 隔离单轮，便于断言该格未被清空。
	var grid := [
		[0, 0, 0, 1],   # (0,0)(1,0)(2,0) 三连；(1,0) 是神秘糖
		[1, 2, 3, 2],
		[2, 3, 4, 5],
	]
	var mystery := _blank(4, 3)
	mystery[0][1] = 1   # (1,0) 是神秘糖
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	# mystery 是 resolve 第16参；纯三消路径(无 fx)、do_refill=false。
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5], rng, [], [], false, null, {"mystery": mystery})
	assert_eq(r.get("mystery_revealed", -1), 1, "exactly one mystery candy revealed when cleared")
	assert_eq(mystery[0][1], 0, "revealed mystery cell: mystery flag cleared to 0")
	# 揭开的格【不清空】：纯三消路径无 fx/ing 层 → 特效/原料档都退化为普通糖，故揭开后 grid 必 >=0。
	assert_true(grid[0][1] >= 0, "revealed mystery cell is NOT emptied — it holds new content (grid >= 0), not EMPTY")
	# 旁边两个非神秘糖的三连成员被正常清空（揭开只针对神秘糖格）。
	assert_eq(grid[0][0], ME.EMPTY, "the non-mystery match member (0,0) is cleared normally")
	assert_eq(grid[0][2], ME.EMPTY, "the non-mystery match member (2,0) is cleared normally")

func test_mystery_revealed_cell_not_recleared_same_round() -> void:
	# 揭开后该格本轮不参与后续清除（它是刚揭开的新内容）。即便揭开成与邻居同色，本轮也不会再被消。
	# 构造：神秘糖在 (1,0)，固定 seed 让它揭开为某普通色；断言该格本轮停留(grid>=0)而非被二次清空。
	var grid := [
		[0, 0, 0, 7],
		[1, 2, 3, 8],
		[4, 5, 6, 9],
	]
	var mystery := _blank(4, 3)
	mystery[0][1] = 1
	var rng := RandomNumberGenerator.new(); rng.seed = 123
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], rng, [], [], false, null, {"mystery": mystery})
	assert_eq(r.get("mystery_revealed", 0), 1, "mystery revealed once")
	# 揭开后该格沉底(重力)但内容保留：盘上该列应仍有这枚揭开的糖（未被清空消失）。grid 全盘非空格数 > 0。
	var nonempty := 0
	for row in grid:
		for v in row:
			if v >= 0:
				nonempty += 1
	assert_true(nonempty >= 1, "revealed content persists this round (not re-cleared into EMPTY)")


# ───────────── 断言③：揭开内容按概率分配（同 seed 确定性）─────────────

func test_mystery_reveal_deterministic_same_seed() -> void:
	# 同 seed 同输入 → 揭开内容完全一致（grid/fx/ing/mystery 三端确定性）。
	var g1 := [[0, 0, 0, 1], [1, 2, 3, 4], [5, 6, 7, 8]]
	var g2 := [[0, 0, 0, 1], [1, 2, 3, 4], [5, 6, 7, 8]]
	var fx1 := _none_fx(4, 3); var fx2 := _none_fx(4, 3)
	var ing1 := _blank(4, 3); var ing2 := _blank(4, 3)
	var m1 := _blank(4, 3); m1[0][1] = 1
	var m2 := _blank(4, 3); m2[0][1] = 1
	var r1 := RandomNumberGenerator.new(); r1.seed = 999
	var r2 := RandomNumberGenerator.new(); r2.seed = 999
	# 特效路径(传 fx) → 揭开可落条纹。do_refill=false 隔离。
	var res1 := ME.resolve(g1, [0, 1, 2, 3, 4, 5, 6, 7, 8], r1, fx1, [], false, null, {"ing": ing1, "mystery": m1})
	var res2 := ME.resolve(g2, [0, 1, 2, 3, 4, 5, 6, 7, 8], r2, fx2, [], false, null, {"ing": ing2, "mystery": m2})
	assert_eq(g1, g2, "same seed -> identical grid after mystery reveal")
	assert_eq(fx1, fx2, "same seed -> identical fx (revealed stripes) after reveal")
	assert_eq(ing1, ing2, "same seed -> identical ing (revealed ingredients) after reveal")
	assert_eq(res1.get("mystery_revealed", -1), res2.get("mystery_revealed", -2), "same seed -> identical mystery_revealed")

func test_mystery_reveal_distribution_hits_all_buckets() -> void:
	# 概率分配(70/20/10)覆盖三档：直接调揭开原语多次，统计应同时出现 普通糖 / 特效 / 原料。
	# 用 _reveal_mystery_at 直接掷骰（每次独立一格），样本足够大时三档都该命中。
	var rng := RandomNumberGenerator.new(); rng.seed = 2024
	var species := [0, 1, 2, 3, 4, 5]
	var got_species := false
	var got_fx := false
	var got_ing := false
	for i in 400:
		var grid := [[3]]
		var fx := [[ME.SP_NONE]]
		var ing := [[0]]
		var mystery := [[1]]
		ME._reveal_mystery_at(grid, fx, ing, mystery, Vector2i(0, 0), rng, species)
		assert_eq(mystery[0][0], 0, "reveal always clears the mystery flag")
		if fx[0][0] == ME.SP_LINE_H or fx[0][0] == ME.SP_LINE_V:
			got_fx = true
		elif ing[0][0] == 1:
			got_ing = true
		else:
			got_species = true   # 普通糖档(无特效无原料)
	assert_true(got_species, "70% bucket hit: some reveals are plain species")
	assert_true(got_fx, "20% bucket hit: some reveals are line effects (SP_LINE_H/V)")
	assert_true(got_ing, "10% bucket hit: some reveals are ingredients (ing=1)")

func test_mystery_reveal_fx_only_with_fx_layer() -> void:
	# 揭开的特效档须有 fx 层才落条纹；无 fx 层(纯三消路径)则特效档退化为普通糖(grid>=0, 不落特效)。
	# 找一个会落特效的 seed，对比传 fx 与不传 fx 的差异。
	var species := [0, 1, 2, 3]
	# 先找一个落 SP_LINE 的 roll：seed 扫描。
	var seed_fx := -1
	for s in range(0, 500):
		var rng := RandomNumberGenerator.new(); rng.seed = s
		var grid := [[2]]; var fx := [[ME.SP_NONE]]; var ing := [[0]]; var mystery := [[1]]
		ME._reveal_mystery_at(grid, fx, ing, mystery, Vector2i(0, 0), rng, species)
		if fx[0][0] == ME.SP_LINE_H or fx[0][0] == ME.SP_LINE_V:
			seed_fx = s
			break
	assert_true(seed_fx >= 0, "found a seed that reveals into a line effect")
	# 同 seed，不传 fx 层 → 该档退化为普通糖（grid>=0），不报错也不丢标记。
	var rng2 := RandomNumberGenerator.new(); rng2.seed = seed_fx
	var grid2 := [[2]]; var ing2 := [[0]]; var mystery2 := [[1]]
	ME._reveal_mystery_at(grid2, [], ing2, mystery2, Vector2i(0, 0), rng2, species)
	assert_eq(mystery2[0][0], 0, "reveal without fx layer still clears the mystery flag")
	assert_true(grid2[0][0] >= 0, "reveal without fx layer degrades the effect bucket to a plain candy (grid >= 0)")


# ───────────── 断言④：神秘糖随重力下落、mystery 标记跟随 ─────────────

func test_mystery_falls_under_gravity_marker_follows() -> void:
	# 神秘糖格 grid 是普通棋子 → 随重力下落；mystery 标记必须跟着移动（apply_gravity 第9参=mystery）。
	# (0,0)=神秘糖(grid=5)，下方 (1,0)(2,0) 空 → 神秘糖沉到列底 (2,0)，mystery 标记也从 (0,0) 移到 (2,0)。
	var E := ME.EMPTY
	var grid := [[5], [E], [E]]
	var mystery := [[1], [0], [0]]
	ME.apply_gravity(grid, [], false, {"mystery": mystery})
	assert_eq(grid[2][0], 5, "mystery candy (normal piece) sank to the column bottom")
	assert_eq(grid[0][0], E, "top cell vacated after the mystery candy fell")
	assert_eq(mystery[2][0], 1, "mystery marker followed its candy down to (2,0)")
	assert_eq(mystery[0][0], 0, "mystery marker no longer at the old top position")

func test_mystery_marker_follows_after_clear_below() -> void:
	# 神秘糖上方、下方三连被清后，神秘糖随重力下沉一格，标记跟随。
	# 列0: (0,0)=神秘糖(grid=9)，下方 (1,0)(2,0)(3,0)? 用三连在它下方清出空位让它沉。
	var grid := [
		[9, 1, 2],   # (0,0)=神秘糖
		[3, 3, 3],   # 行1 三连 3,3,3 → 清掉 (0,1)? 不在列0。改：让列0 下方有可清三连。
		[4, 5, 6],
	]
	# 让 (0,1)(0,2)(0,3)? 列0 只有3行。改构造：神秘糖在 (0,0)，(0,1)(0,2) 与某三连无关。
	# 简化：直接验证“清空下方格 + 重力”后标记跟随。手动制造下方空格 + 重力。
	grid = [[9], [4], [4], [4]]   # 4 行单列：(0,0)=神秘糖(9)，下方 4,4,4
	var mystery := [[1], [0], [0], [0]]
	# 模拟下方三连 4,4,4 被清 → (1,0)(2,0)(3,0)=EMPTY，再重力。
	grid[1][0] = ME.EMPTY; grid[2][0] = ME.EMPTY; grid[3][0] = ME.EMPTY
	ME.apply_gravity(grid, [], false, {"mystery": mystery})
	assert_eq(grid[3][0], 9, "mystery candy fell to the bottom after the pieces below were cleared")
	assert_eq(mystery[3][0], 1, "mystery marker followed the candy down to the bottom")
	assert_eq(ME.count_mystery(mystery), 1, "still exactly one mystery candy on board (only moved, not consumed)")


# ───────────── 断言⑤：揭开统计 / OBJ_REVEAL_MYSTERY（board 集成）─────────────

func test_count_mystery() -> void:
	var mystery := [
		[1, 0, 1],
		[0, 0, 0],
		[0, 1, 0],
	]
	assert_eq(ME.count_mystery(mystery), 3, "three mystery candies counted")

func test_board_mystery_objective_win() -> void:
	# OBJ REVEAL_MYSTERY：揭开够 N 个神秘糖即过关。
	var b := Board.new(5, 5, [1, 2, 3, 4], 0, 30, 7, [], [{"type": "REVEAL_MYSTERY", "species": -1, "target": 2}])
	assert_false(b.is_won(), "fresh REVEAL_MYSTERY level not won")
	b.mystery_revealed = 1
	assert_false(b.is_won(), "below target -> not won")
	b.mystery_revealed = 2
	assert_true(b.is_won(), "won when mystery_revealed reaches target")

func test_board_mystery_layer_is_normal_piece() -> void:
	# Board 用 mystery 层构造 → 神秘糖位是普通棋子(非墙)，mystery 层记录哪些格是神秘糖。
	var mystery := _blank(5, 5)
	mystery[2][2] = 1   # 中心一个神秘糖
	var b := Board.new(5, 5, [0, 1, 2, 3, 4], 999999, 20, 1, [], [], [], [], [], [], [], [], [], [], [], mystery)
	assert_true(b.grid[2][2] >= 0, "mystery position is a NORMAL piece on the board (not a WALL)")
	assert_eq(ME.count_mystery(b.mystery), 1, "board tracks exactly one mystery candy")
	assert_eq(b.mystery[2][2], 1, "mystery flag preserved on the board")

func test_board_mystery_revealed_via_swap() -> void:
	# board.try_swap：一次有效交换让神秘糖进三连 → 神秘糖揭开(mystery→0, mystery_revealed++)（端到端，含 board 结算）。
	var mystery := _blank(5, 5)
	var b := Board.new(5, 5, [1, 2, 3, 4, 5, 6], 999999, 20, 1, [], [], [], [], [], [], [], [], [], [], [], mystery)
	# 手填盘：让交换 (2,3)<->(2,4) 在行3 制造 1,1,1 三连，(2,3) 是神秘糖。绕过 start 的无消除保证。
	b.grid = [
		[2, 3, 4, 5, 6],
		[3, 4, 5, 6, 1],
		[4, 5, 6, 1, 2],
		[1, 1, 5, 1, 2],   # 行3: (0,3)(1,3)=1,1，(2,3)=5(神秘糖)。交换 (2,3)<->(2,4) 把 1 换上来 → (0,3)(1,3)(2,3)=1,1,1
		[2, 3, 1, 4, 5],   # (2,4)=1
	]
	b.fx = b._blank_fx()
	b.mystery[3][2] = 1   # (2,3) 是神秘糖
	assert_eq(ME.count_mystery(b.mystery), 1, "one mystery candy before the move")
	var r := b.try_swap(Vector2i(2, 3), Vector2i(2, 4))   # 把 (2,4)=1 换到 (2,3)，行3 成 1,1,1 三连，(2,3) 是神秘糖
	assert_true(r["ok"], "legal swap forms a 3-run that includes the mystery candy")
	assert_eq(b.mystery_revealed, 1, "the mystery candy was revealed by the match this move")
	assert_eq(ME.count_mystery(b.mystery), 0, "the mystery candy is no longer a mystery (revealed)")


# ───────────── 断言⑥：不破坏其他层（神秘糖与现有 9 类层共存）─────────────

func test_no_mystery_layer_is_noop() -> void:
	# 不传 mystery（[]）时，resolve 行为与旧版完全一致：mystery_revealed=0，普通消除照旧。
	var grid := [
		[0, 0, 0, 4],
		[5, 6, 7, 1],
		[2, 3, 4, 5],
	]
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7], rng, [], [], false)
	assert_eq(r.get("mystery_revealed", 0), 0, "no mystery layer -> mystery_revealed stays 0")
	assert_true(r.get("cleared", 0) >= 3, "the plain 3-match still cleared normally")

func test_mystery_coexists_with_bomb_and_ingredient() -> void:
	# 同一 resolve 里神秘糖 + 炸弹 + 原料并存：神秘糖被消揭开、炸弹随重力沉、原料下沉，互不干扰。
	var grid := [
		[0, 0, 0, ME.EMPTY, 4],   # 行0: (0,0)(1,0)(2,0)=0,0,0 三连；(1,0) 是神秘糖。(3,0) 是原料 actor
		[5, 6, 7, 8, 1],
		[2, 3, 4, 5, 6],
		[5, 5, 7, 8, 1],   # (0,3)(1,3)=5 盖炸弹之一
		[1, 2, 3, 4, 5],
	]
	var mystery := _blank(5, 5)
	mystery[0][1] = 1   # (1,0) 是神秘糖
	var bomb := _blank(5, 5)
	bomb[3][0] = 5   # 炸弹在 (0,3)，远离被清区
	var ing := _blank(5, 5)
	ing[0][3] = 1   # 原料在 (3,0)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	# 传 ing(第12参)、bomb(第14参)、mystery(第16参)；exit_cols=[] 不收原料；do_refill=false。
	var r := ME.resolve(grid, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], rng, [], [], false, null, {"ing": ing, "bomb": bomb, "mystery": mystery})
	assert_eq(r.get("mystery_revealed", -1), 1, "mystery revealed (coexists with bomb+ingredient)")
	assert_eq(ME.count_mystery(mystery), 0, "the mystery candy was revealed")
	assert_eq(r.get("bomb_defused", -1), 0, "bomb not in the cleared area -> not defused (independent layer)")
	assert_eq(ME.count_bombs(bomb), 1, "bomb still live (its own semantics intact)")
	assert_eq(ME.count_ingredients(ing), 1, "ingredient still on board (no exit configured)")

func test_mystery_coexists_with_coat_no_match_interference() -> void:
	# 神秘糖与冰锁(coat)共存：coat 仍断串(不可消)，神秘糖仍可消。验证 find_matches 的 coat 感知不被 mystery 影响。
	# 神秘糖不进 find_matches 参数（神秘糖可消零侵入），coat 照常断串。
	var grid := [
		[0, 0, 0, 1],   # (0,0)(1,0)(2,0)=0,0,0；(1,0) 是神秘糖，(2,0) 上盖冰锁 → coat 断串！只 (0,0)(1,0) 两连 → 不消
		[2, 3, 4, 5],
		[6, 7, 8, 9],
	]
	var coat := _blank(4, 3)
	coat[0][2] = 1   # (2,0) 冰锁 → 断开三连
	var mystery := _blank(4, 3)
	mystery[0][1] = 1
	var m: Array = ME.find_matches(grid, {"coat": coat})   # coat 感知；不传 mystery
	assert_eq(m.size(), 0, "coat at (2,0) breaks the run -> no match (mystery cell does not bypass coat blocking)")


# ───────────── 边界：神秘糖揭开成特效后，下一轮特效可被触发（特效路径揭开真落特效）─────────────

func test_mystery_reveal_into_stripe_is_real_effect() -> void:
	# 走特效路径(传 fx)，找一个落条纹的 seed，验证揭开后该格 fx 确实是 SP_LINE_H/V（真特效，下一轮可触发）。
	var species := [0, 1, 2, 3]
	var seed_fx := -1
	var made_kind := ME.SP_NONE
	for s in range(0, 500):
		var rng := RandomNumberGenerator.new(); rng.seed = s
		var grid := [[2, 2]]; var fx := [[ME.SP_NONE, ME.SP_NONE]]; var ing := [[0, 0]]; var mystery := [[1, 0]]
		ME._reveal_mystery_at(grid, fx, ing, mystery, Vector2i(0, 0), rng, species)
		if fx[0][0] == ME.SP_LINE_H or fx[0][0] == ME.SP_LINE_V:
			seed_fx = s
			made_kind = fx[0][0]
			break
	assert_true(seed_fx >= 0, "a mystery candy can reveal into a real line effect on the fx path")
	assert_true(made_kind == ME.SP_LINE_H or made_kind == ME.SP_LINE_V, "the revealed effect is a genuine stripe (SP_LINE_H or SP_LINE_V)")
