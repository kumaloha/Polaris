class_name CannonOverlay
extends OverlayBase
## 炮口装置 Overlay（cannon 层, §3.1）。
## cannon 是 0/2（0=无炮，1=产普通棋子，2=产原料），固定装置不随重力落。
## z=6：装置置于棋子之上（与 bomb 同层）。
## 程序绘制：深灰炮筒圆柱 + 炮口椭圆。
## TEXTURE_PATHS 预留。
##
## on_step: cannon_spawned 钩子在 report.account.cannon_spawned > 0 时播产出动画。
## 装置不消失（cannon 不归 0），on_cleared 仅备用。

# ── 素材占位 ──
const TEXTURE_PATHS := {
	1: "",   # 产普通棋子的炮
	2: "",   # 产原料的炮
}

# ── 程序绘制颜色 ──
const COLOR_BARREL    := Color(0.22, 0.22, 0.26, 0.95)   # 深灰炮身
const COLOR_BARREL_HL := Color(0.42, 0.42, 0.50, 0.80)   # 高光面
const COLOR_MOUTH     := Color(0.10, 0.10, 0.12, 1.00)   # 炮口深黑
const COLOR_RING      := Color(0.55, 0.55, 0.62, 0.90)   # 炮箍

const SPAWN_FLASH_DURATION := 0.18
const FADE_DURATION        := 0.22

var _sprite: Sprite2D
var _last_value: int = 0

# ── static 元信息 ──

static func layer_key() -> String:
	return "cannon"

static func z_band() -> int:
	return Z_BOMB   # 6: 装置置于棋子之上

# ── 生命周期 ──

func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	super(p_cell, p_board, p_cell_px)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_last_value = current_value()
	_apply_grade(_last_value)

func on_step(report: Dictionary) -> void:
	var account: Dictionary = report.get("account", {})
	# 产出动画钩子
	if account.get("cannon_spawned", 0) > 0:
		_play_spawn_flash()

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
		return
	_sprite.texture = _make_cannon_texture(value)

func _make_cannon_texture(cannon_type: int) -> ImageTexture:
	var size: int = int(_cell_px * 0.85)
	if size <= 0:
		size = 54
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = size * 0.5
	var cy: float = size * 0.5
	# 炮身（竖向圆柱：用椭圆近似）
	var body_rx: float = size * 0.28
	var body_ry: float = size * 0.42
	for y in size:
		for x in size:
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			if (dx * dx) / (body_rx * body_rx) + (dy * dy) / (body_ry * body_ry) <= 1.0:
				img.set_pixel(x, y, COLOR_BARREL)
	# 高光（左侧条）
	var hl_x: int = int(cx - body_rx * 0.55)
	for y in size:
		var dy: float = float(y) - cy
		if (dy * dy) / (body_ry * body_ry) <= 1.0:
			var hl_w: int = max(1, int(body_rx * 0.22))
			for dx in range(-hl_w, hl_w + 1):
				var px: int = clamp(hl_x + dx, 0, size - 1)
				img.set_pixel(px, y, COLOR_BARREL_HL)
	# 炮箍（两道横环）
	for ring_y_frac in [0.30, 0.65]:
		var ry: int = int(cy + (float(ring_y_frac) - 0.5) * body_ry * 2.0)
		for ring_dy in range(-1, 2):
			var py: int = clamp(ry + ring_dy, 0, size - 1)
			for x in size:
				var dx: float = float(x) - cx
				if (dx * dx) / (body_rx * body_rx) <= 1.0:
					img.set_pixel(x, py, COLOR_RING)
	# 炮口（顶部椭圆深孔）
	var mouth_cy: int = int(cy - body_ry * 0.82)
	var mouth_rx: int = int(body_rx * 0.65)
	var mouth_ry: int = max(2, int(body_rx * 0.25))
	for dy in range(-mouth_ry, mouth_ry + 1):
		for dx in range(-mouth_rx, mouth_rx + 1):
			if float(dx * dx) / float(mouth_rx * mouth_rx) + float(dy * dy) / float(mouth_ry * mouth_ry) <= 1.0:
				var px: int = clamp(int(cx) + dx, 0, size - 1)
				var py: int = clamp(mouth_cy + dy, 0, size - 1)
				img.set_pixel(px, py, COLOR_MOUTH)
	# 炮型 2（产原料）加橙色标记点
	if cannon_type == 2:
		var mark_r: int = max(2, int(size * 0.07))
		var mark_cx: int = int(cx)
		var mark_cy_v: int = int(cy + body_ry * 0.15)
		for dy in range(-mark_r, mark_r + 1):
			for dx in range(-mark_r, mark_r + 1):
				if dx * dx + dy * dy <= mark_r * mark_r:
					var px: int = clamp(mark_cx + dx, 0, size - 1)
					var py: int = clamp(mark_cy_v + dy, 0, size - 1)
					img.set_pixel(px, py, Color(1.0, 0.65, 0.15, 1.0))
	return ImageTexture.create_from_image(img)

func _play_spawn_flash() -> void:
	if not is_inside_tree():
		return
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", Color(1.5, 1.3, 0.8, 1.0), SPAWN_FLASH_DURATION * 0.3)
	t.tween_property(self, "modulate", Color.WHITE, SPAWN_FLASH_DURATION * 0.7)
