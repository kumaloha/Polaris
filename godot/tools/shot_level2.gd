extends SceneTree
# shot_level2.gd — 阶段2截图（窗口模式）。用实际时间计时(create_timer)，避免离屏帧率不稳。
#   res://_stage2_before.png  开局盘(core 生成)
#   res://_stage2_after.png   执行一次合法交换后(三连高亮)
# 跑法：godot --path godot -s res://tools/shot_level2.gd

var _scene: Node = null

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1520))
	_scene = load("res://Level.tscn").instantiate()
	get_root().add_child(_scene)
	_run()

func _run() -> void:
	await create_timer(0.4).timeout
	await _save("res://_stage2_before.png")
	var ok: bool = _scene.debug_first_legal_swap()
	print("debug_first_legal_swap=", ok)
	await create_timer(1.2).timeout  # 等交换(0.14s)+高亮脉冲(实际时间)
	await _save("res://_stage2_after.png")
	quit()

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	img.save_png(path)
	print("SHOT_SAVED:", path)
