extends "res://tests/test_lib.gd"

const FxScript := preload("res://match3/effect_manager.gd")


func test_local_burst_bounds_stay_inside_3x3_radius() -> void:
	var cell_size := 88.0
	var clear_radius := cell_size * 1.5
	var bounds: Dictionary = FxScript.local_burst_bounds(clear_radius)
	assert_eq(bounds["clear_cells"], 9, "local burst represents a 3x3 clear")
	assert_true(bounds["flash_peak_radius_px"] <= clear_radius, "flash peak stays inside the 3x3 clear radius")
	assert_true(bounds["particle_max_distance_px"] <= clear_radius, "particles stay inside the 3x3 clear radius")


func test_local_burst_profile_has_layered_magic_distribution() -> void:
	var cell_size := 88.0
	var clear_radius := cell_size * 1.5
	var bounds: Dictionary = FxScript.local_burst_bounds(clear_radius)
	assert_true(bounds["inner_star_count"] > 0, "magic burst has an inner star layer")
	assert_true(bounds["outer_wisp_count"] > 0, "magic burst has an outer wisp layer")
	assert_true(bounds["outer_wisp_radius_px"] <= clear_radius, "outer wisps stay inside the 3x3 clear radius")
	assert_true(bounds["inner_star_radius_px"] < bounds["outer_wisp_radius_px"], "inner stars sit inside the outer wisps")
	assert_true(bounds["spiral_turn_radians"] > 0.0, "magic burst uses a visible spiral motion")


func test_local_burst_rendered_edge_keeps_margin_inside_3x3() -> void:
	var cell_size := 88.0
	var clear_radius := cell_size * 1.5
	var bounds: Dictionary = FxScript.local_burst_bounds(clear_radius)
	assert_true(bounds["visual_safe_radius_ratio"] < 1.0, "burst keeps a visual safety margin inside the 3x3 clear radius")
	assert_true(
		bounds["max_rendered_radius_px"] <= clear_radius * bounds["visual_safe_radius_ratio"],
		"sprite centers plus sprite radius stay comfortably inside the 3x3 clear radius"
	)


func test_local_burst_fades_before_the_outermost_frame() -> void:
	var cell_size := 88.0
	var clear_radius := cell_size * 1.5
	var bounds: Dictionary = FxScript.local_burst_bounds(clear_radius)
	assert_true(bounds["fade_end_ratio"] < 1.0, "burst particles finish fading before their motion reaches the outermost frame")
	assert_true(
		bounds["last_visible_rendered_radius_px"] < bounds["max_rendered_radius_px"],
		"last visible frame is inside the mathematical max endpoint"
	)
	assert_true(
		bounds["last_visible_rendered_radius_px"] <= clear_radius * bounds["last_visible_safe_radius_ratio"],
		"last visible frame keeps an extra safety margin inside 3x3"
	)
