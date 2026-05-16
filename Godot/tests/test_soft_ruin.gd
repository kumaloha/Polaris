extends "res://tests/test_base.gd"
const SoftRuin := preload("res://core/SoftRuin.gd")
const GameState := preload("res://core/GameState.gd")
func test_solvent_by_default() -> void:
	ok(not SoftRuin.is_insolvent(GameState.new()), "solvent at start")
func test_insolvent_when_debt_exceeds_assets() -> void:
	var s = GameState.new()
	for i in range(5):
		s.debts.append({"man": "x", "amount": 3})
	ok(SoftRuin.is_insolvent(s), "debt > assets -> insolvent")
