extends SceneTree
# 重力漂移影响面验证（review Gap1 · 选项0）：
# 老 C++ 管线标定炮关/蛋糕关时用的带墙重力与 GD 真机不同构（C++ 已退役删除）。
# 本脚本用【真机引擎】(core/board.gd + match_engine.gd) 自动玩受影响的 24 关，
# 统计通过率，验证现有 levels.json 这批关在真机下是否可解/难度健康。
# 跑法: godot --headless --path godot -s res://tools/verify_walled_levels.gd -- --runs 60
const Lib := preload("res://core/level_library.gd")
const ME := preload("res://core/match_engine.gd")

const CANNON_LEVELS := [78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89]      # COLLECT_INGREDIENT
const CAKE_LEVELS := [102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113]  # DESTROY_CAKE

func _init() -> void:
	var runs := 40
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--runs" and i + 1 < args.size():
			runs = int(args[i + 1])
	var levels: Array = Lib.load_file("res://levels.json")
	if levels.is_empty():
		push_error("levels.json 加载失败")
		quit(1)
		return
	print("每关局数: %d   策略: ME.best_moves 一步贪心" % runs)
	print("%-5s %-18s %-6s %4s %4s %5s %7s" % ["idx", "objective", "diff", "win", "lose", "stuck", "pass"])
	var t0 := Time.get_ticks_msec()
	var red_flags := []
	for idx in CANNON_LEVELS + CAKE_LEVELS:
		var d: Dictionary = levels[idx]
		var stat := _play_level(d, runs)
		var obj: Dictionary = d.get("objectives", [{}])[0]
		var pass_rate := float(stat.win) / float(runs)
		print("%-5d %-18s %-6s %4d %4d %5d %6.0f%%" % [
			idx, "%s×%d" % [obj.get("type", "?"), int(obj.get("target", 0))],
			d.get("difficulty", "?"), stat.win, stat.lose, stat.stuck, pass_rate * 100.0])
		if stat.win == 0:
			red_flags.append(idx)
	print("耗时 %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if red_flags.is_empty():
		print("RESULT: PASS — 24 关在真机引擎下全部可解(每关至少一局贪心通关)")
	else:
		print("RESULT: RED — 贪心 0 通过的关: %s (需人工复核/重标定)" % str(red_flags))
	quit(0)

func _play_level(d: Dictionary, runs: int) -> Dictionary:
	var win := 0
	var lose := 0
	var stuck := 0
	for r in runs:
		var b = Lib.to_board(d)
		b.rng.seed = hash(str(d.get("idx", 0), ":", r))   # 每局不同补充序列
		var guard := 0
		while not b.is_over() and guard < 200:
			guard += 1
			var mvs: Array = ME.best_moves(b.grid, 1, b._layers(), b.objectives)
			if mvs.is_empty():
				stuck += 1
				break
			var res: Dictionary = b.try_swap(mvs[0][0], mvs[0][1])
			if not res.get("ok", false):
				# 贪心首选被拒(理论不应发生): 当死局计
				stuck += 1
				break
		if b.is_won():
			win += 1
		elif b.is_lost():
			lose += 1
	return {"win": win, "lose": lose, "stuck": stuck}
