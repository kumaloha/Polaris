extends SceneTree

# 量金框内窗: 从外缘 flood 标记"外部透明", 剩下的低 alpha = 内部窗口
func _frame(path: String) -> void:
	var tex := load(path) as Texture2D
	var img := tex.get_image()
	var W := img.get_width()
	var H := img.get_height()
	var A := 80.0 / 255.0  # alpha 阈值
	# outside[y*W+x] = true 表示连通到外缘的透明像素
	var outside := {}
	var stack: Array = []
	for x in range(W):
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, H - 1))
	for y in range(H):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(W - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		var k := p.y * W + p.x
		if outside.has(k):
			continue
		if img.get_pixel(p.x, p.y).a >= A:
			continue  # 不透明(金框/钻), 挡住
		outside[k] = true
		if p.x > 0: stack.append(Vector2i(p.x - 1, p.y))
		if p.x < W - 1: stack.append(Vector2i(p.x + 1, p.y))
		if p.y > 0: stack.append(Vector2i(p.x, p.y - 1))
		if p.y < H - 1: stack.append(Vector2i(p.x, p.y + 1))
	# 内部窗口 = 低 alpha 且不在 outside
	var minx := W
	var maxx := -1
	var miny := H
	var maxy := -1
	for y in range(H):
		for x in range(W):
			if img.get_pixel(x, y).a < A and not outside.has(y * W + x):
				if x < minx: minx = x
				if x > maxx: maxx = x
				if y < miny: miny = y
				if y > maxy: maxy = y
	print(path)
	print("  size=%dx%d" % [W, H])
	if maxx < 0:
		print("  NO interior hole found (frame interior may be opaque)")
		return
	var iw := maxx - minx + 1
	var ih := maxy - miny + 1
	print("  interior px: x[%d..%d] y[%d..%d]  w=%d h=%d" % [minx, maxx, miny, maxy, iw, ih])
	print("  UV: u0=%.4f u1=%.4f v0=%.4f v1=%.4f" % [float(minx) / W, float(maxx + 1) / W, float(miny) / H, float(maxy + 1) / H])
	print("  u-center=%.4f v-center=%.4f (0.5=居中)" % [((minx + maxx + 1) * 0.5) / W, ((miny + maxy + 1) * 0.5) / H])
	print("  inner aspect h/w=%.4f  frame aspect h/w=%.4f" % [float(ih) / iw, float(H) / W])

func _init() -> void:
	_frame("res://assets/ui_frames/title_frame.png")
	_frame("res://assets/ui_frames/purple_bg.png")
	quit()
