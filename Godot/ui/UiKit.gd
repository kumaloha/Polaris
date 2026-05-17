extends RefCounted
class_name UiKit
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")

static var _f_sans: Font = null
static var _f_disp: Font = null
static var _f_loaded := false
static var _last_sig := " force"
static func _fonts() -> void:
	if _f_loaded: return
	_f_loaded = true
	if ResourceLoader.exists(T.FONT_SANS): _f_sans = load(T.FONT_SANS)
	if ResourceLoader.exists(T.FONT_DISPLAY): _f_disp = load(T.FONT_DISPLAY)
static func _apply_font(n: Control, display: bool) -> void:
	_fonts()
	var f: Font = _f_disp if display else _f_sans
	if f != null:
		n.add_theme_font_override("font", f)
static func _stylebox(bg: Color, border: Color, bw: int, rad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	return sb
static func screen(sig := " force") -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, T.BG_TOP); g.set_color(1, T.BG_BOT)
	grad.gradient = g
	grad.fill = GradientTexture2D.FILL_LINEAR
	grad.fill_from = Vector2(0.5, 0.0); grad.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = grad
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	r.add_child(bg)
	var glow := GradientTexture2D.new()
	var gg := Gradient.new()
	gg.set_color(0, Color(T.ACCENT.r, T.ACCENT.g, T.ACCENT.b, 0.10))
	gg.set_color(1, Color(0, 0, 0, 0))
	glow.gradient = gg
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.30); glow.fill_to = Vector2(1.05, 0.95)
	var gr := TextureRect.new()
	gr.texture = glow
	gr.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(gr)
	var do_fade := sig == " force" or sig != _last_sig
	if sig != " force":
		_last_sig = sig
	if do_fade:
		r.modulate = Color(1, 1, 1, 0)
		var tw := r.create_tween()
		tw.tween_property(r, "modulate", Color(1, 1, 1, 1), 0.18)
	else:
		r.modulate = Color(1, 1, 1, 1)
	return r
static func root(sig := " force") -> Control:
	return screen(sig)
static func panel(parent: Control, x: int, y: int, w: int, h: int, raised := false) -> Panel:
	var p := Panel.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.add_theme_stylebox_override("panel", _stylebox(T.PANEL_2 if raised else T.PANEL, T.STROKE, 1, T.RADIUS))
	parent.add_child(p)
	return p
static func label(parent: Control, text: String, x: int, y: int, size: int, col: Color, w := 0) -> Label:
	var l := Label.new()
	l.text = Loc.t(text)
	_apply_font(l, size >= T.TITLE)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.position = Vector2(x, y)
	if w > 0:
		l.size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l
static func btn(parent: Control, text: String, x: int, y: int, w: int, h: int, cb: Callable, sel := false) -> Button:
	var b := Button.new()
	b.text = Loc.t(text)
	_apply_font(b, false)
	b.add_theme_font_size_override("font_size", T.BODY)
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.add_theme_stylebox_override("normal", _stylebox(T.PANEL_SEL if sel else T.PANEL_2, T.ACCENT if sel else T.STROKE, 2 if sel else 1, T.RADIUS))
	b.add_theme_stylebox_override("hover", _stylebox(T.PANEL_SEL, T.ACCENT, 2, T.RADIUS))
	b.add_theme_stylebox_override("pressed", _stylebox(T.ACCENT_SOFT, T.ACCENT, 2, T.RADIUS))
	b.add_theme_stylebox_override("disabled", _stylebox(T.PANEL, T.STROKE, 1, T.RADIUS))
	b.add_theme_color_override("font_color", T.TEXT)
	b.add_theme_color_override("font_color_disabled", T.FAINT)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
static func bar(parent: Control, x: int, y: int, w: int, frac: float, col: Color) -> void:
	var track := Panel.new()
	track.position = Vector2(x, y); track.size = Vector2(w, 30)
	track.add_theme_stylebox_override("panel", _stylebox(T.PANEL, T.STROKE, 1, 15))
	parent.add_child(track)
	var fillw := int(clamp(frac, 0.0, 1.0) * float(w))
	if fillw > 0:
		var fill := Panel.new()
		fill.position = Vector2(x, y); fill.size = Vector2(fillw, 30)
		fill.add_theme_stylebox_override("panel", _stylebox(col, col, 0, 15))
		parent.add_child(fill)
static func navbar(parent: Control) -> Panel:
	var p := Panel.new()
	p.position = Vector2(0, T.REF_H - T.NAV_H)
	p.size = Vector2(T.REF_W, T.NAV_H)
	p.add_theme_stylebox_override("panel", _stylebox(T.PANEL_2, T.STROKE, 1, 0))
	parent.add_child(p)
	return p
