extends "res://tests/test_base.gd"
const FE := preload("res://core/FutureEye.gd")
func test_resource_earned_high_control_correct_read() -> void:
	var r = FE.resolve("resource", "date", 3, "good")
	eq(r.result, "Correct Read", "made him earn it -> Correct Read")
	eq(r.keyframes.size(), 4, "4 keyframes")
	ok(r.energy_roi > 0, "positive ROI")
	eq(r.mirror, "", "no mirror when control held")
func test_resource_chased_low_control_false_alpha_with_mirror() -> void:
	var r = FE.resolve("resource", "date", -2, "poor")
	eq(r.result, "False Alpha", "chased same man -> False Alpha")
	ok(r.mirror != "", "mirror keyframe fires on low control")
func test_sugar_date_is_sugar_trap() -> void:
	eq(FE.resolve("high_sugar", "date", 0, "any").result, "Sugar Trap", "Evan dated -> Sugar Trap")
func test_growth_observe_slow_upside_cut_missed() -> void:
	eq(FE.resolve("growth", "observe", 1, "any").result, "Slow Upside", "Leo observed -> Slow Upside")
	eq(FE.resolve("growth", "cut", 1, "any").result, "Missed Growth", "Leo cut -> Missed Growth")
