class_name CakeOverlay
extends OverlayBase
## 蛋糕大件 Overlay（cake 层, §3.1）。
## cake 是 int 血量（>0），2×2 大件占 4 格、数据按格存储。
## 渲染器只在"左上角格"画完整大件；其余格 setup 时检测非左上角则 queue_free 跳过。
##
## 左上角判定：cake 值 >0 且 (x-1,y) 或 (x,y-1) 处 cake 值相同则非左上角。
## 程序绘制：奶油白多层蛋糕造型 + 血量数字 Label。
## TEXTURE_PATHS 预留。
##
## on_step: cake_destroyed > 0 且 current_value 下降 → 播崩块抖动 + 刷血量显示。
## 归 0:   爆炸放大 + 渐隐 free。

# ── 素材占位 ──
const TEXTURE_PATHS := {
	3: "",
	2: "",
	1: "",
}

# ── 程序绘制颜色 ──
const COLOR_CAKE_BASE   := Color(0.97, 0.90, 0.78, 1.00)   # 奶油白
const COLOR_CAKE_LAYER  := Color(0.90, 0.55, 0.30, 1.00)   # 橙棕蛋糕体
const COLOR_FROSTING    := Color(1.00, 0.96, 0.90, 1.00)   # 奶油霜白
const COLOR_CRACK       := Color(0.65, 0.35, 0.15, 1.00)   # 裂缝棕
const COLOR_CANDLE      := Color(1.00, 0.85, 0.20, 1.00)   # 蜡烛黄
const COLOR_FLAME       := Color(1.00, 0.50, 0.10, 1.00)   # 火焰橙

const SLAM_DURATION := 0.14
const FADE_DURATION := 0.28

var _sprite: Sprite2D
var _label: Label
var _last_value: int = 0
var _is_corner: bool = false   # 是否是左上角格

# ── static 元信息 ──

static func layer_key() -> String:
	return "cake"

static func z_band() -> int:
	return Z_SHELL   # 5

# ── 生命周期 ──

func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	super(p_cell, p_board, p_cell_px)
	_is_corner = _check_is_top_left_corner()
	if not _is_corner:
		# 非左上角格：立即自销毁，不渲染
		queue_free()
		return
	_build_visuals()
	_last_value = current_value()
	_update_label(_last_value)

func on_step(report: Dictionary) -> void:
	if not _is_corner:
		return
	var account: Dictionary = report.get("account", {})
	if account.get("cake_destroyed", 0) <= 0:
		return
	var new_val: int = current_value()
	if new_val < _last_value:
		_play_slam()
		_apply_grade(new_val)
		_update_label(new_val)
	_last_value = new_val
	if new_val <= 0:
		on_cleared()

func on_cleared() -> void:
	if not is_inside_tree():
		queue_free()
		return
	# 蛋糕爆炸：快速放大 + 淡出
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.5, 1.5), SLAM_DURATION * 0.5)
	t.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	t.chain()
	t.tween_callback(queue_free)

# ── 内部 ──

func _check_is_top_left_corner() -> bool:
	var val: int = current_value()
	if val <= 0:
		return false
	# 若左格或上格有相同值，则本格不是左上角
	var cx: int = cell.x
	var cy: int = cell.y
	if cx > 0:
		var left_val: int = _neighbor_cake_value(cx - 1, cy)
		if left_val == val:
			return false
	if cy > 0:
		var up_val: int = _neighbor_cake_value(cx, cy - 1)
		if up_val == val:
			return false
	return true

func _neighbor_cake_value(nx: int, ny: int) -> int:
	if _board == null:
		return 0
	var layers: Dictionary = _board._layers()
	var cake_data = layers.get("cake", [])
	if cake_data is Array and ny < cake_data.size():
		var row = cake_data[ny]
		if row is Array and nx < row.size():
			return row[nx]
	return 0

func _build_visuals() -> void:
	var draw_size: float = _cell_px * 1.90   # 大件跨 2 格，略宽
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_apply_grade(current_value())
	# 血量 Label（右下角）
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var lsize: int = int(_cell_px * 0.40)
	if lsize < 16:
		lsize = 16
	_label.size = Vector2(lsize, lsize)
	_label.position = Vector2(draw_size * 0.5 - lsize - 4, draw_size * 0.5 - lsize - 4)
	var font_size: int = int(_cell_px * 0.28)
	if font_size < 10:
		font_size = 10
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.0, 1.0))
	_label.z_index = 1
	add_child(_label)

func _update_label(value: int) -> void:
	if _label == null:
		return
	_label.text = str(value)

func _apply_grade(value: int) -> void:
	if _sprite == null:
		return
	var path: String = TEXTURE_PATHS.get(value, "")
	if path != "" and ResourceLoader.exists(path):
		_sprite.texture = load(path)
		return
	# crack_level: 0=完整, 1=中等, 2=严重
	var crack_level: int = 0
	if value == 2:
		crack_level = 1
	elif value == 1:
		crack_level = 2
	_sprite.texture = _make_cake_texture(crack_level)

func _make_cake_texture(crack_level: int) -> ImageTexture:
	# 跨 2×2 格：贴图尺寸约 2 格
	var size: int = int(_cell_px * 1.90)
	if size <= 0:
		size = 120
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = size * 0.5
	# 蛋糕底层（长方形）
	var body_x: int = int(size * 0.08)
	var body_w: int = int(size * 0.84)
	var body_y: int = int(size * 0.55)
	var body_h: int = int(size * 0.38)
	_fill_rect_img(img, body_x, body_y, body_w, body_h, COLOR_CAKE_LAYER)
	# 蛋糕上层（稍窄）
	var top_x: int = int(size * 0.14)
	var top_w: int = int(size * 0.72)
	var top_y: int = int(size * 0.30)
	var top_h: int = int(size * 0.28)
	_fill_rect_img(img, top_x, top_y, top_w, top_h, COLOR_CAKE_LAYER)
	# 奶油霜覆盖顶部
	var frost_y: int = top_y
	var frost_h: int = int(size * 0.08)
	_fill_rect_img(img, top_x, frost_y, top_w, frost_h, COLOR_FROSTING)
	# 蛋糕体顶部奶油霜
	_fill_rect_img(img, body_x, body_y, body_w, frost_h, COLOR_FROSTING)
	# 蜡烛
	var candle_x: int = int(cx - size * 0.05)
	var candle_y: int = int(top_y - size * 0.18)
	var candle_w: int = max(3, int(size * 0.08))
	var candle_h: int = int(size * 0.16)
	_fill_rect_img(img, candle_x, candle_y, candle_w, candle_h, COLOR_CANDLE)
	# 火焰
	var flame_r: int = max(2, int(size * 0.06))
	for dy in range(-flame_r, flame_r + 1):
		for dx in range(-flame_r, flame_r + 1):
			if dx * dx + dy * dy <= flame_r * flame_r:
				var px: int = clamp(candle_x + candle_w / 2 + dx, 0, size - 1)
				var py: int = clamp(candle_y - flame_r + dy, 0, size - 1)
				img.set_pixel(px, py, COLOR_FLAME)
	# 裂缝
	if crack_level >= 1:
		for i in range(int(size * 0.35)):
			var px: int = clamp(int(cx - size * 0.15 + i * 0.5), 0, size - 1)
			var py: int = clamp(int(size * 0.40 + i * 0.7), 0, size - 1)
			img.set_pixel(px, py, COLOR_CRACK)
	if crack_level >= 2:
		for i in range(int(size * 0.30)):
			var px: int = clamp(int(cx + size * 0.10 + i * 0.4), 0, size - 1)
			var py: int = clamp(int(size * 0.35 + i * 0.8), 0, size - 1)
			img.set_pixel(px, py, COLOR_CRACK)
	return ImageTexture.create_from_image(img)

func _fill_rect_img(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	for ry in h:
		for rx in w:
			var px: int = x + rx
			var py: int = y + ry
			if px >= 0 and px < iw and py >= 0 and py < ih:
				img.set_pixel(px, py, color)

func _play_slam() -> void:
	if not is_inside_tree():
		return
	var t: Tween = create_tween()
	t.tween_property(self, "position", position + Vector2(0, 4), SLAM_DURATION * 0.3)
	t.tween_property(self, "position", position, SLAM_DURATION * 0.7)
