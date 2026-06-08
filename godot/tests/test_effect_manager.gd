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


func test_local_burst_bounds_can_represent_5x5_radius() -> void:
	var cell_size := 88.0
	var clear_radius := cell_size * 2.5
	var bounds: Dictionary = FxScript.local_burst_bounds(clear_radius, 25)
	assert_eq(bounds["clear_cells"], 25, "cross + cross local burst represents a 5x5 clear")
	assert_true(bounds["flash_peak_radius_px"] <= clear_radius, "flash peak stays inside the 5x5 clear radius")
	assert_true(bounds["particle_max_distance_px"] <= clear_radius, "particles stay inside the 5x5 clear radius")


func test_magic_vfx_profiles_use_the_new_art_pack() -> void:
	var paths: Dictionary = FxScript.magic_vfx_paths()
	assert_eq(paths["basic_flash_blob"], "res://art/vfx/basic_pop/vfx_basic_flash_blob.png", "basic pop uses the magic art pack")
	assert_eq(paths["line_beam_core"], "res://art/vfx/line_blast/vfx_beam_core.png", "line blasts use the magic beam core")
	assert_eq(paths["area_grid"], "res://art/vfx/area_blast/vfx_area_grid_3x3.png", "area blasts use the 3x3 magic grid")
	assert_eq(paths["absorb_orb"], "res://art/vfx/color_absorb/vfx_absorb_orb.png", "colorbomb absorbs use the new orb")


func test_basic_pop_profile_has_visible_flash_swell() -> void:
	var fx := FxScript.new()
	assert_true(fx.has_method("basic_pop_profile"), "Fx exposes basic pop sizing profile")
	if not fx.has_method("basic_pop_profile"):
		fx.free()
		return
	var profile: Dictionary = fx.call("basic_pop_profile")
	fx.free()
	assert_true(float(profile["blob_start_ratio"]) >= 0.50, "basic pop starts large enough to read as gem swelling")
	assert_true(float(profile["blob_end_ratio"]) >= 1.30, "basic pop flash expands past the gem body")
	assert_true(float(profile["ring_end_ratio"]) >= 1.30, "basic pop ring expands past the gem body")


func test_absorb_residue_profile_uses_low_key_stardust() -> void:
	var paths: Dictionary = FxScript.magic_vfx_paths()
	assert_eq(paths.get("absorb_residue_star", ""), "res://art/vfx/basic_pop/vfx_dust_star.png", "absorb residue uses dust stars")
	assert_eq(paths.get("absorb_residue_dot", ""), "res://art/vfx/basic_pop/vfx_dust_dot.png", "absorb residue uses dust dots")
	assert_eq(paths.get("absorb_residue_flash_star", ""), "res://art/vfx/basic_pop/vfx_basic_flash_star.png", "absorb residue may mix a few flash stars")
	var fx := FxScript.new()
	assert_true(fx.has_method("absorb_residue_profile"), "Fx exposes absorb residue timing profile")
	if not fx.has_method("absorb_residue_profile"):
		fx.free()
		return
	var profile: Dictionary = fx.call("absorb_residue_profile")
	fx.free()
	assert_true(int(profile["count_min"]) >= 3 and int(profile["count_max"]) <= 5, "residue emits 3 to 5 small particles")
	assert_eq(float(profile["scale_min"]), 0.35, "residue scale lower bound")
	assert_eq(float(profile["scale_max"]), 0.75, "residue scale upper bound")
	assert_eq(float(profile["move_min_px"]), 8.0, "residue drift lower bound")
	assert_eq(float(profile["move_max_px"]), 22.0, "residue drift upper bound")
	assert_eq(float(profile["alpha_start"]), 0.8, "residue starts translucent")
	assert_eq(float(profile["alpha_end"]), 0.0, "residue fades out")
	assert_eq(float(profile["duration_min"]), 0.35, "residue duration lower bound")
	assert_eq(float(profile["duration_max"]), 0.55, "residue duration upper bound")


func test_absorb_residue_profile_stays_lightweight_for_colorbomb_fanout() -> void:
	var fx := FxScript.new()
	assert_true(fx.has_method("absorb_residue_profile"), "Fx exposes absorb residue timing profile")
	if not fx.has_method("absorb_residue_profile"):
		fx.free()
		return
	var profile: Dictionary = fx.call("absorb_residue_profile")
	fx.free()
	assert_true(int(profile["count_min"]) >= 3, "residue still leaves visible stardust")
	assert_true(int(profile["count_max"]) <= 5, "colorbomb fanout does not allocate heavy residue bursts per absorbed gem")


func test_vfx_load_shedding_profile_caps_same_frame_heavy_effects() -> void:
	var fx := FxScript.new()
	assert_true(fx.has_method("load_shedding_profile"), "Fx exposes a same-frame VFX load shedding profile")
	if not fx.has_method("load_shedding_profile"):
		fx.free()
		return
	var profile: Dictionary = fx.call("load_shedding_profile")
	fx.free()
	assert_true(int(profile["heavy_frame_budget"]) <= 18, "same-frame heavy VFX budget stays bounded")
	assert_true(int(profile["basic_pop_heavy_cost"]) >= 2, "full basic pops consume meaningful budget")
	assert_true(int(profile["area_burst_heavy_cost"]) > int(profile["basic_pop_heavy_cost"]), "area bursts are budgeted as heavier than basic pops")
	assert_true(profile.get("fallback", "") == "single_flash", "over-budget effects downgrade to a single lightweight flash")


func test_color_absorb_orb_profile_uses_trail_and_hit_flash() -> void:
	var paths: Dictionary = FxScript.magic_vfx_paths()
	assert_eq(paths["absorb_trail"], "res://art/vfx/color_absorb/vfx_absorb_trail.png", "orb flight uses absorb trail art")
	assert_eq(paths["absorb_hit_flash"], "res://art/vfx/color_absorb/vfx_absorb_hit_flash.png", "orb impact uses hit flash art")


func test_area_blast_profile_is_square_magic_not_round_shockwave() -> void:
	var cell_size := 88.0
	var profile: Dictionary = FxScript.area_blast_profile(cell_size, 9)
	assert_eq(profile["clear_cells"], 9, "default area blast represents a 3x3 clear")
	assert_true(profile["grid_diameter_px"] <= cell_size * 3.0, "3x3 grid stays inside affected cells")
	assert_true(profile["square_wave_diameter_px"] <= cell_size * 3.0, "square wave stays inside affected cells")
	assert_true(profile["cube_shard_count"] >= 4, "area blast emits cube shards")
	assert_false(profile["uses_round_shockwave"], "area blast must not be the old round explosion")


func test_line_blast_profile_uses_beam_layers_and_cell_glow() -> void:
	var profile: Dictionary = FxScript.line_blast_profile(704.0, 88.0)
	assert_eq(profile["beam_core"], "res://art/vfx/line_blast/vfx_beam_core.png", "line blast uses beam core texture")
	assert_eq(profile["beam_glow"], "res://art/vfx/line_blast/vfx_beam_glow.png", "line blast uses beam glow texture")
	assert_true(profile["cell_glow_count"] >= 8, "line blast can light each crossed cell")
	assert_true(profile["stagger_sec"] >= 0.015 and profile["stagger_sec"] <= 0.03, "line blast clears cells in the requested stagger range")
