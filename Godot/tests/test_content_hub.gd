extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
const Tuning := preload("res://core/Tuning.gd")
func test_outfits_exist() -> void:
	var xs = Content.outfits()
	ok(xs.size() >= 3, "≥3 outfits")
	for x in xs:
		ok(x.has("id") and x.has("name") and x.has("effect"), "outfit shape")
func test_workouts_exist() -> void:
	var ws = Content.workouts()
	ok(ws.size() >= 3, "≥3 workouts")
	for w in ws:
		ok(w.has("id") and w.has("effect"), "workout shape")
func test_existing_self_investments_unchanged() -> void:
	eq(Content.self_investments().size(), 4, "self_investments still 4 (not modified)")
func test_social_tuning_present() -> void:
	Tuning.load_data()
	eq(Tuning.num("social.validation_reach"), 3, "social tuning loaded")
	eq(Tuning.num("dossier.read_correct_archives"), 1, "dossier tuning loaded")
