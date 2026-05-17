extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
const Spotter := preload("res://core/Spotter.gd")

func test_truth_map_matches_hidden_type() -> void:
	for m in Content.men():
		var scum: bool = Spotter.is_scumbag(m)
		if m["hidden_type"] == "high_sugar":
			ok(scum, "%s (high_sugar) is 渣" % str(m["id"]))
		else:
			ok(not scum, "%s (%s) is 好" % [str(m["id"]), str(m["hidden_type"])])

func test_is_scumbag_empty_man_safe() -> void:
	ok(not Spotter.is_scumbag({}), "empty man -> not 渣, no crash")

func test_ending_matrix_full_coverage() -> void:
	var keys := {}
	for scum in [true, false]:
		for ch in ["expose", "probe", "leave"]:
			var k: String = Spotter.ending_key(scum, ch)
			ok(k != "", "ending key non-empty for scum=%s %s" % [str(scum), ch])
			keys[k] = true
	eq(keys.size(), 6, "6 distinct ending keys (2 truths × 3 choices)")

func test_ending_key_unknown_choice_safe() -> void:
	var k: String = Spotter.ending_key(true, "garbage")
	ok(k != "", "unknown choice still returns a non-empty key, no crash")
