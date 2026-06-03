extends SceneTree
# headless 测试运行器。运行：
#   godot --headless --path godot -s res://tests/runner.gd
# 退出码：0 全过 / 1 有失败。

func _initialize() -> void:
	var suites := [
		preload("res://tests/test_match_engine.gd").new(),
		preload("res://tests/test_board.gd").new(),
	]
	var total := 0
	var failed := 0
	for suite in suites:
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
