class_name CoatOverlay
extends OverlayBase
## 冰锁 Overlay（coat 层, §3.1）。
## coat 是 int 等级（1-3），受击-1，归0解冻。
## ob_ice.png 存在时优先使用；否则程序绘制冰蓝色块 + 裂纹线分级。
##
## TEXTURE_PATHS: 有素材时填路径，程序绘制自动降级。
## 受击: blocker_cleared > 0 且 current_value 下降 → 播裂纹抖动 + 换分级。
## 归 0: on_cleared 渐隐后 free。

# ── 素材占位 ──
const TEXTURE_PATHS := {
	3: "res://assets/obstacles/ob_ice.png",   # 等级 3 用 ob_ice（若存在）
	2: "",
	1: "",
}

# ── 程序绘制颜色 ──
const COLOR_COAT_3  := Color(0.55, 0.82, 1.00, 0.80)   # 深冰蓝
const COLOR_COAT_2  := Color(0.68, 0.90, 1.00, 0.62)   # 中冰蓝
const COLOR_COAT_1  := Color(0.80, 0.95, 1.00, 0.42)   # 浅冰蓝
const COLOR_CRACK   := Color(0.95, 0.98, 1.00, 0.90)   # 裂纹白

const COAT_FILL := 0.88
const FADE_DURATION := 0.22
const SHAKE_DURATION := 0.10

var _sprite: Sprite2D
var _last_value: int = 0

# ── static 元信息 ──

static func layer_key() -> String:
	return "coat"

static func z_band() -> int:
	return Z_SHELL   # 5: 罩在棋子上的壳

# ── 生命周期 ──

func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	super(p_cell, p_board, p_cell_px)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_last_value = current_value()
	_apply_grade(_last_value)

func on_step(report: Dictionary) -> void:
	var account: Dictionary = report.get("account", {})
	if account.get("blocker_cleared", 0) <= 0:
		return
	var new_val: int = current_value()
	if new_val < _last_value:
		_play_crack_shake()
		_apply_grade(new_val)
	_last_value = new_val
	if new_val <= 0:
		on_cleared()

func on_cleared() -> void:
	if not is_inside_tree():
		queue_free()
		return
	var t: Tween = create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	t.tween_callback(queue_free)

# ── 内部 ──

func _apply_grade(value: int) -> void:
	var path: String = TEXTURE_PATHS.get(value, "")
	if path != "" and ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_fit_sprite_to_cell()
		return
	match value:
		3:
			_sprite.texture = _make_coat_texture(COLOR_COAT_3, 0)
		2:
			_sprite.texture = _make_coat_texture(COLOR_COAT_2, 1)
		1:
			_sprite.texture = _make_coat_texture(COLOR_COAT_1, 2)
		_:
			pass
	_fit_sprite_to_cell()

func _fit_sprite_to_cell() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var size: Vector2 = _sprite.texture.get_size()
	var longest: float = maxf(size.x, size.y)
	if longest <= 0.0 or _cell_px <= 0.0:
		_sprite.scale = Vector2.ONE
		return
	var scale_value: float = (_cell_px * COAT_FILL) / longest
	_sprite.scale = Vector2(scale_value, scale_value)

func _make_coat_texture(base_color: Color, crack_level: int) -> ImageTexture:
	var size: int = int(_cell_px)
	if size <= 0:
		size = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 填充冰蓝色块
	for y in size:
		for x in size:
			img.set_pixel(x, y, base_color)
	# 裂纹线（crack_level=0 无裂纹, 1=一条, 2=两条）
	if crack_level >= 1:
		# 斜裂纹 1
		for i in range(size):
			var px: int = clamp(int(size * 0.25 + i * 0.45), 0, size - 1)
			var py: int = clamp(int(size * 0.10 + i * 0.55), 0, size - 1)
			img.set_pixel(px, py, COLOR_CRACK)
	if crack_level >= 2:
		# 斜裂纹 2
		for i in range(size):
			var px: int = clamp(int(size * 0.60 + i * 0.35), 0, size - 1)
			var py: int = clamp(int(size * 0.05 + i * 0.65), 0, size - 1)
			img.set_pixel(px, py, COLOR_CRACK)
	return ImageTexture.create_from_image(img)

func _play_crack_shake() -> void:
	if not is_inside_tree():
		return
	var t: Tween = create_tween()
	t.tween_property(self, "position", position + Vector2(3, 0), SHAKE_DURATION * 0.3)
	t.tween_property(self, "position", position + Vector2(-3, 0), SHAKE_DURATION * 0.3)
	t.tween_property(self, "position", position, SHAKE_DURATION * 0.4)
