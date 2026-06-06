extends SceneTree
# shot_stage3.gd — 验证阶段3消除/下落/连锁。触发一次合法交换→等连锁跑完→
# 检查 grid 无 EMPTY(下落补满) + 无残留匹配(连锁消完)，并截前后图。

const ME := preload("res://core/match_engine.gd")
var _scene: Node = null

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1520))
	_scene = load("res://Level.tscn").instantiate()
	get_root().add_child(_scene)
	_run()

func _run() -> void:
	await create_timer(0.6).timeout
	await _save("res://_stage3_before.png")
	var ok: bool = _scene.debug_first_legal_swap()
	print("triggered_swap=", ok)
	await create_timer(3.0).timeout
	var board = _scene.board
	var empties: int = 0
	for row in board.grid:
		for v in row:
			if v == ME.EMPTY:
				empties += 1
	var has_match: bool = not ME.find_matches(board.grid).is_empty()
	print("AFTER_CASCADE empties=%d has_match=%s" % [empties, str(has_match)])
	await _save("res://_stage3_after.png")
	quit()

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
