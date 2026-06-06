extends SceneTree
# find_crystal.gd — 在中央台座区扫描水晶球白亮核心，输出精确 UV。
func _initialize() -> void:
	var img: Image = load("res://assets/ui/bg_scene.png").get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var best: float = -9.0
	var bx: int = w / 2
	var by: int = h / 2
	for y in range(int(h * 0.32), int(h * 0.56), 1):
		for x in range(int(w * 0.48), int(w * 0.72), 1):
			var c: Color = img.get_pixel(x, y)
			var mn: float = min(c.r, min(c.g, c.b))
			var score: float = mn * 2.0 + c.v
			if score > best:
				best = score
				bx = x
				by = y
	print("CRYSTAL uv=(%.4f, %.4f) px=(%d,%d) of (%dx%d)" % [float(bx)/float(w), float(by)/float(h), bx, by, w, h])
	quit()
