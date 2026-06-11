class_name JellyOverlay
extends OverlayBase
## 果冻底片 Overlay（契约 B §3.5 最简形态）。
## 没有现成 jelly 素材, 以程序绘制为占位 —— 半透明圆角色块双层分级:
##   层数 2 → 深色（α 0.55）; 层数 1 → 浅色（α 0.30）。
## TEXTURE_PATHS 预留, 有素材时换图极简。
##
## on_step: 读 report.account.jelly_cleared > 0 且 current_value 下降 → 播碎裂 + 换分级。
## 归 0:    on_cleared 渐隐后 free。

# ── 素材占位（有图时填路径）──
const TEXTURE_PATHS := {
	2: "",   # jelly 层数 2 对应的贴图路径（空=程序绘制）
	1: "",   # jelly 层数 1 对应的贴图路径（空=程序绘制）
}

# ── 程序绘制颜色 ──
const COLOR_LAYER_2 := Color(0.18, 0.52, 0.90, 0.55)   # 深蓝, 层数 2
const COLOR_LAYER_1 := Color(0.42, 0.72, 0.98, 0.30)   # 浅蓝, 层数 1
const CORNER_RADIUS := 6.0

# ── 渐隐常量 ──
const FADE_DURATION := 0.22

var _sprite: Sprite2D
var _last_value: int = 0

# ── static 元信息 ──

static func layer_key() -> String:
	return "jelly"

static func z_band() -> int:
	return Z_JELLY   # 2: 棋子之下的底片

# ── 生命周期 ──

func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	super(p_cell, p_board, p_cell_px)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_last_value = current_value()
	_apply_grade(_last_value)

func on_step(report: Dictionary) -> void:
	var account: Dictionary = report.get("account", {})
	if account.get("jelly_cleared", 0) <= 0:
		return
	var new_val := current_value()
	if new_val < _last_value:
		_play_shatter()
		_apply_grade(new_val)
	_last_value = new_val
	if new_val <= 0:
		on_cleared()

func on_cleared() -> void:
	# 渐隐后 queue_free（不阻塞主循环）
	if not is_inside_tree():
		queue_free()
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	t.tween_callback(queue_free)

# ── 内部 ──

func _apply_grade(value: int) -> void:
	match value:
		2:
			_sprite.texture = _make_texture(COLOR_LAYER_2)
		1:
			_sprite.texture = _make_texture(COLOR_LAYER_1)
		_:
			pass   # 归 0 由 on_cleared 处理

func _make_texture(color: Color) -> ImageTexture:
	# 优先用声明的贴图路径
	var grade: int = _last_value
	var path: String = TEXTURE_PATHS.get(grade, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	# 程序绘制：半透明圆角色块
	var size := int(_cell_px)
	if size <= 0:
		size = 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var half := size * 0.5
	var r := CORNER_RADIUS
	for y in size:
		for x in size:
			var fx2 := float(x)
			var fy2 := float(y)
			# 圆角判断：四个角落区域外圆弧
			var in_corner := false
			var dx := 0.0
			var dy := 0.0
			if fx2 < r and fy2 < r:
				dx = r - fx2; dy = r - fy2
				in_corner = true
			elif fx2 >= size - r and fy2 < r:
				dx = fx2 - (size - r - 1.0); dy = r - fy2
				in_corner = true
			elif fx2 < r and fy2 >= size - r:
				dx = r - fx2; dy = fy2 - (size - r - 1.0)
				in_corner = true
			elif fx2 >= size - r and fy2 >= size - r:
				dx = fx2 - (size - r - 1.0); dy = fy2 - (size - r - 1.0)
				in_corner = true
			if in_corner and dx * dx + dy * dy > r * r:
				continue
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

func _play_shatter() -> void:
	# 调 Fx.spawn_shatter（autoload，不存在时静默降级）
	if Engine.has_singleton("Fx"):
		var fx = Engine.get_singleton("Fx")
		var world_pos := global_position
		fx.spawn_shatter(world_pos, COLOR_LAYER_2)
	else:
		# 无 Fx（headless/demo）：简单缩放抖动
		if not is_inside_tree():
			return
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.06)
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
