extends SceneTree
## overlay_demo.gd — 构造含 jelly/bomb 层的小盘，实例化渲染器铺在格上，截图供评审。
## 运行:
##   godot --headless --path godot -s res://tools/overlay_demo.gd
## 截图输出: res://_overlay_demo.png

const Board            := preload("res://core/board.gd")
const OverlayRegistry  := preload("res://match3/overlays/overlay_registry.gd")

const CELL_PX  := 64.0
const GRID_W   := 4
const GRID_H   := 4
const MARGIN   := 20.0

# 复制自 jelly_overlay / bomb_overlay 常量（避免跨脚本静态访问问题）
const JELLY_COLOR_2   := Color(0.18, 0.52, 0.90, 0.55)
const JELLY_COLOR_1   := Color(0.42, 0.72, 0.98, 0.30)
const BOMB_BODY_COLOR := Color(0.12, 0.10, 0.10, 0.90)
const BOMB_DANGER_THRESHOLD := 3

func _initialize() -> void:
	# 构造最小盘面
	var board := Board.new(GRID_W, GRID_H, [0, 1, 2, 3, 4], 0, 30, 1)
	board.grid = [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	]
	board.fx   = board._blank_fx()
	board.jelly = board._blank_fx()
	board.bomb  = board._blank_fx()
	# jelly: 第0行全层=2, 第1行全层=1
	for x in GRID_W:
		board.jelly[0][x] = 2
		board.jelly[1][x] = 1
	# bomb: 第3行放两个炸弹, 倒计时 5 和 2
	board.bomb[3][0] = 5
	board.bomb[3][3] = 2

	# 根节点（headless，节点不渲染，但需要父节点让 add_child 成功）
	var root := Node2D.new()
	root.name = "OverlayDemo"
	get_root().add_child(root)

	# 创建 overlay 节点
	var tracker: Dictionary = {}
	for y in GRID_H:
		for x in GRID_W:
			var cell := Vector2i(x, y)
			var world_pos := Vector2(
				MARGIN + x * CELL_PX + CELL_PX * 0.5,
				MARGIN + y * CELL_PX + CELL_PX * 0.5)
			OverlayRegistry.ensure_overlays_at(cell, board, root, tracker, CELL_PX, world_pos)

	# 验证 tracker 节点数
	var jelly_count := 0
	var bomb_count := 0
	for k in tracker:
		var key_arr: Array = k
		if key_arr[0] == "jelly":
			jelly_count += 1
		elif key_arr[0] == "bomb":
			bomb_count += 1
	print("overlay_demo: jelly_count=%d (期望8), bomb_count=%d (期望2)" % [jelly_count, bomb_count])
	assert(jelly_count == 8, "jelly overlay 数量不符，期望 8 得 %d" % jelly_count)
	assert(bomb_count == 2,  "bomb overlay 数量不符，期望 2 得 %d" % bomb_count)

	# 程序合成截图（headless 无 Viewport 渲染）
	var img_w := int(MARGIN * 2 + GRID_W * CELL_PX)
	var img_h := int(MARGIN * 2 + GRID_H * CELL_PX)
	var img := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.12, 1.0))

	for y in GRID_H:
		for x in GRID_W:
			var cx := int(MARGIN + x * CELL_PX)
			var cy := int(MARGIN + y * CELL_PX)
			# 格子背景
			_fill_rect(img, cx, cy, int(CELL_PX) - 2, int(CELL_PX) - 2,
				Color(0.18, 0.20, 0.28, 1.0))
			# jelly 层
			var jval: int = board.jelly[y][x]
			if jval > 0:
				var jcol: Color = JELLY_COLOR_2 if jval == 2 else JELLY_COLOR_1
				_fill_rect(img, cx + 2, cy + 2, int(CELL_PX) - 6, int(CELL_PX) - 6, jcol)
			# bomb 层
			var bval: int = board.bomb[y][x]
			if bval > 0:
				_fill_circle(img, cx + int(CELL_PX * 0.5), cy + int(CELL_PX * 0.5),
					int(CELL_PX * 0.35), BOMB_BODY_COLOR)
				# 颜色标注: 红=危险(≤3), 白=正常
				var num_col: Color = Color(1.0, 0.18, 0.18, 1.0) if bval <= BOMB_DANGER_THRESHOLD \
					else Color(1.0, 1.0, 1.0, 1.0)
				_fill_circle(img, cx + int(CELL_PX * 0.5), cy + int(CELL_PX * 0.5),
					int(CELL_PX * 0.12), num_col)

	# 保存
	var path := "res://_overlay_demo.png"
	var abs_path := ProjectSettings.globalize_path(path)
	var err := img.save_png(abs_path)
	if err == OK:
		print("overlay_demo: 截图已保存 -> ", abs_path)
	else:
		print("overlay_demo: 截图保存失败 err=", err, " (路径: ", abs_path, ")")

	print("overlay_demo: PASS")
	quit(0)

# ── 工具绘制函数（无 CanvasItem 依赖）──

func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for ry in h:
		for rx in w:
			var px := x + rx
			var py := y + ry
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)

func _fill_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for ry in range(-radius, radius + 1):
		for rx in range(-radius, radius + 1):
			if rx * rx + ry * ry <= radius * radius:
				var px := cx + rx
				var py := cy + ry
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, color)
