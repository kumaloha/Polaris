class_name ChocoOverlay
extends OverlayBase
## 巧克力 Overlay（choco 层, §3.1）。
## choco 是 0/1，1=占格。被相邻消除啃食后 choco→0 消失。
## 程序绘制：深棕色填充格 + 两条高光线模拟巧克力块纹理。
## TEXTURE_PATHS 预留，有素材时换图。
##
## on_step: choco_cleared > 0 且 current_value 归 0 → 播碎屑演出后 on_cleared。
## 归 0: 缩放爆出 + 渐隐后 free。

# ── 素材占位 ──
const TEXTURE_PATH := ""   # 巧克力贴图路径（空=程序绘制）

# ── 程序绘制颜色 ──
const COLOR_CHOCO   := Color(0.38, 0.20, 0.08, 0.92)   # 深棕
const COLOR_GROOVE  := Color(0.28, 0.14, 0.05, 1.00)   # 凹槽深色
const COLOR_LIGHT   := Color(0.52, 0.32, 0.15, 0.80)   # 高光浅棕

const FADE_DURATION := 0.18
const POP_DURATION  := 0.14

var _sprite: Sprite2D
var _last_value: int = 0

# ── static 元信息 ──

static func layer_key() -> String:
	return "choco"

static func z_band() -> int:
	return Z_SHELL   # 5: 罩在棋子上的壳

# ── 生命周期 ──

func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	super(p_cell, p_board, p_cell_px)
	_sprite = Sprite2D.new()
	if TEXTURE_PATH != "" and ResourceLoader.exists(TEXTURE_PATH):
		_sprite.texture = load(TEXTURE_PATH)
	else:
		_sprite.texture = _make_choco_texture()
	add_child(_sprite)
	_last_value = current_value()

func on_step(report: Dictionary) -> void:
	var account: Dictionary = report.get("account", {})
	if account.get("choco_cleared", 0) <= 0:
		return
	var new_val: int = current_value()
	if new_val < _last_value:
		_play_crumble()
	_last_value = new_val
	if new_val <= 0:
		on_cleared()

func on_cleared() -> void:
	if not is_inside_tree():
		queue_free()
		return
	# 被啃食：先缩放爆出再渐隐
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.20, 1.20), POP_DURATION * 0.4)
	t.chain()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(0.8, 0.8), POP_DURATION * 0.3)
	t.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	t.chain()
	t.tween_callback(queue_free)

# ── 内部 ──

func _make_choco_texture() -> ImageTexture:
	var size: int = int(_cell_px)
	if size <= 0:
		size = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 深棕主体
	for y in size:
		for x in size:
			img.set_pixel(x, y, COLOR_CHOCO)
	# 横向凹槽线（模拟巧克力分块）
	var mid_y: int = size / 2
	for x in size:
		img.set_pixel(x, mid_y,     COLOR_GROOVE)
		img.set_pixel(x, mid_y + 1, COLOR_GROOVE)
	# 纵向凹槽线
	var mid_x: int = size / 2
	for y in size:
		img.set_pixel(mid_x,     y, COLOR_GROOVE)
		img.set_pixel(mid_x + 1, y, COLOR_GROOVE)
	# 四块高光点
	for by in [size / 4, size * 3 / 4]:
		for bx in [size / 4, size * 3 / 4]:
			var hl_r: int = max(2, size / 12)
			for dy in range(-hl_r, hl_r + 1):
				for dx in range(-hl_r, hl_r + 1):
					if dx * dx + dy * dy <= hl_r * hl_r:
						var px: int = clamp(bx + dx, 0, size - 1)
						var py: int = clamp(by + dy, 0, size - 1)
						img.set_pixel(px, py, COLOR_LIGHT)
	return ImageTexture.create_from_image(img)

func _play_crumble() -> void:
	if not is_inside_tree():
		return
	var t: Tween = create_tween()
	t.tween_property(self, "scale", Vector2(1.10, 1.10), 0.06)
	t.tween_property(self, "scale", Vector2(1.00, 1.00), 0.06)
