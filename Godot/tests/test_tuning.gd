extends "res://tests/test_base.gd"
const Tuning := preload("res://core/Tuning.gd")
func test_start_energy() -> void:
	Tuning.load_data()
	eq(Tuning.num("start.energy"), 8, "start.energy")
func test_weeks_per_season() -> void:
	Tuning.load_data()
	eq(Tuning.num("season.weeks_per_season"), 3, "weeks")
func test_default_fallback() -> void:
	Tuning.load_data()
	eq(Tuning.num("missing.path", -1), -1, "default fallback")
