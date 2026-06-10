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
	assert_true(float(profile["blob_start_ratio"]) >= 0.78, "basic pop starts near gem size so the swell is visible immediately")
	assert_true(float(profile["blob_end_ratio"]) >= 1.36, "basic pop flash swells a little more past the gem body")
	assert_true(float(profile["blob_end_ratio"]) <= 1.40, "basic pop flash stays restrained instead of ballooning")
	assert_true(float(profile["ring_end_ratio"]) >= 1.38, "basic pop ring opens a little wider around the gem body")
	assert_true(float(profile["ring_end_ratio"]) <= 1.42, "basic pop ring stays restrained instead of ballooning")
	assert_true(float(profile.get("blob_delay", 1.0)) <= 0.02, "main basic pop flash starts immediately with the gem-body swell")
	assert_eq(float(profile.get("duration_scale", 0.0)), 1.3, "basic pop VFX timeline uses the requested 1.3x slowdown")
	assert_eq(float(profile.get("blob_duration", 0.0)), 0.234, "basic pop flash duration is 0.18s * 1.3")
	assert_eq(float(profile.get("star_duration", 0.0)), 0.234, "basic pop star duration is 0.18s * 1.3")
	assert_eq(float(profile.get("ring_duration", 0.0)), 0.312, "basic pop ring duration is 0.24s * 1.3")
	assert_eq(float(profile.get("star_delay", 0.0)), 0.0455, "basic pop star delay preserves the 1.3x timeline")
	assert_eq(float(profile.get("ring_delay", 0.0)), 0.0585, "basic pop ring delay preserves the 1.3x timeline")


func test_magic_clear_light_keeps_species_color_instead_of_whitewashing() -> void:
	var src := FileAccess.get_file_as_string("res://match3/effect_manager.gd")
	assert_false(src.contains("MAGIC_BASIC_FLASH_STAR, pos, Color(1, 1, 1, 1)"), "basic pop star layer should be tinted by the gem color, not pure white")
	assert_false(src.contains("_flash(pos, Color(1, 1, 1, 1), radius_px"), "area/cross center flash should keep the trigger gem color")
	assert_false(src.contains("MAGIC_LINE_BEAM_CORE, center, angle, full_len, 30.0, Color(1, 1, 1, 1)"), "line blast core should keep the trigger gem color")


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


func test_endgame_reward_comet_beam_code_is_removed() -> void:
	var fx := FxScript.new()
	assert_false(fx.has_method("comet_beam_profile"), "endgame reward no longer exposes a fired comet-beam profile")
	assert_false(fx.has_method("spawn_comet_beam"), "endgame reward no longer has a UI-to-board comet beam helper")
	fx.free()
	var src := FileAccess.get_file_as_string("res://match3/effect_manager.gd")
	assert_false(src.contains("func spawn_comet_beam"), "removed reward beam helper does not remain as dead code")
	assert_true(src.contains("func spawn_line_blast"), "line blast rendering remains available")
	assert_true(src.contains("load(COMET)"), "legacy line-blast fallback can still use the comet texture")


func test_line_blast_colored_light_outlasts_thin_white_core() -> void:
	var profile: Dictionary = FxScript.line_blast_profile(704.0, 88.0)
	assert_true(absf(float(profile.get("timing_scale", 0.0)) - 1.3) < 0.001, "line blast timeline uses the requested 1.3x slowdown")
	assert_true(absf(float(profile.get("beam_glow_duration", 0.0)) - 0.546) < 0.001, "colored line glow duration is 0.42s * 1.3")
	assert_true(absf(float(profile.get("cell_glow_duration", 0.0)) - 0.39) < 0.001, "colored cell glow duration is 0.30s * 1.3")
	assert_true(float(profile.get("beam_glow_alpha", 1.0)) <= 0.26, "colored glow should be background aura, not smoky main line")
	assert_eq(float(profile.get("beam_glow_thickness_px", 0.0)), 152.0, "colored line glow width should be doubled again from the tuned 76px width")
	assert_true(absf(float(profile.get("laser_core_duration", 0.0)) - 0.208) < 0.001, "thin laser duration is 0.16s * 1.3")
	assert_eq(float(profile.get("laser_core_width_px", 0.0)), 16.0, "visible colored laser line should be doubled again from the tuned 8px width")
	assert_true(float(profile.get("laser_core_white_mix", 1.0)) <= 0.20, "laser may be hot but must keep the trigger color")
	assert_true(float(profile.get("laser_core_alpha", 0.0)) >= 0.92, "laser should be especially bright")
	assert_true(profile.get("laser_core_additive", false), "laser should use additive blend for a crisp bright read")
	assert_true(float(profile.get("beam_cap_white_mix", 1.0)) <= 0.10, "beam caps should keep the trigger color instead of washing white")
	assert_true(float(profile.get("beam_cap_alpha", 1.0)) <= 0.70, "beam caps should not become solid endpoint blobs")
	assert_true(float(profile.get("beam_cap_start_scale", 1.0)) <= 0.22, "beam caps should start smaller")
	assert_true(float(profile.get("beam_cap_end_scale", 1.0)) <= 0.32, "beam caps should end smaller")
	assert_true(float(profile.get("beam_spark_white_mix", 0.0)) >= 0.90, "nearby beam spark shards should read as white particles")
	assert_true(int(profile.get("beam_spark_count", 99)) <= 6, "white beam spark shards should stay sparse")
	assert_true(float(profile.get("beam_spark_radius_ratio", 1.0)) <= 0.11, "beam spark shards should stay close to the line")
	assert_true(float(profile.get("cell_glow_end_px", 999.0)) <= 46.0, "cell glows should not become the dominant wide flash")
	assert_true(float(profile.get("cell_glow_alpha", 1.0)) <= 0.18, "cell glows should sit under the colored beam instead of overpowering it")
	assert_true(absf(float(profile.get("beam_cap_duration", 0.0)) - 0.416) < 0.001, "line blast cap duration is 0.32s * 1.3")
	assert_true(absf(float(profile.get("beam_spark_duration", 0.0)) - 0.338) < 0.001, "line blast spark duration is 0.26s * 1.3")
	assert_true(absf(float(profile.get("cell_sweep_delay", 0.0)) - 0.156) < 0.001, "cell glow sweep delay is 0.12s * 1.3")


func test_line_blast_fallback_uses_same_thin_core_profile() -> void:
	var src := FileAccess.get_file_as_string("res://match3/effect_manager.gd")
	var fallback_literal := "_magic_beam_sprite(MAGIC_LINE_BEAM_CORE, origin, u.angle(), full_len, 30.0, color, 0.20, 0.0)"
	assert_false(src.contains(fallback_literal), "over-budget line blast fallback must not use the old wide 30px beam core")
	assert_true(src.contains("fallback_profile := line_blast_profile(full_len, 88.0)"), "over-budget line blast fallback should use the shared thin core profile")
	assert_true(src.contains("float(profile[\"beam_glow_thickness_px\"])"), "normal line blast should use the compact beam glow thickness from the shared profile")
	assert_true(src.contains("float(profile[\"beam_cap_start_scale\"])"), "beam caps should use compact profile scaling")


func test_line_blast_draws_cell_glows_behind_colored_beam() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var fx := FxScript.new()
	var layer := Node2D.new()
	root.add_child(fx)
	root.add_child(layer)
	fx.attach(layer)
	var trigger_color := Color(0.72, 0.08, 0.04, 1.0)
	fx.spawn_line_blast(Vector2(0, 40), Vector2(704, 40), trigger_color)
	var cell_idx := _find_child_index_with_texture(layer, "res://art/vfx/line_blast/cell_glow_horizontal.png")
	var beam_idx := _find_child_index_with_texture(layer, "res://art/vfx/line_blast/vfx_beam_glow.png")
	var beam := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/vfx_beam_glow.png")
	var cell := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/cell_glow_horizontal.png")
	assert_true(cell_idx >= 0, "line blast should create cell glow sprites")
	assert_true(beam_idx >= 0, "line blast should create the colored beam glow")
	assert_true(beam_idx > cell_idx, "cell glow sprites should be drawn behind the colored beam glow")
	if beam != null:
		assert_eq(Color(beam.modulate.r, beam.modulate.g, beam.modulate.b, 1.0), trigger_color, "colored beam glow should keep the trigger color")
	if cell != null:
		assert_true(cell.modulate.a <= 0.45, "cell glow overlay should be dim enough to reveal the colored beam")
	layer.queue_free()
	fx.queue_free()


func test_line_blast_runtime_uses_soft_b_style_alpha_balance() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var fx := FxScript.new()
	var layer := Node2D.new()
	root.add_child(fx)
	root.add_child(layer)
	fx.attach(layer)
	fx.spawn_line_blast(Vector2(0, 40), Vector2(704, 40), Color(0.08, 0.64, 1.0, 1.0))
	var beam := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/vfx_beam_glow.png")
	var smoke_core := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/vfx_beam_core.png")
	var laser := _find_line2d(layer)
	var cell := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/cell_glow_horizontal.png")
	var cap := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/vfx_beam_cap.png")
	var particles := _find_cpu_particles(layer)
	assert_true(beam != null and beam.modulate.a <= 0.26, "colored texture should be supporting aura, not smoky main line")
	assert_true(smoke_core == null, "soft beam core texture should not be used as the main laser")
	assert_true(laser != null and laser.width == 16.0 and laser.default_color.a >= 0.92 and _canvas_item_uses_additive(laser), "main line should be doubled again as a thick bright additive laser")
	assert_true(cell != null and cell.modulate.a <= 0.18, "cell glow should stay behind the colored beam")
	assert_true(cap != null and cap.modulate.a <= 0.70, "beam caps should not become solid endpoint blobs")
	assert_true(particles != null and Color(particles.color.r, particles.color.g, particles.color.b, 1.0) == Color(1, 1, 1, 1), "line blast should add sparse white particles around the bright line")
	layer.queue_free()
	fx.queue_free()


func test_line_blast_main_light_layers_use_alpha_blend_not_additive() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var fx := FxScript.new()
	var layer := Node2D.new()
	root.add_child(fx)
	root.add_child(layer)
	fx.attach(layer)
	fx.spawn_line_blast(Vector2(0, 40), Vector2(704, 40), Color(0.08, 0.64, 1.0, 1.0))
	var beam := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/vfx_beam_glow.png")
	var smoke_core := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/vfx_beam_core.png")
	var laser := _find_line2d(layer)
	var cell := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/cell_glow_horizontal.png")
	var cap := _find_sprite_with_texture(layer, "res://art/vfx/line_blast/vfx_beam_cap.png")
	assert_true(beam != null and _sprite_uses_alpha_blend(beam), "colored beam glow should alpha-blend so it stays colored on bright boards")
	assert_true(smoke_core == null, "line blast should not use the smoky beam core texture as its main line")
	assert_true(laser != null and _canvas_item_uses_additive(laser), "line blast should use a thin additive Line2D laser")
	assert_true(cell != null and _sprite_uses_alpha_blend(cell), "cell glow should alpha-blend below the colored beam")
	assert_true(cap != null and _sprite_uses_alpha_blend(cap), "beam cap should alpha-blend instead of washing the endpoint white")
	layer.queue_free()
	fx.queue_free()


func test_area_blast_profile_is_square_magic_not_round_shockwave() -> void:
	var cell_size := 88.0
	var profile: Dictionary = FxScript.area_blast_profile(cell_size, 9)
	assert_eq(profile["clear_cells"], 9, "default area blast represents a 3x3 clear")
	assert_true(absf(float(profile.get("timing_scale", 0.0)) - 1.3) < 0.001, "area blast timeline uses the requested 1.3x slowdown")
	assert_true(profile["grid_diameter_px"] <= cell_size * 3.0, "3x3 grid stays inside affected cells")
	assert_true(profile["square_wave_diameter_px"] <= cell_size * 3.0, "square wave stays inside affected cells")
	assert_true(profile["cube_shard_count"] >= 4, "area blast emits cube shards")
	assert_true(profile.get("grid_uses_trigger_color", false), "area blast 3x3 grid should be tinted by the trigger gem color")
	assert_true(float(profile.get("grid_white_mix", 1.0)) <= 0.05, "area blast grid should not be washed toward white")
	assert_true(profile.get("cube_frame_uses_trigger_color", false), "area blast rectangle/cube frame should be tinted by the trigger gem color")
	assert_true(float(profile.get("cube_frame_white_mix", 1.0)) <= 0.05, "area blast rectangle/cube frame should not be washed toward white")
	assert_true(profile.get("square_wave_uses_trigger_color", false), "area blast square wave should be tinted by the trigger gem color")
	assert_true(profile.get("center_flash_uses_trigger_color", false), "area blast center flash should be tinted by the trigger gem color")
	assert_true(float(profile.get("center_flash_white_mix", 1.0)) <= 0.05, "area blast center flash should not wash toward white")
	assert_true(float(profile.get("grid_alpha", 1.0)) <= 0.48, "area blast grid should read as colored light, not a solid texture")
	assert_true(float(profile.get("cube_frame_alpha", 1.0)) <= 0.55, "area blast rectangle/cube frame should stay translucent")
	assert_true(float(profile.get("square_wave_alpha", 1.0)) <= 0.38, "area blast square wave should be the soft outer layer")
	assert_true(float(profile.get("center_flash_alpha", 1.0)) <= 0.30, "area blast center flash should be translucent enough to keep its color")
	assert_true(float(profile.get("fallback_flash_white_mix", 1.0)) <= 0.05, "over-budget area blast fallback should stay tinted")
	assert_true(float(profile.get("fallback_flash_alpha", 1.0)) <= 0.45, "over-budget area blast fallback should not become a white slab")
	assert_false(profile["uses_round_shockwave"], "area blast must not be the old round explosion")
	assert_true(absf(float(profile.get("cube_frame_duration", 0.0)) - 0.442) < 0.001, "area cube frame duration is 0.34s * 1.3")
	assert_true(absf(float(profile.get("grid_duration", 0.0)) - 0.494) < 0.001, "area grid duration is 0.38s * 1.3")
	assert_true(absf(float(profile.get("square_wave_duration", 0.0)) - 0.624) < 0.001, "area square wave duration is 0.48s * 1.3")
	assert_true(absf(float(profile.get("cube_shard_duration", 0.0)) - 0.598) < 0.001, "area cube shard duration is 0.46s * 1.3")
	assert_true(absf(float(profile.get("center_flash_duration", 0.0)) - 0.208) < 0.001, "area center flash duration is 0.16s * 1.3")


func test_area_blast_rectangle_layer_does_not_use_washed_glow_color() -> void:
	var src := FileAccess.get_file_as_string("res://match3/effect_manager.gd")
	assert_false(src.contains("MAGIC_AREA_CUBE_FRAME, pos, glow"), "area blast rectangle/cube frame must not use the washed glow color")
	assert_true(src.contains("MAGIC_AREA_CUBE_FRAME, pos, cube_frame_color"), "area blast rectangle/cube frame should use its trigger-color profile color")


func test_area_blast_runtime_tints_rectangle_and_grid_layers_with_trigger_color() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var fx := FxScript.new()
	var layer := Node2D.new()
	root.add_child(fx)
	root.add_child(layer)
	fx.attach(layer)
	var trigger_color := Color(0.2, 0.72, 0.95, 1.0)
	fx.spawn_local_burst(Vector2(40, 40), trigger_color, 132.0, 9)
	var frame := _find_sprite_with_texture(layer, "res://art/vfx/area_blast/vfx_area_cube_frame.png")
	var grid := _find_sprite_with_texture(layer, "res://art/vfx/area_blast/vfx_area_grid_3x3.png")
	var center := _find_sprite_with_texture(layer, "res://assets/fx/fx_bokeh.png")
	assert_true(frame != null, "area blast should spawn the rectangle/cube frame layer")
	assert_true(grid != null, "area blast should spawn the 3x3 grid layer")
	assert_true(center != null, "area blast should spawn a center flash")
	if frame != null:
		assert_eq(Color(frame.modulate.r, frame.modulate.g, frame.modulate.b, 1.0), trigger_color, "rectangle/cube frame should use the trigger gem color exactly")
	if grid != null:
		assert_eq(Color(grid.modulate.r, grid.modulate.g, grid.modulate.b, 1.0), trigger_color, "3x3 grid should use the trigger gem color exactly")
	if center != null:
		assert_eq(Color(center.modulate.r, center.modulate.g, center.modulate.b, 1.0), trigger_color, "center flash should keep the trigger color")
		assert_true(center.modulate.a <= 0.45, "center flash should not become a white slab")
	layer.queue_free()
	fx.queue_free()


func test_area_blast_runtime_uses_soft_b_style_alpha_balance() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var fx := FxScript.new()
	var layer := Node2D.new()
	root.add_child(fx)
	root.add_child(layer)
	fx.attach(layer)
	fx.spawn_local_burst(Vector2(40, 40), Color(1.0, 0.20, 0.58, 1.0), 132.0, 9)
	var frame := _find_sprite_with_texture(layer, "res://art/vfx/area_blast/vfx_area_cube_frame.png")
	var grid := _find_sprite_with_texture(layer, "res://art/vfx/area_blast/vfx_area_grid_3x3.png")
	var square := _find_sprite_with_texture(layer, "res://art/vfx/area_blast/vfx_area_square_wave.png")
	var center := _find_sprite_with_texture(layer, "res://assets/fx/fx_bokeh.png")
	assert_true(frame != null and frame.modulate.a <= 0.55, "area frame should be translucent colored structure")
	assert_true(grid != null and grid.modulate.a <= 0.48, "area grid should be translucent colored structure")
	assert_true(square != null and square.modulate.a <= 0.38, "area square wave should stay soft")
	assert_true(center != null and center.modulate.a <= 0.30, "area center flash should not overpower the colored structure")
	layer.queue_free()
	fx.queue_free()


func test_area_blast_main_light_layers_use_alpha_blend_not_additive() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var fx := FxScript.new()
	var layer := Node2D.new()
	root.add_child(fx)
	root.add_child(layer)
	fx.attach(layer)
	fx.spawn_local_burst(Vector2(40, 40), Color(1.0, 0.20, 0.58, 1.0), 132.0, 9)
	var frame := _find_sprite_with_texture(layer, "res://art/vfx/area_blast/vfx_area_cube_frame.png")
	var grid := _find_sprite_with_texture(layer, "res://art/vfx/area_blast/vfx_area_grid_3x3.png")
	var square := _find_sprite_with_texture(layer, "res://art/vfx/area_blast/vfx_area_square_wave.png")
	var center := _find_sprite_with_texture(layer, "res://assets/fx/fx_bokeh.png")
	assert_true(frame != null and _sprite_uses_alpha_blend(frame), "area cube frame should alpha-blend so trigger color remains visible")
	assert_true(grid != null and _sprite_uses_alpha_blend(grid), "area grid should alpha-blend so trigger color remains visible")
	assert_true(square != null and _sprite_uses_alpha_blend(square), "area square wave should alpha-blend so trigger color remains visible")
	assert_true(center != null and _sprite_uses_alpha_blend(center), "area center flash should alpha-blend instead of adding into white")
	layer.queue_free()
	fx.queue_free()


func test_area_blast_over_budget_fallback_stays_tinted() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var fx := FxScript.new()
	var layer := Node2D.new()
	root.add_child(fx)
	root.add_child(layer)
	fx.attach(layer)
	var trigger_color := Color(0.80, 0.10, 0.38, 1.0)
	fx.spawn_local_burst(Vector2(40, 40), trigger_color, 132.0, 9)
	fx.spawn_local_burst(Vector2(140, 40), trigger_color, 132.0, 9)
	fx.spawn_local_burst(Vector2(240, 40), trigger_color, 132.0, 9)
	var fallback := _find_sprite_with_texture(layer, "res://art/vfx/basic_pop/vfx_basic_flash_blob.png")
	assert_true(fallback != null, "over-budget area blast fallback should spawn a compact flash")
	if fallback != null:
		assert_eq(Color(fallback.modulate.r, fallback.modulate.g, fallback.modulate.b, 1.0), trigger_color, "fallback flash should keep the trigger color")
		assert_true(fallback.modulate.a <= 0.45, "fallback flash should not become a white slab")
	layer.queue_free()
	fx.queue_free()


func test_line_blast_profile_uses_beam_layers_and_cell_glow() -> void:
	var profile: Dictionary = FxScript.line_blast_profile(704.0, 88.0)
	assert_eq(profile["beam_core"], "res://art/vfx/line_blast/vfx_beam_core.png", "line blast uses beam core texture")
	assert_eq(profile["beam_glow"], "res://art/vfx/line_blast/vfx_beam_glow.png", "line blast uses beam glow texture")
	assert_true(profile["cell_glow_count"] >= 8, "line blast can light each crossed cell")
	assert_true(absf(float(profile["stagger_sec"]) - 0.026) < 0.001, "line blast cell stagger is 0.02s * 1.3")


func _find_sprite_with_texture(parent: Node, texture_path: String) -> Sprite2D:
	for child in parent.get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			if sprite.texture != null and sprite.texture.resource_path == texture_path:
				return sprite
	return null


func _find_child_index_with_texture(parent: Node, texture_path: String) -> int:
	var children := parent.get_children()
	for i in range(children.size()):
		var child := children[i]
		if child is Sprite2D:
			var sprite := child as Sprite2D
			if sprite.texture != null and sprite.texture.resource_path == texture_path:
				return i
	return -1


func _sprite_uses_alpha_blend(sprite: Sprite2D) -> bool:
	if sprite == null:
		return false
	if sprite.material == null:
		return true
	if sprite.material is CanvasItemMaterial:
		return (sprite.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_MIX
	return false


func _sprite_uses_additive(sprite: Sprite2D) -> bool:
	if sprite == null:
		return false
	if sprite.material is CanvasItemMaterial:
		return (sprite.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
	return false


func _canvas_item_uses_additive(item: CanvasItem) -> bool:
	if item == null:
		return false
	if item.material is CanvasItemMaterial:
		return (item.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
	return false


func _find_line2d(parent: Node) -> Line2D:
	for child in parent.get_children():
		if child is Line2D:
			return child as Line2D
	return null


func _find_cpu_particles(parent: Node) -> CPUParticles2D:
	for child in parent.get_children():
		if child is CPUParticles2D:
			return child as CPUParticles2D
	return null
