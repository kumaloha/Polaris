extends "res://tests/test_base.gd"
const SF := preload("res://core/SeasonFlow.gd")
func test_correct_read_archives_dossier() -> void:
	var f = SF.new()
	var n0 = f.state.dossier.size()
	var r = f.read_signal("high_sugar", "high_sugar")
	ok(r.correct, "matching guess = correct read")
	eq(f.state.dossier.size(), n0 + 1, "correct read archives one dossier entry")
	eq(f.state.dossier[-1]["type"], "high_sugar", "archived the read type")
func test_wrong_read_no_archive() -> void:
	var f = SF.new()
	var n0 = f.state.dossier.size()
	var r = f.read_signal("growth", "high_sugar")
	ok(not r.correct, "mismatch = wrong")
	eq(f.state.dossier.size(), n0, "wrong read archives nothing")
func test_dossier_growth_lifts_net_worth() -> void:
	var f = SF.new()
	var nw0 = f.state.net_worth()
	f.read_signal("resource", "resource")
	ok(f.state.net_worth() > nw0, "dossier is a net-worth asset (judgment equity)")
