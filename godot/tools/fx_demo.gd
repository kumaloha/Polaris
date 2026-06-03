extends SceneTree
# 特效渲染演示截图：贪心走几步得到真实盘面，再在顶行摆全 4 种特效标记，截图。
# 运行：godot --path godot -s res://tools/fx_demo.gd  → res://_shot_fx.png

const ME := preload("res://core/match_engine.gd")

var _frames := 0
var _game: Node

func _initialize() -> void:
	_game = load("res://main.tscn").instantiate()
	get_root().add_child(_game)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		var b = _game.board
		for _i in 15:
			if b.is_over():
				break
			var mv := _first_legal(b.grid)
			if mv.is_empty():
				break
			b.try_swap(mv[0], mv[1])
		# 顶行强制摆一排，确保 4 种特效标记都可见（图例）
		b.fx[0][0] = ME.SP_LINE_H
		b.fx[0][1] = ME.SP_LINE_V
		b.fx[0][2] = ME.SP_BOMB
		b.fx[0][3] = ME.SP_COLORBOMB
		_game._render()
	if _frames == 9:
		var img := get_root().get_texture().get_image()
		if img != null:
			img.save_png("res://_shot_fx.png")
			print("saved res://_shot_fx.png  score=", _game.board.score)
		quit()
	return false

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
