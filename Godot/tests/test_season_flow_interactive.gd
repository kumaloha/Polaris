extends "res://tests/test_base.gd"
const SF := preload("res://core/SeasonFlow.gd")

func test_begin_night_applies_self_invest_and_persona() -> void:
	var f = SF.new()
	var c0 = f.state.charm
	f.begin_night("beauty_care", "soft_sun")
	eq(f.state.charm, c0 + 2 + 1, "beauty_care +2 charm, soft_sun +1 charm")

func test_available_parties_gated_by_tier() -> void:
	var f = SF.new()
	f.begin_night("solo_reset", "rare_girl")
	var ps = f.available_parties()
	var rooftop = null
	for p in ps:
		if p.id == "rooftop": rooftop = p
	ok(rooftop != null and rooftop.unlocked, "rooftop tier1 unlocked at start")
	var founders = null
	for p in ps:
		if p.id == "founders": founders = p
	ok(founders != null and not founders.unlocked, "founders locked at start")

func test_party_drive_and_after_date_returns_future_eye() -> void:
	var f = SF.new()
	f.begin_night("solo_reset", "rare_girl")
	ok(f.choose_party("rooftop"), "choose unlocked rooftop")
	f.set_primary("adrian")
	var enc = f.start_party()
	ok(enc != null, "start_party returns an encounter")
	for i in range(enc.total_rounds):
		var r = enc.act("boundary")
		f.record_party_action("boundary")
	var results = f.resolve_after({"adrian": "date"})
	eq(results.size(), 1, "one date result for future eye")
	ok(results[0].has("result") and results[0].has("keyframes"), "future eye payload present")
	var fin = f.finish_night()
	eq(f.state.day, 2, "night finished, day advanced")
	ok(fin.has("snapshot"), "finish returns snapshot")

func test_interactive_log_does_not_leak_across_nights() -> void:
	var f = SF.new()
	# Night 1: chase pattern that produces MIRROR/log lines
	f.begin_night("solo_reset", "rare_girl")
	f.choose_party("rooftop")
	f.set_primary("evan")
	var e1 = f.start_party()
	for i in range(e1.total_rounds):
		e1.act("engage")
		f.record_party_action("engage")
	f.resolve_after({"evan": "date"})
	var n1 = f.finish_night()
	var n1_count = (n1.log as Array).size()
	# Night 2: must NOT contain night 1's accumulated lines
	f.begin_night("solo_reset", "rare_girl")
	f.choose_party("rooftop")
	f.set_primary("leo")
	var e2 = f.start_party()
	for i in range(e2.total_rounds):
		e2.act("exit")
		f.record_party_action("exit")
	f.resolve_after({"leo": "observe"})
	var n2 = f.finish_night()
	ok((n2.log as Array).size() <= n1_count, "night 2 log not inflated by night 1 (no leak)")

func test_batch_step_night_still_works() -> void:
	var f = SF.new()
	var r = f.step_night({"self_invest": "solo_reset", "primary": "leo",
		"party_actions": ["exit"], "after": {"leo": "observe"}})
	eq(f.state.day, 2, "batch path intact")
	ok(r.has("log"), "batch returns log")
