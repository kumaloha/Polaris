class_name MysteryOverlay
extends OverlayBase
## 神秘糖 Overlay（mystery 层, §3.1）。
## mystery 是 0/1，1=神秘糖格，被消揭开变随机内容后→0。
## 程序绘制：紫色圆角矩形 + 白色"？"字符 Label。
## TEXTURE_PATH 预留。
##
## on_step: mystery_revealed > 0 且 current_value 归 0 → 播揭开闪光后 on_cleared 回收。
## 归 0:   揭开闪光（白色扩散）+ 旋转淡出 free。

# ── 素材占位 ──
const TEXTURE_PATH := ""   # 神秘糖贴图（空=程序绘制）

# ── 程序绘制颜色 ──
const COLOR_BG      := Color(0.55, 0.18, 0.82, 0.90)   # 紫色主体
const COLOR_BORDER  := Color(0.78, 0.45, 1.00, 1.00)   # 亮紫边框
const COLOR_QM      := Color(1.00, 1.00, 1.00, 1.00)   # 问号白

const REVEAL_DURATION := 0.30
const FADE_DURATION   := 0.22

var _sprite: Sprite2D
var _label: Label
var _last_value: int = 0

# ── static 元信息 ──

static func layer_key() -> String:
	return "mystery"

static func z_band() -> int:
	return Z_SHELL   # 5

# ── 生命周期 ──

func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	super(p_cell, p_board, p_cell_px)
	_build_visuals()
	_last_value = current_value()

func on_step(report: Dictionary) -> void:
	var account: Dictionary = report.get("account", {})
	if account.get("mystery_revealed", 0) <= 0:
		return
	var new_val: int = current_value()
	if new_val < _last_value:
		_play_reveal()
	_last_value = new_val
	if new_val <= 0:
		on_cleared()

func on_cleared() -> void:
	if not is_inside_tree():
		queue_free()
		return
	# 揭开闪光：先白闪扩大，再旋转淡出
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 1.0), REVEAL_DURATION * 0.25)
	t.tween_property(self, "scale", Vector2(1.30, 1.30), REVEAL_DURATION * 0.25)
	t.chain()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	t.tween_property(self, "scale", Vector2(1.6, 1.6), FADE_DURATION)
	t.tween_property(self, "rotation_degrees", 25.0, FADE_DURATION)
	t.chain()
	t.tween_callback(queue_free)

# ── 内部 ──

func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	if TEXTURE_PATH != "" and ResourceLoader.exists(TEXTURE_PATH):
		_sprite.texture = load(TEXTURE_PATH)
	else:
		_sprite.texture = _make_mystery_texture()
	add_child(_sprite)
	# "？" Label
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var lsize: int = int(_cell_px * 0.65)
	if lsize < 24:
		lsize = 24
	_label.size = Vector2(lsize, lsize)
	_label.position = Vector2(-lsize * 0.5, -lsize * 0.5)
	var font_size: int = int(_cell_px * 0.46)
	if font_size < 16:
		font_size = 16
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", COLOR_QM)
	_label.text = "?"
	_label.z_index = 1
	add_child(_label)

func _make_mystery_texture() -> ImageTexture:
	var size: int = int(_cell_px * 0.88)
	if size <= 0:
		size = 56
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r: float = 8.0
	# 圆角矩形主体
	for y in size:
		for x in size:
			var fx: float = float(x)
			var fy: float = float(y)
			var in_corner: bool = false
			var cdx: float = 0.0
			var cdy: float = 0.0
			if fx < r and fy < r:
				cdx = r - fx; cdy = r - fy; in_corner = true
			elif fx >= size - r and fy < r:
				cdx = fx - (size - r - 1.0); cdy = r - fy; in_corner = true
			elif fx < r and fy >= size - r:
				cdx = r - fx; cdy = fy - (size - r - 1.0); in_corner = true
			elif fx >= size - r and fy >= size - r:
				cdx = fx - (size - r - 1.0); cdy = fy - (size - r - 1.0); in_corner = true
			if in_corner and cdx * cdx + cdy * cdy > r * r:
				continue
			# 边框（外 2 px）
			if fx < 2 or fx >= size - 2 or fy < 2 or fy >= size - 2:
				img.set_pixel(x, y, COLOR_BORDER)
			else:
				img.set_pixel(x, y, COLOR_BG)
	return ImageTexture.create_from_image(img)

func _play_reveal() -> void:
	if not is_inside_tree():
		return
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", Color(1.8, 1.5, 2.0, 1.0), REVEAL_DURATION * 0.4)
	t.tween_property(self, "modulate", Color.WHITE, REVEAL_DURATION * 0.6)
