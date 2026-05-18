extends Node
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")
const Spotter := preload("res://core/Spotter.gd")
const UiKit := preload("res://ui/UiKit.gd")
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")

var state: String = "party"        # party -> inbox -> thread / judge -> ending
var sel: int = 0                   # 选中男人 index → Content.men()
var thread_i: int = 0              # 选中 thread index → PeekChat.threads()
var correct: int = 0               # 首判读对的人数 (重判不重复计)
var judged: Dictionary = {}        # man id -> bool(首判是否读对)
var _pending_guess: int = -1       # -1 无, 1 渣, 0 好 (judge 子步)
var _choice: String = ""
var _was_right: bool = false
var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func _man_now() -> Dictionary:
	var men: Array = Content.men()
	if men.is_empty() or sel < 0 or sel >= men.size():
		return {}
	return men[sel]

func open_inbox(i: int) -> void:
	if state != "party":
		return
	sel = i
	thread_i = 0
	state = "inbox"
	_render()

func open_thread(ti: int) -> void:
	if state != "inbox":
		return
	thread_i = ti
	state = "thread"
	_render()

func begin_judge() -> void:
	if state != "inbox":
		return
	_pending_guess = -1
	state = "judge"
	_render()

func back() -> void:
	match state:
		"thread":
			state = "inbox"
		"inbox":
			state = "party"
		"judge":
			_pending_guess = -1
			state = "inbox"
		_:
			return
	_render()

func _ask_choice(is_scum_guess: bool) -> void:
	if state != "judge":
		return
	_pending_guess = 1 if is_scum_guess else 0
	_render()

func judge(is_scum_guess: bool, choice: String) -> void:
	if state != "judge":
		return
	_choice = choice
	var m: Dictionary = _man_now()
	var truth: bool = Spotter.is_scumbag(m)
	_was_right = (is_scum_guess == truth)
	var id: String = str(m.get("id", ""))
	if not judged.has(id):
		judged[id] = _was_right
		if _was_right:
			correct += 1          # 首判才计;重判只更新角标,不重复计
	else:
		judged[id] = _was_right
	_pending_guess = -1
	state = "ending"
	_render()

func next_round() -> void:
	if state != "ending":
		return
	state = "party"
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	var r: Control = UiKit.screen("peek:%d:%d:%s" % [sel, thread_i, state])
	match state:
		"party": _build_party(r)
		"inbox": _build_inbox(r)
		"thread": _build_thread(r)
		"judge": _build_judge(r)
		"ending": _build_ending(r)
		_: _build_party(r)
	_layer.add_child(r)

func _preview(msgs: Array) -> String:
	if msgs.is_empty():
		return ""
	var t: String = str((msgs[msgs.size() - 1] as Dictionary).get("text", ""))
	if t.length() > 26:
		t = t.substr(0, 26) + "…"
	return t

func _build_party(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	UiKit.label(r, "PARTY_TITLE", T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.label(r, "PARTY_SUB", T.PAD, T.PAD + 86, T.SMALL, T.DIM, W)
	UiKit.label(r, Loc.t("SPOT_TALLY") % [correct, Content.men().size()], T.PAD, T.PAD + 150, T.SMALL, T.DIM, W)
	var men: Array = Content.men()
	var cv: Control = UiKit.hscroll(r, 0, 440, T.REF_W, T.CARD_H + 100)
	var CW: int = 300
	var x: int = T.PAD
	for i in men.size():
		var mi: int = i
		var m: Dictionary = men[i]
		var id: String = str(m.get("id", ""))
		UiKit.btn(cv, str(m.get("name", "")), x, 0, CW, T.CARD_H, func() -> void: open_inbox(mi))
		if judged.has(id):
			var won: bool = judged[id]
			UiKit.label(cv, Loc.t("MARK_RIGHT") if won else Loc.t("MARK_WRONG"), x + CW - 52, T.CARD_H + 12, T.SMALL, (T.ACCENT if won else T.DANGER))
		x += CW + T.GAP
	cv.custom_minimum_size = Vector2(x, T.CARD_H + 100)

func _build_inbox(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	UiKit.label(r, str(m.get("name", "")), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.btn(r, "THREAD_BACK", T.PAD, T.PAD + 96, 240, 96, back)
	UiKit.btn(r, "INBOX_JUDGE", T.PAD, T.REF_H - 300, W, T.BTN_H, begin_judge)
	var threads: Array = PeekChat.threads(m)
	var top: int = T.PAD + 230
	var cv: Control = UiKit.scroll(r, T.PAD, top, W, T.REF_H - top - 360)
	var y: int = 0
	for ti in threads.size():
		var idx_t: int = ti
		var th: Dictionary = threads[ti]
		var contact: String = str(th.get("contact", ""))
		var prev: String = _preview(th.get("msgs", []))
		UiKit.btn(cv, contact + "   ·   " + prev + "   ›", 0, y, W, T.BTN_H, func() -> void: open_thread(idx_t))
		y += T.BTN_H + T.GAP
		if ti == 0:
			var rule := ColorRect.new()
			rule.color = T.ACCENT
			rule.position = Vector2(0, y + 6)
			rule.size = Vector2(W, 2)
			cv.add_child(rule)
			UiKit.label(cv, "PEEK_HINGE", 0, y + 18, T.SMALL, T.ACCENT, W)
			y += 18 + 64 + T.GAP
	cv.custom_minimum_size = Vector2(W, y)

func _build_thread(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	var threads: Array = PeekChat.threads(m)
	var th: Dictionary = threads[thread_i] if thread_i >= 0 and thread_i < threads.size() else {}
	UiKit.label(r, str(th.get("contact", "")), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.btn(r, "THREAD_BACK", T.PAD, T.PAD + 96, 240, 96, back)
	var msgs: Array = th.get("msgs", [])
	var top: int = T.PAD + 230
	var cv: Control = UiKit.scroll(r, T.PAD, top, W, T.REF_H - top - 120)
	var y: int = 0
	var bw: int = int(float(W) * 0.78)
	for line in msgs:
		var d: Dictionary = line
		var mine: bool = str(d.get("from", "")) == "you"
		var bx: int = (W - bw) if mine else 0
		var pan: Panel = UiKit.bubble(cv, bx, y, bw, str(d.get("text", "")), mine)
		y += int(pan.size.y) + T.GAP
	cv.custom_minimum_size = Vector2(W, y)

func _build_judge(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	UiKit.label(r, str(m.get("name", "")) + " · " + Loc.t("SPOT_ASK"), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.btn(r, "THREAD_BACK", T.PAD, T.PAD + 96, 240, 96, back)
	var y: int = 380
	UiKit.btn(r, "SPOT_SCUM", T.PAD, y, W, T.BTN_H, func() -> void: _ask_choice(true))
	y += T.BTN_H + T.GAP
	UiKit.btn(r, "SPOT_GOOD", T.PAD, y, W, T.BTN_H, func() -> void: _ask_choice(false))
	if _pending_guess != -1:
		y += T.BTN_H + T.GAP * 2
		UiKit.label(r, "SPOT_ASK", T.PAD, y, T.SMALL, T.DIM, W)
		y += 64
		var guess_scum: bool = _pending_guess == 1
		for ch in [["expose", "SPOT_EXPOSE"], ["probe", "SPOT_PROBE"], ["leave", "SPOT_LEAVE"]]:
			var cid: String = ch[0]
			var clbl: String = ch[1]
			UiKit.btn(r, clbl, T.PAD, y, W, T.BTN_H, func() -> void: judge(guess_scum, cid))
			y += T.BTN_H + T.GAP

func _build_ending(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	var truth: bool = Spotter.is_scumbag(m)
	var nm: String = str(m.get("name", ""))
	var ekey: String = Spotter.ending_key(truth, _choice)
	var vkey: String = Spotter.verdict_key(_was_right, truth)
	UiKit.label(r, nm, T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.panel(r, T.PAD, 340, W, 360)
	UiKit.label(r, Loc.t(ekey) % nm, T.PAD + 40, 390, T.BODY, T.TEXT, W - 80)
	UiKit.label(r, Loc.t(vkey), T.PAD, 760, T.TITLE, (T.ACCENT if _was_right else T.DANGER), W)
	UiKit.btn(r, "SPOT_NEXT", T.PAD, T.REF_H - 320, W, T.BTN_H, next_round)
