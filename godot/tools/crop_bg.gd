extends SceneTree
# crop_bg.gd — 裁剪 bg_scene 中部放大，肉眼定位水晶球真实位置。
func _initialize() -> void:
	var img: Image = load("res://assets/ui/bg_scene.png").get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var rx: int = int(w * 0.30)
	var ry: int = int(h * 0.26)
	var rw: int = int(w * 0.44)
	var rh: int = int(h * 0.42)
	var r: Image = img.get_region(Rect2i(rx, ry, rw, rh))
	r.resize(rw * 2, rh * 2)
	r.save_png("res://_bg_crop.png")
	print("BG_CROP uv x:%.2f-%.2f y:%.2f-%.2f" % [float(rx)/w, float(rx+rw)/w, float(ry)/h, float(ry+rh)/h])
	quit()
