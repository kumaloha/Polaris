extends "res://tests/test_base.gd"
const SF := preload("res://core/SeasonFlow.gd")
func test_night_advances_day_and_regens_energy() -> void:
	var f = SF.new()
	f.state.apply({"energy": -5})
	f.step_night({"self_invest": "solo_reset", "party": "rooftop",
		"primary": "adrian", "party_actions": ["boundary"], "after": {"adrian": "date"}})
	eq(f.state.day, 2, "day advanced")
	ok(f.state.energy >= 0, "energy valid")
func test_week_and_season_boundaries() -> void:
	var f = SF.new()
	var npw = f.nights_per_week
	for i in range(npw):
		f.step_night({"party": "rooftop", "primary": "leo",
			"party_actions": ["exit"], "after": {"leo": "observe"}})
	ok(f.at_week_boundary(), "week boundary after nights_per_week")
	var settle = f.settle()
	ok(settle.has("net_worth"), "settlement marks net worth")
func test_season_close_inherits_social_resets_men() -> void:
	var f = SF.new()
	f.state.dossier.append({"man": "evan", "hidden_type": "high_sugar"})
	f.gf.adjust("claire", 5)
	f.state.energy = 1
	var carried = f.close_season()
	eq(carried.dossier.size(), 1, "dossier carried")
	eq(carried.gf_warmth.claire, 5, "gf warmth carried")
	eq(f.state.season, 2, "season incremented")
	eq(f.state.energy, f.start_energy, "energy reset on new season")
