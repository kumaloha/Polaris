extends SceneTree
# 裁 _ui_shot.png 顶部(标题+目标区)放大, 看横幅移除后的效果
func _init() -> void:
	var img := Image.load_from_file("res://_ui_shot.png")
	var crop := img.get_region(Rect2i(30, 0, 660, 340))
	crop.resize(1320, 680)
	crop.save_png("res://_top_crop.png")
	print("TOP_SAVED")
	quit()
