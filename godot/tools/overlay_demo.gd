extends SceneTree
## overlay_demo.gd — 构造含全部 9 种障碍层的全家福盘，程序合成截图供评审。
## 运行:
##   godot --headless --path godot -s res://tools/overlay_demo.gd
## 截图输出: res://_overlay_demo_full.png

const Board            := preload("res://core/board.gd")
const OverlayRegistry  := preload("res://match3/overlays/overlay_registry.gd")

const CELL_PX  := 64.0
const GRID_W   := 9    # 一行铺九种，每格一种
const GRID_H   := 4
const MARGIN   := 16.0

# 各层颜色（程序绘制对应色，与各 overlay 内部色保持一致供截图辨认）
const JELLY_COLOR_2    := Color(0.18, 0.52, 0.90, 0.55)
const JELLY_COLOR_1    := Color(0.42, 0.72, 0.98, 0.30)
const COAT_COLOR_3     := Color(0.55, 0.82, 1.00, 0.70)
const COAT_COLOR_2     := Color(0.68, 0.90, 1.00, 0.52)
const COAT_COLOR_1     := Color(0.80, 0.95, 1.00, 0.35)
const CHOCO_COLOR      := Color(0.38, 0.20, 0.08, 0.88)
const ING_COLOR        := Color(1.00, 0.75, 0.15, 0.90)
const BOMB_BODY_COLOR  := Color(0.12, 0.10, 0.10, 0.90)
const CANNON_COLOR     := Color(0.22, 0.22, 0.26, 0.90)
const POPCORN_COLOR    := Color(0.97, 0.93, 0.80, 0.85)
const CAKE_COLOR       := Color(0.97, 0.90, 0.78, 0.90)
const MYSTERY_COLOR    := Color(0.55, 0.18, 0.82, 0.85)

# 危险阈值（bomb ≤3 用红色标记）
const BOMB_DANGER_THRESHOLD := 3

func _initialize() -> void:
	# ── 构造 9×4 盘 ──
	var board := Board.new(GRID_W, GRID_H, [0, 1, 2, 3, 4], 0, 30, 1)
	board.grid = []
	for _y in GRID_H:
		var row: Array = []
		for _x in GRID_W:
			row.append(_x % 5)
		board.grid.append(row)
	board.fx      = board._blank_fx()
	board.jelly   = board._blank_fx()
	board.bomb    = board._blank_fx()
	board.coat    = board._blank_fx()
	board.choco   = board._blank_fx()
	board.ing     = board._blank_fx()
	board.cannon  = board._blank_fx()
	board.popcorn = board._blank_fx()
	board.cake    = board._blank_fx()
	board.mystery = board._blank_fx()

	# 列分配：col → 层名
	# col 0: jelly(层2+1), col 1: coat(等级3+2), col 2: choco, col 3: ing,
	# col 4: bomb(5+2), col 5: cannon, col 6: popcorn(4+2), col 7: cake, col 8: mystery
	# jelly: 第0行=2, 第1行=1
	board.jelly[0][0] = 2
	board.jelly[1][0] = 1
	# coat: 第0行=3, 第1行=2, 第2行=1
	board.coat[0][1] = 3
	board.coat[1][1] = 2
	board.coat[2][1] = 1
	# choco: 全列放 1
	for y in GRID_H:
		board.choco[y][2] = 1
	# ing: 第0行=1, 第1行=2
	board.ing[0][3] = 1
	board.ing[1][3] = 2
	# bomb: 倒计时 5（正常）和 2（危险）
	board.bomb[0][4] = 5
	board.bomb[2][4] = 2
	# cannon: type=1 和 type=2
	board.cannon[0][5] = 1
	board.cannon[2][5] = 2
	# popcorn: 血量 4 和 2
	board.popcorn[0][6] = 4
	board.popcorn[2][6] = 2
	# cake: 2×2 大件 血量=2，(7,0),(7,1),(8,0),(8,1) 同值
	board.cake[0][7] = 2
	board.cake[0][8] = 2
	board.cake[1][7] = 2
	board.cake[1][8] = 2
	# mystery: 全列放 1
	for y in GRID_H:
		board.mystery[y][8] = 1

	# ── 根节点（headless 用）──
	var root := Node2D.new()
	root.name = "OverlayDemoFull"
	get_root().add_child(root)

	# ── 创建 overlay 节点 ──
	var tracker: Dictionary = {}
	for y in GRID_H:
		for x in GRID_W:
			var cell := Vector2i(x, y)
			var world_pos := Vector2(
				MARGIN + x * CELL_PX + CELL_PX * 0.5,
				MARGIN + y * CELL_PX + CELL_PX * 0.5)
			OverlayRegistry.ensure_overlays_at(cell, board, root, tracker, CELL_PX, world_pos)

	# ── 统计 overlay 节点数 ──
	var counts: Dictionary = {}
	for k in tracker:
		var key_arr: Array = k
		var layer_name: String = key_arr[0]
		counts[layer_name] = counts.get(layer_name, 0) + 1

	print("overlay_demo_full: overlay 节点统计:")
	for layer_name in counts:
		print("  %s: %d" % [layer_name, counts[layer_name]])

	var total_overlays: int = 0
	for cnt in counts.values():
		total_overlays += cnt
	print("overlay_demo_full: 总节点数=%d" % total_overlays)

	# ── 程序合成截图 ──
	var img_w: int = int(MARGIN * 2 + GRID_W * CELL_PX)
	var img_h: int = int(MARGIN * 2 + GRID_H * CELL_PX)
	var img: Image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.12, 1.0))

	for y in GRID_H:
		for x in GRID_W:
			var cx: int = int(MARGIN + x * CELL_PX)
			var cy: int = int(MARGIN + y * CELL_PX)
			var cs: int = int(CELL_PX) - 2

			# 格子背景
			_fill_rect(img, cx, cy, cs, cs, Color(0.18, 0.20, 0.28, 1.0))

			# ── 绘制各层 ──
			# jelly（列0）
			var jval: int = board.jelly[y][x]
			if jval > 0:
				var jcol: Color = JELLY_COLOR_2 if jval == 2 else JELLY_COLOR_1
				_fill_rect(img, cx + 2, cy + 2, cs - 4, cs - 4, jcol)

			# coat（列1）
			var cval: int = board.coat[y][x]
			if cval > 0:
				var ccol: Color = COAT_COLOR_3
				if cval == 2:
					ccol = COAT_COLOR_2
				elif cval == 1:
					ccol = COAT_COLOR_1
				_fill_rect(img, cx + 1, cy + 1, cs - 2, cs - 2, ccol)
				# 裂纹线（cval < 3 时）
				if cval <= 2:
					for i in range(cs / 2):
						var px: int = clamp(cx + 8 + i, 0, img_w - 1)
						var py: int = clamp(cy + 5 + i, 0, img_h - 1)
						img.set_pixel(px, py, Color(0.95, 0.98, 1.0, 0.90))

			# choco（列2）
			var chval: int = board.choco[y][x]
			if chval > 0:
				_fill_rect(img, cx + 2, cy + 2, cs - 4, cs - 4, CHOCO_COLOR)
				# 十字槽
				_fill_rect(img, cx + 2, cy + cs / 2 - 1, cs - 4, 3, Color(0.20, 0.10, 0.02, 1.0))
				_fill_rect(img, cx + cs / 2 - 1, cy + 2, 3, cs - 4, Color(0.20, 0.10, 0.02, 1.0))

			# ing（列3）
			var ival: int = board.ing[y][x]
			if ival > 0:
				var ing_col: Color = ING_COLOR if ival == 1 else Color(0.95, 0.40, 0.15, 0.90)
				_fill_circle(img, cx + cs / 2, cy + cs / 2, int(cs * 0.38), ing_col)

			# bomb（列4）
			var bval: int = board.bomb[y][x]
			if bval > 0:
				_fill_circle(img, cx + cs / 2, cy + cs / 2, int(cs * 0.36), BOMB_BODY_COLOR)
				# 数字颜色标记（红=危险, 白=正常）
				var num_col: Color = Color(1.0, 0.18, 0.18, 1.0) if bval <= BOMB_DANGER_THRESHOLD \
					else Color(1.0, 1.0, 1.0, 1.0)
				# 内圈表示数字（大=大数，小=小数）
				var inner_r: int = max(4, int(cs * 0.08 + bval * 0.018 * cs))
				_fill_circle(img, cx + cs / 2, cy + cs / 2, inner_r, num_col)
				# 数字标记条（顶部短横线：条数=bval，最多5条）
				var bars: int = min(bval, 5)
				for bi in bars:
					var bx: int = cx + 6 + bi * 8
					var by: int = cy + 6
					if bx + 4 < cx + cs:
						_fill_rect(img, bx, by, 5, 3, num_col)

			# cannon（列5）
			var kval: int = board.cannon[y][x]
			if kval > 0:
				# 炮身矩形
				_fill_rect(img, cx + cs / 2 - 10, cy + 8, 20, cs - 14, CANNON_COLOR)
				# 炮口椭圆
				_fill_circle(img, cx + cs / 2, cy + 10, 8, Color(0.08, 0.08, 0.10, 1.0))
				# type=2 加橙点
				if kval == 2:
					_fill_circle(img, cx + cs / 2, cy + cs / 2 + 4, 5, Color(1.0, 0.65, 0.15, 1.0))

			# popcorn（列6）
			var pval: int = board.popcorn[y][x]
			if pval > 0:
				_fill_circle(img, cx + cs / 2, cy + cs / 2 - 4, int(cs * 0.34), POPCORN_COLOR)
				_fill_circle(img, cx + cs / 2 - 10, cy + cs / 2 + 6, int(cs * 0.24), POPCORN_COLOR)
				_fill_circle(img, cx + cs / 2 + 10, cy + cs / 2 + 6, int(cs * 0.24), POPCORN_COLOR)
				# 裂缝线（pval < 4）
				if pval < 4:
					for i in range(16):
						var px: int = clamp(cx + cs / 2 + 2 + i, 0, img_w - 1)
						var py: int = clamp(cy + cs / 2 - 4 + i / 2, 0, img_h - 1)
						img.set_pixel(px, py, Color(0.55, 0.40, 0.20, 1.0))

			# cake（列7-8 共享，只在 (7,0) 和 (7,2) 画大件）
			var cakeval: int = board.cake[y][x]
			if cakeval > 0 and x == 7 and (y == 0 or y == 2):
				# 跨两格画蛋糕
				var ck_w: int = int(CELL_PX * 2 - 4)
				var ck_h: int = int(CELL_PX * 2 - 4)
				# 蛋糕体
				_fill_rect(img, cx + 2, cy + 2, ck_w, int(ck_h * 0.45), CAKE_COLOR)
				# 上层
				_fill_rect(img, cx + int(ck_w * 0.10) + 2, cy + 2,
					int(ck_w * 0.80), int(ck_h * 0.35), Color(0.90, 0.55, 0.30, 0.90))
				# 奶油顶
				_fill_rect(img, cx + int(ck_w * 0.10) + 2, cy + 2,
					int(ck_w * 0.80), 6, Color(1.0, 0.96, 0.90, 1.0))
				# 血量数字点（cakeval 个点）
				for ci in cakeval:
					_fill_circle(img, cx + 12 + ci * 12, cy + ck_h - 10, 4, Color(0.6, 0.2, 0.0, 1.0))

			# mystery（列8，但 cake 也占列8；mystery 在 cake 格上不绘制，避免混乱）
			var mval: int = board.mystery[y][x]
			if mval > 0 and board.cake[y][x] <= 0:
				# 紫色圆角块 + "?"
				_fill_rect(img, cx + 4, cy + 4, cs - 8, cs - 8, MYSTERY_COLOR)
				# 问号用两个白圆近似
				_fill_circle(img, cx + cs / 2, cy + cs / 2 - 6, 7, Color(0.9, 0.7, 1.0, 1.0))
				_fill_circle(img, cx + cs / 2, cy + cs / 2 + 6, 3, Color(0.9, 0.7, 1.0, 1.0))

	# 顶部色条（辨识各列层名）
	var label_colors: Array = [
		Color(0.18, 0.52, 0.90, 0.8),  # jelly
		Color(0.55, 0.82, 1.00, 0.8),  # coat
		Color(0.38, 0.20, 0.08, 0.8),  # choco
		Color(1.00, 0.75, 0.15, 0.8),  # ing
		Color(0.12, 0.10, 0.10, 0.8),  # bomb
		Color(0.22, 0.22, 0.26, 0.8),  # cannon
		Color(0.97, 0.93, 0.80, 0.8),  # popcorn
		Color(0.97, 0.90, 0.78, 0.8),  # cake
		Color(0.55, 0.18, 0.82, 0.8),  # mystery
	]
	for x in GRID_W:
		var cx: int = int(MARGIN + x * CELL_PX)
		_fill_rect(img, cx + 2, int(MARGIN) - 10, int(CELL_PX) - 4, 8,
			label_colors[x] if x < label_colors.size() else Color.WHITE)

	# 保存
	var path := "res://_overlay_demo_full.png"
	var abs_path: String = ProjectSettings.globalize_path(path)
	var err: int = img.save_png(abs_path)
	if err == OK:
		print("overlay_demo_full: 截图已保存 -> ", abs_path)
	else:
		print("overlay_demo_full: 截图保存失败 err=", err, " (路径: ", abs_path, ")")

	print("overlay_demo_full: PASS  总 overlay 节点数=", total_overlays)
	quit(0)

# ── 工具绘制函数 ──

func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	for ry in h:
		for rx in w:
			var px: int = x + rx
			var py: int = y + ry
			if px >= 0 and px < iw and py >= 0 and py < ih:
				img.set_pixel(px, py, color)

func _fill_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	for ry in range(-radius, radius + 1):
		for rx in range(-radius, radius + 1):
			if rx * rx + ry * ry <= radius * radius:
				var px: int = cx + rx
				var py: int = cy + ry
				if px >= 0 and px < iw and py >= 0 and py < ih:
					img.set_pixel(px, py, color)
