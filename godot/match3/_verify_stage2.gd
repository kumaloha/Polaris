extends SceneTree
# _verify_stage2.gd — 阶段2逻辑验证（headless）。
# 跑法：godot --headless --path godot -s res://match3/_verify_stage2.gd
# 断言每关：① 有合法移动(可玩)；② 能找到合法交换；③ 该合法交换后 find_matches 非空(确实成三连)；
#          ④ 一个明显非法交换(同行相邻但不成连或边角)被 is_legal_swap 拒绝。

const CoreBoard := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")
const LevelConfig := preload("res://match3/level_config.gd")

func _init() -> void:
	var fail: int = 0
	for i in range(LevelConfig.count()):
		var cfg: Dictionary = LevelConfig.get_level(i)
		var ncolors: int = int(cfg.get("colors", 6))
		var sp: Array = []
		for k in range(ncolors):
			sp.append(k)
		var b = CoreBoard.new(cfg["cols"], cfg["rows"], sp, 999999, 999, 12345 + i)

		var has_move: bool = ME.has_legal_move(b.grid)

		# 找首个合法交换，验证交换后确实产生匹配
		var found_legal: bool = false
		var makes_match: bool = false
		for y in range(b.height):
			for x in range(b.width):
				var a := Vector2i(x, y)
				for d in [Vector2i(1, 0), Vector2i(0, 1)]:
					var bb: Vector2i = a + d
					if bb.x < b.width and bb.y < b.height and ME.is_legal_swap(b.grid, a, bb):
						found_legal = true
						ME._swap_cells(b.grid, a, bb)
						makes_match = not ME.find_matches(b.grid).is_empty()
						ME._swap_cells(b.grid, a, bb)  # 还原
						break
				if found_legal:
					break
			if found_legal:
				break

		# 找一个非法交换样本（存在即可）：遍历直到 is_legal_swap=false
		var found_illegal: bool = false
		for y in range(b.height):
			for x in range(b.width):
				var a := Vector2i(x, y)
				var bb := Vector2i(x + 1, y)
				if bb.x < b.width and not ME.is_legal_swap(b.grid, a, bb):
					found_illegal = true
					break
			if found_illegal:
				break

		var ok: bool = has_move and found_legal and makes_match and found_illegal
		if ok:
			print("  ✓ L%d %d×%d  has_move=%s legal_swap=%s makes_match=%s has_illegal=%s"
				% [cfg["id"], b.width, b.height, str(has_move), str(found_legal), str(makes_match), str(found_illegal)])
		else:
			fail += 1
			print("  ✗ L%d %d×%d  has_move=%s legal_swap=%s makes_match=%s has_illegal=%s"
				% [cfg["id"], b.width, b.height, str(has_move), str(found_legal), str(makes_match), str(found_illegal)])

	print("==== 阶段2验证：%d 关，失败 %d ====" % [LevelConfig.count(), fail])
	quit(0 if fail == 0 else 1)
