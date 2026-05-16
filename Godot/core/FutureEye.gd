extends RefCounted
class_name FutureEye
const KF := {
	"Correct Read":  ["Keeps concrete plans", "Public and stable", "Standing rises", "High-return asset"],
	"Sugar Trap":    ["Hot then vague", "Still no plan", "You spent, he stalled", "Net loss"],
	"Slow Upside":   ["Quiet, consistent", "Becomes visible", "Real jump", "Compounds"],
	"False Alpha":   ["Impressive night one", "Control creeps in", "Costs exceed status", "Overhead eats you"],
	"Missed Growth": ["You kept arm's length", "He moved on", "He grew elsewhere", "Upside you skipped"],
}
static func resolve(hidden_type: String, decision: String, control_level: int, sequence_quality: String) -> Dictionary:
	var result := "Correct Read"
	if hidden_type == "high_sugar":
		result = "Sugar Trap" if decision == "date" else "Correct Read"
	elif hidden_type == "growth":
		if decision == "cut": result = "Missed Growth"
		elif decision in ["observe", "test", "date"]: result = "Slow Upside"
	elif hidden_type == "resource":
		if decision == "date":
			result = "Correct Read" if control_level >= 0 else "False Alpha"
		elif decision == "cut":
			result = "Correct Read"
	var mirror := ""
	if control_level < 0:
		mirror = "His view of you: 'Always available, reorganized her life around me. Sugar source. Held her cheap.'"
	var roi := 0
	if result == "Correct Read": roi = 3
	elif result == "Slow Upside": roi = 2
	elif result == "Sugar Trap": roi = -3
	elif result == "False Alpha": roi = -2
	elif result == "Missed Growth": roi = -2
	return {"result": result, "keyframes": KF[result].duplicate(),
		"energy_roi": roi, "fantasy_debt": (2 if result == "Sugar Trap" else 0),
		"mirror": mirror}
