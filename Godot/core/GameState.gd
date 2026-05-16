extends RefCounted
class_name GameState
const Tuning := preload("res://core/Tuning.gd")
var energy: int
var charm: int
var position: int
var control: int
var day: int = 1
var week: int = 1
var season: int = 1
var dossier: Array = []
var debts: Array = []
var keyframes: Array = []
func _init() -> void:
	energy = Tuning.num("start.energy", 8)
	charm = Tuning.num("start.charm", 40)
	position = Tuning.num("start.position", 1)
	control = Tuning.num("start.control", 0)
func apply(delta: Dictionary) -> void:
	energy = max(0, energy + int(delta.get("energy", 0)))
	charm = max(0, charm + int(delta.get("charm", 0)))
	position = max(0, position + int(delta.get("position", 0)))
	control = control + int(delta.get("control", 0))
func net_worth() -> int:
	var liab := 0
	for d in debts: liab += int(d.get("amount", 0))
	return position + dossier.size() + keyframes.size() - liab
func snapshot() -> Dictionary:
	return {"day": day, "week": week, "season": season, "energy": energy,
		"charm": charm, "position": position, "control": control,
		"net_worth": net_worth(), "debts": debts.size()}
