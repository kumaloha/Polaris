extends SceneTree
# _verify_stage1.gd — 阶段1数据验证（headless 可跑，无需 GPU）。
# 跑法：godot --headless --path godot -s res://match3/_verify_stage1.gd
# 断言：每关尺寸正确、cells 维度吻合、颜色在 [0,colors)、无初始三连；并随机重复压测。

const Board := preload("res://match3/board.gd")
const LevelConfig := preload("res://match3/level_config.gd")

func _init() -> void:
	var fail: int = 0
	var total: int = 0
	for i in range(LevelConfig.count()):
		var cfg: Dictionary = LevelConfig.get_level(i)
		var ncolors: int = int(cfg.get("colors", 6))
		var b := Board.new(cfg["rows"], cfg["cols"], ncolors)
		total += 1
		var errs: Array = []
		if b.rows != cfg["rows"] or b.cols != cfg["cols"]:
			errs.append("尺寸 %d×%d≠%d×%d" % [b.rows, b.cols, cfg["rows"], cfg["cols"]])
		if b.cells.size() != b.rows:
			errs.append("行数不符")
		else:
			for row in b.cells:
				if row.size() != b.cols:
					errs.append("列数不符"); break
		var color_ok: bool = true
		for row in b.cells:
			for v in row:
				if v < 0 or v >= ncolors:
					color_ok = false
		if not color_ok:
			errs.append("颜色越界")
		if b.has_any_match():
			errs.append("存在初始三连!")
		if errs.is_empty():
			print("  ✓ L%d  %d×%d(列×行) colors=%d" % [cfg["id"], b.cols, b.rows, ncolors])
		else:
			fail += 1
			print("  ✗ L%d  %s" % [cfg["id"], ", ".join(errs)])

	# 随机压测：重复生成 9×9，统计含初始三连的次数（应为 0）。
	var reps: int = 300
	var bad: int = 0
	for k in range(reps):
		var b2 := Board.new(9, 9, 6)
		if b2.has_any_match():
			bad += 1
	if bad == 0:
		print("  ✓ 随机压测 %d 次 9×9：0 次初始三连" % reps)
	else:
		fail += 1
		print("  ✗ 随机压测 %d 次：%d 次出现初始三连" % [reps, bad])

	print("==== 阶段1验证：%d 关检查，失败 %d ====" % [total, fail])
	quit(0 if fail == 0 else 1)
