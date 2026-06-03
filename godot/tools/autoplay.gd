extends SceneTree
# headless 自动对局：贪心选第一个合法交换，跑完整局。
# 验证端到端循环（Board+引擎），也是 09 "贪心求解器" 的雏形。
# 运行：godot --headless --path godot -s res://tools/autoplay.gd

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")

func _initialize() -> void:
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 2000, 25, 12345)
	print("开局: 目标=%d 步数=%d" % [b.target_score, b.moves_left])
	var turn := 0
	while not b.is_over():
		var mv := _first_legal(b.grid)
		if mv.is_empty():
			print("  !! 无合法步（应已洗牌），中断"); break
		var r: Dictionary = b.try_swap(mv[0], mv[1])
		turn += 1
		if turn % 5 == 0:
			print("  第%2d步: +%4d → 总分=%5d 剩余步=%2d (连锁%d)" % [turn, r["gained"], b.score, b.moves_left, r["cascades"]])
	print("结果: 过关=%s 失败=%s 终分=%d 用了%d步" % [b.is_won(), b.is_lost(), b.score, turn])
	quit()

func _first_legal(grid: Array) -> Array:
	var h := grid.size()
	var w: int = grid[0].size()
	for y in h:
		for x in w:
			if x + 1 < w and ME.is_legal_swap(grid, Vector2i(x, y), Vector2i(x + 1, y)):
				return [Vector2i(x, y), Vector2i(x + 1, y)]
			if y + 1 < h and ME.is_legal_swap(grid, Vector2i(x, y), Vector2i(x, y + 1)):
				return [Vector2i(x, y), Vector2i(x, y + 1)]
	return []
