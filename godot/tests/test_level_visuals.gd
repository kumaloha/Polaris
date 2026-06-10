extends "res://tests/test_lib.gd"

const ClearVisuals := preload("res://match3/clear_visuals.gd")
const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")


func _none_fx(w: int, h: int) -> Array:
	var fx := []
	for y in h:
		var row := []
		for x in w:
			row.append(ME.SP_NONE)
		fx.append(row)
	return fx


func test_bomb_blast_cells_use_trigger_gem_species() -> void:
	var grid := [
		[0, 1, 2, 3, 4],
		[1, 2, 3, 4, 5],
		[2, 3, 1, 5, 0],  # center (2,2)=blue trigger gem
		[3, 4, 5, 0, 1],
		[4, 5, 0, 1, 2],
	]
	var fx := _none_fx(5, 5)
	fx[2][2] = ME.SP_BOMB
	var cells: Array = ME.special_effect_cells(grid, Vector2i(2, 2), ME.SP_BOMB)
	var species: Dictionary = ClearVisuals.special_clear_species_overrides(grid, fx, cells)
	for p in cells:
		assert_eq(species.get(p, -1), 1, "3x3 cell %s uses trigger bomb species" % str(p))


func test_virtual_colorbomb_bombs_color_their_3x3_blast_area() -> void:
	var grid := [
		[2, 3, 4, 5, 6],
		[3, 4, 5, 6, 7],
		[4, 5, 1, 7, 2],  # virtual bomb target at (2,2)=blue
		[5, 6, 7, 2, 3],
		[6, 7, 2, 3, 4],
	]
	var fx := _none_fx(5, 5)
	var virtual_fx := {Vector2i(2, 2): ME.SP_BOMB}
	var cells: Array = ME.special_effect_cells(grid, Vector2i(2, 2), ME.SP_BOMB)
	var species: Dictionary = ClearVisuals.special_clear_species_overrides(grid, fx, cells, {}, virtual_fx)
	assert_eq(species.get(Vector2i(1, 1), -1), 1, "virtual bomb corner uses target species")
	assert_eq(species.get(Vector2i(3, 3), -1), 1, "virtual bomb corner uses target species")


func test_colorbomb_virtual_stripes_have_separate_conversion_phase() -> void:
	var virtual_fx := {
		Vector2i(1, 0): ME.SP_LINE_H,
		Vector2i(2, 1): ME.SP_LINE_V,
	}
	assert_true(ClearVisuals.colorbomb_combo_has_conversion_phase(virtual_fx), "colorbomb + 4-match specials first show converted stripes")
	assert_true(ClearVisuals.colorbomb_virtual_conversion_delay(virtual_fx) >= 0.45, "conversion phase is held long enough to read before detonation")
	assert_false(ClearVisuals.colorbomb_combo_has_conversion_phase({}), "plain colorbomb clears do not add a conversion phase")
	assert_eq(ClearVisuals.colorbomb_virtual_conversion_delay({}), 0.0, "plain colorbomb clears have no conversion delay")


func test_colorbomb_preview_centers_on_virtual_conversion_targets() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_colorbomb_absorb_preview_targets"), "Level exposes colorbomb preview target selection")
	if not level.has_method("_colorbomb_absorb_preview_targets"):
		level.free()
		return
	var cb := Vector2i(0, 0)
	var cells := [
		cb,
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(3, 2),
	]
	var virtual_targets := [Vector2i(3, 2), Vector2i(1, 1)]
	var targets: Array = level.call("_colorbomb_absorb_preview_targets", cb, cells, virtual_targets, 8)
	assert_eq(targets, [Vector2i(1, 1), Vector2i(3, 2)], "colorbomb + 4-match preview should center effects on pieces that will become 4-match specials")
	var capped: Array = level.call("_colorbomb_absorb_preview_targets", cb, cells, virtual_targets, 1)
	assert_eq(capped, [Vector2i(1, 1)], "preview budget trims the virtual target list without falling back to unrelated cleared cells")
	level.free()


func test_colorbomb_conversion_outlines_cover_every_virtual_target() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_colorbomb_conversion_outline_targets"), "Level exposes uncapped conversion outline target selection")
	if not level.has_method("_colorbomb_conversion_outline_targets"):
		level.free()
		return
	var cb := Vector2i(0, 0)
	var cells := [cb]
	var virtual_targets := []
	for y in range(5):
		for x in range(5):
			var p := Vector2i(x, y)
			if p == cb:
				continue
			cells.append(p)
			virtual_targets.append(p)
	var targets: Array = level.call("_colorbomb_conversion_outline_targets", cb, cells, virtual_targets)
	assert_eq(targets.size(), virtual_targets.size(), "every same-color conversion target gets a rectangular outline, independent of absorb orb budget")
	assert_eq(targets[0], Vector2i(1, 0), "outline targets keep stable top-to-bottom ordering")
	assert_eq(targets[targets.size() - 1], Vector2i(4, 4), "outline target selection does not drop later cells")
	level.free()


func test_colorbomb_resolve_passes_virtual_targets_to_absorb_preview() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _resolve_colorbomb")
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	assert_true(start >= 0 and end > start, "_resolve_colorbomb can be inspected")
	if start < 0 or end <= start:
		return
	var body := src.substr(start, end - start)
	assert_true(body.contains("await _play_colorbomb_absorb_preview(cb_pos, cells, virtual_fx.keys())"), "colorbomb + 4-match absorb preview should use the cells that will become 4-match specials")


func test_colorbomb_idle_does_not_tween_board_position() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _apply_colorbomb_layers")
	assert_true(start >= 0, "_apply_colorbomb_layers exists")
	if start < 0:
		return
	var end: int = src.find("# ───────── 整页 UI", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_false(body.contains("\"position\""), "colorbomb idle must not tween position; fall/swap owns board position")
	assert_true(body.contains("\"offset\""), "colorbomb bob uses visual offset instead of board position")


func test_combo_idle_uses_restrained_directional_motion() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("const COMBO_SWING_AMP := 0.14"), "4-match idle pinch is restrained, not a large wobble")
	assert_true(src.contains("const COMBO_SWING_WIDEN := 0.025"), "4-match idle front-facing widen stays subtle")
	assert_true(src.contains("const COMBO_SWING_OFFSET := 3.0"), "4-match idle uses a small visual offset to disambiguate direction")
	assert_true(src.contains("const COMBO_VERTICAL_SWING_OFFSET := 1.8"), "vertical 4-match idle uses a smaller offset so water-drop gems do not look like they only tip upward")
	assert_true(src.contains("const COMBO_LIGHT_STRENGTH := 1.65"), "directional highlight is strong enough on symmetric gems")
	assert_true(src.contains("const COMBO_LIGHT_W := 0.30"), "directional highlight is narrow enough to read as one side")
	assert_true(src.contains("const COMBO_LIGHT_TINT := Color(1.0, 1.0, 1.0)"), "line-special highlight stays neutral white so blue gems do not shift purple")
	var start: int = src.find("func _build_swing_loop")
	var end: int = src.find("func _build_pulse_loop", start)
	assert_true(start >= 0 and end > start, "_build_swing_loop can be inspected")
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("_combo_swing_scale(base, horizontal, s)"), "line specials choose their scale axis from the intended motion axis")
	assert_true(body.contains("node.offset = Vector2(COMBO_SWING_OFFSET * s, 0.0) if horizontal else Vector2(0.0, COMBO_VERTICAL_SWING_OFFSET * s)"), "line specials show left/right or up/down through visual offset, with a restrained vertical offset")
	var stop_start: int = src.find("func _stop_combo_idle")
	var stop_end: int = src.find("func _clear_colorbomb_layers", stop_start)
	assert_true(stop_start >= 0 and stop_end > stop_start, "_stop_combo_idle can be inspected")
	if stop_start >= 0 and stop_end > stop_start:
		var stop_body: String = src.substr(stop_start, stop_end - stop_start)
		assert_true(stop_body.contains("combo_base_offset"), "combo idle records and restores the original visual offset")


func test_vertical_combo_idle_scales_vertically_not_sideways() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_combo_swing_scale"), "Level exposes combo idle axis scale calculation")
	if not level.has_method("_combo_swing_scale"):
		level.free()
		return
	var base := Vector2(0.80, 0.72)
	var horizontal: Vector2 = level.call("_combo_swing_scale", base, true, 1.0)
	var vertical: Vector2 = level.call("_combo_swing_scale", base, false, 1.0)
	assert_true(horizontal.x < base.x, "horizontal idle pinches the horizontal axis")
	assert_true(absf(horizontal.y - base.y) < 0.001, "horizontal idle keeps y scale stable")
	assert_true(absf(vertical.x - base.x) < 0.001, "vertical idle keeps x scale stable so pink/blue gems do not read as left-right wobble")
	assert_true(vertical.y < base.y, "vertical idle pinches the vertical axis")
	level.free()


func test_combo_idle_uses_directional_light_without_added_shadows() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	assert_true(src.contains("const COMBO_RIM_STRENGTH :="), "combo idle exposes a rim-light cue for pseudo 3D volume")
	assert_true(src.contains("const COMBO_SPECULAR_STRENGTH :="), "combo idle exposes a crisp specular cue for a gem-like curved surface")
	assert_false(src.contains("COMBO_DARK_SIDE_STRENGTH"), "line-special idle must not add dark-side shadow on the gem body")
	assert_false(src.contains("COMBO_VOLUME_SHADOW_STRENGTH"), "line-special idle must not add volume shadow on the gem body")
	assert_false(src.contains("COMBO_SHADOW_OFFSET"), "line-special idle must not animate the gem shadow while wobbling")
	var swing_start: int = src.find("func _build_swing_loop")
	var swing_end: int = src.find("func _build_pulse_loop", swing_start)
	assert_true(swing_start >= 0 and swing_end > swing_start, "_build_swing_loop can be inspected")
	if swing_start >= 0 and swing_end > swing_start:
		var swing_body: String = src.substr(swing_start, swing_end - swing_start)
		assert_false(swing_body.contains("_apply_combo_depth_pose"), "directional idle should not drive extra shadow/depth cues every frame")
	var shader := FileAccess.get_file_as_string("res://match3/directional_glow.gdshader")
	assert_true(shader.contains("uniform float rim_strength"), "directional shader has a rim-light strength uniform")
	assert_true(shader.contains("uniform float bulge_strength"), "directional shader has a curved-surface highlight uniform")
	assert_true(shader.contains("uniform float specular_strength"), "directional shader has a white specular hotspot uniform")
	assert_false(shader.contains("shadow_strength"), "directional shader should not expose a dark-side shadow uniform")
	assert_false(shader.contains("volume_shadow_strength"), "directional shader should not expose a volume-shadow uniform")
	assert_true(shader.contains("dome_normal"), "directional shader derives a fake curved-surface normal")
	assert_true(shader.contains("specular_shape"), "directional shader adds a tight gem-like highlight")
	assert_false(shader.contains("volume_shadow"), "directional shader must not darken curved edges/opposite side")
	assert_false(shader.contains("opposite_shadow"), "directional shader must not darken the side opposite the moving highlight")
	assert_false(shader.contains("col.rgb *="), "directional shader must not multiply-darken gem colors")
	assert_false(shader.contains("col.rgb += light_tint * curved_light"), "directional shader must not add a warm RGB bias directly to blue gems")
	assert_false(shader.contains("col.rgb = mix(col.rgb, light_tint"), "directional shader must not mix blue gems toward white/lavender")
	assert_true(shader.contains("hue_safe_light"), "directional shader uses hue-preserving light so blue 4-match specials stay blue")
	assert_true(shader.contains("col.rgb + col.rgb * light_mix"), "directional shader brightens from the gem's own color instead of flooding red/green channels")


func test_shape_shadow_is_soft_not_black() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	assert_true(src.contains("const GEM_SHADOW_COLOR := Color(0.10, 0.08, 0.16, 0.28)"), "gem shape shadow uses a light tinted color instead of heavy black")
	assert_true(src.contains("sh.modulate = GEM_SHADOW_COLOR"), "shape shadow uses the shared soft shadow color")
	assert_false(src.contains("Color(0.0, 0.0, 0.0, GEM_SHADOW_ALPHA)"), "shape shadow must not use pure black at high alpha")


func test_gem_saturation_experiment_uses_shader_not_asset_rewrites() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	assert_true(src.contains("const GEM_SATURATION := 0.86"), "gem saturation experiment uses the preferred 86% color intensity")
	assert_true(src.contains("const GEM_SATURATION_SHADER := \"res://match3/gem_saturation.gdshader\""), "gem saturation experiment uses a reversible shader")
	assert_true(src.contains("gs.material = _gem_saturation_material()"), "ordinary board gems use the shared saturation material")
	assert_true(src.contains("node.material = _gem_saturation_material()"), "stopping line-special idle restores the same saturation material instead of full saturation")
	assert_true(src.contains("m.set_shader_parameter(\"base_saturation\", GEM_SATURATION)"), "line-special directional glow inherits the board gem saturation factor")
	var shader := FileAccess.get_file_as_string("res://match3/gem_saturation.gdshader")
	assert_true(shader.contains("uniform float saturation"), "gem saturation shader exposes a single saturation parameter")
	assert_true(shader.contains("uniform float saturation : hint_range(0.0, 1.5) = 0.86;"), "gem saturation shader preview default matches the 86% experiment")
	assert_true(shader.contains("vec3 gray"), "gem saturation shader computes luminance gray")
	assert_true(shader.contains("mix(gray, col.rgb, saturation)"), "gem saturation shader reduces saturation without darkening by simple RGB multiply")
	assert_true(shader.contains("vec4 col = COLOR"), "gem saturation shader starts from Godot's modulated sprite color")
	assert_false(shader.contains("texture(TEXTURE, UV)"), "gem saturation shader must not multiply the texture color twice")
	assert_false(shader.contains("col.rgb *= tint.rgb"), "gem saturation shader must not darken gems by multiplying modulate after a manual texture sample")
	var dir_shader := FileAccess.get_file_as_string("res://match3/directional_glow.gdshader")
	assert_true(dir_shader.contains("uniform float base_saturation"), "directional glow shader can keep 4-match gems at the same base saturation")
	assert_true(dir_shader.contains("mix(base_gray, col.rgb, base_saturation)"), "directional glow desaturates before adding hue-safe highlights")


func test_pet_skill_charge_requirement_is_halved() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	assert_true(src.contains("const SKILL_CHARGE_REQ := 10.0"), "pet skill progress should fill twice as fast by halving the shared charge requirement")


func test_combo_idle_reapply_same_fx_does_not_restart() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var apply_start: int = src.find("func _apply_fx_overlay")
	var apply_end: int = src.find("func _fx_overlay_is_current", apply_start)
	assert_true(apply_start >= 0 and apply_end > apply_start, "_apply_fx_overlay can be inspected")
	if apply_start < 0 or apply_end <= apply_start:
		return
	var apply_body: String = src.substr(apply_start, apply_end - apply_start)
	var guard_idx: int = apply_body.find("if _fx_overlay_is_current(node, kind):")
	var stop_idx: int = apply_body.find("_stop_combo_idle(node)")
	assert_true(guard_idx >= 0, "same fx overlay has an idempotent guard")
	assert_true(stop_idx > guard_idx, "same-kind 4-match idle returns before stopping and replaying its tween")
	assert_true(src.contains("func _fx_overlay_is_current"), "Level has a reusable fx overlay current-state check")
	var current_start: int = src.find("func _fx_overlay_is_current")
	var current_end: int = src.find("func _stored_tween_is_running", current_start)
	assert_true(current_start >= 0 and current_end > current_start, "_fx_overlay_is_current can be inspected")
	if current_start >= 0 and current_end > current_start:
		var current_body: String = src.substr(current_start, current_end - current_start)
		assert_true(current_body.contains("ME.SP_LINE_H, ME.SP_LINE_V, ME.SP_BOMB"), "4-match specials keep their existing idle tween when the fx kind is unchanged")
		assert_true(current_body.contains("_stored_tween_is_running(node, \"combo_tween\")"), "4-match idle is considered current only while its tween is still valid")
		assert_true(current_body.contains("_stored_tween_is_running(node, \"colorbomb_tween\")"), "5-match idle also avoids stacking repeated bob tweens")


func test_board_layout_centers_playable_books_between_topbar_and_skills() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	for dims in [Vector2i(8, 8), Vector2i(8, 10), Vector2i(9, 11)]:
		var level := scene.instantiate()
		assert_true(level.has_method("_compute_layout"), "Level exposes board layout calculation")
		if not level.has_method("_compute_layout"):
			level.free()
			return
		level.board = Board.new(dims.x, dims.y, [0, 1, 2, 3, 4, 5], 0, 25, 1)
		level.call("_compute_layout")
		var board_h: float = float(level.board.height) * level.cell_size
		var visual_center_y: float = level.board_origin.y + board_h * 0.5
		var topbar_bottom: float = -48.0 + float(level.call("_topbar_height"))
		var skill_top: float = 1374.0 - 132.0 * 0.5
		var book_top: float = level.board_origin.y - 21.0
		var ribbons_bottom: float = level.board_origin.y + board_h + 56.0 + 726.0 * 77.0 / 982.0
		var top_gap: float = book_top - topbar_bottom
		var bottom_gap: float = skill_top - ribbons_bottom
		assert_eq(int(roundf(visual_center_y)), 762, "playable %dx%d board uses the balanced book center" % [dims.x, dims.y])
		assert_true(absf(top_gap - bottom_gap) <= 1.5, "playable %dx%d book has balanced top/bottom gaps" % [dims.x, dims.y])
		level.free()


func test_board_layout_keeps_tallest_playable_book_inside_play_area() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.board = Board.new(9, 11, [0, 1, 2, 3, 4, 5], 0, 25, 1)
	level.call("_compute_layout")
	var topbar_bottom: float = -48.0 + float(level.call("_topbar_height"))
	var skill_top: float = 1374.0 - 132.0 * 0.5
	var book_y: float = level.board_origin.y - 21.0
	var book_bottom: float = level.board_origin.y + float(level.board.height) * level.cell_size + 56.0
	var ribbons_bottom: float = book_bottom + 726.0 * 77.0 / 982.0
	assert_true(book_y >= topbar_bottom + 40.0, "tallest playable book leaves breathing room under the raised topbar")
	assert_true(ribbons_bottom <= skill_top - 40.0, "tallest playable book leaves breathing room above the skill portraits")
	level.free()


func test_bomb_combo_idle_uses_lub_dub_heartbeat_cadence() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("const COMBO_HEARTBEAT_FIRST_AMP := 0.16"), "bomb idle first heartbeat peak is the larger lub")
	assert_true(src.contains("const COMBO_HEARTBEAT_SECOND_AMP := 0.09"), "bomb idle second heartbeat peak is the smaller dub")
	assert_true(src.contains("const COMBO_HEARTBEAT_UP := 0.12"), "heartbeat rises quickly instead of slowly swelling")
	assert_true(src.contains("const COMBO_HEARTBEAT_DOWN := 0.10"), "heartbeat falls quickly after each beat")
	assert_true(src.contains("const COMBO_HEARTBEAT_GAP := 0.07"), "two heartbeat beats have a short gap")
	assert_true(src.contains("const COMBO_HEARTBEAT_REST := 0.58"), "heartbeat loop has a longer rest after the second beat")
	var start: int = src.find("func _build_pulse_loop")
	var end: int = src.find("func _stop_combo_idle", start)
	assert_true(start >= 0 and end > start, "_build_pulse_loop can be inspected")
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("var first_peak: Vector2 = base * (1.0 + COMBO_HEARTBEAT_FIRST_AMP)"), "first beat uses its own larger peak")
	assert_true(body.contains("var second_peak: Vector2 = base * (1.0 + COMBO_HEARTBEAT_SECOND_AMP)"), "second beat uses its own smaller peak")
	assert_false(body.contains("_base_mod"), "bomb idle uses the original color while shrinking instead of discarding it")
	assert_true(body.count("t.parallel().tween_property(node, \"modulate\", COMBO_BRIGHTEN, COMBO_HEARTBEAT_UP)") >= 2, "both heartbeat enlargement phases brighten the bomb special")
	assert_true(body.count("t.parallel().tween_property(node, \"modulate\", base_mod, COMBO_HEARTBEAT_DOWN)") >= 2, "both heartbeat shrink phases restore the original color")
	assert_true(body.find("t.tween_interval(COMBO_HEARTBEAT_GAP)") < body.find("t.tween_property(node, \"scale\", second_peak"), "short gap lands before the second beat")
	assert_true(body.contains("t.tween_interval(COMBO_HEARTBEAT_REST)"), "heartbeat rests after the lub-dub pair")


func test_bomb_combo_idle_brightens_body_without_outline_glow() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(level)
	var node := Sprite2D.new()
	node.texture = load("res://art/gems/base/gem_star.png")
	node.scale = Vector2(0.5, 0.5)
	level.add_child(node)
	level.call("_apply_fx_overlay", node, ME.SP_BOMB)
	var glow := node.get_node_or_null("combo_glow")
	assert_eq(glow, null, "bomb combo idle should brighten the gem body without adding a white outline glow")
	node.queue_free()
	level.queue_free()


func test_colorbomb_absorb_preview_leaves_residue_and_pulses_crystal() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_colorbomb_absorb_preview")
	assert_true(start >= 0, "_play_colorbomb_absorb_preview exists")
	if start < 0:
		return
	var end: int = src.find("func _show_colorbomb_virtual_conversion", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("Fx.spawn_absorb_residue"), "each absorbed gem leaves residue stardust at its source cell")
	assert_true(body.contains("_pulse_colorbomb_core"), "orb impact pulses the current single-texture crystal ball")
	assert_false(body.contains("_pulse_colorbomb_gold_glow"), "single-texture colorbomb no longer references the removed gold-glow layer")
	assert_false(body.contains("_pulse_colorbomb_inner_stars"), "single-texture colorbomb no longer references the removed inner-stars layer")


func test_colorbomb_resolve_has_no_final_particle_burst() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _resolve_colorbomb")
	assert_true(start >= 0, "_resolve_colorbomb exists")
	if start < 0:
		return
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("await _play_colorbomb_absorb_preview"), "colorbomb still plays the absorb sequence")
	assert_false(body.contains("Fx.spawn_explosion"), "colorbomb absorb should not add a final generic particle burst")


func test_colorbomb_clear_fx_has_bounded_final_burst_budget() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("COLORBOMB_ABSORB_TARGET_BUDGET"), "colorbomb absorb preview has an explicit fanout budget")
	assert_true(src.contains("COLORBOMB_FINE_CLEAR_BUDGET"), "colorbomb final clear has an explicit fine FX budget")
	assert_true(src.contains("COLORBOMB_CLEAR_FX_BATCH_SIZE"), "colorbomb final clear work is batched across frames")
	assert_true(src.contains("mini(targets.size(), COLORBOMB_ABSORB_TARGET_BUDGET)"), "absorb preview uses the named fanout budget")
	assert_true(src.contains("COLORBOMB_FINE_CLEAR_BUDGET") and not src.contains("fine_budget: int = 36"), "final clear no longer bursts dozens of basic pops in one frame")
	assert_true(src.contains("await get_tree().process_frame"), "final clear FX yields between batches to avoid a last-frame spike")
	var start: int = src.find("func _resolve_colorbomb")
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("if ClearVisuals.colorbomb_combo_has_conversion_phase(virtual_fx):\n\t\tawait _show_colorbomb_virtual_conversion(virtual_fx)\n\tvar fine_budget"), "final clear FX budget runs for plain colorbombs too, not only conversion combos")


func test_level_clear_pops_gem_body_before_fade() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("CLEAR_POP_SCALE"), "level defines a visible gem-body clear pop scale")
	assert_true(src.contains("CLEAR_POP_TIME"), "level defines a short gem-body clear pop phase")
	assert_true(src.contains("const CLEAR_POP_SCALE := 1.25"), "basic clear gem body swells a little more without ballooning")
	assert_true(src.contains("const CLEAR_POP_TIME := 0.117"), "basic clear gem body uses the requested 1.3x slower swell phase")
	var start: int = src.find("func _play_clear")
	assert_true(start >= 0, "_play_clear exists")
	if start < 0:
		return
	var end: int = src.find("## 某已存在特效棋子", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("\n\t\tif not spawn_set.has(p):"), "all cleared non-spawn gems pop/fade, including existing special gems")
	assert_true(body.contains("base_scale * CLEAR_POP_SCALE"), "clearing gem body first swells above its base scale")
	assert_true(body.contains("base_scale * 0.1"), "clearing gem body still collapses out after the swell")
	assert_true(body.find("base_scale * CLEAR_POP_SCALE") < body.find("base_scale * 0.1"), "gem body swell is scheduled before collapse")
	assert_true(body.contains("set_trans(Tween.TRANS_SINE)"), "basic clear swell should not use an overshooting Back tween")

func test_level_clear_stops_combo_idle_before_clear_tween() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_clear")
	assert_true(start >= 0, "_play_clear exists")
	if start < 0:
		return
	var end: int = src.find("## 某已存在特效棋子", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var stop_idx: int = body.find("_stop_combo_idle(n)")
	var base_idx: int = body.find("var base_scale: Vector2 = n.scale")
	assert_true(stop_idx >= 0, "clear animation stops any special idle tween before taking over scale/modulate")
	assert_true(stop_idx >= 0 and base_idx > stop_idx, "clear tween captures the restored base scale after stopping idle")


func test_level_clear_batches_vfx_creation_across_frames() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("CLEAR_FX_BATCH_SIZE"), "level defines a clear VFX batch size")
	var start: int = src.find("func _play_clear")
	assert_true(start >= 0, "_play_clear exists")
	if start < 0:
		return
	var end: int = src.find("## 某已存在特效棋子", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("spawned_fx_count"), "_play_clear tracks spawned VFX per batch")
	assert_true(body.contains("CLEAR_FX_BATCH_SIZE"), "_play_clear uses the named batch size")
	assert_true(body.contains("await get_tree().process_frame"), "large clears yield between VFX batches instead of allocating every effect in one frame")

func test_special_spawn_clear_hold_is_snappy() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("const CLEAR_TIME := 0.156"), "basic clear gem body uses the requested 1.3x slower total animation")
	assert_true(src.contains("const CLEAR_POP_TIME := 0.117"), "the swell phase stays in the same proportion after the 1.3x slowdown")
	assert_true(src.contains("const CLEAR_POP_SCALE := 1.25"), "the swell reads clearly before the special appears")
	assert_true(src.contains("const ELIM_HOLD := 0.156"), "post-clear hold matches the slower basic clear animation before freeing gems")


func test_spawned_combo_idle_starts_after_clear_phase() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _resolve_cascades")
	assert_true(start >= 0, "_resolve_cascades exists")
	if start < 0:
		return
	var end: int = src.find("## 阶段5 消除表现", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var play_idx: int = body.find("await _play_clear(to_clear, spawns, protected_spawn_set, raw_special_fx_cells, clear_visual_timing)")
	var overlay_idx: int = body.find("if protected_spawn_set.has(p):\n\t\t\t\t_apply_fx_overlay")
	var unfiltered_overlay_idx: int = body.find("if not cleared_this_step.has(p):\n\t\t\t\t_apply_fx_overlay")
	assert_true(play_idx >= 0, "resolve cascades plays clear animation")
	assert_true(overlay_idx > play_idx, "new 4-match specials start their idle only after the clear phase, not during nearby clear animations")
	assert_true(unfiltered_overlay_idx > overlay_idx, "new 4-match specials still receive their idle overlay when their spawn cell was filtered out of to_clear")


func test_line_blast_hit_specials_keep_explosion_visual_even_if_filtered() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	assert_true(src.contains("func _special_fx_cells_for_clear_visuals"), "Level collects raw hit special cells before account filtering")
	assert_true(src.contains("raw_special_fx_cells = _special_fx_cells_for_clear_visuals(to_clear, triggered_spawn_fx)"), "cascade path preserves raw line-hit special cells before locked filtering")
	assert_true(src.contains("await _play_clear(to_clear, spawns, protected_spawn_set, raw_special_fx_cells, clear_visual_timing)"), "cascade clear animation receives raw hit special cells")
	assert_true(src.contains("fusion_special_fx_cells = _special_fx_cells_for_clear_visuals(cells)"), "fusion path preserves raw hit special cells before locked filtering")
	assert_true(src.contains("await _play_clear(to_clear, [], {}, fusion_special_fx_cells, fusion_clear_timing)"), "fusion clear animation receives raw hit special cells")
	var play_start: int = src.find("func _play_clear")
	var play_end: int = src.find("## 某已存在特效棋子", play_start)
	assert_true(play_start >= 0 and play_end > play_start, "_play_clear can be inspected")
	if play_start < 0 or play_end <= play_start:
		return
	var play_body: String = src.substr(play_start, play_end - play_start)
	assert_true(play_body.contains("extra_special_fx_cells: Dictionary = {}"), "_play_clear accepts visual-only special hit cells")
	assert_true(play_body.contains("played_special_fx[p] = true"), "_play_clear tracks special FX already played during normal clear animation")
	assert_true(play_body.contains("for p in extra_special_fx_cells:"), "_play_clear plays visual-only hit specials after regular clear cells")
	assert_true(play_body.contains("_play_special_fx_delayed(p, fx_kind"), "visual-only hit specials play their line/bomb explosion")
	assert_true(play_body.contains("if clear_set.has(p):\n\t\t\tcontinue"), "visual-only hit specials do not duplicate normal clear animations")


func test_line_blast_visual_timing_spreads_from_trigger_and_chains_hit_specials() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_clear_visual_timing_for_triggers"), "Level exposes ordered clear visual timing")
	if not level.has_method("_clear_visual_timing_for_triggers"):
		level.free()
		return
	level.board = Board.new(5, 4, [0, 1, 2], 0, 25, 1)
	level.board.grid = [
		[0, 1, 2, 0, 1],
		[1, 2, 0, 1, 2],
		[2, 0, 1, 2, 0],
		[0, 1, 2, 0, 1],
	]
	level.board.fx = _none_fx(5, 4)
	level.board.fx[1][2] = ME.SP_LINE_H
	level.board.fx[1][4] = ME.SP_LINE_V
	var timing: Dictionary = level.call("_clear_visual_timing_for_triggers", [Vector2i(2, 1)])
	var cell_delays: Dictionary = timing.get("cell_delay", {})
	var special_delays: Dictionary = timing.get("special_delay", {})
	assert_true(absf(float(cell_delays.get(Vector2i(2, 1), -1.0)) - 0.0) < 0.001, "trigger cell starts immediately")
	assert_true(absf(float(cell_delays.get(Vector2i(1, 1), -1.0)) - 0.026) < 0.001, "line blast one-cell delay is 0.02s * 1.3")
	assert_true(absf(float(cell_delays.get(Vector2i(0, 1), -1.0)) - 0.052) < 0.001, "line blast two-cell delay is 0.04s * 1.3")
	assert_true(float(cell_delays.get(Vector2i(1, 1), -1.0)) < float(cell_delays.get(Vector2i(0, 1), -1.0)), "left side clears outward from trigger")
	assert_true(float(cell_delays.get(Vector2i(3, 1), -1.0)) < float(cell_delays.get(Vector2i(4, 1), -1.0)), "right side clears outward from trigger")
	assert_true(absf(float(special_delays.get(Vector2i(4, 1), -1.0)) - float(cell_delays.get(Vector2i(4, 1), -2.0))) < 0.001, "hit line special triggers when the sweep reaches it")
	assert_true(absf(float(cell_delays.get(Vector2i(4, 0), -1.0)) - 0.078) < 0.001, "chained line blast delay also uses the 1.3x stagger")
	assert_true(float(cell_delays.get(Vector2i(4, 0), -1.0)) > float(special_delays.get(Vector2i(4, 1), -1.0)), "chained vertical blast clears after the hit special triggers")
	level.free()


func test_line_blast_clear_animation_uses_ordered_delays() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var play_start: int = src.find("func _play_clear")
	var play_end: int = src.find("## 某已存在特效棋子", play_start)
	assert_true(play_start >= 0 and play_end > play_start, "_play_clear can be inspected")
	if play_start < 0 or play_end <= play_start:
		return
	var play_body: String = src.substr(play_start, play_end - play_start)
	assert_true(play_body.contains("clear_visual_timing: Dictionary = {}"), "_play_clear accepts ordered line clear timing")
	assert_true(play_body.contains("_spawn_shatter_delayed"), "line-hit gems shatter on their ordered delay")
	assert_true(play_body.contains("_play_special_fx_delayed"), "hit specials trigger on their ordered delay")
	assert_true(play_body.contains("ELIM_HOLD + max_fx_delay"), "clear phase waits for the ordered sweep before falling")


func test_line_blast_uses_saturated_trigger_color_not_whitened_fx_color() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	assert_true(src.contains("const GEM_FX_COLORS"), "special effects should use bright saturated VFX colors")
	assert_false(src.contains("return (GEM_COLORS[GEM_KEYS[sp]] as Color).lightened(0.25)"), "special effect colors should not be pre-whitened before additive rendering")
	assert_true(src.contains("func _line_fx_color"), "line blasts should have a dedicated saturated color helper")
	var special_start: int = src.find("func _play_special_fx(pos")
	var special_end: int = src.find("\nfunc ", special_start + 1)
	assert_true(special_start >= 0 and special_end > special_start, "_play_special_fx can be inspected")
	if special_start < 0 or special_end <= special_start:
		return
	var special_body: String = src.substr(special_start, special_end - special_start)
	assert_true(special_body.contains("var line_col: Color = _line_fx_color"), "line blasts should use saturated trigger color")
	assert_false(special_body.contains("var col: Color = _fx_color"), "line blasts should not share the whitened generic fx color")
	var fusion_start: int = src.find("func _play_fusion_fx_after_swap")
	var fusion_end: int = src.find("\nfunc ", fusion_start + 1)
	assert_true(fusion_start >= 0 and fusion_end > fusion_start, "_play_fusion_fx_after_swap can be inspected")
	if fusion_start < 0 or fusion_end <= fusion_start:
		return
	var fusion_body: String = src.substr(fusion_start, fusion_end - fusion_start)
	assert_true(fusion_body.contains("_line_fx_color(board.grid"), "line+bomb fusion should also use saturated line color")
	assert_false(fusion_body.contains("_play_wide_line_fx(b_after, kb, _fx_color"), "wide line fusion should not use whitened fx color")


func test_level_colorbomb_filters_locked_direct_clears() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _resolve_colorbomb")
	assert_true(start >= 0, "_resolve_colorbomb exists")
	if start < 0:
		return
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("to_clear"), "colorbomb direct clear path filters account_clears locked cells")
	assert_true(body.contains("cake_blast"), "colorbomb direct clear path includes cake blast cells after filtering")
	assert_true(body.contains("ME._apply_clears(board.grid, board.fx, to_clear, [])"), "colorbomb direct clear applies only filtered cells")
	assert_false(body.contains("board.grid[p.y][p.x] = ME.EMPTY"), "colorbomb must not manually clear locked cells")

func test_double_bomb_fusion_plays_both_burst_centers() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _play_double_bomb_fusion_fx"), "Level has an explicit two-center double-bomb fusion visual")
	var fusion_start: int = src.find("func _play_fusion_fx_after_swap")
	var fusion_end: int = src.find("func _play_wide_line_fx", fusion_start)
	assert_true(fusion_start >= 0 and fusion_end > fusion_start, "_play_fusion_fx_after_swap can be inspected")
	if fusion_start < 0 or fusion_end <= fusion_start:
		return
	var fusion_body: String = src.substr(fusion_start, fusion_end - fusion_start)
	assert_true(fusion_body.contains("_play_double_bomb_fusion_fx(a_after, b_after)"), "double cross fusion delegates to a two-center burst helper")
	var helper_start: int = src.find("func _play_double_bomb_fusion_fx")
	var helper_end: int = src.find("func _play_wide_line_fx", helper_start)
	assert_true(helper_start >= 0 and helper_end > helper_start, "_play_double_bomb_fusion_fx can be inspected")
	if helper_start < 0 or helper_end <= helper_start:
		return
	var helper_body: String = src.substr(helper_start, helper_end - helper_start)
	assert_true(helper_body.contains("_cell_center(a_after.y, a_after.x)"), "first swapped bomb center gets a visible burst")
	assert_true(helper_body.contains("_cell_center(b_after.y, b_after.x)"), "second swapped bomb center gets a visible burst")
	assert_true(helper_body.count("Fx.spawn_local_burst") >= 2, "double cross fusion must emit two local burst effects")

func test_level_consumed_move_paths_share_board_settlement() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _finish_consumed_move("), "Level exposes one consumed-move finish path")
	for name in ["func _try_swap", "func _resolve_colorbomb", "func _resolve_fusion"]:
		var start: int = src.find(name)
		assert_true(start >= 0, "%s exists" % name)
		if start < 0:
			continue
		var end: int = src.find("\nfunc ", start + 1)
		if end < 0:
			end = src.length()
		var body: String = src.substr(start, end - start)
		assert_true(body.contains("await _finish_consumed_move("), "%s uses Board settlement instead of local move-only bookkeeping" % name)

func test_level_collapse_refill_uses_core_layers_and_feed() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _collapse_and_refill")
	assert_true(start >= 0, "_collapse_and_refill exists")
	if start < 0:
		return
	var end: int = src.find("func debug_first_legal_swap", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("ME.apply_gravity(board.grid, board.fx, false, board._layers())"), "visual collapse uses core gravity so all movable layers stay aligned")
	assert_true(body.contains("ME.refill(board.grid, board.species, board.rng, board.fx"), "visual refill delegates to core refill")
	assert_true(body.contains("board.feed"), "visual refill respects scrolling feed")
	assert_true(body.contains("_sync_collapse_segment"), "visual collapse moves existing gem nodes instead of rebuilding the whole board")
	assert_true(src.contains("tween.tween_property"), "incremental collapse helper animates moved/refilled gem nodes")
	assert_false(body.contains("_sync_visuals_to_board()"), "visual collapse must not full-rerender the board after every clear")
	assert_false(body.contains("board.rng.randi() % board.species.size()"), "visual collapse must not hand-roll random refill")

func test_level_collapse_refill_repairs_missing_visual_gems() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _repair_missing_gem_nodes_from_board"), "Level exposes a targeted visual hole repair helper")
	var start: int = src.find("func _collapse_and_refill")
	assert_true(start >= 0, "_collapse_and_refill exists")
	if start < 0:
		return
	var end: int = src.find("func debug_first_legal_swap", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var assign_idx: int = body.find("_gem_nodes = new_nodes")
	var repair_idx: int = body.find("_repair_missing_gem_nodes_from_board()", assign_idx)
	var coat_idx: int = body.find("_refresh_coat_visuals()", assign_idx)
	assert_true(assign_idx >= 0, "collapse stores the incremental visual grid")
	assert_true(repair_idx > assign_idx, "collapse repairs missing gem sprites after storing the incremental visual grid")
	assert_true(coat_idx > repair_idx, "layer overlays refresh after visual hole repair")

func test_level_wall_collapse_uses_cross_column_slide_visuals() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _sync_wall_slide_visuals"), "Level has a wall-aware cross-column visual collapse helper")
	assert_true(src.contains("func _grid_has_fall_obstacle"), "Level detects all gravity-blocking cells, not only stone walls")
	var start: int = src.find("func _collapse_and_refill")
	assert_true(start >= 0, "_collapse_and_refill exists")
	if start < 0:
		return
	var end: int = src.find("func debug_first_legal_swap", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("_grid_has_fall_obstacle(before_grid)"), "collapse detects obstacle boards before visual syncing")
	assert_true(body.contains("_grid_has_fall_obstacle(board.grid)"), "collapse keeps tracking visuals active after refill")
	assert_true(body.contains("_sync_wall_slide_visuals(before_grid, old_nodes"), "obstacle boards use cross-column slide visuals instead of per-column segment-only syncing")


func test_wall_slide_tracking_maps_include_coat_blockers() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_build_wall_slide_tracking_maps"), "Level can replay visual gravity routes")
	if not level.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board.grid = [
		[0, ME.EMPTY, 2],
		[0, ME.EMPTY, 3],
		[0, 0, 0],
	]
	level.board.fx = _none_fx(3, 3)
	level.board.coat = [
		[0, 1, 0],
		[0, 0, 0],
		[0, 0, 0],
	]
	var maps: Dictionary = level.call("_build_wall_slide_tracking_maps", level.board.grid.duplicate(true))
	var source_map: Array = maps["source"]
	var path_map: Array = maps["path"]
	assert_eq(source_map[1][1], Vector2i(2, 0), "coat blocker above a target replays the same diagonal source as core gravity")
	assert_true(path_map[1][1].size() >= 2, "coat-assisted slide keeps a visible step path")
	if path_map[1][1].size() >= 2:
		assert_eq(path_map[1][1][0], Vector2i(2, 0), "path starts at the diagonal source")
		assert_eq(path_map[1][1][path_map[1][1].size() - 1], Vector2i(1, 1), "path ends at the opened slot")
	level.free()


func test_wall_slide_tracking_waits_for_vertical_chain_before_diagonal() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_build_wall_slide_tracking_maps"), "Level can replay visual gravity routes")
	if not level.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	level.board = Board.new(3, 4, [0, 1, 2], 0, 25, 1)
	level.board.grid = [
		[ME.EMPTY, ME.WALL, ME.EMPTY],
		[10, 12, 11],
		[5, ME.EMPTY, 6],
		[7, ME.EMPTY, 9],
	]
	level.board.fx = _none_fx(3, 4)
	var maps: Dictionary = level.call("_build_wall_slide_tracking_maps", level.board.grid.duplicate(true))
	var source_map: Array = maps["source"]
	var path_map: Array = maps["path"]
	assert_eq(source_map[3][1], Vector2i(1, 1), "visual gravity keeps the lower pocket on the same-column source while vertical fill is possible")
	assert_false(source_map[3][1] == Vector2i(2, 2), "visual gravity must not steal the right-above candidate before the vertical chain resolves")
	assert_eq(path_map[3][1], [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)], "visual path shows a continuous vertical fall, not a diagonal jump")
	level.free()

func test_level_wall_slide_visuals_tween_cell_steps() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("WALL_SLIDE_STEP_TIME"), "wall slide animation has a per-cell step duration")
	assert_true(src.contains("func _wall_slide_path_points"), "Level exposes a path builder for wall slide visuals")
	assert_true(src.contains("func _wall_slide_position_at"), "Level samples wall slide paths continuously")
	assert_true(src.contains("func _tween_wall_slide_node"), "Level tweens wall slide nodes through path steps")
	var start: int = src.find("func _sync_wall_slide_visuals")
	assert_true(start >= 0, "_sync_wall_slide_visuals exists")
	if start < 0:
		return
	var end: int = src.find("func _collapse_and_refill", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("_tween_wall_slide_node(node"), "wall slide sync delegates movement to stepped tween helper")
	assert_false(body.contains("tween.tween_property(node, \"position\", target, FALL_TIME)"), "wall slide must not jump directly to the final target in one tween")
	var tween_start: int = src.find("func _tween_wall_slide_node")
	var tween_end: int = src.find("func _take_wall_slide_source", tween_start)
	var tween_body: String = src.substr(tween_start, tween_end - tween_start)
	assert_true(tween_body.contains("tween_method"), "wall slide uses one continuous tween across the stepped path instead of restarting at every cell")
	assert_false(tween_body.contains("tween_property(node, \"position\""), "wall slide helper should not chain per-cell position tweens")

func test_cascade_fall_tweens_land_linearly_before_next_match() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var helper_start: int = src.find("func _queue_cascade_fall_tween")
	var helper_end: int = src.find("func _sync_collapse_segment", helper_start)
	assert_true(helper_start >= 0 and helper_end > helper_start, "cascade fall movement is centralized in an inspectable helper")
	if helper_start >= 0 and helper_end > helper_start:
		var helper_body: String = src.substr(helper_start, helper_end - helper_start)
		assert_true(helper_body.contains(".set_trans(Tween.TRANS_LINEAR)"), "ordinary cascade drops should not ease out and linger in the last few pixels")
	var sync_start: int = src.find("func _sync_collapse_segment")
	var sync_end: int = src.find("func _sync_fixed_cell_visual", sync_start)
	assert_true(sync_start >= 0 and sync_end > sync_start, "_sync_collapse_segment can be inspected")
	if sync_start >= 0 and sync_end > sync_start:
		var sync_body: String = src.substr(sync_start, sync_end - sync_start)
		assert_true(sync_body.contains("_queue_cascade_fall_tween(tween, node, center, _ordinary_refill_duration_for_positions(node.position, center))"), "spawned refill nodes use the same no-settle-slowdown fall tween")
		assert_true(sync_body.contains("_queue_cascade_fall_tween(tween, node, target, _fall_duration_for_positions(node.position, target))"), "existing nodes use the same no-settle-slowdown fall tween")
	var wall_start: int = src.find("func _tween_wall_slide_node")
	var wall_end: int = src.find("func _source_none", wall_start)
	assert_true(wall_start >= 0 and wall_end > wall_start, "_tween_wall_slide_node can be inspected")
	if wall_start >= 0 and wall_end > wall_start:
		var wall_body: String = src.substr(wall_start, wall_end - wall_start)
		assert_true(wall_body.contains(".set_trans(Tween.TRANS_LINEAR)"), "wall-assisted cascade drops should keep the same apparent speed through landing")
		assert_false(wall_body.contains(".set_ease(Tween.EASE_OUT)"), "wall-assisted cascade drops must not decelerate before the next auto match")

func test_wall_slide_spawned_piece_enters_vertically_before_sliding() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_path_points"), "Level exposes wall slide path calculation")
	if not level.has_method("_wall_slide_path_points"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var start := Vector2(90 + 2.5 * level.cell_size, level.board_origin.y - 2.0 * level.cell_size)
	var target := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y + 2.5 * level.cell_size)
	var points: Array = level.call("_wall_slide_path_points", start, target)
	assert_false(points.is_empty(), "spawn path has points")
	if points.is_empty():
		level.free()
		return
	var first: Vector2 = points[0]
	assert_eq(first.x, start.x, "spawned wall-slide piece first falls vertically in its source column")
	assert_true(first.y > start.y, "spawned wall-slide piece enters downward before any sideways movement")
	level.free()


func test_wall_slide_visual_path_uses_recorded_gravity_route() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_cell_path_points"), "Level can convert recorded gravity cells into visual path points")
	if not level.has_method("_wall_slide_cell_path_points"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var start := Vector2(90 + 2.5 * level.cell_size, level.board_origin.y + 0.5 * level.cell_size)
	var target := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y + 2.5 * level.cell_size)
	var route := [Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 2)]
	var points: Array = level.call("_wall_slide_cell_path_points", start, route, target)
	assert_true(points.size() >= 2, "recorded route has at least the intermediate and target points")
	if points.size() < 2:
		level.free()
		return
	var first: Vector2 = points[0]
	assert_eq(first, Vector2(90 + 2.5 * level.cell_size, level.board_origin.y + 1.5 * level.cell_size), "visual follows the actual first vertical gravity step")
	assert_eq(points[points.size() - 1], target, "visual ends at the target cell")
	level.free()


func test_wall_slide_long_paths_keep_per_cell_pacing() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_duration_for_points"), "Level exposes wall slide duration calculation")
	if not level.has_method("_wall_slide_duration_for_points"):
		level.free()
		return
	var points := []
	for idx in range(10):
		points.append(Vector2(0, float(idx) * 70.0))
	var duration: float = level.call("_wall_slide_duration_for_points", points)
	assert_true(duration >= 0.52, "ten cell-steps still read as a multi-step slide")
	assert_true(duration <= 0.56, "ten cell-steps use the brisk global cap instead of dragging blocker levels")
	level.free()


func test_wall_slide_replacement_node_starts_at_recorded_source() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_visual_start_position"), "Level can place replacement visuals at the recorded source")
	if not level.has_method("_wall_slide_visual_start_position"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var N := Vector2i(-1, -1)
	var source_map := [
		[N, N, N],
		[N, N, N],
		[N, Vector2i(2, 0), N],
	]
	var path_map := [
		[[], [], []],
		[[], [], []],
		[[], [Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 2)], []],
	]
	var start: Vector2 = level.call("_wall_slide_visual_start_position", source_map, path_map, 2, 1)
	assert_eq(start, Vector2(90 + 2.5 * level.cell_size, level.board_origin.y + 0.5 * level.cell_size), "replacement node starts where the logical source was, not above the target column")
	level.free()


func test_ordinary_long_falls_keep_per_cell_pacing() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_fall_duration_for_positions"), "Level exposes ordinary fall duration calculation")
	if not level.has_method("_fall_duration_for_positions"):
		level.free()
		return
	level.cell_size = 70.0
	var duration: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 700))
	assert_true(duration >= 0.39, "ordinary ten-cell fall still reads as movement, not a teleport")
	assert_true(duration <= 0.44, "ordinary ten-cell fall is capped so tall or blocker-heavy levels do not feel slower")
	level.free()


func test_ordinary_refill_nodes_start_above_board() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_ordinary_refill_start_position"), "Level exposes ordinary refill start calculation")
	if not level.has_method("_ordinary_refill_start_position"):
		level.free()
		return
	level.board = Board.new(5, 8, [0, 1, 2], 0, 25, 1)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var spawn_count := 8
	var deep_target_start: Vector2 = level.call("_ordinary_refill_start_position", 6, 2, 1, spawn_count)
	var next_spawn_start: Vector2 = level.call("_ordinary_refill_start_position", 5, 2, 2, spawn_count)
	var top_target_start: Vector2 = level.call("_ordinary_refill_start_position", 0, 2, 7, spawn_count)
	var deep_target: Vector2 = level.call("_cell_center", 6, 2)
	var top_target: Vector2 = level.call("_cell_center", 0, 2)
	assert_true(level.has_method("_ordinary_refill_duration_for_positions"), "Level exposes ordinary refill duration calculation")
	assert_true(deep_target_start.y < level.board_origin.y, "deep ordinary refill must enter from above the board, not appear inside a lower hole")
	assert_true(next_spawn_start.y < deep_target_start.y, "later spawned refill nodes stay stacked above earlier ones")
	assert_eq(deep_target_start.x, level.call("_cell_center", 0, 2).x, "ordinary refill starts in the target column")
	assert_true(absf((deep_target.y - deep_target_start.y) - (top_target.y - top_target_start.y)) < 0.01, "ordinary refill stack keeps equal travel distance so it falls as a column, not top-to-bottom paint")
	if level.has_method("_ordinary_refill_duration_for_positions"):
		var refill_duration: float = level.call("_ordinary_refill_duration_for_positions", deep_target_start, deep_target)
		assert_true(refill_duration <= 0.64, "full-column refill stays bounded even though all nodes travel the same visual distance")
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f != null:
		var src: String = f.get_as_text()
		assert_true(src.contains("node.position = _ordinary_refill_start_position(row, col, spawn_i, first_old_slot)"), "ordinary collapse uses the above-board refill stack start position")
		assert_true(src.contains("_ordinary_refill_duration_for_positions(node.position, center)"), "ordinary collapse uses the capped refill duration")
	level.free()


func test_fall_durations_scale_with_each_cell_step() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.cell_size = 70.0
	var one_cell: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 70))
	var two_cells: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 140))
	var ten_cells: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 700))
	assert_true(one_cell >= 0.16, "one-cell fall should not feel instant")
	assert_true(one_cell <= 0.17, "one-cell fall should be brisk")
	assert_true(two_cells > one_cell, "a two-cell fall still reads as a longer fall")
	assert_true(two_cells < one_cell * 1.6, "fall timing accelerates instead of adding a full duration per cell")
	assert_true(ten_cells >= 0.39, "long falls should remain readable")
	assert_true(ten_cells <= 0.44, "long falls must not feel sluggish during auto cascades")
	var very_long: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 1400))
	assert_true(very_long <= 0.43, "very long falls share the same brisk cap instead of making tall levels feel different")
	var wall_one: float = level.call("_wall_slide_duration_for_points", [Vector2(0, 70)])
	var wall_three: float = level.call("_wall_slide_duration_for_points", [Vector2(0, 70), Vector2(0, 140), Vector2(70, 210)])
	assert_true(wall_three > wall_one, "multi-step wall slide still takes longer than one step")
	assert_true(wall_three < wall_one * 2.5, "multi-step wall slide also accelerates")
	level.free()

func test_refill_duration_cap_stays_near_long_fall_speed() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.cell_size = 70.0
	var long_fall: float = level.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 700))
	var long_refill: float = level.call("_ordinary_refill_duration_for_positions", Vector2(0, -735), Vector2(0, 0))
	assert_true(long_refill >= long_fall - 0.07, "long refill should stay visually connected to an equally long existing-gem fall")
	assert_true(long_refill <= long_fall - 0.02, "long refill should finish a little sooner so automatic cascades do not feel late")
	level.free()

func test_level_fall_animation_timing_is_slightly_slower() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("const FALL_TIME := 0.16"), "ordinary one-cell falling is readable without dragging")
	assert_true(src.contains("const FALL_EXTRA_CELL_TIME := 0.030"), "longer falls add only a small accelerated increment per extra cell")
	assert_true(src.contains("const FALL_MAX_TIME := 0.42"), "long ordinary falls have a global cap so levels do not feel differently paced")
	assert_true(src.contains("const ORDINARY_REFILL_MAX_TIME := 0.38"), "spawned refill stays brisk without collapsing into a paint effect")
	assert_true(src.contains("const WALL_SLIDE_STEP_TIME := 0.045"), "wall slide timing stays readable but does not drag through blocker lanes")
	assert_true(src.contains("const WALL_SLIDE_MAX_TIME := 0.55"), "wall slide wait cap prevents long obstacle paths from dragging")

func test_level_wall_slide_visuals_only_cross_columns_under_fall_obstacles() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _wall_slide_target_has_fall_obstacle_above"), "Level can tell whether a target is under a gravity-blocking obstacle")
	var take_start: int = src.find("func _take_wall_slide_source")
	var take_end: int = src.find("func _free_unused_wall_slide_sources", take_start)
	assert_true(take_start >= 0 and take_end > take_start, "_take_wall_slide_source body can be inspected")
	if take_start < 0 or take_end <= take_start:
		return
	var take_body: String = src.substr(take_start, take_end - take_start)
	assert_true(take_body.contains("allow_cross_column"), "source matching receives a per-target cross-column gate")
	assert_true(take_body.contains("col != target_col"), "non-wall targets reject adjacent-column visual sources")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	assert_true(sync_body.contains("_wall_slide_target_has_fall_obstacle_above(before_grid, row, col)"), "only cells below actual fall blockers may use diagonal visual sourcing")

func test_level_wall_slide_source_prefers_right_above_before_left_above() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _wall_slide_source_priority"), "wall slide visuals expose a deterministic source priority helper")
	var start: int = src.find("func _wall_slide_source_priority")
	var end: int = src.find("func _take_wall_slide_source", start)
	assert_true(start >= 0 and end > start, "wall slide source priority body can be inspected")
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("col == target_col + 1"), "right-above source has an explicit priority branch")
	assert_true(body.contains("col == target_col - 1"), "left-above source has an explicit priority branch")
	assert_true(body.find("col == target_col + 1") < body.find("col == target_col - 1"), "right-above branch is checked before left-above")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	assert_true(sync_start >= 0 and sync_end > sync_start, "_sync_wall_slide_visuals can be inspected")
	if sync_start < 0 or sync_end <= sync_start:
		return
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	assert_true(sync_body.contains("_build_wall_slide_tracking_maps(before_grid)"), "wall slide visuals build source and path maps by replaying gravity")
	assert_true(sync_body.contains("_take_wall_slide_source(before_grid, old_nodes, used, row, col, sp, allow_cross_column, source_map)"), "wall slide visuals pick old nodes from the replayed source map")


func test_level_wall_refill_start_uses_spawn_source_map() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _wall_slide_spawn_source_col"), "wall slide visuals can recover the spawned top source column")
	var refill_start: int = src.find("func _wall_refill_start_position")
	var refill_end: int = src.find("func _wall_slide_target_has_fall_obstacle_above", refill_start)
	assert_true(refill_start >= 0 and refill_end > refill_start, "_wall_refill_start_position can be inspected")
	if refill_start < 0 or refill_end <= refill_start:
		return
	var refill_body: String = src.substr(refill_start, refill_end - refill_start)
	assert_true(refill_body.contains("_wall_slide_spawn_source_col(source_map, row, col)"), "new wall-slide pieces start from the exact spawned source column")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	assert_true(sync_start >= 0 and sync_end > sync_start, "_sync_wall_slide_visuals can be inspected")
	if sync_start < 0 or sync_end <= sync_start:
		return
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	assert_true(sync_body.contains("_wall_slide_visual_start_position(source_map, path_map, row, col)"), "wall-slide visual refill passes the replayed source and path maps into start-position calculation")
	var start_pos_start: int = src.find("func _wall_slide_visual_start_position")
	var start_pos_end: int = src.find("func _free_unused_wall_slide_sources", start_pos_start)
	assert_true(start_pos_start >= 0 and start_pos_end > start_pos_start, "_wall_slide_visual_start_position can be inspected")
	if start_pos_start >= 0 and start_pos_end > start_pos_start:
		var start_pos_body: String = src.substr(start_pos_start, start_pos_end - start_pos_start)
		assert_true(start_pos_body.contains("_wall_refill_start_position(row, col, source_map)"), "spawned replacement pieces still use the source-map-aware off-board start")
	assert_false(sync_body.contains("_wall_refill_start_position(row, col, allow_cross_column)"), "wall-slide visual refill must not guess the start column from allow_cross_column alone")


func test_wall_refill_spawn_stack_falls_from_top_together() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_refill_start_position"), "Level exposes wall refill start calculation")
	if not level.has_method("_wall_refill_start_position"):
		level.free()
		return
	level.board = Board.new(3, 7, [0, 1, 2], 0, 25, 1)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var N := Vector2i(-1, -1)
	var source_map := [
		[N, Vector2i(1, -2), N],
		[N, N, N],
		[N, N, N],
		[N, N, N],
		[N, N, N],
		[N, N, N],
		[N, Vector2i(1, -2), N],
	]
	var top_start: Vector2 = level.call("_wall_refill_start_position", 0, 1, source_map)
	var deep_start: Vector2 = level.call("_wall_refill_start_position", 6, 1, source_map)
	var top_target: Vector2 = level.call("_cell_center", 0, 1)
	var deep_target: Vector2 = level.call("_cell_center", 6, 1)
	assert_true(top_start.y < level.board_origin.y, "top spawned wall refill enters from above the board")
	assert_true(deep_start.y < level.board_origin.y, "deep spawned wall refill must still enter from above the board, not pop in near the hole")
	assert_true(absf((deep_target.y - deep_start.y) - (top_target.y - top_start.y)) < 0.01, "wall-slide refill keeps equal travel distance so vertical clears fall as a stack, not a top-to-bottom paint")
	level.free()


func test_wall_refill_spawned_targets_use_snappy_refill_cap() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_target_refill_cap"), "Level exposes spawned wall-refill duration capping")
	if not level.has_method("_wall_slide_target_refill_cap"):
		level.free()
		return
	var N := Vector2i(-1, -1)
	var source_map := [
		[N, Vector2i(1, -2), N],
		[N, Vector2i(1, 0), N],
	]
	var spawned_cap: float = level.call("_wall_slide_target_refill_cap", source_map, 0, 1)
	var old_node_cap: float = level.call("_wall_slide_target_refill_cap", source_map, 1, 1)
	assert_true(spawned_cap > 0.0 and spawned_cap <= 0.56, "spawned wall refill uses the same bounded duration as ordinary refill")
	assert_true(old_node_cap < 0.0, "existing wall-slide nodes keep per-step timing instead of refill capping")
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f != null:
		var src: String = f.get_as_text()
		var sync_start: int = src.find("func _sync_wall_slide_visuals")
		var sync_end: int = src.find("func _collapse_and_refill", sync_start)
		assert_true(sync_start >= 0 and sync_end > sync_start, "_sync_wall_slide_visuals can be inspected")
		if sync_start >= 0 and sync_end > sync_start:
			var sync_body: String = src.substr(sync_start, sync_end - sync_start)
			assert_true(sync_body.contains("var refill_cap := _wall_slide_target_refill_cap(source_map, row, col)"), "wall-slide visual sync calculates a per-target refill cap")
			assert_true(sync_body.contains("_tween_wall_slide_node(node, target, visual_path, refill_cap)"), "spawned wall-slide refills pass the cap into tween timing")
	level.free()


func test_wall_refill_spawned_targets_do_not_replay_top_to_bottom_path() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_target_visual_path"), "Level can choose a visual path per wall-slide target")
	if not level.has_method("_wall_slide_target_visual_path"):
		level.free()
		return
	var N := Vector2i(-1, -1)
	var source_map := [
		[N, Vector2i(1, -2), N],
		[N, Vector2i(1, 0), N],
	]
	var spawned_route := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]
	var old_route := [Vector2i(1, 0), Vector2i(1, 1)]
	var path_map := [
		[[], spawned_route, []],
		[[], old_route, []],
	]
	assert_eq(level.call("_wall_slide_target_visual_path", source_map, path_map, 0, 1), [], "spawned refill uses a continuous fall path instead of replaying row0-to-rowN visual steps")
	assert_eq(level.call("_wall_slide_target_visual_path", source_map, path_map, 1, 1), old_route, "old wall-slide pieces still replay the recorded gravity route")
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f != null:
		var src: String = f.get_as_text()
		var sync_start: int = src.find("func _sync_wall_slide_visuals")
		var sync_end: int = src.find("func _collapse_and_refill", sync_start)
		assert_true(sync_start >= 0 and sync_end > sync_start, "_sync_wall_slide_visuals can be inspected")
		if sync_start >= 0 and sync_end > sync_start:
			var sync_body: String = src.substr(sync_start, sync_end - sync_start)
			assert_true(sync_body.contains("var visual_path := _wall_slide_target_visual_path(source_map, path_map, row, col)"), "wall-slide sync asks the target whether recorded path replay is appropriate")
			assert_true(sync_body.contains("_tween_wall_slide_node(node, target, visual_path, refill_cap)"), "wall-slide sync tweens spawned refills without replaying the top-to-bottom route")
	level.free()


func test_wall_refill_spawned_targets_use_same_duration_for_short_and_long_paths() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_wall_slide_duration_for_target"), "Level can force a shared duration for spawned refill targets")
	if not level.has_method("_wall_slide_duration_for_target"):
		level.free()
		return
	level.board = Board.new(3, 7, [0, 1, 2], 0, 25, 1)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var top_start := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y - 7.0 * level.cell_size)
	var top_target: Vector2 = level.call("_cell_center", 0, 1)
	var deep_start := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y - 1.0 * level.cell_size)
	var deep_target: Vector2 = level.call("_cell_center", 6, 1)
	var top_points: Array = level.call("_wall_slide_path_points", top_start, top_target)
	var deep_points: Array = level.call("_wall_slide_path_points", deep_start, deep_target)
	var top_uncapped: float = level.call("_wall_slide_duration_for_points", top_points)
	var deep_uncapped: float = level.call("_wall_slide_duration_for_points", deep_points)
	assert_true(top_uncapped < deep_uncapped, "short top refill paths would otherwise arrive before deep refill paths")
	var forced_duration := 0.52
	var top_forced: float = level.call("_wall_slide_duration_for_target", top_points, forced_duration)
	var deep_forced: float = level.call("_wall_slide_duration_for_target", deep_points, forced_duration)
	assert_eq(top_forced, deep_forced, "spawned refill targets share one duration so upper cells do not settle before lower cells")
	assert_eq(top_forced, forced_duration, "shared spawned-refill duration uses the configured refill time")
	level.free()


func test_level_finish_consumed_move_does_not_full_rerender() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _finish_consumed_move")
	assert_true(start >= 0, "_finish_consumed_move exists")
	if start < 0:
		return
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("board._settle_consumed_move"), "finish path still delegates move settlement to Board")
	assert_false(body.contains("_sync_visuals_to_board()"), "move finish must not full-rerender the board after every ordinary clear")
	assert_false(body.contains("_sync_changed_visuals_to_board()"), "move finish must not snap changed board visuals to their final cells")
	assert_true(body.contains("await _animate_board_changes_from_snapshot"), "move finish animates post-settlement board changes instead of jumping")


func test_level_swap_passes_moved_position_to_first_cascade() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var swap_start: int = src.find("func _try_swap")
	assert_true(swap_start >= 0, "_try_swap exists")
	var swap_end: int = src.find("\n\t## 问题2", swap_start)
	if swap_end < 0:
		swap_end = src.find("\nfunc ", swap_start + 1)
	if swap_start < 0:
		return
	var swap_body: String = src.substr(swap_start, swap_end - swap_start)
	assert_false(swap_body.contains("_line_kind_from_swap"), "swap direction must not override generated line-special kind")
	assert_true(swap_body.contains("ME.swap_special_spawn_preference(board.grid, board.fx, board._layers(), b, a)"), "first cascade considers both post-swap positions for generated special placement")
	assert_true(swap_body.contains("_resolve_cascades(spawn_preference, true)"), "first cascade receives the selected post-swap special position")

	var resolve_start: int = src.find("func _resolve_cascades")
	assert_true(resolve_start >= 0, "_resolve_cascades exists")
	if resolve_start < 0:
		return
	var resolve_end: int = src.find("\nfunc ", resolve_start + 1)
	if resolve_end < 0:
		resolve_end = src.length()
	var resolve_body: String = src.substr(resolve_start, resolve_end - resolve_start)
	assert_true(resolve_body.contains("ME.collect_clears(board.grid, board.fx, board._layers(), cascade_preferred, ME.SP_NONE, cascade_force_preferred)"), "collect_clears receives the first-cascade target-position override")
	assert_false(resolve_body.contains("cascade_preferred_line_kind"), "line-special kind is decided by the 4-match rule, not swap direction")


func test_endgame_bonus_refills_and_stabilizes_before_result() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_endgame_bonus()")
	assert_true(start >= 0, "_play_endgame_bonus exists")
	if start < 0:
		return
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var initial_blast_idx: int = body.find("await _play_endgame_bonus_special_blast(seeds, 1)")
	var chain_idx: int = body.find("await _resolve_endgame_bonus_special_chain()")
	var result_idx: int = body.find("ENDGAME_BONUS_RESULT_HOLD")
	assert_true(initial_blast_idx >= 0, "endgame bonus sends reward specials through the shared blast helper")
	assert_true(chain_idx > initial_blast_idx, "endgame bonus starts the special-blast chain after the initial reward blast")
	assert_true(result_idx > chain_idx, "result panel waits until the board is stable")
	var blast_start: int = src.find("func _play_endgame_bonus_special_blast")
	var blast_end: int = src.find("func _resolve_endgame_bonus_special_chain", blast_start)
	assert_true(blast_start >= 0 and blast_end > blast_start, "endgame bonus blast helper can be inspected")
	if blast_start < 0 or blast_end <= blast_start:
		return
	var blast_body: String = src.substr(blast_start, blast_end - blast_start)
	var clear_idx: int = blast_body.find("ME._apply_clears(board.grid, board.fx, to_clear, [])")
	var collapse_idx: int = blast_body.find("await _collapse_and_refill()", clear_idx)
	assert_true(clear_idx >= 0, "endgame bonus applies clears")
	assert_true(collapse_idx > clear_idx, "endgame bonus refills after reward blasts")


func test_endgame_bonus_uses_in_board_conversion_matrix_before_blast() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_false(src.contains("ENDGAME_BONUS_BEAM_COLOR"), "endgame bonus no longer has reward-beam color state")
	assert_false(src.contains("ENDGAME_BONUS_BEAM_TRAVEL"), "endgame bonus no longer waits on a fired beam")
	assert_false(src.contains("ENDGAME_BONUS_CONVERT_HOLD"), "endgame bonus uses the 5+4 conversion timing without the old extra reward-beam hold")
	assert_false(src.contains("ENDGAME_BONUS_MATRIX_PREVIEW_HOLD"), "endgame bonus must not add settlement-only preview timing")
	assert_false(src.contains("ENDGAME_BONUS_MATRIX_OUTLINE_FILL"), "endgame bonus must not use a settlement-only outline size")
	var start: int = src.find("func _play_endgame_bonus()")
	assert_true(start >= 0, "_play_endgame_bonus exists")
	if start < 0:
		return
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_false(body.contains("_topbar_moves_number_center()"), "endgame bonus does not use the moves-number anchor as a launch point")
	assert_false(body.contains("spawn_comet_beam"), "endgame bonus does not fire comet beams")
	var conversion_idx: int = body.find("await _play_endgame_bonus_conversion_matrix(picks)")
	var blast_idx: int = body.find("await _play_endgame_bonus_special_blast(seeds, 1)")
	assert_true(conversion_idx >= 0, "endgame bonus plays an in-board conversion matrix")
	assert_true(blast_idx > conversion_idx, "reward specials blast only after the conversion matrix finishes")
	var helper_start: int = src.find("func _play_endgame_bonus_conversion_matrix")
	var helper_end: int = src.find("func _play_endgame_bonus_special_blast", helper_start)
	assert_true(helper_start >= 0 and helper_end > helper_start, "endgame conversion matrix helper can be inspected")
	if helper_start < 0 or helper_end <= helper_start:
		return
	var helper_body: String = src.substr(helper_start, helper_end - helper_start)
	assert_true(helper_body.contains("preview_cells.append(p)"), "each picked gem is passed into the same preview target list used by colorbomb conversion")
	assert_true(helper_body.contains("await _play_colorbomb_absorb_preview(Vector2i(-1, -1), preview_cells, virtual_fx.keys(), _endgame_bonus_conversion_preview_center(preview_cells), false)"), "endgame bonus reuses the 5+4 absorb/matrix preview without inventing a settlement-only marker")
	assert_false(helper_body.contains("spawn_conversion_matrix_marker"), "endgame bonus does not use the abandoned custom marker")
	var outline_idx: int = helper_body.find("await _play_colorbomb_absorb_preview")
	var convert_idx: int = helper_body.find("await _show_colorbomb_virtual_conversion(virtual_fx)", outline_idx)
	assert_true(convert_idx > outline_idx, "special conversion starts after the shared 5+4 preview")
	assert_true(helper_body.contains("await _show_colorbomb_virtual_conversion(virtual_fx)"), "endgame bonus reuses the 5+4 special-conversion animation")
	assert_false(helper_body.contains("spawn_comet_beam"), "conversion matrix helper does not fire from the UI")


func test_endgame_bonus_reuses_colorbomb_preview_without_core_pulse() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_false(src.contains("func spawn_conversion_matrix_marker"), "settlement does not keep a custom marker that differs from 5+4")
	var start: int = src.find("func _play_colorbomb_absorb_preview")
	var end: int = src.find("func _colorbomb_node_at", start)
	assert_true(start >= 0 and end > start, "colorbomb preview helper can be inspected")
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("end_pos_override: Variant = null"), "the shared 5+4 preview can be aimed at a virtual settlement center")
	assert_true(body.contains("if end_pos_override is Vector2:"), "endgame can reuse the target-side preview without a real colorbomb source")
	assert_true(body.contains("if pulse_core:"), "endgame can disable the single colorbomb core pulse")


func test_endgame_bonus_spends_visible_moves_without_per_beam_fire_sequence() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	assert_true(src.contains("func _display_moves_left"), "topbar can use a temporary moves display value")
	assert_true(src.contains("func _set_moves_display_override"), "endgame bonus can update only the moves counter text")
	assert_true(src.contains("func _clear_moves_display_override"), "endgame bonus clears the temporary moves display after the animation")
	var start: int = src.find("func _play_endgame_bonus()")
	assert_true(start >= 0, "_play_endgame_bonus exists")
	if start < 0:
		return
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var capture_idx: int = body.find("var bonus_moves: int = maxi(board.moves_left, 0)")
	var prepare_idx: int = body.find("var picks: Array = board.prepare_endgame_bonus_lines()")
	var spend_idx: int = body.find("_set_moves_display_override(0)", prepare_idx)
	var conversion_idx: int = body.find("await _play_endgame_bonus_conversion_matrix(picks)", spend_idx)
	var clear_idx: int = body.find("_clear_moves_display_override()", conversion_idx)
	assert_true(capture_idx >= 0 and capture_idx < prepare_idx, "endgame bonus captures the visible moves count before Board spends it")
	assert_true(spend_idx > prepare_idx, "endgame bonus spends the visible moves count once instead of decrementing per fired beam")
	assert_true(conversion_idx > spend_idx, "board conversion starts after the moves count is visibly spent")
	assert_true(clear_idx > conversion_idx, "temporary moves display is cleared after board conversion and blasts")
	assert_false(body.contains("bonus_moves = maxi(bonus_moves - 1, 0)"), "endgame bonus no longer decrements once per beam")


func test_endgame_bonus_loops_special_blasts_until_plain_board() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_endgame_bonus()")
	assert_true(start >= 0, "_play_endgame_bonus exists")
	if start < 0:
		return
	var end: int = src.find("# 程序绘制", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("await _play_endgame_bonus_special_blast(seeds, 1)"), "initial reward specials use the shared blast path")
	assert_true(body.contains("await _resolve_endgame_bonus_special_chain()"), "endgame bonus keeps resolving specials after refill")
	assert_true(body.find("await _play_endgame_bonus_special_blast(seeds, 1)") < body.find("await _resolve_endgame_bonus_special_chain()"), "special chain starts after the initial reward blast")
	var chain_start: int = src.find("func _resolve_endgame_bonus_special_chain")
	var chain_end: int = src.find("func _endgame_bonus_special_seeds", chain_start)
	assert_true(chain_start >= 0 and chain_end > chain_start, "endgame special chain helper can be inspected")
	if chain_start < 0 or chain_end <= chain_start:
		return
	var chain_body: String = src.substr(chain_start, chain_end - chain_start)
	assert_true(chain_body.contains("while guard < ENDGAME_BONUS_SPECIAL_CHAIN_MAX"), "endgame special chain is guarded")
	assert_true(chain_body.contains("await _resolve_cascades()"), "each bonus loop first lets falling matches form specials")
	assert_true(chain_body.contains("var seeds := _endgame_bonus_special_seeds()"), "each bonus loop searches for newly formed specials")
	assert_true(chain_body.contains("await _play_endgame_bonus_special_blast(seeds"), "each remaining special batch is auto-blasted")


func test_endgame_bonus_special_seed_scan_finds_only_active_specials() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_endgame_bonus_special_seeds"), "Level exposes endgame special seed scanning")
	if not level.has_method("_endgame_bonus_special_seeds"):
		level.free()
		return
	level.board = Board.new(4, 3, [0, 1, 2], 0, 25, 1)
	level.board.grid = [
		[0, 1, 2, 0],
		[1, ME.EMPTY, 2, ME.WALL],
		[2, 1, 0, 2],
	]
	level.board.fx = [
		[ME.SP_NONE, ME.SP_LINE_H, ME.SP_NONE, ME.SP_BOMB],
		[ME.SP_LINE_V, ME.SP_BOMB, ME.SP_COLORBOMB, ME.SP_LINE_H],
		[ME.SP_NONE, ME.SP_NONE, ME.SP_COLORBOMB, ME.SP_NONE],
	]
	var seeds: Array = level.call("_endgame_bonus_special_seeds")
	assert_true(seeds.has(Vector2i(1, 0)), "line special on a gem is a bonus seed")
	assert_true(seeds.has(Vector2i(3, 0)), "bomb special on a gem is a bonus seed")
	assert_true(seeds.has(Vector2i(0, 1)), "vertical line special on a gem is a bonus seed")
	assert_true(seeds.has(Vector2i(2, 1)), "colorbomb special on a gem is a bonus seed")
	assert_true(seeds.has(Vector2i(2, 2)), "newly formed colorbomb after a fall is a bonus seed")
	assert_false(seeds.has(Vector2i(1, 1)), "stale fx on empty cells is ignored")
	assert_false(seeds.has(Vector2i(3, 1)), "stale fx on wall cells is ignored")
	level.free()


func test_opening_drop_starts_gems_above_the_board() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_opening_drop_start_position"), "Level exposes opening drop start calculation")
	assert_true(level.has_method("_opening_drop_delay"), "Level exposes opening drop delay calculation")
	if not level.has_method("_opening_drop_start_position") or not level.has_method("_opening_drop_delay"):
		level.free()
		return
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var top_center := Vector2(125, 455)
	var low_center := Vector2(125, 455 + 5.0 * level.cell_size)
	var top_start: Vector2 = level.call("_opening_drop_start_position", top_center, 0)
	var low_start: Vector2 = level.call("_opening_drop_start_position", low_center, 5)
	assert_true(top_start.y < level.board_origin.y, "top-row gem begins above the board")
	assert_true(low_start.y < level.board_origin.y, "lower-row gem also begins above the board")
	assert_eq(top_start.y, low_start.y, "all opening gems enter from the same empty-board line")
	var top_delay: float = level.call("_opening_drop_delay", 0, 10)
	var bottom_delay: float = level.call("_opening_drop_delay", 9, 10)
	assert_true(bottom_delay < top_delay, "bottom row starts first so the board fills from bottom to top")
	assert_true(top_delay - bottom_delay >= 0.25, "opening drop is slow enough to read")
	level.free()


func test_opening_drop_skips_temporary_gems_for_ice_cells() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_opening_visual_species"), "Level exposes opening visual species calculation")
	if not level.has_method("_opening_visual_species"):
		level.free()
		return
	var coat := [
		[1, 0],
		[0, 0],
	]
	level.board = Board.new(2, 2, [0, 1], 0, 10, 1, [], [], [], coat)
	assert_eq(level.board.grid[0][0], ME.EMPTY, "ice logic cell still has no hidden gem")
	var visual_sp: int = level.call("_opening_visual_species", 0, 0)
	assert_eq(visual_sp, ME.EMPTY, "ice opening visual does not show a temporary falling gem")
	level.free()


func test_opening_drop_renders_ice_marker_from_start_line() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.background_layer = level.get_node("BackgroundLayer")
	level.board_layer = level.get_node("BoardLayer")
	level.gem_layer = level.get_node("GemLayer")
	level.character_layer = level.get_node("CharacterLayer")
	level.ui_layer = level.get_node("UILayer")
	level.skill_bar = level.get_node("SkillBar")
	var coat := [
		[1, 0],
		[0, 0],
	]
	level.board = Board.new(2, 2, [0, 1], 0, 10, 1, [], [], [], coat)
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	level.call("_render_board", true)
	assert_eq(level._gem_nodes[0][0], null, "opening ice cell does not create a standalone temporary gem")
	var marker: Sprite2D = level._coat_nodes[0][0]
	assert_true(marker != null, "opening ice marker is created immediately")
	if marker != null:
		assert_true(marker.position.y < level.board_origin.y, "opening ice marker starts above the board and falls in")
	level.free()


func test_ice_marker_position_is_horizontally_centered_in_cell() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_coat_marker_position"), "Level exposes ice marker position calculation")
	if not level.has_method("_coat_marker_position"):
		level.free()
		return
	level.board_origin = Vector2(90, 420)
	level.cell_size = 70.0
	var center: Vector2 = level.call("_cell_center", 0, 0)
	var marker_position: Vector2 = level.call("_coat_marker_position", 0, 0)
	assert_eq(marker_position.x, center.x, "ice marker should be horizontally centered in its cell")
	level.free()


func test_opening_drop_uses_temporary_gems_for_wall_cells() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_opening_visual_species"), "Level exposes opening visual species calculation")
	if not level.has_method("_opening_visual_species"):
		level.free()
		return
	var wall_mask := [
		[true, false],
		[false, false],
	]
	level.board = Board.new(2, 2, [0, 1], 0, 10, 1, wall_mask)
	assert_eq(level.board.grid[0][0], ME.WALL, "stone logic cell is still a wall")
	var visual_sp: int = level.call("_opening_visual_species", 0, 0)
	assert_true(level.board.species.has(visual_sp), "stone opening visual uses a temporary falling gem species")
	level.free()


func test_opening_obstacle_markers_replace_temporary_gems() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var wall_start: int = src.find("func _show_opening_wall_marker")
	var wall_end: int = src.find("func _play_opening_freeze", wall_start)
	assert_true(wall_start >= 0 and wall_end > wall_start, "wall opening marker function can be inspected")
	if wall_start < 0 or wall_end <= wall_start:
		return
	var wall_body: String = src.substr(wall_start, wall_end - wall_start)
	assert_true(wall_body.contains("_clear_gem_node_at(pos.y, pos.x)"), "stone cast removes the temporary gem before showing the stone")
	assert_false(src.contains("func _show_opening_coat_marker"), "ice opening marker no longer has a separate boss-cast replacement path")


func test_opening_stone_casts_from_boss_but_ice_does_not() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var freeze_start: int = src.find("func _play_opening_freeze")
	assert_true(freeze_start >= 0, "opening freeze phase exists")
	if freeze_start < 0:
		return
	var freeze_end: int = src.find("func _apply_opening_freeze_instant", freeze_start)
	if freeze_end < 0:
		freeze_end = src.length()
	var freeze_body: String = src.substr(freeze_start, freeze_end - freeze_start)
	var finish_idx: int = src.find("_finish_opening_drop(generation)", freeze_start)
	var beam_idx: int = freeze_body.find("Fx.spawn_beam(BOSS_C")
	var marker_idx: int = freeze_body.find("_show_opening_wall_marker(p, true)")
	assert_true(beam_idx >= 0, "opening stone generation still casts beams from the boss position")
	assert_true(marker_idx > beam_idx, "stone marker appears after the boss beam")
	assert_false(freeze_body.contains("OPENING_FREEZE_COLOR"), "initial ice is not generated by a boss freeze beam")
	assert_false(freeze_body.contains("_show_opening_coat_marker(p, true)"), "initial ice marker is not spawned after the opening drop")
	assert_true(finish_idx > freeze_start, "input unlock waits until opening obstacles are settled")


func test_opening_boss_casts_stones_only_and_ice_falls_with_board() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var render_start: int = src.find("func _render_board")
	var render_end: int = src.find("func _blank_visual_rows", render_start)
	assert_true(render_start >= 0 and render_end > render_start, "_render_board can be inspected")
	if render_start < 0 or render_end <= render_start:
		return
	var render_body: String = src.substr(render_start, render_end - render_start)
	assert_true(render_body.contains("if opening_drop:\n\t\t_wall_nodes = _blank_visual_rows()\n\telse:\n\t\t_render_wall_visuals()"), "opening drop keeps wall stones hidden until the boss casts them")
	assert_true(render_body.contains("if opening_drop:\n\t\t_render_opening_coat_visuals()\n\telse:\n\t\t_render_coat_visuals()"), "opening drop renders ice markers immediately so they fall with the board")

	var freeze_start: int = src.find("func _play_opening_freeze")
	var freeze_end: int = src.find("func _apply_opening_freeze_instant", freeze_start)
	assert_true(freeze_start >= 0 and freeze_end > freeze_start, "opening freeze phase can be inspected")
	if freeze_start < 0 or freeze_end <= freeze_start:
		return
	var freeze_body: String = src.substr(freeze_start, freeze_end - freeze_start)
	var wall_cells_idx: int = freeze_body.find("_opening_wall_cells()")
	var wall_beam_idx: int = freeze_body.find("OPENING_STONE_COLOR")
	var wall_marker_idx: int = freeze_body.find("_show_opening_wall_marker(p, true)")
	assert_true(wall_cells_idx >= 0, "opening freeze gathers wall stone cells")
	assert_true(wall_beam_idx >= 0, "stone generation uses a boss beam color")
	assert_true(wall_marker_idx > wall_beam_idx, "stone marker appears after the boss beam")
	assert_false(freeze_body.contains("_opening_coat_cells()"), "ice cells are not gathered for boss casting")
	assert_false(freeze_body.contains("_show_opening_coat_marker(p, true)"), "boss opening phase no longer spawns ice markers")
