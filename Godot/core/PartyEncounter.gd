extends RefCounted
class_name PartyEncounter
const Tuning := preload("res://core/Tuning.gd")
var man: Dictionary
var round_index: int = 0
var total_rounds: int
var interest: int = 0
var respect: int = 0
var finished: bool = false
func _init(target: Dictionary) -> void:
	man = target
	total_rounds = int(Tuning.num("party.rounds", 5))
func read() -> Dictionary:
	return {"round": round_index + 1, "of": total_rounds,
		"interest": interest, "respect": respect}
func _tell(action: String) -> Dictionary:
	var t: String = man["hidden_type"]
	if action == "boundary":
		if t == "resource":
			return {"tell": "He pauses, then: 'Saturday 8, I'll book it.'", "evidence": "resource"}
		if t == "high_sugar":
			return {"tell": "'Don't be so serious, just come over.'", "evidence": "high_sugar"}
		return {"tell": "He's prickly, then thoughtful.", "evidence": "growth"}
	if action == "social_proof":
		if t == "growth":
			return {"tell": "He goes quiet and drifts off.", "evidence": "growth"}
		if t == "resource":
			return {"tell": "He steps up, competes for you.", "evidence": "resource"}
		return {"tell": "He love-bombs harder, words not plans.", "evidence": "high_sugar"}
	if action == "engage":
		return {"tell": "He warms up; cheap and easy.", "evidence": "uncertain"}
	return {"tell": "You step back, hold your energy.", "evidence": "uncertain"}
func act(action: String) -> Dictionary:
	if finished: return {}
	var out := _tell(action)
	match action:
		"engage": interest += 1; respect -= 1
		"boundary": respect += 1
		"social_proof": respect += 1
		"exit": pass
	round_index += 1
	if round_index >= total_rounds: finished = true
	out["finished"] = finished
	out["state"] = read()
	return out
