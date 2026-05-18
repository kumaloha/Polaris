extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
const Spotter := preload("res://core/Spotter.gd")
const Loc := preload("res://ui/Loc.gd")

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

func test_verdict_matrix_full_coverage() -> void:
	var keys := {}
	for was_right in [true, false]:
		for is_scum in [true, false]:
			var k: String = Spotter.verdict_key(was_right, is_scum)
			ok(k != "", "verdict key non-empty right=%s scum=%s" % [str(was_right), str(is_scum)])
			keys[k] = true
	eq(keys.size(), 4, "4 distinct verdict keys (读对? × 真相)")

func test_verdict_key_mapping() -> void:
	eq(Spotter.verdict_key(true, true), "VERDICT_RIGHT_SCUM", "读对·真渣")
	eq(Spotter.verdict_key(true, false), "VERDICT_RIGHT_GOOD", "读对·真好")
	eq(Spotter.verdict_key(false, true), "VERDICT_WRONG_SCUM", "以为好·真渣")
	eq(Spotter.verdict_key(false, false), "VERDICT_WRONG_GOOD", "以为渣·真好")

func test_every_spotter_key_has_zh() -> void:
	for is_scum in [true, false]:
		for ch in ["expose", "probe", "leave"]:
			var ek: String = Spotter.ending_key(is_scum, ch)
			ok(Loc.ZH.has(ek), "Loc.ZH has ending key %s" % ek)
	for was_right in [true, false]:
		for s2 in [true, false]:
			var vk: String = Spotter.verdict_key(was_right, s2)
			ok(Loc.ZH.has(vk), "Loc.ZH has verdict key %s" % vk)
