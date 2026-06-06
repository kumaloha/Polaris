extends SceneTree
# 真渲染截图工具（需真渲染，不能 --headless）。
#   PLAY_MOVES=0  → 截开局盘面，存 res://_shot.png
#   PLAY_MOVES>0  → 先贪心走若干步再截，存 res://_shot_played.png
# 运行：godot --path godot -s res://tools/screenshot.gd

const ME := preload("res://core/match_engine.gd")
const GameScript := preload("res://view/game.gd")
const PLAY_MOVES := 12

var _frames := 0
var _game: Node

func _initialize() -> void:
	_game = Node2D.new()
	_game.set_script(GameScript)
	get_root().add_child(_game)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3 and PLAY_MOVES > 0:
		var b = _game.board
		for _i in PLAY_MOVES:
			if b.is_over():
				break
			var mv := _first_legal(b.grid)
			if mv.is_empty():
				break
			b.try_swap(mv[0], mv[1])
		if b.fx.size() >= 4 and b.fx[0].size() >= 4:
			b.fx[1][1] = ME.SP_LINE_H
			b.fx[1][2] = ME.SP_LINE_V
			b.fx[1][3] = ME.SP_BOMB
		_game._render()
	if _frames == 9:
		var img := get_root().get_texture().get_image()
		var path := "res://_shot_played.png" if PLAY_MOVES > 0 else "res://_shot.png"
		if img != null:
			img.save_png(path)
			print("saved ", path, "  score=", _game.board.score, " moves=", _game.board.moves_left)
		else:
			print("no image (renderer unavailable)")
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
