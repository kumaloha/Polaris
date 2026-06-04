extends Control
# 爆炸形态特效(补 BOMB/T-L 缺失的专属图)：基础宝石后方叠一圈放射能量爆裂(粉金光束+辉光+星点)。
# 纯 _draw 程序绘制，呼应横/竖炸的能量风(横=横束、竖=竖束、炸=放射)。叠在宝石之下当光环。

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c := size * 0.5
	var R := size.x * 0.5
	# 中心放射辉光(粉)
	for k in 6:
		draw_circle(c, R * (0.78 - k * 0.10), Color(1.0, 0.62, 0.88, 0.05 + k * 0.018))
	# 放射光束(12 道锥形三角，粉/金交替)
	var rays := 12
	for i in rays:
		var a := TAU * i / rays
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		var inner := c + dir * (R * 0.18)
		var tip := c + dir * (R * 1.04)
		var wide := 4.5
		var col := Color(1.0, 0.45, 0.82, 0.55) if i % 2 == 0 else Color(1.0, 0.82, 0.46, 0.45)
		var poly := PackedVector2Array([inner + perp * wide, tip, inner - perp * wide])
		draw_colored_polygon(poly, col)
	# 光束尖端小星
	for i in rays:
		if i % 2 != 0:
			continue
		var a := TAU * i / rays
		var p := c + Vector2(cos(a), sin(a)) * (R * 0.98)
		_star(p, 3.2, Color(1.0, 0.95, 0.8, 0.85))

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.4
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
