extends RefCounted
class_name ControlEngine
const Tuning := preload("res://core/Tuning.gd")
const CHASE := ["engage"]
const EARN := ["boundary"]
static func classify(action: String) -> String:
	if action in CHASE: return "chase"
	if action in EARN: return "earn"
	return "neutral"
static func resolve(man_pos: Dictionary, action: String) -> Dictionary:
	var kind := classify(action)
	if kind == "chase":
		var p: int = Tuning.num("control.chase_penalty", 1)
		return {"cheap": 1, "costly": -1,
			"control": -p,
			"sign": "He's sweeter than ever, but the plan stays vague — busy week, or are you too easy to reach?"}
	if kind == "earn":
		return {"cheap": 0, "costly": 1,
			"control": Tuning.num("control.earn_gain", 1),
			"sign": "You held the line; the ball is in his court."}
	return {"cheap": 0, "costly": 0, "control": 0, "sign": ""}
