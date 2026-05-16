extends "res://tests/test_base.gd"
const GameState := preload("res://core/GameState.gd")
func test_start_from_tuning() -> void:
	var s = GameState.new()
	eq(s.energy, 8, "start energy from tuning")
	eq(s.charm, 40, "start charm")
	eq(s.day, 1, "day 1")
func test_apply_clamps() -> void:
	var s = GameState.new()
	s.apply({"energy": -99})
	eq(s.energy, 0, "energy clamped >=0")
func test_net_worth_assets_minus_liabilities() -> void:
	var s = GameState.new()
	s.dossier.append({"man": "evan", "result": "Correct Read"})
	s.keyframes.append({"result": "Correct Read"})
	s.debts.append({"man": "x", "amount": 2})
	eq(s.net_worth(), 1 + 1 + 1 - 2, "net worth formula")
