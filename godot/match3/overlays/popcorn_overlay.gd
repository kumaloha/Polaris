class_name PopcornOverlay
extends OverlayBase
## 爆米花 Overlay（popcorn 层, §3.1）。
## popcorn 是 int 血量（>0=有爆米花），特效命中-1，归0变彩球。
## 血量分级：4+ 完整 / 3 一裂 / 2 两裂 / 1 严重破损。
## 程序绘制：奶白色爆米花团 + 分级裂缝。
## TEXTURE_PATHS 预留。
##
## on_step: popcorn_hit > 0 且 current_value 下降 → 播爆裂抖动 + 换分级。
## 归 0:   current_value 归 0 → on_cleared（自回收），调方自无需额外处理。

# ── 素材占位 ──
const TEXTURE_PATHS := {
	4: "",
	3: "",
	2: "",
	1: "",
}

# ── 程序绘制颜色 ──
const COLOR_KERNEL   := Color(0.97, 0.93, 0.80, 0.95)   # 奶白爆米花
const COLOR_SHADOW   := Color(0.75, 0.68, 0.50, 0.80)   # 阴影底
const COLOR_CRACK    := Color(0.60, 0.45, 0.20, 1.00)   # 裂缝棕
const COLOR_POP_FX   := Color(1.00, 0.90, 0.40, 1.00)   # 受击黄闪

const HIT_DURATION  := 0.14
const FADE_DURATION := 0.20

var _sprite: Sprite2D
var _last_value: int = 0

# ── static 元信息 ──

static func layer_key() -> String:
	return "popcorn"

static func z_band() -> int:
	return Z_SHELL   # 5

# ── 生命周期 ──

func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	super(p_cell, p_board, p_cell_px)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_last_value = current_value()
	_apply_grade(_last_value)

func on_step(report: Dictionary) -> void:
	var account: Dictionary = report.get("account", {})
	if account.get("popcorn_hit", 0) <= 0:
		return
	var new_val: int = current_value()
	if new_val < _last_value:
		_play_pop_hit()
		_apply_grade(new_val)
	_last_value = new_val
	if new_val <= 0:
		on_cleared()

func on_cleared() -> void:
	if not is_inside_tree():
		queue_free()
		return
	# 归0变彩球：闪光后淡出
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate", Color(1.5, 1.5, 0.5, 1.0), HIT_DURATION * 0.4)
	t.chain()
	t.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	t.chain()
	t.tween_callback(queue_free)

# ── 内部 ──

func _apply_grade(value: int) -> void:
	var path: String = TEXTURE_PATHS.get(value, "")
	if path != "" and ResourceLoader.exists(path):
		_sprite.texture = load(path)
		return
	# crack_level: 0=无裂纹, 1=轻微, 2=中等, 3=严重
	var crack_level: int = 0
	if value == 3:
		crack_level = 1
	elif value == 2:
		crack_level = 2
	elif value == 1:
		crack_level = 3
	_sprite.texture = _make_popcorn_texture(crack_level)

func _make_popcorn_texture(crack_level: int) -> ImageTexture:
	var size: int = int(_cell_px * 0.82)
	if size <= 0:
		size = 52
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = size * 0.5
	var cy: float = size * 0.5
	# 底部阴影椭圆
	var sh_rx: float = size * 0.38
	var sh_ry: float = size * 0.18
	var sh_cy: float = cy + size * 0.30
	for y in size:
		for x in size:
			var dx: float = float(x) - cx
			var dy: float = float(y) - sh_cy
			if (dx * dx) / (sh_rx * sh_rx) + (dy * dy) / (sh_ry * sh_ry) <= 1.0:
				img.set_pixel(x, y, COLOR_SHADOW)
	# 主爆花体（不规则圆团：3 个叠加圆）
	var blobs := [
		[cx, cy - size * 0.05, size * 0.32],
		[cx - size * 0.18, cy + size * 0.08, size * 0.26],
		[cx + size * 0.18, cy + size * 0.08, size * 0.26],
	]
	for blob in blobs:
		var bx: float = blob[0]
		var by: float = blob[1]
		var br: float = blob[2]
		for y in size:
			for x in size:
				var dx: float = float(x) - bx
				var dy: float = float(y) - by
				if dx * dx + dy * dy <= br * br:
					img.set_pixel(x, y, COLOR_KERNEL)
	# 裂缝线（根据 crack_level 数量）
	if crack_level >= 1:
		for i in range(size / 2):
			var px: int = clamp(int(cx + 2 + i * 0.3), 0, size - 1)
			var py: int = clamp(int(cy - 5 + i * 0.6), 0, size - 1)
			img.set_pixel(px, py, COLOR_CRACK)
	if crack_level >= 2:
		for i in range(size / 2):
			var px: int = clamp(int(cx - 5 - i * 0.4), 0, size - 1)
			var py: int = clamp(int(cy + 2 + i * 0.5), 0, size - 1)
			img.set_pixel(px, py, COLOR_CRACK)
	if crack_level >= 3:
		for i in range(size / 3):
			var px: int = clamp(int(cx - 2 + i * 0.5), 0, size - 1)
			var py: int = clamp(int(cy - 8 - i * 0.6), 0, size - 1)
			img.set_pixel(px, py, COLOR_CRACK)
	return ImageTexture.create_from_image(img)

func _play_pop_hit() -> void:
	if not is_inside_tree():
		return
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.15, 1.15), HIT_DURATION * 0.35)
	t.tween_property(self, "modulate", COLOR_POP_FX, HIT_DURATION * 0.35)
	t.chain()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, HIT_DURATION * 0.65)
	t.tween_property(self, "modulate", Color.WHITE, HIT_DURATION * 0.65)
