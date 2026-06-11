class_name IngOverlay
extends OverlayBase
## 原料 Overlay（ing 层, §3.1）。
## ing 是 int 档（>0=有原料），随重力下落，到出口列收集后→0。
## z=4：与 gem 互斥层，替换 gem 形象显示在棋子之上但位于外壳之下。
## 程序绘制：橙黄色圆 + 中心白点（模拟糖果原料），分档变色。
## TEXTURE_PATHS 预留，有素材时换图。
##
## on_step: ing 层不通过 account_clears 通知（收集在 apply_gravity/exits 处理）
##   → 采用 §3.5 自查模式：每步 refresh() 确认 current_value 变化。
## 归 0: 放大消失（收集动效）。

# ── 素材占位 ──
const TEXTURE_PATHS := {
	1: "",   # 原料档 1 贴图（空=程序绘制）
	2: "",   # 原料档 2 贴图
	3: "",   # 原料档 3 贴图
}

# ── 程序绘制颜色（按档）──
const COLORS_BY_GRADE := [
	Color(1.00, 0.75, 0.15, 1.0),   # 档 1 橙黄
	Color(0.95, 0.40, 0.15, 1.0),   # 档 2 橙红
	Color(0.80, 0.20, 0.50, 1.0),   # 档 3 品红
]
const COLOR_HIGHLIGHT  := Color(1.0, 1.0, 1.0, 0.75)

const COLLECT_DURATION := 0.18
const FADE_DURATION    := 0.16

var _sprite: Sprite2D
var _last_value: int = 0

# ── static 元信息 ──

static func layer_key() -> String:
	return "ing"

static func z_band() -> int:
	return Z_ING   # 4: 替换 gem 形象

# ── 生命周期 ──

func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	super(p_cell, p_board, p_cell_px)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_last_value = current_value()
	_apply_grade(_last_value)

## ing 收集不在 account 中，用自查模式。
## board_view 在每步末尾对 ing overlay 调一次 refresh()。
func refresh() -> void:
	var val: int = current_value()
	if val != _last_value:
		if val <= 0:
			on_cleared()
			return
		_apply_grade(val)
	_last_value = val

func on_step(_report: Dictionary) -> void:
	# ing 层变化不经 account，on_step 不处理；由 refresh() 自查。
	pass

func on_cleared() -> void:
	if not is_inside_tree():
		queue_free()
		return
	# 收集动效：放大 + 快速淡出
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.35, 1.35), COLLECT_DURATION * 0.45)
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
	var idx: int = clamp(value - 1, 0, COLORS_BY_GRADE.size() - 1)
	_sprite.texture = _make_ing_texture(COLORS_BY_GRADE[idx])

func _make_ing_texture(base_color: Color) -> ImageTexture:
	var size: int = int(_cell_px * 0.80)
	if size <= 0:
		size = 52
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = size * 0.5
	var cy: float = size * 0.5
	var radius: float = size * 0.42
	# 主圆
	for y in size:
		for x in size:
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, base_color)
	# 高光点（左上 1/4 处）
	var hl_cx: int = int(cx - radius * 0.30)
	var hl_cy: int = int(cy - radius * 0.30)
	var hl_r: int = max(2, int(radius * 0.22))
	for dy in range(-hl_r, hl_r + 1):
		for dx in range(-hl_r, hl_r + 1):
			if dx * dx + dy * dy <= hl_r * hl_r:
				var px: int = clamp(hl_cx + dx, 0, size - 1)
				var py: int = clamp(hl_cy + dy, 0, size - 1)
				img.set_pixel(px, py, COLOR_HIGHLIGHT)
	return ImageTexture.create_from_image(img)
