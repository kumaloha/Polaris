extends Node
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")
const UiKit := preload("res://ui/UiKit.gd")
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")

var state: String = "list"      # "list" | "reveal"
var sel_id: String = ""
var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func _man(id: String) -> Dictionary:
	for m in Content.men():
		if m["id"] == id:
			return m
	return {}

func open_reveal(id: String) -> void:
	sel_id = id
	state = "reveal"
	_render()

func back_to_list() -> void:
	state = "list"
	sel_id = ""
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	var sig: String = "list" if state == "list" else "reveal:" + sel_id
	var r: Control = UiKit.screen(sig)
	if state == "list":
		_build_list(r)
	else:
		_build_reveal(r)
	_layer.add_child(r)

func _build_list(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	UiKit.label(r, "PEEK_TITLE", T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.label(r, "PEEK_LIST_SUB", T.PAD, T.PAD + 86, T.SMALL, T.DIM, W)
	var y: int = T.PAD + 220
	for m in Content.men():
		var mid: String = m["id"]
		var nm: String = str(m["name"])
		var lead: String = Loc.t("PEEK_ROW_LEAD")
		UiKit.btn(r, nm + "   ·   " + lead, T.PAD, y, W, T.BTN_H, func() -> void: open_reveal(mid))
		y += T.BTN_H + T.GAP

func _build_reveal(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var man: Dictionary = _man(sel_id)
	var p: Dictionary = PeekChat.peek(man)
	var to_you: Array = p.get("to_you_chat", [])
	var others: Array = p["others_chat"]
	UiKit.label(r, str(p["name"]), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.label(r, "PEEK_REVEAL_SUB", T.PAD, T.PAD + 86, T.SMALL, T.DIM, W)
	UiKit.btn(r, "PEEK_BACK", T.PAD, T.REF_H - 170, 300, 120, func() -> void: back_to_list())
	var top: int = T.PAD + 200
	var body: Control = UiKit.scroll(r, T.PAD, top, W, T.REF_H - top - 210)
	var y: int = 0
	y = _section(body, "PEEK_TO_YOU", to_you, y, false, W)
	y = _hinge(body, y, W)
	y = _section(body, "PEEK_TO_OTHERS", others, y, true, W)
	body.custom_minimum_size = Vector2(W, y)

func _section(cv: Control, title_key: String, lines: Array, y0: int, show_to: bool, W: int) -> int:
	var y: int = y0
	UiKit.label(cv, title_key, 0, y, T.SMALL, T.DIM, W)
	y += 70
	var bw: int = int(float(W) * 0.84)
	var inner_w: int = bw - 60
	for line in lines:
		var tx: String = str(line["text"])
		# Deterministic bubble height: estimate wrapped rows from text length
		# at T.BODY in inner_w (conservative chars/line → over-provision).
		# Generous height is free inside the scroll container; a clipped
		# gut-punch line is not.
		var per_line: int = max(1, int(float(inner_w) / float(T.BODY) * 1.6))
		var rows: int = int(ceil(float(tx.length()) / float(per_line)))
		if rows < 1:
			rows = 1
		var bh: int = rows * int(float(T.BODY) * 1.4) + 60
		if bh < 120:
			bh = 120
		var pan: Panel = UiKit.panel(cv, 0, y, bw, bh)
		UiKit.label(pan, tx, 30, 26, T.BODY, T.TEXT, inner_w)
		if show_to:
			var who: String = str(line.get("to", ""))
			if who != "":
				UiKit.label(cv, who, 8, y + bh + 4, T.TINY, T.FAINT, bw)
				y += bh + 4 + 38 + T.GAP
			else:
				y += bh + T.GAP
		else:
			y += bh + T.GAP
	return y + 28

func _hinge(cv: Control, y0: int, W: int) -> int:
	var y: int = y0 + 18
	var rule := ColorRect.new()
	rule.color = T.ACCENT
	rule.position = Vector2(0, y)
	rule.size = Vector2(W, 2)
	cv.add_child(rule)
	UiKit.label(cv, "PEEK_HINGE", 0, y + 18, T.SMALL, T.ACCENT, W)
	return y + 18 + 64 + 28
