extends SceneTree
# crop_bg.gd — 裁 _ui_shot 棋盘底部两角放大，检查露灰是否消除。
func _initialize() -> void:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path("res://_ui_shot.png"))
	var r: Image = img.get_region(Rect2i(0, 1080, 720, 160))
	r.resize(1440, 320)
	r.save_png("res://_board_bottom.png")
	print("saved _board_bottom.png")
	quit()
