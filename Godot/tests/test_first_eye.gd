extends "res://tests/test_base.gd"
const FirstEye := preload("res://core/FirstEye.gd")
const Content := preload("res://core/Content.gd")
func _man(id):
	for m in Content.men():
		if m.id == id: return m
	return {}
func test_surface_only_no_dossier() -> void:
	var r = FirstEye.intel(_man("evan"), [], 0)
	eq(r.claims.surface, "growth", "shows surface claim, not truth")
	eq(r.dossier_tag, "", "no dossier tag without history")
	ok(not r.has("hidden_type"), "truth not revealed at first eye")
func test_dossier_tag_when_burned_before() -> void:
	var dossier := [{"man": "evan", "hidden_type": "high_sugar"}]
	var r = FirstEye.intel(_man("evan"), dossier, 0)
	ok(r.dossier_tag != "", "pings like a type you've burned")
func test_bought_depth_adds_clue() -> void:
	var r0 = FirstEye.intel(_man("adrian"), [], 0)
	var r1 = FirstEye.intel(_man("adrian"), [], 1)
	ok(r1.clues.size() > r0.clues.size(), "depth buys a clue, never certainty")
	ok(not r1.has("hidden_type"), "still no certainty")
