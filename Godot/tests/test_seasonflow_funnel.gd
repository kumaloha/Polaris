extends "res://tests/test_base.gd"
const SF := preload("res://core/SeasonFlow.gd")
func test_scarce_post_fewer_higher_control() -> void:
	var f = SF.new()
	var ctl0 = f.state.control
	var r = f.compose_post("scarce")
	ok(r.inbound_men.size() >= 1, "scarce yields some inbound")
	ok(r.control_delta > 0, "scarce gains control (earn)")
	eq(f.state.control, ctl0 + r.control_delta, "control applied to state")
	eq(r.mirror, "", "no mirror on scarce")
	ok(f.inbound_men().size() == r.inbound_men.size(), "inbound_men() exposes the pool")
func test_validation_post_more_and_lemon_weighted() -> void:
	var f = SF.new()
	var rs = f.compose_post("scarce")
	var f2 = SF.new()
	var rv = f2.compose_post("validation")
	ok(rv.inbound_men.size() >= rs.inbound_men.size(), "validation reaches more")
	ok(rv.control_delta < 0, "validation costs control (chase)")
	eq(rv.inbound_men[0]["hidden_type"], "high_sugar", "validation surfaces the lemon first")
func test_validation_low_control_fires_mirror() -> void:
	var f = SF.new()
	f.state.control = -1
	var r = f.compose_post("validation")
	ok(r.mirror != "", "validation + negative control → mirror")
func test_post_does_not_advance_day_and_one_per_night() -> void:
	var f = SF.new()
	var d0 = f.state.day
	f.compose_post("scarce")
	eq(f.state.day, d0, "compose_post does not advance the day")
	var r2 = f.compose_post("scarce")
	eq(r2.inbound_men.size(), 0, "second post same night is a no-op (one/night)")
func test_begin_night_resets_post_state() -> void:
	var f = SF.new()
	f.compose_post("scarce")
	f.begin_night("solo_reset", "rare_girl")
	var r = f.compose_post("validation")
	ok(r.inbound_men.size() > 0, "begin_night reset allows posting again next night")
func test_batch_and_interactive_intact() -> void:
	var f = SF.new()
	var r = f.step_night({"self_invest": "solo_reset", "primary": "leo",
		"party_actions": ["exit"], "after": {"leo": "observe"}})
	eq(f.state.day, 2, "batch path still advances")
	ok(r.has("log"), "batch returns log")
