extends RefCounted
class_name SeasonFlow
const Tuning := preload("res://core/Tuning.gd")
const GameState := preload("res://core/GameState.gd")
const Content := preload("res://core/Content.gd")
const ControlEngine := preload("res://core/ControlEngine.gd")
const PartyEncounter := preload("res://core/PartyEncounter.gd")
const Book := preload("res://core/Book.gd")
const FutureEye := preload("res://core/FutureEye.gd")
const Girlfriends := preload("res://core/Girlfriends.gd")
const SoftRuin := preload("res://core/SoftRuin.gd")

var state: GameState
var book: Book
var gf: Girlfriends
var nights_per_week: int
var weeks_per_season: int
var start_energy: int
var _nights_this_week: int = 0
var log_lines: Array = []
var _np_self_invest: String = ""
var _np_persona: String = ""
var _np_party: String = ""
var _np_primary: String = ""
var _np_backup: String = ""
var _np_control_delta: int = 0
var _np_begun: bool = false
var _np_inbound: Array = []
var _np_posted: bool = false

func _init() -> void:
	state = GameState.new()
	book = Book.new(state)
	gf = Girlfriends.new(state)
	nights_per_week = int(Tuning.num("season.nights_per_week", 6))
	weeks_per_season = int(Tuning.num("season.weeks_per_season", 3))
	start_energy = state.energy

func _man(id: String) -> Dictionary:
	for m in Content.men():
		if m.id == id: return m
	return {}

func step_night(choices: Dictionary) -> Dictionary:
	log_lines = []
	if choices.has("self_invest"):
		for c in Content.self_investments():
			if c.id == choices.self_invest:
				state.apply(c.effect)
	var primary_id: String = choices.get("primary", "")
	var control_delta := 0
	if primary_id != "":
		var enc = PartyEncounter.new(_man(primary_id))
		for a in choices.get("party_actions", []):
			if enc.finished: break
			var res = enc.act(a)
			log_lines.append(res.get("tell", ""))
			var ce = ControlEngine.resolve({}, a)
			control_delta += int(ce.control)
		state.apply({"control": control_delta})
	for man_id in choices.get("after", {}).keys():
		var decision: String = choices.after[man_id]
		var ht: String = _man(man_id)["hidden_type"]
		book.open(man_id, decision, ht)
		if decision == "date":
			var fe = FutureEye.resolve(ht, "date", state.control, "any")
			state.keyframes.append({"man": man_id, "result": fe.result})
			if fe.result == "Correct Read":
				state.apply({"position": 1})
			if str(fe.mirror) != "":
				log_lines.append("[MIRROR] " + str(fe.mirror))
			if fe.fantasy_debt > 0:
				state.debts.append({"man": man_id, "amount": fe.fantasy_debt})
			book.decide(man_id, "cut")
	for ev in book.advance_night():
		log_lines.append("[BOOK] %s: %s" % [ev.man, ev.event])
	state.apply({"energy": int(Tuning.num("energy.regen_per_night", 2))})
	state.day += 1
	_nights_this_week += 1
	return {"log": log_lines, "snapshot": state.snapshot(),
		"insolvent": SoftRuin.is_insolvent(state)}

func at_week_boundary() -> bool:
	return _nights_this_week >= nights_per_week

func at_season_boundary() -> bool:
	return state.week > weeks_per_season

func settle() -> Dictionary:
	_nights_this_week = 0
	state.week += 1
	return {"net_worth": state.net_worth(), "week": state.week - 1,
		"keyframes": state.keyframes.size(), "debts": state.debts.size()}

func close_season() -> Dictionary:
	var carried := {
		"dossier": state.dossier.duplicate(true),
		"gf_warmth": gf._warmth.duplicate(true),
		"position": state.position,
	}
	var new_state := GameState.new()
	if bool(Tuning.num("inherit.keep_dossier", true)):
		new_state.dossier = carried.dossier
	if bool(Tuning.num("inherit.keep_social", true)):
		new_state.position = carried.position
	new_state.season = state.season + 1
	state = new_state
	book = Book.new(state)
	var ng = Girlfriends.new(state)
	if bool(Tuning.num("inherit.keep_social", true)):
		ng._warmth = carried.gf_warmth.duplicate(true)
	gf = ng
	_nights_this_week = 0
	return carried

func _persona(id: String) -> Dictionary:
	for p in Content.personas():
		if p.id == id: return p
	return {}

func begin_night(self_invest_id: String, persona_id: String) -> void:
	if _np_begun: return
	_np_begun = true
	_np_self_invest = self_invest_id
	_np_persona = persona_id
	_np_party = ""
	_np_primary = ""
	_np_backup = ""
	_np_control_delta = 0
	_np_inbound = []
	_np_posted = false
	log_lines = []
	for c in Content.self_investments():
		if c.id == self_invest_id:
			state.apply(c.effect)
	var p = _persona(persona_id)
	if p.has("effect"):
		state.apply(p.effect)

func available_parties() -> Array:
	var tier: int = gf.available_tier()
	var out := []
	for p in Content.parties():
		var pt: int = p.tier
		out.append({"id": p.id, "name": p.name, "tier": pt,
			"unlocked": pt <= tier, "men": p.men})
	return out

func choose_party(party_id: String) -> bool:
	for p in available_parties():
		if p.id == party_id and p.unlocked:
			_np_party = party_id
			return true
	return false

func party_men() -> Array:
	var ids := []
	for p in Content.parties():
		if p.id == _np_party: ids = p.men
	var out := []
	for m in Content.men():
		if m.id in ids: out.append(m)
	return out

func set_primary(man_id: String) -> void:
	_np_primary = man_id

func set_backup(man_id: String) -> void:
	_np_backup = man_id

func start_party() -> PartyEncounter:
	if _np_primary == "": return null
	return PartyEncounter.new(_man(_np_primary))

func record_party_action(action: String) -> void:
	var ce = ControlEngine.resolve({}, action)
	_np_control_delta += int(ce.control)

func book_for_after() -> Array:
	var out := []
	var seen := {}
	for mid in [_np_primary, _np_backup]:
		if mid != "" and not seen.has(mid):
			seen[mid] = true
			var m = _man(mid)
			var chat0 := ""
			if m.has("chat") and (m["chat"] as Array).size() > 0:
				chat0 = m["chat"][0]["text"]
			out.append({"man_id": mid, "name": m.get("name", mid),
				"message": chat0,
				"snark": "Watch what he does, not what he says.",
				"held": false})
	for pos in book.positions():
		if not seen.has(pos.man):
			seen[pos.man] = true
			var hm = _man(pos.man)
			out.append({"man_id": pos.man, "name": hm.get("name", pos.man),
				"message": "(still on your book: %s)" % pos.decision,
				"snark": "Still carrying this one.", "held": true})
	return out

func resolve_after(decisions: Dictionary) -> Array:
	var results := []
	for man_id in decisions.keys():
		var decision: String = decisions[man_id]
		var ht: String = _man(man_id)["hidden_type"]
		book.open(man_id, decision, ht)
		if decision == "date":
			var fe = FutureEye.resolve(ht, "date", state.control, "any")
			state.keyframes.append({"man": man_id, "result": fe.result})
			if fe.result == "Correct Read":
				state.apply({"position": 1})
			if str(fe.mirror) != "":
				log_lines.append("[MIRROR] " + str(fe.mirror))
			if fe.fantasy_debt > 0:
				state.debts.append({"man": man_id, "amount": fe.fantasy_debt})
			book.decide(man_id, "cut")
			results.append({"man_id": man_id, "result": fe.result,
				"keyframes": fe.keyframes, "mirror": str(fe.mirror),
				"energy_roi": fe.energy_roi})
	return results

func finish_night() -> Dictionary:
	state.apply({"control": _np_control_delta})
	var events := book.advance_night()
	for ev in events:
		log_lines.append("[BOOK] %s: %s" % [ev.man, ev.event])
	var regen: int = Tuning.num("energy.regen_per_night", 2)
	state.apply({"energy": regen})
	state.day += 1
	_nights_this_week += 1
	_np_begun = false
	return {"log": log_lines, "snapshot": state.snapshot(),
		"insolvent": SoftRuin.is_insolvent(state), "book_events": events}

func apply_outfit(outfit_id: String) -> void:
	for o in Content.outfits():
		if o["id"] == outfit_id:
			state.apply(o["effect"])
			return

func apply_workout(workout_id: String) -> void:
	for w in Content.workouts():
		if w["id"] == workout_id:
			state.apply(w["effect"])
			return

func _inbound_for(posture: String) -> Array:
	var scarce_order := ["adrian", "leo", "evan"]
	var valid_order := ["evan", "adrian", "leo"]
	var ids: Array = scarce_order if posture == "scarce" else valid_order
	var reach: int
	if posture == "scarce":
		reach = int(Tuning.num("social.scarce_reach", 1))
	else:
		reach = int(Tuning.num("social.validation_reach", 3))
	var out := []
	for i in range(min(reach, ids.size())):
		out.append(_man(ids[i]))
	return out

func compose_post(posture: String) -> Dictionary:
	if _np_posted:
		return {"inbound_men": [], "gf_leads": [], "control_delta": 0,
			"standing_delta": 0, "mirror": ""}
	_np_posted = true
	var action := "boundary" if posture == "scarce" else "engage"
	var ce = ControlEngine.resolve({}, action)
	var control_delta: int = int(ce.control)
	var standing_delta: int
	if posture == "scarce":
		standing_delta = int(Tuning.num("social.scarce_standing", 1))
	else:
		standing_delta = int(Tuning.num("social.validation_standing", 0))
	state.apply({"control": control_delta, "position": standing_delta})
	_np_inbound = _inbound_for(posture)
	var gf_leads := []
	if posture == "scarce" and state.position >= int(Tuning.num("social.gf_lead_threshold", 2)):
		for g in Content.girlfriends():
			if int(g["tier"]) == 2:
				gf.adjust(g["id"], int(Tuning.num("social.gf_lead_warmth", 1)))
				gf_leads.append(g["id"])
				break
	var mirror := ""
	if posture == "validation" and state.control < 0:
		mirror = "Your feed reads thirsty. To them you're the easy one — a sugar source, held cheap."
	return {"inbound_men": _np_inbound, "gf_leads": gf_leads,
		"control_delta": control_delta, "standing_delta": standing_delta,
		"mirror": mirror}

func inbound_men() -> Array:
	return _np_inbound

func read_signal(hidden_type: String, guess: String) -> Dictionary:
	var correct := guess == hidden_type
	if correct:
		state.dossier.append({"type": hidden_type, "result": "read_correct"})
	return {"correct": correct, "dossier_size": state.dossier.size()}
