extends RefCounted
class_name Faces
const T := preload("res://ui/Theme.gd")
const Content := preload("res://core/Content.gd")
const Hub := preload("res://ui/Hub.gd")
const UiKit := preload("res://ui/UiKit.gd")
const Loc := preload("res://ui/Loc.gd")

const NAV_H := 130

static func _loc_msg(msg: String) -> String:
	# Translate the "(still on your book: <decision>)" pattern from SeasonFlow
	if msg.begins_with("(still on your book:"):
		var decision := msg.trim_prefix("(still on your book: ").trim_suffix(")")
		return "（仍在账上：%s）" % Loc.t(decision)
	if msg.begins_with("[MIRROR] "):
		return Loc.t("[MIRROR] ") + Loc.t(msg.trim_prefix("[MIRROR] "))
	if msg.begins_with("[BOOK] "):
		var body := msg.trim_prefix("[BOOK] ")
		var parts := body.split(": ", false, 1)
		if parts.size() == 2:
			return Loc.t("[BOOK] ") + Loc.t(parts[0]) + "：" + Loc.t(parts[1])
		return Loc.t("[BOOK] ") + Loc.t(body)
	return Loc.t(msg)

static func _hud(r: Control, h) -> void:
	var s = h.flow.state.snapshot()
	# Numeric/HUD line: only static abbreviations + numbers, no translatable sentence.
	var top := "DAY %d   ·   S%d W%d   ·   C%d  P%d  Ctl%d   ·   %s %d" % [
		int(s["day"]), int(s["season"]), int(s["week"]),
		int(s["charm"]), int(s["position"]), int(s["control"]),
		Loc.t("Net worth"), int(s["net_worth"])]
	UiKit.label(r, top, T.PAD, T.PAD, T.SMALL, T.DIM)
	# Energy bar
	var e: int = int(s["energy"])
	var bar_y := T.PAD + 70
	var bar_w := T.REF_W - T.PAD * 2
	var track := ColorRect.new()
	track.color = T.PANEL
	track.position = Vector2(T.PAD, bar_y)
	track.size = Vector2(bar_w, 16)
	r.add_child(track)
	var frac: float = clamp(float(e) / 12.0, 0.0, 1.0)
	var fill := ColorRect.new()
	fill.color = T.ACCENT
	fill.position = Vector2(T.PAD, bar_y)
	fill.size = Vector2(int(bar_w * frac), 16)
	r.add_child(fill)
	UiKit.label(r, Loc.t("ENERGY") + " %d" % e, T.PAD, bar_y + 22, T.SMALL, T.DIM)

static func _nav(r: Control, h) -> void:
	var tabs := [
		[Hub.F.SELF, "SELF"],
		[Hub.F.SOCIAL, "SOCIAL"],
		[Hub.F.PARTY, "PARTY"],
		[Hub.F.DATING, "DATING"],
		[Hub.F.CARDS, "CARDS"],
		[Hub.F.ASSETS, "ASSETS"],
	]
	var n := tabs.size()
	var bw := (T.REF_W - T.PAD * 2 - T.GAP * (n - 1)) / n
	var bx := T.PAD
	var by := T.REF_H - NAV_H - 20
	for tab in tabs:
		var fid: int = tab[0]
		var lbl: String = tab[1]
		var sel: bool = h.face == fid and h.overlay == "" and not h.ui.get("show_future", false)
		UiKit.btn(r, lbl, bx, by, bw, NAV_H,
			func(): h.go_face(fid), sel)
		bx += bw + T.GAP

static func build(h) -> Control:
	var r := UiKit.root()
	var W: int = T.REF_W - T.PAD * 2

	# ── Future Eye overlay ──────────────────────────────────────────────────
	if h.ui.get("show_future", false):
		UiKit.label(r, "FUTURE EYE", T.PAD, 200, T.TITLE, T.ACCENT)
		var y := 320
		for fp in h.future_payload:
			UiKit.label(r, "%s — %s" % [Loc.t(str(fp["man_id"])), Loc.t(str(fp["result"]))],
				T.PAD, y, T.BODY, T.ACCENT)
			y += 80
			for kf in fp["keyframes"]:
				UiKit.label(r, "·  " + Loc.t(str(kf)), T.PAD + 20, y, T.SMALL, T.TEXT, W - 20)
				y += 56
			if str(fp["mirror"]) != "":
				y += 20
				UiKit.label(r, Loc.t(str(fp["mirror"])), T.PAD, y, T.SMALL, Color(0.85, 0.35, 0.35), W)
				y += 110
			y += 40
		UiKit.btn(r, "CONTINUE  →", T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
			func(): h.dismiss_future())
		return r

	# ── Week / Season overlays ──────────────────────────────────────────────
	if h.overlay == "settle":
		var stl = h.ui.get("settle", {})
		UiKit.label(r, "WEEK SETTLEMENT", T.PAD, 260, T.TITLE, T.ACCENT)
		UiKit.label(r, "%s %s  ·  %s %s  ·  %s %s" % [
			Loc.t("Net worth"), str(stl.get("net_worth", 0)),
			Loc.t("keyframes"), str(stl.get("keyframes", 0)),
			Loc.t("debts"), str(stl.get("debts", 0))],
			T.PAD, 380, T.BODY, T.TEXT, W)
		UiKit.btn(r, "CONTINUE  →", T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
			func(): h.dismiss_overlay())
		return r
	if h.overlay == "season":
		var cl = h.ui.get("close", {})
		UiKit.label(r, "SEASON CLOSE", T.PAD, 260, T.TITLE, T.ACCENT)
		UiKit.label(r, "Your year, your call.", T.PAD, 360, T.BODY, T.DIM, W)
		UiKit.label(r, "%s — %s %s  ·  %s %s" % [
			Loc.t("Carried"),
			Loc.t("dossier"), str((cl.get("dossier", []) as Array).size()),
			Loc.t("standing"), str(cl.get("position", 0))],
			T.PAD, 460, T.BODY, T.TEXT, W)
		UiKit.btn(r, "CONTINUE  →", T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
			func(): h.dismiss_overlay())
		return r

	# ── HUD (always on for face screens) ────────────────────────────────────
	_hud(r, h)

	match h.face:
		Hub.F.HOME:
			var s = h.flow.state.snapshot()
			UiKit.label(r, "YOU", T.PAD, 200, T.TITLE, T.ACCENT)
			var persona_id: String = h.ui.get("persona", "rare_girl")
			var persona_name := persona_id
			for p in Content.personas():
				if p["id"] == persona_id:
					persona_name = p["name"]
			# Stat line: localize words, keep numbers raw (no translatable sentence).
			UiKit.label(r, "%s · %s %d · %s %d · %s %d" % [
				Loc.t(str(persona_name)),
				Loc.t("charm"), int(s["charm"]),
				Loc.t("standing"), int(s["position"]),
				Loc.t("control"), int(s["control"])],
				T.PAD, 300, T.BODY, T.TEXT, W)
			UiKit.label(r, "You decide who's worth your energy.",
				T.PAD, 380, T.SMALL, T.DIM, W)
			# Avatar placeholder
			var av := ColorRect.new()
			av.color = T.PANEL
			av.position = Vector2(T.PAD, 480)
			av.size = Vector2(W, 520)
			r.add_child(av)
			UiKit.label(r, "·", T.PAD + W / 2 - 10, 720, T.TITLE, T.DIM)
		Hub.F.SELF:
			UiKit.label(r, "SELF-IMPROVEMENT", T.PAD, 200, T.TITLE, T.ACCENT)
			UiKit.label(r, "Invest in yourself before you walk in.",
				T.PAD, 290, T.SMALL, T.DIM, W)
			if h.night_open:
				UiKit.label(r, "Locked in for tonight.", T.PAD, 330, T.SMALL, T.ACCENT, W)
			var y := 380
			var locked: bool = h.night_open
			var groups := [
				[Content.self_investments(), "SELF_INVESTMENTS", "self_invest"],
				[Content.personas(), "PERSONAS", "persona"],
				[Content.outfits(), "OUTFITS", "outfit"],
				[Content.workouts(), "WORKOUTS", "workout"],
			]
			for grp in groups:
				UiKit.label(r, grp[1], T.PAD, y, T.SMALL, T.DIM)
				y += 56
				var key: String = grp[2]
				for c in grp[0]:
					var cid: String = c["id"]
					var sel: bool = h.ui.get(key, "") == cid
					var b := UiKit.btn(r, Loc.t(str(c["name"])), T.PAD, y, W, T.BTN_H,
						func():
							if h.ui.get(key, "") == cid:
								h.ui.erase(key)
							else:
								h.ui[key] = cid
							h._render(),
						sel)
					if locked:
						b.disabled = true
					y += T.BTN_H + 14
				y += 24
		Hub.F.PARTY:
			if h.enc != null and not h.enc.finished:
				var st = h.enc.read()
				UiKit.label(r, Loc.t("PARTY") + "  ·  round %d / %d" % [
					int(st["round"]), int(st["of"])], T.PAD, 200, T.TITLE, T.ACCENT)
				var ly := 330
				for line in h.party_log:
					UiKit.label(r, "“" + _loc_msg(str(line)) + "”", T.PAD, ly, T.BODY, T.TEXT, W)
					ly += 130
				var by := T.REF_H - NAV_H - 40 - (T.BTN_H + 16) * 4
				for a in ["engage", "boundary", "social_proof", "exit"]:
					var act: String = a
					UiKit.btn(r, Loc.t(a.to_upper().replace("_", " ")), T.PAD, by, W, T.BTN_H,
						func(): h.act_party(act))
					by += T.BTN_H + 16
			elif h.ui.get("_chose_party", false) and h.party_face_men().size() > 0:
				UiKit.label(r, "FIRST EYE", T.PAD, 200, T.TITLE, T.ACCENT)
				UiKit.label(r, "Surface only. The truth is in the signs, not the words.",
					T.PAD, 290, T.SMALL, T.DIM, W)
				var y := 420
				for m in h.party_face_men():
					var line := "%s   ·   %s\n%s %s\n\"%s\"" % [
						Loc.t(str(m["name"])), Loc.t(str(m["surface"])),
						Loc.t("risk:"), Loc.t(str(m["risk"])),
						Loc.t(str(m["chat"][0]["text"]))]
					var mid: String = m["id"]
					UiKit.btn(r, line, T.PAD, y, W, T.CARD_H + 60,
						func(): h.act_enter_party(mid))
					y += T.CARD_H + 80
			else:
				UiKit.label(r, "PARTY MAP", T.PAD, 200, T.TITLE, T.ACCENT)
				UiKit.label(r, "Your circle decides which rooms you get into.",
					T.PAD, 290, T.SMALL, T.DIM, W)
				var y := 420
				for gfx in Content.girlfriends():
					UiKit.label(r, "%s — %s" % [Loc.t(str(gfx["name"])), Loc.t(str(gfx["role"]))],
						T.PAD, y, T.BODY, T.TEXT)
					y += 70
				y += 30
				for p in h.flow.available_parties():
					var unlocked: bool = p["unlocked"]
					var tag: String = "" if unlocked else Loc.t("  · LOCKED (tier %d)") % int(p["tier"])
					if unlocked:
						var pid: String = p["id"]
						UiKit.btn(r, Loc.t(str(p["name"])) + tag, T.PAD, y, W, T.BTN_H,
							func():
								h.act_choose_party(pid)
								h.ui["_chose_party"] = true
								h._render())
					else:
						var lb := UiKit.btn(r, Loc.t(str(p["name"])) + tag, T.PAD, y, W, T.BTN_H,
							func(): pass)
						lb.disabled = true
					y += T.BTN_H + 16
		Hub.F.DATING:
			UiKit.label(r, "DATING", T.PAD, 200, T.TITLE, T.ACCENT)
			UiKit.label(r, "Decide where your energy goes. You can only Date one.",
				T.PAD, 290, T.SMALL, T.DIM, W)
			if not h.ui.has("after"):
				h.ui["after"] = {}
			var rows = h.flow.book_for_after()
			if rows.is_empty():
				UiKit.label(r, "Nothing booked yet.", T.PAD, 420, T.BODY, T.DIM, W)
			else:
				var y := 400
				for entry in rows:
					UiKit.label(r, "%s: \"%s\"  — %s" % [
						Loc.t(str(entry["name"])), _loc_msg(str(entry["message"])),
						Loc.t(str(entry["snark"]))], T.PAD, y, T.SMALL, T.DIM, W)
					y += 90
					var bx := T.PAD
					var bw := (W - T.GAP * 3) / 4
					for ch in ["date", "observe", "test", "cut"]:
						var mid: String = entry["man_id"]
						var choice: String = ch
						var seld: bool = h.ui["after"].get(mid, "") == choice
						UiKit.btn(r, Loc.t(ch), bx, y, bw, T.BTN_H,
							func():
								h.ui["after"][mid] = choice
								h._render(),
							seld)
						bx += bw + T.GAP
					y += T.BTN_H + 36
				UiKit.btn(r, "CONFIRM  →", T.PAD, T.REF_H - NAV_H - 40 - T.BTN_H, W, T.BTN_H,
					func(): h.act_after(h.ui["after"]))
		Hub.F.SOCIAL:
			UiKit.label(r, "SOCIAL MEDIA", T.PAD, 240, T.TITLE, T.ACCENT)
			UiKit.label(r, "After you change your look you post. What you post decides who slides in.", T.PAD, 330, T.SMALL, T.DIM, W)
			var y := 470
			if h.ui.has("post_result"):
				var pr = h.ui["post_result"]
				UiKit.label(r, "Posted. %d slid in · %d girlfriend lead(s) · Standing %+d · Control %+d" % [int(pr["inbound_men"].size()), int(pr["gf_leads"].size()), int(pr["standing_delta"]), int(pr["control_delta"])], T.PAD, y, T.BODY, T.TEXT, W)
				y += 150
				if str(pr["mirror"]) != "":
					UiKit.label(r, str(pr["mirror"]), T.PAD, y, T.SMALL, Color(0.85,0.35,0.35), W)
					y += 140
				UiKit.label(r, "(One post per night. Go to PARTY to read who showed up.)", T.PAD, y, T.SMALL, T.DIM, W)
			else:
				UiKit.label(r, "POST TONIGHT", T.PAD, y, T.SMALL, T.DIM); y += 56
				UiKit.btn(r, "Scarce — restrained, fewer but higher-value", T.PAD, y, W, T.BTN_H, func(): h.act_compose_post("scarce")); y += T.BTN_H + 16
				UiKit.btn(r, "Validation — chase the feed, more but cheaper", T.PAD, y, W, T.BTN_H, func(): h.act_compose_post("validation")); y += T.BTN_H + 28
			y += 20
			UiKit.label(r, "READ THE COMMENTS", T.PAD, y, T.SMALL, T.DIM); y += 56
			if h.ui.has("read_feedback"):
				var fb: String = h.ui["read_feedback"]
				UiKit.label(r, "Filed — you read him right." if fb == "correct" else "Off. Look again.", T.PAD, y, T.SMALL, (T.ACCENT if fb == "correct" else T.DIM), W)
				y += 80
			var samples: Array = Content.dm_signals()
			var cap: int = h._tuning_read_cap()
			var done: int = int(h.ui.get("reads_tonight", 0))
			if done >= cap:
				UiKit.label(r, "That's enough reading for tonight.", T.PAD, y, T.SMALL, T.DIM, W)
			elif samples.size() > 0:
				var idx: int = int(h.flow.state.dossier.size()) % samples.size()
				var sample = samples[idx]
				var truth: String = str(sample["hidden_type"])
				UiKit.label(r, "DM: \"%s\"" % str(sample["text"]), T.PAD, y, T.SMALL, T.TEXT, W); y += 90
				UiKit.label(r, "reads tonight %d / %d" % [done, cap], T.PAD, y, T.SMALL, T.DIM); y += 50
				for g in ["high_sugar", "resource", "growth"]:
					var gg: String = g
					UiKit.btn(r, gg, T.PAD, y, W, 100, func(): h.act_read_signal(truth, gg))
					y += 116
		Hub.F.CARDS:
			UiKit.label(r, "COLLECTION", T.PAD, 240, T.TITLE, T.ACCENT)
			UiKit.label(r, "Your reads, your circle, your proven calls — earned, not drawn.", T.PAD, 330, T.SMALL, T.DIM, W)
			var y := 470
			UiKit.label(r, "DOSSIER (men you read right)", T.PAD, y, T.SMALL, T.DIM); y += 56
			var d: Array = h.flow.state.dossier
			if d.size() == 0:
				UiKit.label(r, "— none yet —", T.PAD + 16, y, T.SMALL, T.TEXT); y += 56
			else:
				for e in d:
					UiKit.label(r, "·  %s" % str(e["type"]), T.PAD + 16, y, T.SMALL, T.TEXT); y += 50
			y += 30
			UiKit.label(r, "GIRLFRIEND NETWORK", T.PAD, y, T.SMALL, T.DIM); y += 56
			for g in Content.girlfriends():
				var warm: int = int(h.flow.gf._warmth.get(g["id"], 0))
				UiKit.label(r, "·  %s (%s)  warmth %d" % [str(g["name"]), str(g["role"]), warm], T.PAD + 16, y, T.SMALL, T.TEXT, W - 16); y += 56
			y += 30
			UiKit.label(r, "KEYFRAMES (proven futures)", T.PAD, y, T.SMALL, T.DIM); y += 56
			var kf: Array = h.flow.state.keyframes
			if kf.size() == 0:
				UiKit.label(r, "— none yet —", T.PAD + 16, y, T.SMALL, T.TEXT)
			else:
				for k in kf:
					UiKit.label(r, "·  %s — %s" % [str(k["man"]), str(k["result"])], T.PAD + 16, y, T.SMALL, T.TEXT, W - 16); y += 50
		Hub.F.ASSETS:
			UiKit.label(r, "ASSET LIST", T.PAD, 240, T.TITLE, T.ACCENT)
			UiKit.label(r, "What you compounded. The men cleared; you didn't.", T.PAD, 330, T.SMALL, T.DIM, W)
			var s2 = h.flow.state.snapshot()
			var dz: int = h.flow.state.dossier.size()
			var kz: int = h.flow.state.keyframes.size()
			var liab := 0
			for db in h.flow.state.debts:
				liab += int(db.get("amount", 0))
			var y := 480
			UiKit.label(r, "ASSETS", T.PAD, y, T.SMALL, T.DIM); y += 56
			UiKit.label(r, "Standing %d   Dossier %d   Keyframes %d" % [int(s2["position"]), dz, kz], T.PAD + 16, y, T.BODY, T.TEXT, W); y += 110
			UiKit.label(r, "LIABILITIES", T.PAD, y, T.SMALL, T.DIM); y += 56
			UiKit.label(r, "Fantasy debt %d" % liab, T.PAD + 16, y, T.BODY, Color(0.85,0.35,0.35), W); y += 110
			UiKit.label(r, "NET WORTH  %d" % int(s2["net_worth"]), T.PAD, y, T.TITLE, T.ACCENT, W); y += 110
			if h.ui.has("settle"):
				UiKit.label(r, "last week settled at %s" % str(h.ui["settle"].get("net_worth", 0)), T.PAD, y, T.SMALL, T.DIM, W)
		_:
			UiKit.label(r, "YOU", T.PAD, 200, T.TITLE, T.ACCENT)

	_nav(r, h)
	return r
