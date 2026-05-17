extends SceneTree
const TESTS := [
	"res://tests/test_tuning.gd", "res://tests/test_game_state.gd",
	"res://tests/test_content.gd", "res://tests/test_control_engine.gd",
	"res://tests/test_first_eye.gd", "res://tests/test_party_encounter.gd",
	"res://tests/test_book.gd", "res://tests/test_future_eye.gd",
	"res://tests/test_girlfriends.gd", "res://tests/test_soft_ruin.gd",
	"res://tests/test_season_flow.gd",
	"res://tests/test_season_flow_interactive.gd",
	"res://tests/test_content_hub.gd",
	"res://tests/test_seasonflow_self_improve.gd",
	"res://tests/test_seasonflow_funnel.gd",
]
func _initialize() -> void:
	var fails := 0
	var ran := 0
	for p in TESTS:
		if not ResourceLoader.exists(p): continue
		var inst = load(p).new()
		for m in inst.get_method_list():
			var n: String = m.name
			if n.begins_with("test_"):
				inst.errors = []
				inst.call(n)
				ran += 1
				for e in inst.errors:
					fails += 1
					print("FAIL %s::%s -> %s" % [p, n, e])
	print("RAN %d tests, %d failures" % [ran, fails])
	quit(fails)
