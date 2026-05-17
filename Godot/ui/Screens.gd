extends RefCounted
class_name Screens
const T := preload("res://ui/Theme.gd")
const Content := preload("res://core/Content.gd")
const UICtl := preload("res://ui/UIController.gd")
const Loc := preload("res://ui/Loc.gd")

static func _root() -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = T.BG_TOP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(bg)
	return r

static func _label(parent: Control, text: String, x: int, y: int, size: int, col: Color, w := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.position = Vector2(x, y)
	if w > 0:
		l.size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

static func _btn(parent: Control, text: String, x: int, y: int, w: int, h: int, cb: Callable, selected := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", T.BODY)
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = T.PANEL_SEL if selected else T.PANEL
	sb.border_color = T.ACCENT
	sb.set_border_width_all(2 if selected else 0)
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", T.TEXT)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

static func _loc_msg(msg: String) -> String:
	# Translate the "(still on your book: <decision>)" pattern from SeasonFlow
	if msg.begins_with("(still on your book:"):
		var decision := msg.trim_prefix("(still on your book: ").trim_suffix(")")
		return "（仍在账上：%s）" % Loc.t(decision)
	# Translate [MIRROR] / [BOOK] prefixed log lines
	if msg.begins_with("[MIRROR] "):
		return Loc.t("[MIRROR] ") + Loc.t(msg.trim_prefix("[MIRROR] "))
	if msg.begins_with("[BOOK] "):
		# format: "[BOOK] <man_id>: <event>"
		var body := msg.trim_prefix("[BOOK] ")
		var parts := body.split(": ", false, 1)
		if parts.size() == 2:
			return Loc.t("[BOOK] ") + Loc.t(parts[0]) + "：" + Loc.t(parts[1])
		return Loc.t("[BOOK] ") + Loc.t(body)
	return Loc.t(msg)

static func _hud(parent: Control, ctrl) -> void:
	var s = ctrl.flow.state.snapshot()
	var txt := "DAY %d   ·   S%d W%d   ·   E%d  C%d  P%d  Ctl%d   ·   net %d" % [
		s.day, s.season, s.week, s.energy, s.charm, s.position, s.control, s.net_worth]
	_label(parent, txt, T.PAD, T.PAD, T.SMALL, T.DIM)

static func build(ctrl) -> Control:
	var r := _root()
	_hud(r, ctrl)
	var W: int = T.REF_W - T.PAD * 2
	match ctrl.screen:
		UICtl.S.READY:
			_label(r, Loc.t("READY ROOM"), T.PAD, 200, T.TITLE, T.ACCENT)
			_label(r, Loc.t("Invest in yourself before you walk in. You decide who's worth your energy."), T.PAD, 290, T.SMALL, T.DIM, W)
			var y := 430
			_label(r, Loc.t("TONIGHT'S BUILD"), T.PAD, y, T.SMALL, T.DIM)
			y += 60
			for c in Content.self_investments():
				var sel: bool = ctrl.ui.get("self_invest", "") == c.id
				_btn(r, Loc.t(c.name), T.PAD, y, W, T.BTN_H,
					func(): ctrl.ui["self_invest"] = c.id; ctrl._render(), sel)
				y += T.BTN_H + 18
			y += 20
			_label(r, Loc.t("PERSONA"), T.PAD, y, T.SMALL, T.DIM)
			y += 60
			for p in Content.personas():
				var ps: bool = ctrl.ui.get("persona", "") == p.id
				_btn(r, Loc.t(p.name), T.PAD, y, W, T.BTN_H,
					func(): ctrl.ui["persona"] = p.id; ctrl._render(), ps)
				y += T.BTN_H + 18
			_btn(r, Loc.t("GO TO GIRLFRIEND NIGHT  →"), T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_begin_night())
		UICtl.S.MAP:
			_label(r, Loc.t("GIRLFRIEND NIGHT"), T.PAD, 200, T.TITLE, T.ACCENT)
			_label(r, Loc.t("Your circle decides which rooms you get into."), T.PAD, 290, T.SMALL, T.DIM, W)
			var y := 420
			for gfx in Content.girlfriends():
				_label(r, "%s — %s" % [Loc.t(gfx.name), Loc.t(gfx.role)], T.PAD, y, T.BODY, T.TEXT)
				y += 70
			y += 30
			_label(r, Loc.t("PARTY MAP"), T.PAD, y, T.SMALL, T.DIM)
			y += 60
			for p in ctrl.flow.available_parties():
				var tag: String = "" if p.unlocked else Loc.t("  · LOCKED (tier %d)") % p.tier
				if p.unlocked:
					var pid: String = p.id
					_btn(r, Loc.t(p.name) + tag, T.PAD, y, W, T.BTN_H,
						func(): ctrl.act_choose_party(pid))
				else:
					var lb := _btn(r, Loc.t(p.name) + tag, T.PAD, y, W, T.BTN_H, func(): pass)
					lb.disabled = true
				y += T.BTN_H + 18
		UICtl.S.FIRST_EYE:
			_label(r, Loc.t("FIRST EYE"), T.PAD, 200, T.TITLE, T.ACCENT)
			_label(r, Loc.t("Surface only. The truth is in the signs, not the words."), T.PAD, 290, T.SMALL, T.DIM, W)
			var y := 420
			for m in ctrl.flow.party_men():
				var line := "%s   ·   %s\n%s %s\n\"%s\"" % [
					Loc.t(m.name), Loc.t(m.surface),
					Loc.t("risk:"), Loc.t(m.risk),
					Loc.t(m["chat"][0]["text"])]
				var mid: String = m.id
				_btn(r, line, T.PAD, y, W, T.CARD_H + 60,
					func(): ctrl.act_enter_party(mid))
				y += T.CARD_H + 80
		UICtl.S.PARTY:
			var st = ctrl.enc.read()
			_label(r, Loc.t("PARTY") + "  ·  round %d / %d" % [st["round"], st["of"]], T.PAD, 200, T.TITLE, T.ACCENT)
			var ly := 330
			for line in ctrl.party_log:
				_label(r, "“" + _loc_msg(line) + "”", T.PAD, ly, T.BODY, T.TEXT, W)
				ly += 130
			var by := T.REF_H - (T.BTN_H + 18) * 4 - T.PAD
			for a in ["engage", "boundary", "social_proof", "exit"]:
				var act: String = a
				_btn(r, Loc.t(a.to_upper().replace("_", " ")), T.PAD, by, W, T.BTN_H,
					func(): ctrl.act_party(act))
				by += T.BTN_H + 18
		UICtl.S.AFTER:
			_label(r, Loc.t("AFTER PARTY"), T.PAD, 200, T.TITLE, T.ACCENT)
			_label(r, Loc.t("Decide where your energy goes. You can only Date one."), T.PAD, 290, T.SMALL, T.DIM, W)
			if not ctrl.ui.has("after"):
				ctrl.ui["after"] = {}
			var y := 420
			for entry in ctrl.flow.book_for_after():
				_label(r, "%s: \"%s\"  — %s" % [Loc.t(entry.name), _loc_msg(entry.message), Loc.t(entry.snark)], T.PAD, y, T.SMALL, T.DIM, W)
				y += 90
				var bx := T.PAD
				var bw := (W - T.GAP * 3) / 4
				for ch in ["date", "observe", "test", "cut"]:
					var mid: String = entry.man_id
					var choice: String = ch
					var seld: bool = ctrl.ui["after"].get(mid, "") == choice
					_btn(r, Loc.t(ch), bx, y, bw, T.BTN_H,
						func(): ctrl.ui["after"][mid] = choice; ctrl._render(), seld)
					bx += bw + T.GAP
				y += T.BTN_H + 40
			_btn(r, Loc.t("CONFIRM  →"), T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_after(ctrl.ui["after"]))
		UICtl.S.FUTURE:
			_label(r, Loc.t("FUTURE EYE"), T.PAD, 200, T.TITLE, T.ACCENT)
			var y := 320
			for fp in ctrl.future_payload:
				_label(r, "%s — %s" % [Loc.t(fp.man_id), Loc.t(fp.result)], T.PAD, y, T.BODY, T.ACCENT)
				y += 80
				for kf in fp.keyframes:
					_label(r, "·  " + Loc.t(str(kf)), T.PAD + 20, y, T.SMALL, T.TEXT, W - 20)
					y += 56
				if str(fp.mirror) != "":
					y += 20
					_label(r, Loc.t(str(fp.mirror)), T.PAD, y, T.SMALL, Color(0.85, 0.35, 0.35), W)
					y += 110
				y += 40
			_btn(r, Loc.t("CONTINUE  →"), T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_continue_from_future())
		UICtl.S.WEEK:
			var stl = ctrl.ui.get("settle", {})
			_label(r, Loc.t("WEEK SETTLEMENT"), T.PAD, 260, T.TITLE, T.ACCENT)
			_label(r, "%s %s  ·  %s %s  ·  %s %s" % [
				Loc.t("Net worth"), str(stl.get("net_worth", 0)),
				Loc.t("keyframes"), str(stl.get("keyframes", 0)),
				Loc.t("debts"), str(stl.get("debts", 0))],
				T.PAD, 380, T.BODY, T.TEXT, W)
			_btn(r, Loc.t("NEXT WEEK  →"), T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_next_night())
		UICtl.S.SEASON_END:
			var cl = ctrl.ui.get("close", {})
			_label(r, Loc.t("SEASON CLOSE"), T.PAD, 260, T.TITLE, T.ACCENT)
			_label(r, Loc.t("Your year, your call."), T.PAD, 360, T.BODY, T.DIM, W)
			_label(r, "%s — %s %s  ·  %s %s" % [
				Loc.t("Carried"),
				Loc.t("dossier"), str((cl.get("dossier", []) as Array).size()),
				Loc.t("standing"), str(cl.get("position", 0))],
				T.PAD, 460, T.BODY, T.TEXT, W)
			_btn(r, Loc.t("NEW SEASON  →"), T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_next_night())
		_:
			_label(r, "…", T.PAD, 300, T.TITLE, T.TEXT)
	return r
