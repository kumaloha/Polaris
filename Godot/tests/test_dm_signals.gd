extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
const Tuning := preload("res://core/Tuning.gd")
func test_dm_signals_shape_and_size() -> void:
	var xs = Content.dm_signals()
	ok(xs.size() >= 6, "≥6 dm samples")
	for x in xs:
		ok(x.has("text") and x.has("hidden_type") and x.has("surface"), "sample shape {text,hidden_type,surface}")
		ok(x["hidden_type"] in ["resource", "high_sugar", "growth"], "hidden_type is a known archetype")
func test_has_each_archetype_and_disguised() -> void:
	var xs = Content.dm_signals()
	var types := {}
	var disguised := 0
	for x in xs:
		types[x["hidden_type"]] = true
		if x["surface"] != x["hidden_type"]:
			disguised += 1
	ok(types.has("resource") and types.has("high_sugar") and types.has("growth"), "all 3 archetypes present")
	ok(disguised >= 2, "≥2 disguised (surface != hidden_type)")
func test_read_cap_tuning() -> void:
	Tuning.load_data()
	eq(Tuning.num("social.read_cap"), 3, "read_cap default 3")
