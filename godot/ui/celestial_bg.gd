extends Control
# 占星/魔法风背景：深蓝竖向渐变 + 中心柔光 + 星点 + 可选魔法阵(金环+刻度+四方星)。
# 纯 _draw 绘制，零美术依赖；首页/对局/角色屏共用，保证视觉统一(对齐 resources/board.png 调性)。

const VIEW_W := 720.0
const VIEW_H := 1520.0

@export var show_circle: bool = false
@export var circle_center: Vector2 = Vector2(360, 600)
@export var circle_radius: float = 250.0
@export var glow_center: Vector2 = Vector2(360, 620)
@export var light_mode: bool = false   # 浅蓝通透星空(对局，对齐 board.png)；否则深蓝(首页)
@export var planets: bool = false       # 魔法阵环上的小行星(彩球)
@export var inner_ring: bool = true     # true=内环+刻度(首页小阵)；false=外侧细环(对局大阵，避免切到棋盘)

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
	# 竖向渐变：首页深navy；对局浅蓝通透(对齐 board.png)
	var top := Color("141d38")
	var mid := Color("253f6e")
	var bot := Color("3f5f93")
	if light_mode:
		top = Color("adc5ed")
		mid = Color("8aaadd")
		bot = Color("6c8dc8")
	var bands := 60
	for i in bands:
		var t := float(i) / bands
		var c := top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(bot, (t - 0.5) * 2.0)
		draw_rect(Rect2(0, t * VIEW_H, VIEW_W, VIEW_H / bands + 1.0), c)
	# 中心柔光(英雄台/棋盘后方的云光)：多层同心半透明圆
	for k in 7:
		var rr := 320.0 - k * 34.0
		var a := (0.05 + k * 0.012) * (1.8 if light_mode else 1.0)
		draw_circle(glow_center, rr, Color(1, 1, 1, a) if light_mode else Color(0.75, 0.86, 1.0, a))
	# 星点
	for s in _stars:
		draw_circle(s[0], s[1], Color(1, 1, 1, s[2] * (0.65 if light_mode else 1.0)))
	# 魔法阵
	if show_circle:
		_draw_magic_circle(circle_center, circle_radius)

func _draw_magic_circle(c: Vector2, r: float) -> void:
	var gold := Color("e9c97c")
	var gold_dim := Color(0.91, 0.79, 0.49, 0.45)
	draw_arc(c, r, 0, TAU, 140, gold_dim, 2.0, true)
	draw_arc(c, r * 0.985, 0, TAU, 140, gold, 1.6, true)
	if inner_ring:
		draw_arc(c, r * 0.80, 0, TAU, 120, gold_dim, 1.4, true)
		var ticks := 60
		for i in ticks:
			var a := TAU * i / ticks
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * (r * 0.80), c + dir * (r * 0.76), gold_dim, 1.0)
	else:
		# 对局大阵：双层金环在棋盘外侧，环间刻度(对齐 board.png)
		draw_arc(c, r * 1.07, 0, TAU, 150, gold_dim, 1.4, true)
		var ticks2 := 72
		for i in ticks2:
			var a := TAU * i / ticks2
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * r, c + dir * (r * 1.05), gold_dim, 1.0)
	# 四方星徽
	for k in 4:
		var a := PI * 0.5 * k - PI * 0.5
		_draw_star(c + Vector2(cos(a), sin(a)) * r, 11.0, gold)
	# 环上行星(彩球，对齐 board.png)
	if planets:
		var pcols := [Color("8fb7e6"), Color("b89be0"), Color("e0b07a"), Color("9fd0ea"), Color("c98fb0"), Color("d9c074")]
		for k in pcols.size():
			var pa := TAU * k / pcols.size() + 0.42
			var pp := c + Vector2(cos(pa), sin(pa)) * (r * 1.07 if k % 2 == 0 else r)
			draw_circle(pp, 12.0, pcols[k])
			draw_circle(pp + Vector2(-3, -3), 4.0, Color(1, 1, 1, 0.55))
			draw_arc(pp, 12.0, 0, TAU, 24, Color(1, 1, 1, 0.4), 1.4, true)
	# 散落小星
	for k in 12:
		var a := TAU * k / 12 + 0.26
		_draw_star(c + Vector2(cos(a), sin(a)) * (r * (0.9 if inner_ring else 1.03)), 3.2, Color(1, 0.94, 0.78, 0.8))

func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.4
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
