extends Control

var kind := 0
var special := 0

const C_RED := Color("ff302d")
const C_BLUE := Color("19a9ff")
const C_GREEN := Color("52d51f")
const C_GOLD := Color("ffbd28")
const C_PURPLE := Color("9d29ff")
const C_PINK := Color("ff4f92")
const C_ICE := Color("55bdff")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_piece(next_kind: int, next_special: int) -> void:
	kind = next_kind
	special = next_special
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	if special == 4:
		_draw_portal(c, r)
		return
	match kind % 7:
		0:
			_draw_faceted_hex(c, r, C_RED)
		1:
			_draw_teardrop(c, r, C_BLUE)
		2:
			_draw_clover(c, r, C_GREEN)
		3:
			_draw_star_gem(c, r, C_GOLD)
		4:
			_draw_round_gem(c, r, C_PURPLE)
		5:
			_draw_heart(c, r, C_PINK)
		_:
			_draw_square_gem(c, r, C_ICE)
	_draw_special(c, r)


func _draw_faceted_hex(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col.darkened(0.10))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), col.lightened(0.55), 3.0)
	for p in pts:
		draw_line(c, p, Color(1, 1, 1, 0.38), 2.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.45), c + Vector2(r * 0.10, -r * 0.58), c + Vector2(r * 0.34, -r * 0.08), c + Vector2(-r * 0.18, r * 0.04)]), col.lightened(0.35))
	draw_arc(c, r * 1.08, 0, TAU, 36, col.darkened(0.45), 2.0)
	_draw_spark(c + Vector2(-r * 0.35, -r * 0.28), r * 0.16)


func _draw_teardrop(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0, -r * 1.08),
		c + Vector2(r * 0.78, -r * 0.08),
		c + Vector2(r * 0.44, r * 0.75),
		c + Vector2(0, r * 1.0),
		c + Vector2(-r * 0.44, r * 0.75),
		c + Vector2(-r * 0.78, -r * 0.08),
	])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), Color("bff4ff"), 3.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.40, -r * 0.16), c + Vector2(-r * 0.05, -r * 0.82), c + Vector2(r * 0.22, -r * 0.12), c + Vector2(-r * 0.08, r * 0.22)]), col.lightened(0.38))
	draw_line(c + Vector2(-r * 0.54, r * 0.12), c + Vector2(r * 0.54, r * 0.12), Color(1, 1, 1, 0.30), 2.0)
	_draw_spark(c + Vector2(-r * 0.28, -r * 0.42), r * 0.15)


func _draw_clover(c: Vector2, r: float, col: Color) -> void:
	for off in [Vector2(-0.34, -0.34), Vector2(0.34, -0.34), Vector2(-0.34, 0.34), Vector2(0.34, 0.34)]:
		draw_circle(c + off * r, r * 0.46, col.darkened(0.06))
		draw_circle(c + off * r + Vector2(-r * 0.08, -r * 0.08), r * 0.18, col.lightened(0.35))
	draw_circle(c, r * 0.20, col.darkened(0.22))
	draw_line(c + Vector2(0, r * 0.18), c + Vector2(r * 0.34, r * 0.86), col.darkened(0.35), 4.0)
	draw_arc(c, r * 0.88, 0, TAU, 40, Color("b8ff75"), 2.0)
	_draw_spark(c + Vector2(-r * 0.30, -r * 0.38), r * 0.12)


func _draw_star_gem(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.48
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	draw_polyline(_closed(pts), Color("fff1a2"), 3.0)
	for p in pts:
		draw_line(c, p, Color(1, 1, 1, 0.34), 1.8)
	draw_circle(c, r * 0.18, col.lightened(0.55))
	_draw_spark(c + Vector2(-r * 0.10, -r * 0.42), r * 0.15)


func _draw_round_gem(c: Vector2, r: float, col: Color) -> void:
	for i in 5:
		draw_circle(c, r * (1.0 - i * 0.13), col.lightened(0.06 * i).darkened(0.03 * (4 - i)))
	draw_arc(c, r, 0, TAU, 60, Color("efc7ff"), 3.0)
	for i in 8:
		var a := TAU * i / 8.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.92, Color(1, 1, 1, 0.25), 1.5)
	draw_circle(c + Vector2(-r * 0.30, -r * 0.34), r * 0.16, Color(1, 1, 1, 0.62))


func _draw_heart(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 42:
		var t := TAU * i / 42.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * (r / 17.0))
	draw_colored_polygon(pts, col)
	draw_polyline(_closed(pts), Color("ffc0d7"), 3.0)
	draw_circle(c + Vector2(-r * 0.28, -r * 0.20), r * 0.15, Color(1, 1, 1, 0.55))
	draw_line(c + Vector2(-r * 0.55, r * 0.10), c + Vector2(r * 0.50, r * 0.08), Color(1, 1, 1, 0.20), 2.0)


func _draw_square_gem(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-r * 0.78, -r * 0.78),
		c + Vector2(r * 0.78, -r * 0.78),
		c + Vector2(r * 0.78, r * 0.78),
		c + Vector2(-r * 0.78, r * 0.78),
	])
	draw_colored_polygon(pts, col)
	draw_polyline(_closed(pts), Color("c9f7ff"), 3.0)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.62, -r * 0.62),
		c + Vector2(r * 0.10, -r * 0.62),
		c + Vector2(-r * 0.22, r * 0.62),
		c + Vector2(-r * 0.62, r * 0.24),
	]), col.lightened(0.32))
	draw_line(c + Vector2(-r * 0.50, r * 0.45), c + Vector2(r * 0.54, -r * 0.48), Color(1, 1, 1, 0.28), 2.0)
	draw_arc(c, r * 1.02, 0, TAU, 4, Color("effcff"), 1.6)
	_draw_spark(c + Vector2(-r * 0.36, -r * 0.36), r * 0.14)


func _draw_portal(c: Vector2, r: float) -> void:
	for i in 5:
		draw_arc(c, r * (0.95 - i * 0.12), TAU * 0.1 * i, TAU * (0.86 + 0.08 * i), 60, Color(0.72, 0.20, 1.0, 0.80 - i * 0.10), 5.0 - i * 0.5)
	draw_circle(c, r * 0.42, Color("080014"))
	draw_arc(c, r * 1.06, 0, TAU, 60, Color("e05cff"), 2.0)


func _draw_special(c: Vector2, r: float) -> void:
	if special == 1:
		draw_line(c + Vector2(-r * 1.05, 0), c + Vector2(r * 1.05, 0), Color(1, 0.20, 0.24, 0.82), 6.0)
		draw_line(c + Vector2(-r * 1.05, 0), c + Vector2(r * 1.05, 0), Color(1, 1, 1, 0.75), 2.0)
	elif special == 2:
		draw_line(c + Vector2(0, -r * 1.05), c + Vector2(0, r * 1.05), Color(0.20, 0.85, 1, 0.82), 6.0)
		draw_line(c + Vector2(0, -r * 1.05), c + Vector2(0, r * 1.05), Color(1, 1, 1, 0.75), 2.0)
	elif special == 3:
		draw_arc(c, r * 1.12, 0, TAU, 40, Color(1.0, 0.84, 0.25, 0.9), 4.0)
		for i in 8:
			var a := TAU * i / 8.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * r * 1.16, Color(1.0, 0.80, 0.25, 0.35), 2.0)


func _draw_spark(c: Vector2, r: float) -> void:
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(1, 1, 1, 0.9), 2.0)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(1, 1, 1, 0.9), 2.0)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	if not points.is_empty():
		out.append(points[0])
	return out
