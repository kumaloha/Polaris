extends "res://tests/test_lib.gd"
# 彩球(SP_COLORBOMB)组合精度测试 —— 对标 Candy Crush 的"彩球+特效"满屏连锁。
# 增强点(在 match_engine.gd 的 colorbomb_clear_plan/colorbomb_clear_set + board.gd 的 _activate_colorbomb)：
#   ① 彩球+条纹(SP_LINE_H/V)：全盘该色【先全部变条纹糖再一起引爆】，每个清整行/列 → 清除量远多于该色原始格数。
#   ② 彩球+包装(SP_BOMB)：全盘该色【先变包装糖再引爆】，每个 3x3 连锁。
#   ③ 彩球+普通棋子：清掉该色(行为不退)。
#   ④ 双彩球：清全盘(行为不退)。
#   ⑤ 确定性：同 seed 同输入 → 结果一致。
#   ⑥ 不破坏现有 choco/ing/bomb/coat 路径(本文件只新增正向覆盖，既有测试在各自文件保持绿)。
# 彩球不再触发彩球(避免自激/递归)——既有代码已处理，本文件 ④ 间接覆盖。
# 注：特效仅 Godot 侧实现(Core C++ 不实现特效，已在 match_engine 注释声明)，故无 C++ 镜像测试。

const ME := preload("res://core/match_engine.gd")
const Board := preload("res://core/board.gd")

# 全 SP_NONE 的 H×W 特效层。
func _none_fx(w: int, h: int) -> Array:
	var f := []
	for y in h:
		var row := []
		for x in w:
			row.append(ME.SP_NONE)
		f.append(row)
	return f

# 数某 species 在 grid 上的格数。
func _count_species(grid: Array, sp: int) -> int:
	var n := 0
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] == sp:
				n += 1
	return n


# ───────────── 断言①：彩球 + 条纹 → 全盘该色变条纹引爆，清除量远多于该色原始格数 ─────────────

func test_colorbomb_plus_stripe_converts_and_detonates() -> void:
	# 6×6 盘，目标色=1 散落 3 处(不同行)。彩球在 (0,0)，partner=条纹(在 (1,0))、partner 的 species=1。
	# 每个 1-格染成条纹后清整行/列 → 清除格数远超 3(原始 1-格数)。
	var grid := [
		[7, 1, 2, 3, 4, 5],  # (1,0)=1 ← partner(条纹)；行0
		[2, 3, 4, 5, 6, 7],
		[3, 4, 1, 6, 7, 2],  # (2,2)=1；行2
		[4, 5, 6, 7, 2, 3],
		[5, 6, 7, 2, 1, 4],  # (4,4)=1；行4
		[6, 7, 2, 3, 4, 5],
	]
	var fx := _none_fx(6, 6)
	fx[0][0] = ME.SP_COLORBOMB   # 彩球
	fx[0][1] = ME.SP_LINE_H      # partner：横向条纹（kind 不决定方向，引爆时按 override 行号定向）
	var color_count := _count_species(grid, 1)
	assert_eq(color_count, 3, "exactly three 1-cells on the board (seed)")
	var cells: Array = ME.colorbomb_clear_set(grid, fx, Vector2i(0, 0), Vector2i(1, 0))
	var n := cells.size()
	# 三个 1-格分别在行0/行2/行4：偶数行 → 染清行(LINE_H)，各清一整行(6 格)。
	# 三整行(行0/2/4)共 18 格(去重，三行不相交) → 清除量远多于 3。
	assert_true(n > color_count, "cleared cells (%d) FAR exceed the 3 original color cells (chain via stripes)" % n)
	assert_true(n >= 18, "three even-row 1-cells each clear a full row of 6 -> >=18 cells, got %d" % n)
	# 全盘该色都应被卷入清除（彩球+条纹的本质：先全染该色）。
	assert_true(cells.has(Vector2i(1, 0)) and cells.has(Vector2i(2, 2)) and cells.has(Vector2i(4, 4)), "every 1-cell is part of the blast")
	assert_true(cells.has(Vector2i(0, 0)), "colorbomb itself consumed")

func test_colorbomb_plus_stripe_clears_full_rows_and_cols() -> void:
	# 验证"条纹方向按行号交替"：偶数行的该色格清整行、奇数行的该色格清整列。
	# 目标色=1：放 (0,0)=行0(偶→清行)、(0,1)=行1(奇→清列)。彩球放 (3,3)，partner 条纹放 (4,3) species=1? 不行——
	# partner 自身格必须是该色。改：彩球 (5,5)，partner=(4,5)=1。
	var grid := [
		[1, 2, 3, 4, 5, 6],  # (0,0)=1 行0(偶) → 清整行0
		[1, 3, 4, 5, 6, 7],  # (0,1)=1 行1(奇) → 清整列0
		[2, 3, 4, 5, 6, 7],
		[3, 4, 5, 6, 7, 2],
		[4, 5, 6, 7, 2, 1],  # (5,4)=1 行4(偶) → 清整行4
		[5, 6, 7, 2, 3, 1],  # (5,5)=彩球；(4,5)? 用 (5,5) 彩球、partner 取相邻同色
	]
	# partner 必须是该色格：取 (0,1)=1 当 partner，彩球放任意。简化：彩球 (3,0)，partner (0,1)? 不相邻无所谓——
	# colorbomb_clear_set 是纯函数，cb_pos/partner_pos 只用于取色与排除，不校验相邻(相邻校验在 board.try_swap)。
	var fx := _none_fx(6, 6)
	fx[0][3] = ME.SP_COLORBOMB   # 彩球(放在非 1 格 (3,0))
	fx[1][0] = ME.SP_LINE_V      # partner=条纹，落在 (0,1)=1
	var cells: Array = ME.colorbomb_clear_set(grid, fx, Vector2i(3, 0), Vector2i(0, 1))
	var s := {}
	for c in cells:
		s[c] = true
	# (0,0) 在行0(偶) → 清整行0：(0,0)..(5,0) 都在
	for x in 6:
		assert_true(s.has(Vector2i(x, 0)), "even-row 1-cell cleared full row 0 at x=%d" % x)
	# (0,1) 在行1(奇) → 清整列0：(0,0)..(0,5) 都在
	for y in 6:
		assert_true(s.has(Vector2i(0, y)), "odd-row 1-cell cleared full column 0 at y=%d" % y)
	# (5,4) 在行4(偶) → 清整行4
	for x in 6:
		assert_true(s.has(Vector2i(x, 4)), "even-row 1-cell cleared full row 4 at x=%d" % x)


# ───────────── 断言②：彩球 + 包装(SP_BOMB) → 全盘该色变包装引爆(3x3 连锁) ─────────────

func test_colorbomb_plus_bomb_converts_to_3x3() -> void:
	# 目标色=1 放在盘中央 (2,2)，四周非 1。彩球+包装 → (2,2) 染成包装 → 清以它为心的 3x3。
	var grid := [
		[5, 6, 7, 2, 3],
		[6, 7, 2, 3, 4],
		[7, 2, 1, 4, 5],  # (2,2)=1 唯一该色
		[2, 3, 4, 5, 6],
		[3, 4, 5, 6, 7],
	]
	var fx := _none_fx(5, 5)
	fx[0][0] = ME.SP_COLORBOMB
	fx[1][0] = ME.SP_BOMB      # partner=包装，落在 (0,1)；species=grid[1][0]=6? 不——partner 自身格取色。
	# partner_pos=(0,1)，grid[1][0]=6 → 目标色会是 6 不是 1。修正：把 partner 放到一个 1-格旁不行，partner 必须是 1 格。
	# 让 partner 直接落在 (2,2)=1：
	fx[1][0] = ME.SP_NONE
	fx[2][2] = ME.SP_BOMB
	var cells: Array = ME.colorbomb_clear_set(grid, fx, Vector2i(0, 0), Vector2i(2, 2))
	var s := {}
	for c in cells:
		s[c] = true
	# (2,2) 染成包装 → 3x3 = x∈[1,3], y∈[1,3] 共 9 格全清。
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			assert_true(s.has(Vector2i(2 + dx, 2 + dy)), "3x3 around the converted bomb includes (%d,%d)" % [2 + dx, 2 + dy])
	assert_true(cells.has(Vector2i(0, 0)), "colorbomb itself consumed")

func test_colorbomb_plus_bomb_chains_multiple() -> void:
	# 多个该色格各自染包装 → 多个 3x3 连锁，清除量远多于该色原始格数。
	# 目标色=1 放 (1,1) 与 (5,5)(相距远，两 3x3 不重叠)。
	var grid := [
		[2, 3, 4, 5, 6, 7, 2],
		[3, 1, 5, 6, 7, 2, 3],  # (1,1)=1
		[4, 5, 6, 7, 2, 3, 4],
		[5, 6, 7, 2, 3, 4, 5],
		[6, 7, 2, 3, 4, 5, 6],
		[7, 2, 3, 4, 5, 1, 7],  # (5,5)=1
		[2, 3, 4, 5, 6, 7, 2],
	]
	var fx := _none_fx(7, 7)
	fx[0][0] = ME.SP_COLORBOMB
	fx[1][1] = ME.SP_BOMB   # partner 落在 (1,1)=1（该色之一）
	var color_count := _count_species(grid, 1)
	assert_eq(color_count, 2, "two 1-cells on the board")
	var cells: Array = ME.colorbomb_clear_set(grid, fx, Vector2i(0, 0), Vector2i(1, 1))
	var n := cells.size()
	# 两个 1-格各染包装 → 两个不相交 3x3 = 18 格，远多于 2。
	assert_true(n > color_count, "bomb-chain cleared %d cells >> 2 original color cells" % n)
	assert_true(n >= 18, "two 3x3 blasts (non-overlapping) -> >=18 cells, got %d" % n)

func test_colorbomb_plan_marks_virtual_bombs_for_bounded_visuals() -> void:
	# 彩球+包装会把全盘目标色都临时视为包装糖。清除集合已能体现 3x3，
	# 表现层也需要知道哪些格是"虚拟包装爆点"，否则只会播普通三帧消除。
	var grid := [
		[2, 3, 4, 5, 6, 7, 2],
		[3, 1, 5, 6, 7, 2, 3],  # partner 包装，目标色=1
		[4, 5, 6, 7, 2, 3, 4],
		[5, 6, 7, 2, 3, 4, 5],
		[6, 7, 2, 3, 4, 5, 6],
		[7, 2, 3, 4, 5, 1, 7],  # 这个 1 应作为虚拟包装爆点，播 3x3 有界动画
		[2, 3, 4, 5, 6, 7, 2],
	]
	var fx := _none_fx(7, 7)
	fx[0][0] = ME.SP_COLORBOMB
	fx[1][1] = ME.SP_BOMB
	var plan: Dictionary = ME.colorbomb_clear_plan(grid, fx, Vector2i(0, 0), Vector2i(1, 1))
	var override: Dictionary = plan["override"]
	assert_eq(override.get(Vector2i(5, 5), ME.SP_NONE), ME.SP_BOMB, "other target-color cells are virtual 3x3 bombs")
	assert_eq(override.get(Vector2i(1, 1), ME.SP_NONE), ME.SP_BOMB, "the real partner bomb is explicitly represented for the conversion/visual path")


func test_colorbomb_plus_bomb_overrides_target_color_line_specials_to_bombs() -> void:
	# 玩家视角：5 合 1 吃十字 4 合 1时，全盘目标色都应该新生成十字炸。
	# 即使某些目标色格原本带横/竖 4 合 1，也不能在本次"新生成"阶段回落成横/竖炸。
	var grid := [
		[2, 3, 4, 5, 6, 7],
		[3, 1, 5, 6, 7, 2],  # partner 十字，目标色=1
		[4, 5, 1, 7, 2, 3],  # 目标色上原本有横炸
		[5, 6, 7, 1, 3, 4],  # 目标色上原本有竖炸
		[6, 7, 2, 3, 1, 5],  # 普通目标色
		[7, 2, 3, 4, 5, 6],
	]
	var fx := _none_fx(6, 6)
	fx[0][0] = ME.SP_COLORBOMB
	fx[1][1] = ME.SP_BOMB
	fx[2][2] = ME.SP_LINE_H
	fx[3][3] = ME.SP_LINE_V
	var plan: Dictionary = ME.colorbomb_clear_plan(grid, fx, Vector2i(0, 0), Vector2i(1, 1))
	var override: Dictionary = plan["override"]
	for p in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)]:
		assert_eq(override.get(p, ME.SP_NONE), ME.SP_BOMB, "target-color cell %s should convert to a cross/bomb special" % str(p))
	for p in override:
		assert_false(int(override[p]) == ME.SP_LINE_H or int(override[p]) == ME.SP_LINE_V, "colorbomb+bomb must not generate horizontal/vertical virtual specials")


func test_colorbomb_plus_special_uses_endgame_special_blast_visual_path() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var resolve_start: int = src.find("func _resolve_colorbomb")
	var resolve_end: int = src.find("func _colorbomb_absorb_preview_targets", resolve_start)
	assert_true(resolve_start >= 0 and resolve_end > resolve_start, "_resolve_colorbomb can be inspected")
	if resolve_start < 0 or resolve_end <= resolve_start:
		return
	var resolve_body: String = src.substr(resolve_start, resolve_end - resolve_start)
	assert_true(resolve_body.contains("await _play_colorbomb_combo_blast(cells, to_clear, virtual_fx)"), "5+4 colorbomb combo delegates the post-conversion blast to the shared special-blast helper")
	assert_false(resolve_body.contains("if vk != ME.SP_NONE:\n\t\t\tboard_view.play_special_fx"), "5+4 colorbomb combo must not use the old manual per-cell special FX path")
	var helper_start: int = src.find("func _play_colorbomb_combo_blast")
	var helper_end: int = src.find("func _apply_colorbomb_virtual_fx_for_blast", helper_start)
	assert_true(helper_start >= 0 and helper_end > helper_start, "_play_colorbomb_combo_blast can be inspected")
	if helper_start < 0 or helper_end <= helper_start:
		return
	var helper_body: String = src.substr(helper_start, helper_end - helper_start)
	# 钉源码理由：5合1吃4合1转化后应和结算奖励的 4合1 自动爆裂一样，走 board_view.play_clear + special timing，
	# 而不是自己手写 play_special_fx/shatter/elimination，避免同一种“满屏4合1爆裂”出现两种观感。
	assert_true(helper_body.contains("_special_fx_cells_for_clear_visuals(cells, virtual_fx)"), "5+4 blast feeds virtual specials into the shared special-clear visual map")
	assert_true(helper_body.contains("_clear_visual_timing_for_triggers(virtual_fx.keys(), virtual_fx)"), "5+4 blast uses the same trigger timing model as special-blast chains")
	assert_true(helper_body.contains("await board_view.play_clear(to_clear, [], {}, raw_special_fx_cells, clear_visual_timing)"), "5+4 blast uses board_view.play_clear just like the endgame special-blast path")


# ───────────── 断言③：彩球 + 普通棋子 → 清掉该色(行为不退) ─────────────

func test_colorbomb_plus_plain_clears_color_only() -> void:
	# partner 是普通棋子(无特效) → 退回原行为：清该色全部 + 彩球 + partner，无连锁放大。
	# 复刻既有 test_colorbomb_clear_set_targets_partner_species 的盘，确保行为完全一致。
	var grid := [
		[0, 1, 2, 3],
		[1, 0, 3, 2],
		[8, 1, 2, 3],  # (0,2)=彩球；partner=(0,1)，species=grid[1][0]=1
		[4, 1, 2, 3],
	]
	var fx := _none_fx(4, 4)
	fx[2][0] = ME.SP_COLORBOMB   # partner (0,1) 是普通棋子，无特效
	var cells: Array = ME.colorbomb_clear_set(grid, fx, Vector2i(0, 2), Vector2i(0, 1))
	# 1 在 (1,0),(0,1),(1,2),(1,3) 共 4 个 + 彩球 (0,2) = 5（与原行为一致，无放大）
	assert_eq(cells.size(), 5, "plain partner -> only the 4 color cells + colorbomb (no chain blowup)")
	assert_true(cells.has(Vector2i(0, 2)), "colorbomb consumed")
	assert_true(cells.has(Vector2i(1, 0)) and cells.has(Vector2i(0, 1)) and cells.has(Vector2i(1, 2)) and cells.has(Vector2i(1, 3)), "all four 1-cells")


# ───────────── 断言④：双彩球 → 清全盘(行为不退) ─────────────

func test_double_colorbomb_clears_whole_board() -> void:
	# 两个彩球交换 → 清全盘非空(排除墙)。验证行为不退、且彩球不触发彩球(不死循环)。
	var grid := [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	]
	var fx := _none_fx(4, 4)
	fx[0][0] = ME.SP_COLORBOMB
	fx[3][3] = ME.SP_COLORBOMB
	var cells: Array = ME.colorbomb_clear_set(grid, fx, Vector2i(0, 0), Vector2i(3, 3))
	assert_eq(cells.size(), 16, "double colorbomb clears the entire 4x4 board (16 non-empty cells)")

func test_double_colorbomb_still_spares_wall() -> void:
	# 双彩球清全盘也必须排除墙（既有 test_double_colorbomb_spares_wall 的语义，本文件再守一道）。
	var grid := [
		[0, 1, 2],
		[1, ME.WALL, 0],
		[2, 0, 1],
	]
	var fx := [
		[ME.SP_COLORBOMB, ME.SP_NONE, ME.SP_NONE],
		[ME.SP_NONE, ME.SP_NONE, ME.SP_NONE],
		[ME.SP_NONE, ME.SP_NONE, ME.SP_COLORBOMB],
	]
	var cells: Array = ME.colorbomb_clear_set(grid, fx, Vector2i(0, 0), Vector2i(2, 2))
	assert_false(cells.has(Vector2i(1, 1)), "double colorbomb must NOT clear the wall")
	assert_eq(cells.size(), 8, "all 8 non-wall cells cleared")


# ───────────── 断言⑤：确定性 —— 同 seed 同输入结果一致 ─────────────

func test_colorbomb_stripe_deterministic() -> void:
	# colorbomb_clear_set 是纯函数：同输入 → 同输出（cells 集合一致）。
	var g1 := _det_grid()
	var g2 := _det_grid()
	var fx1 := _none_fx(6, 6); fx1[0][0] = ME.SP_COLORBOMB; fx1[2][2] = ME.SP_LINE_H
	var fx2 := _none_fx(6, 6); fx2[0][0] = ME.SP_COLORBOMB; fx2[2][2] = ME.SP_LINE_H
	var c1: Array = ME.colorbomb_clear_set(g1, fx1, Vector2i(0, 0), Vector2i(2, 2))
	var c2: Array = ME.colorbomb_clear_set(g2, fx2, Vector2i(0, 0), Vector2i(2, 2))
	var s1 := {}
	for c in c1:
		s1[c] = true
	var s2 := {}
	for c in c2:
		s2[c] = true
	assert_eq(c1.size(), c2.size(), "same input -> same number of cleared cells")
	assert_eq(s1, s2, "same input -> identical cleared cell set")

func test_colorbomb_board_deterministic_same_seed() -> void:
	# board 集成层确定性：同 seed 两局，彩球+条纹引爆后 grid/score 完全一致。
	var b1 := _det_board()
	var b2 := _det_board()
	var r1 := b1.try_swap(Vector2i(2, 2), Vector2i(2, 1))   # 彩球(2,2) 与上方交换引爆
	var r2 := b2.try_swap(Vector2i(2, 2), Vector2i(2, 1))
	assert_true(r1.get("ok", false) and r1.get("colorbomb", false), "colorbomb swap detonated (run 1)")
	assert_true(r2.get("ok", false) and r2.get("colorbomb", false), "colorbomb swap detonated (run 2)")
	assert_eq(b1.grid, b2.grid, "same seed -> identical grid after colorbomb+stripe")
	assert_eq(b1.score, b2.score, "same seed -> identical score")
	assert_eq(b1.fx, b2.fx, "same seed -> identical fx layer")

func _det_grid() -> Array:
	return [
		[7, 1, 2, 3, 4, 5],
		[2, 3, 4, 5, 6, 7],
		[3, 4, 1, 6, 7, 2],
		[4, 5, 6, 7, 2, 3],
		[5, 6, 7, 2, 1, 4],
		[6, 7, 2, 3, 4, 5],
	]

func _det_board() -> Board:
	var b := Board.new(6, 6, [1, 2, 3, 4, 5, 6, 7], 999999, 20, 4242)
	b.grid = _det_grid()
	b.fx = b._blank_fx()
	b.fx[2][2] = ME.SP_COLORBOMB   # 彩球在 (2,2)
	b.fx[1][2] = ME.SP_LINE_V      # 上方 (2,1) 是条纹 partner，species=grid[1][2]=4
	return b


# ───────────── 断言①(board 集成)：彩球+条纹真的清掉远多于该色原始格数 ─────────────

func test_colorbomb_stripe_board_clears_many() -> void:
	# board 层端到端：彩球+条纹引爆后，盘上目标色应被清空，且本步清除推动了分数(连锁放大)。
	# 目标色=4：彩球(2,2) 换上方 (2,1)=条纹(species 4) → 全盘 4 染条纹引爆。
	var b := Board.new(6, 6, [1, 2, 3, 4, 5, 6, 7], 999999, 20, 4242)
	b.grid = [
		[7, 1, 2, 3, 4, 5],  # 4 在 (4,0)
		[2, 3, 4, 6, 5, 7],  # (2,1)=4 ← partner 条纹；4 在 (2,1)
		[3, 1, 4, 6, 7, 2],  # (2,2)=4? 不——(2,2) 要放彩球。改 grid[2][2] 为彩球占位
		[5, 6, 7, 2, 1, 3],
		[1, 6, 7, 2, 5, 4],  # 4 在 (5,4)
		[6, 7, 2, 3, 1, 5],
	]
	# (2,2) 占位彩球(它本是某色，引爆时被消)。确保 (2,2) 不是 4 以免自计；设为 0 不在 species? species 无 0——
	# 用 species 内的值即可：把 (2,2) 当作普通 3。
	b.grid[2][2] = 3
	b.fx = b._blank_fx()
	b.fx[2][2] = ME.SP_COLORBOMB
	b.fx[1][2] = ME.SP_LINE_V   # partner 条纹落 (2,1)=4
	var before_4 := _count_species(b.grid, 4)
	assert_true(before_4 >= 2, "at least two 4-cells before blast (seed has 4 at (2,1),(4,0),(5,4))")
	var sc_before := b.score
	var r := b.try_swap(Vector2i(2, 2), Vector2i(2, 1))
	assert_true(r.get("ok", false), "colorbomb+stripe swap is legal and resolves")
	assert_true(b.score > sc_before, "score increased from the chained blast")
	# 引爆后盘面已结算 + 补充(普通关)，但本步必然清掉了多行(条纹) → 分数增量显著。
	# 直接断言"远多于该色原始格数"用纯函数测(上面已覆盖)；此处守 board 端到端不退化即可。
	assert_false(b.is_over(), "game continues after the blast (huge score, no objective)")
