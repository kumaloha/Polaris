extends SceneTree
# headless 测试运行器。运行：
#   godot --headless --path godot -s res://tests/runner.gd
# 退出码：0 全过 / 1 有失败。

func _initialize() -> void:
	var suites := [
		preload("res://tests/test_match_engine.gd").new(),
		preload("res://tests/test_board.gd").new(),
		preload("res://tests/test_ui_assets.gd").new(),
		preload("res://tests/test_effect_manager.gd").new(),
		preload("res://tests/test_level_visuals.gd").new(),
		preload("res://tests/test_level_clear.gd").new(),
		preload("res://tests/test_level_collapse.gd").new(),
		preload("res://tests/test_board_view.gd").new(),
		preload("res://tests/test_time_rabbit.gd").new(),
		preload("res://tests/test_hud.gd").new(),
		preload("res://tests/test_skills.gd").new(),
		preload("res://tests/test_raccoon_miner.gd").new(),
		preload("res://tests/test_dragon_breath.gd").new(),
		preload("res://tests/test_overlays.gd").new(),
		preload("res://tests/test_session.gd").new(),
		preload("res://tests/test_level_motion.gd").new(),
		preload("res://tests/test_meta.gd").new(),
		preload("res://tests/test_chocolate.gd").new(),
		preload("res://tests/test_ingredient.gd").new(),
		preload("res://tests/test_bomb.gd").new(),
		preload("res://tests/test_colorbomb.gd").new(),
		preload("res://tests/test_cannon.gd").new(),
		preload("res://tests/test_popcorn.gd").new(),
		preload("res://tests/test_cake.gd").new(),
		preload("res://tests/test_mystery.gd").new(),
		preload("res://tests/test_mechanism_icons.gd").new(),
	]
	# --only <子串>: 只跑脚本路径含该子串的 suite(调试用)。如:
	#   godot --headless --path godot -s res://tests/runner.gd -- --only test_hud
	var only := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--only" and i + 1 < args.size():
			only = String(args[i + 1])
	var total := 0
	var failed := 0
	for suite in suites:
		if only != "" and not String(suite.get_script().resource_path).contains(only):
			continue
		print("SUITE ", suite.get_script().resource_path)
		for m in suite.get_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			total += 1
			suite.failures = []
			suite.call(mname)
			if suite.failures.is_empty():
				print("PASS  ", mname)
			else:
				failed += 1
				print("FAIL  ", mname)
				for f in suite.failures:
					print("        ", f)
	print("")
	print("Total: %d   Failed: %d" % [total, failed])
	quit(1 if failed > 0 else 0)
