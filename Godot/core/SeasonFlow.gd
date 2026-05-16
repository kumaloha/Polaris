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
