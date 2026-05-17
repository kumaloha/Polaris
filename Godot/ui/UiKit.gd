extends RefCounted
class_name UiKit
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")
static func root() -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = T.BG_TOP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(bg)
	return r
static func label(p: Control, text: String, x: int, y: int, sz: int, col: Color, w := 0) -> Label:
	var l := Label.new()
	l.text = Loc.t(text)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.position = Vector2(x, y)
	if w > 0:
		l.size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return l
static func btn(p: Control, text: String, x: int, y: int, w: int, h: int, cb: Callable, sel := false) -> Button:
	var b := Button.new()
	b.text = Loc.t(text)
	b.add_theme_font_size_override("font_size", T.BODY)
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = T.PANEL_SEL if sel else T.PANEL
	sb.border_color = T.ACCENT
	sb.set_border_width_all(2 if sel else 0)
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", T.TEXT)
	b.pressed.connect(cb)
	p.add_child(b)
	return b
