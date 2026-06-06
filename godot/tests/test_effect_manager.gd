extends "res://tests/test_lib.gd"

const FxScript := preload("res://match3/effect_manager.gd")


func test_local_burst_bounds_stay_inside_3x3_radius() -> void:
	var cell_size := 88.0
	var clear_radius := cell_size * 1.5
	var bounds: Dictionary = FxScript.local_burst_bounds(clear_radius)
	assert_eq(bounds["clear_cells"], 9, "local burst represents a 3x3 clear")
	assert_true(bounds["flash_peak_radius_px"] <= clear_radius, "flash peak stays inside the 3x3 clear radius")
	assert_true(bounds["particle_max_distance_px"] <= clear_radius, "particles stay inside the 3x3 clear radius")
