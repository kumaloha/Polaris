extends RefCounted
class_name Book
const Tuning := preload("res://core/Tuning.gd")
var state
var _positions: Array = []
func _init(game_state) -> void:
	state = game_state
func open(man_id: String, decision: String, hidden_type: String) -> void:
	_positions.append({"man": man_id, "decision": decision,
		"hidden_type": hidden_type, "decay": 0, "status": "open"})
func positions() -> Array:
	return _positions
func decide(man_id: String, choice: String) -> void:
	for p in _positions:
		if p.man == man_id:
			p.decision = choice
	if choice == "cut":
		_positions = _positions.filter(func(p): return p.man != man_id)
func advance_night() -> Array:
	var events := []
	for p in _positions:
		if p.decision == "observe":
			var d: int = Tuning.num("book.observe_decay_per_night", 1)
			p.decay += d
			if p.decay >= 9 and p.status == "open":
				p.status = "missed"
				events.append({"man": p.man, "event": "missed_growth"})
		elif p.decision == "string_along":
			var drain: int = Tuning.num("book.creditor_energy_drain", 1)
			state.apply({"energy": -drain})
			var debt_amt: int = Tuning.num("book.fantasy_debt_per_unsettled", 1)
			state.debts.append({"man": p.man, "amount": debt_amt})
			events.append({"man": p.man, "event": "creditor_pressure"})
	return events
