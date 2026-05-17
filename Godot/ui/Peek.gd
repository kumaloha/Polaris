extends Node
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")
const Spotter := preload("res://core/Spotter.gd")
const UiKit := preload("res://ui/UiKit.gd")
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")

var state: String = "intel"        # intel -> face -> ending -> (next) intel
var idx: int = 0
var seen: int = 0
var correct: int = 0
var _choice: String = ""
var _was_right: bool = false
var _pending_guess: int = -1       # -1 none, 1 scum, 0 good (face sub-step)
var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func _man_now() -> Dictionary:
	var men: Array = Content.men()
	if men.is_empty():
		return {}
	return men[idx % men.size()]

func reveal_face() -> void:
	if state != "intel":
		return
	_pending_guess = -1
	state = "face"
	_render()

func judge(is_scum_guess: bool, choice: String) -> void:
	if state != "face":
		return
	_choice = choice
	var truth: bool = Spotter.is_scumbag(_man_now())
	_was_right = (is_scum_guess == truth)
	if _was_right:
		correct += 1
	_pending_guess = -1
	state = "ending"
	_render()

func next_round() -> void:
	if state != "ending":
		return
	seen += 1
	idx += 1
	_pending_guess = -1
	state = "intel"
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	var r: Control = UiKit.screen("spot:%d:%s" % [idx, state])
	match state:
		"intel": _build_intel(r)
		"face": _build_face(r)
		"ending": _build_ending(r)
		_: _build_intel(r)
	_layer.add_child(r)

func _sharp_line(others: Array) -> String:
	if others.is_empty():
		return ""
	var ln: Dictionary = others[0]
	return "（对%s）%s" % [str(ln.get("to", "")), str(ln.get("text", ""))]

func _build_intel(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var p: Dictionary = PeekChat.peek(_man_now())
	UiKit.label(r, "SPOT_INTEL", T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.label(r, Loc.t("SPOT_TALLY") % [correct, seen], T.PAD, T.PAD + 90, T.SMALL, T.DIM, W)
	var others: Array = p.get("others_chat", [])
	UiKit.panel(r, T.PAD, 360, W, 360)
	UiKit.label(r, _sharp_line(others), T.PAD + 40, 410, T.BODY, T.TEXT, W - 80)
	UiKit.btn(r, "SPOT_FACE", T.PAD, T.REF_H - 320, W, T.BTN_H, reveal_face)

func _build_face(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var p: Dictionary = PeekChat.peek(_man_now())
	var to_you: Array = p.get("to_you_chat", [])
	var line := ""
	if not to_you.is_empty():
		line = str((to_you[0] as Dictionary).get("text", ""))
	UiKit.label(r, str(p.get("name", "")) + " · " + Loc.t("SPOT_FACE"), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.panel(r, T.PAD, 320, W, 300)
	UiKit.label(r, line, T.PAD + 40, 370, T.BODY, T.TEXT, W - 80)
	UiKit.label(r, "SPOT_ASK", T.PAD, 700, T.SMALL, T.DIM, W)
	var y := 780
	UiKit.btn(r, "SPOT_SCUM", T.PAD, y, W, T.BTN_H, func() -> void: _ask_choice(true))
	y += T.BTN_H + T.GAP
	UiKit.btn(r, "SPOT_GOOD", T.PAD, y, W, T.BTN_H, func() -> void: _ask_choice(false))
	if _pending_guess != -1:
		y += T.BTN_H + T.GAP * 2
		UiKit.label(r, "SPOT_ASK", T.PAD, y, T.SMALL, T.DIM, W); y += 64
		var guess_scum: bool = _pending_guess == 1
		for ch in [["expose", "SPOT_EXPOSE"], ["probe", "SPOT_PROBE"], ["leave", "SPOT_LEAVE"]]:
			var cid: String = ch[0]
			var clbl: String = ch[1]
			UiKit.btn(r, clbl, T.PAD, y, W, T.BTN_H, func() -> void: judge(guess_scum, cid))
			y += T.BTN_H + T.GAP

func _ask_choice(is_scum_guess: bool) -> void:
	if state != "face":
		return
	_pending_guess = 1 if is_scum_guess else 0
	_render()

func _build_ending(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	var truth: bool = Spotter.is_scumbag(m)
	var key: String = Spotter.ending_key(truth, _choice)
	var nm: String = str(m.get("name", ""))
	UiKit.label(r, nm, T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.panel(r, T.PAD, 340, W, 360)
	UiKit.label(r, Loc.t(key) % nm, T.PAD + 40, 390, T.BODY, T.TEXT, W - 80)
	var verdict := "你看穿了。" if _was_right else "你被他骗了。"
	UiKit.label(r, verdict, T.PAD, 760, T.TITLE, (T.ACCENT if _was_right else T.DANGER), W)
	UiKit.btn(r, "SPOT_NEXT", T.PAD, T.REF_H - 320, W, T.BTN_H, next_round)
