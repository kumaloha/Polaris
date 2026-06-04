extends Control
# 特效光环(纯 _draw)：
#   burst = BOMB 放射爆裂(宝石下方)
#   lineh / linev = 横/竖直线特效的利落光条(宝石上方)，替掉烤死在美术里的脏粉光束
# 配色统一金白(无粉)，干净不脏。

var mode := "burst"   # burst | lineh | linev

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if mode == "lineh":
		_line(true)
	elif mode == "linev":
		_line(false)
	else:
		_burst()

# 利落的方向光条：外发光 → 亮白核心 → 两端金色箭头。
func _line(horiz: bool) -> void:
	var c := size * 0.5
	var dir := Vector2(1, 0) if horiz else Vector2(0, 1)
	var ln: float = (size.x if horiz else size.y)
	var a := c - dir * (ln * 0.5)
	var b := c + dir * (ln * 0.5)
	draw_line(a, b, Color(0.96, 0.86, 0.55, 0.22), 16.0)   # 外发光
	draw_line(a, b, Color(1.0, 0.95, 0.72, 0.55), 9.0)     # 金芯
	draw_line(a, b, Color(1, 1, 1, 0.95), 3.5)             # 亮白核心
	var perp := Vector2(-dir.y, dir.x)
	var gold := Color("ffe6a8")
	for s in [-1.0, 1.0]:
		var sf := float(s)
		var tip: Vector2 = c + dir * (ln * 0.5 * sf)
		var bse: Vector2 = tip - dir * (13.0 * sf)
		draw_colored_polygon(PackedVector2Array([tip, bse + perp * 9.0, bse - perp * 9.0]), gold)

# 放射爆裂(BOMB)：金白同心辉光 + 锥形光束 + 尖端星。
func _burst() -> void:
	var c := size * 0.5
	var r := size.x * 0.5
	for k in 6:
		draw_circle(c, r * (0.78 - k * 0.10), Color(1.0, 0.88, 0.6, 0.05 + k * 0.018))
	var rays := 12
	for i in rays:
		var a := TAU * i / rays
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		var inner := c + dir * (r * 0.18)
		var tip := c + dir * (r * 1.04)
		var col := Color(1.0, 0.82, 0.46, 0.5) if i % 2 == 0 else Color(1.0, 0.95, 0.75, 0.4)
		draw_colored_polygon(PackedVector2Array([inner + perp * 4.5, tip, inner - perp * 4.5]), col)
	for i in rays:
		if i % 2 != 0:
			continue
		var a := TAU * i / rays
		var p := c + Vector2(cos(a), sin(a)) * (r * 0.98)
		_star(p, 3.2, Color(1.0, 0.95, 0.8, 0.85))

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.4
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
