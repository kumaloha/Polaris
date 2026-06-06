extends SceneTree
# shot_ui.gd — 整页截图 + 角色区裁剪放大(看水晶球对齐)。窗口模式。
# 产物 res://_ui_shot.png(整页) + res://_crop_chars.png(角色区放大2x)

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1520))
	var scene: Node = load("res://Level.tscn").instantiate()
	get_root().add_child(scene)
	_run()

func _run() -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	img.save_png("res://_ui_shot.png")
	var crop: Image = img.get_region(Rect2i(0, 150, 720, 430))
	crop.resize(1440, 860)
	crop.save_png("res://_crop_chars.png")
	var skill: Image = img.get_region(Rect2i(0, 1190, 720, 330))
	skill.resize(1440, 660)
	skill.save_png("res://_crop_skill.png")
	var one: Image = img.get_region(Rect2i(20, 1280, 180, 190))
	one.resize(720, 760)
	one.save_png("res://_crop_one.png")
	print("SHOT_SAVED: ui+chars+skill+one")
	quit()
