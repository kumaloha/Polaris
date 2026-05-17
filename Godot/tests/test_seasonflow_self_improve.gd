extends "res://tests/test_base.gd"
const SF := preload("res://core/SeasonFlow.gd")
func test_apply_outfit() -> void:
	var f = SF.new()
	var c0 = f.state.charm
	f.apply_outfit("midnight_silk")
	eq(f.state.charm, c0 + 2, "midnight_silk +2 charm")
func test_apply_workout() -> void:
	var f = SF.new()
	var e0 = f.state.energy
	f.apply_workout("reset_run")
	eq(f.state.energy, e0 + 2, "reset_run +2 energy")
func test_unknown_id_noop() -> void:
	var f = SF.new()
	var s0 = f.state.snapshot()
	f.apply_outfit("nope"); f.apply_workout("nope")
	eq(f.state.snapshot(), s0, "unknown id is a no-op")
