extends SceneTree
# crop_bg.gd — 裁 _ui_shot 标题框区放大，检查两端紫钻是否变形 + 文字。
func _initialize() -> void:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path("res://_ui_shot.png"))
	var r: Image = img.get_region(Rect2i(80, 4, 560, 94))
	r.resize(1120, 188)
	r.save_png("res://_title_crop.png")
	print("saved _title_crop.png")
	quit()
