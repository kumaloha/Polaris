extends Control
# 占星/魔法风背景：深蓝竖向渐变 + 中心柔光 + 星点 + 可选魔法阵(金环+刻度+四方星)。
# 纯 _draw 绘制，零美术依赖；首页/对局/角色屏共用，保证视觉统一(对齐 resources/board.png 调性)。

const VIEW_W := 720.0
const VIEW_H := 920.0

@export var show_circle: bool = false
@export var circle_center: Vector2 = Vector2(360, 410)
@export var circle_radius: float = 230.0
@export var glow_center: Vector2 = Vector2(360, 430)

var _stars: Array = []   # [pos:Vector2, r:float, a:float]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260604
	for i in 110:
		_stars.append([
			Vector2(rng.randf() * VIEW_W, rng.randf() * VIEW_H),
			rng.randf_range(0.6, 2.3),
			rng.randf_range(0.18, 0.92),
		])

func _draw() -> void:
	# 竖向渐变：深navy → 蓝 → 稍亮蓝
	var top := Color("141d38")
	var mid := Color("253f6e")
	var bot := Color("3f5f93")
	var bands := 60
	for i in bands:
		var t := float(i) / bands
		var c := top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(bot, (t - 0.5) * 2.0)
		draw_rect(Rect2(0, t * VIEW_H, VIEW_W, VIEW_H / bands + 1.0), c)
	# 中心柔光(英雄台后方的云光)：多层同心半透明圆
	for k in 7:
		var rr := 300.0 - k * 32.0
		var a := 0.05 + k * 0.012
		draw_circle(glow_center, rr, Color(0.75, 0.86, 1.0, a))
	# 星点
	for s in _stars:
		draw_circle(s[0], s[1], Color(1, 1, 1, s[2]))
	# 魔法阵
	if show_circle:
		_draw_magic_circle(circle_center, circle_radius)

func _draw_magic_circle(c: Vector2, r: float) -> void:
	var gold := Color("e9c97c")
	var gold_dim := Color(0.91, 0.79, 0.49, 0.45)
	draw_arc(c, r, 0, TAU, 120, gold_dim, 2.0, true)
	draw_arc(c, r * 0.985, 0, TAU, 120, gold, 1.4, true)
	draw_arc(c, r * 0.80, 0, TAU, 120, gold_dim, 1.4, true)
	# 内圈刻度(点阵)
	var ticks := 60
	for i in ticks:
		var a := TAU * i / ticks
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (r * 0.80), c + dir * (r * 0.76), gold_dim, 1.0)
	# 四方星徽
	for k in 4:
		var a := PI * 0.5 * k - PI * 0.5
		_draw_star(c + Vector2(cos(a), sin(a)) * r, 9.0, gold)
	# 散落小星
	for k in 12:
		var a := TAU * k / 12 + 0.26
		_draw_star(c + Vector2(cos(a), sin(a)) * (r * 0.9), 3.2, Color(1, 0.94, 0.78, 0.8))

func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.4
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
