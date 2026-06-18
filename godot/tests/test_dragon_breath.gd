extends "res://tests/test_lib.gd"

const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const LevelLayout := preload("res://match3/level_layout.gd")
const LevelSkills := preload("res://match3/skills.gd")
const PetRegistry := preload("res://match3/pets/pet_registry.gd")
const DragonBreathVisual := preload("res://match3/pets/dragon_breath_visual.gd")

const DRAGON_BABY_AVATAR := "res://assets/pets/dragon_baby/frames/dragon_00.png"
const DRAGON_BABY_LAST_FRAME := "res://assets/pets/dragon_baby/frames/dragon_63.png"
const DRAGON_YOUTH_FIRST_FRAME := "res://assets/pets/dragon_youth/frames/frame_001.png"
const DRAGON_YOUTH_LAST_FRAME := "res://assets/pets/dragon_youth/frames/frame_280.png"
const DRAGON_VISUAL_SCRIPT := "res://match3/pets/dragon_breath_visual.gd"
const DRAGON_CAST_SCRIPT := "res://match3/pets/dragon_breath_cast.gd"
const LEVEL_SCRIPT := "res://match3/level.gd"
const DRAGON_CAST_NODE := "DragonBreathCast"
const DRAGON_FRAME_NODE := "DragonBreathFrame"
const DRAGON_BABY_TEXTURE_SIZE := Vector2(512.0, 512.0)
const DRAGON_BABY_VISIBLE_BBOX := Rect2(Vector2(44.0, 41.0), Vector2(387.0, 418.0))
const DRAGON_YOUTH_TEXTURE_SIZE := Vector2(1440.0, 1440.0)
const DRAGON_YOUTH_VISIBLE_BBOX := Rect2(Vector2(279.0, 434.0), Vector2(883.0, 571.0))


func _configured_dragon_visual(skill_layer: CanvasLayer = null, variant: String = "youth", slot_index: int = 1, flipped: bool = false) -> Node:
	var script := load(DRAGON_VISUAL_SCRIPT)
	assert_true(script != null, "dragon breath visual helper exists")
	if script == null:
		return null
	var cast = script.new()
	var board := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 25, 7)
	var layout: Dictionary = LevelLayout.compute_layout(board.width, board.height)
	cast.setup({
		"skill_bar": skill_layer,
		"board": board,
		"cell_size": float(layout["cell_size"]),
		"board_origin": layout["board_origin"],
		"variant": variant,
		"slot_index": slot_index,
		"flip_h": flipped,
	})
	if skill_layer != null:
		skill_layer.add_child(cast)
	cast.play_and_retire()
	return cast


func _dragon_visible_metrics(cast: Node) -> Dictionary:
	var sprite := cast.get_node_or_null(DRAGON_FRAME_NODE) as AnimatedSprite2D
	assert_true(sprite != null, "dragon cast builds an animated youth dragon sprite")
	if sprite == null:
		return {}
	var bbox: Rect2 = sprite.get_meta("visible_bbox", cast.get("FRAME_VISIBLE_BBOX"))
	var scale := absf(sprite.scale.x)
	var visible_left := sprite.position.x + bbox.position.x * sprite.scale.x
	var visible_right := sprite.position.x + bbox.end.x * sprite.scale.x
	if sprite.scale.x < 0.0:
		visible_left = sprite.position.x + bbox.end.x * sprite.scale.x
		visible_right = sprite.position.x + bbox.position.x * sprite.scale.x
	var visible_center_x := visible_left + (visible_right - visible_left) * 0.5
	var visible_bottom := sprite.position.y + bbox.end.y * scale
	return {
		"sprite": sprite,
		"scale": scale,
		"visible_left": visible_left,
		"visible_center_x": visible_center_x,
		"visible_right": visible_right,
		"visible_bottom": visible_bottom,
	}


func _prepare_live_level_for_dragon(level_idx: int = 1) -> Node:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "test runs with a SceneTree for the real pressed-signal path")
	if tree == null:
		level.free()
		return null
	tree.root.add_child(level)
	level.background_layer = level.get_node("BackgroundLayer")
	level.board_layer = level.get_node("BoardLayer")
	level.gem_layer = level.get_node("GemLayer")
	level.character_layer = level.get_node("CharacterLayer")
	level.ui_layer = level.get_node("UILayer")
	level.skill_bar = level.get_node("SkillBar")
	var fx := tree.root.get_node_or_null("Fx")
	if fx != null:
		fx.call("attach", level.get_node("FXLayer"), level.gem_layer)
	level._levels = LevelLibrary.load_file(LevelLibrary.DEFAULT_LEVELS_PATH)
	level._playable = []
	for i in range(level._levels.size()):
		var objs = level._levels[i].get("objectives", [])
		if objs is Array and not objs.is_empty():
			level._playable.append(i)
	level.load_level(level_idx)
	return level


func _free_live_level(level: Node) -> void:
	if level == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and level.get_parent() == tree.root:
		tree.root.remove_child(level)
	level.free()


func _find_node_with_script_path(root: Node, script_path: String) -> Node:
	if root == null:
		return null
	var script: Script = root.get_script()
	if script != null and script.resource_path == script_path:
		return root
	for child in root.get_children():
		var found := _find_node_with_script_path(child, script_path)
		if found != null:
			return found
	return null


func _button_visible_width(btn: TextureButton, bbox: Rect2, texture_size: Vector2) -> float:
	if btn == null or texture_size.x <= 0.0:
		return 0.0
	return bbox.size.x * btn.size.x * absf(btn.scale.x) / texture_size.x


func _button_visible_top(btn: TextureButton, bbox: Rect2, texture_size: Vector2) -> float:
	if btn == null or texture_size.y <= 0.0:
		return 0.0
	return btn.position.y + bbox.position.y * btn.size.y / texture_size.y


func _texture_used_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var image := tex.get_image()
	if image == null or image.is_empty():
		return Rect2()
	var used := image.get_used_rect()
	return Rect2(
		Vector2(float(used.position.x), float(used.position.y)),
		Vector2(float(used.size.x), float(used.size.y))
	)


func _texture_horn_span(tex: Texture2D, used_rect: Rect2) -> float:
	if tex == null or used_rect.size.x <= 0.0 or used_rect.size.y <= 0.0:
		return 0.0
	var image := tex.get_image()
	if image == null or image.is_empty():
		return 0.0
	var x0 := int(used_rect.position.x + used_rect.size.x * 0.50)
	var x1 := int(used_rect.end.x)
	var y0 := int(used_rect.position.y)
	var y1 := int(used_rect.position.y + used_rect.size.y * 0.44)
	var min_x := 999999
	var max_x := -999999
	for y in range(y0, y1, 2):
		for x in range(x0, x1, 2):
			if _is_horn_pixel(image.get_pixel(x, y)):
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	if max_x < min_x:
		return 0.0
	return float(max_x - min_x + 1)


func _is_horn_pixel(c: Color) -> bool:
	if c.a < 0.25:
		return false
	if c.r < 0.52 or c.g < 0.24 or c.b > 0.34:
		return false
	if c.r < c.g * 1.05:
		return false
	if c.g < c.b * 1.4:
		return false
	return true


func _expected_dragon_visible_width(level: Node, variant: String) -> float:
	var board_w: float = float(level.board.width) * level.cell_size
	if variant == "baby":
		return clampf(board_w * 0.42, 220.0, 300.0)
	return clampf(board_w * 0.68, 360.0, 430.0)


func _clear_dragon_frame_cache() -> void:
	var probe := DragonBreathVisual.new()
	if probe.has_method("clear_frame_cache_for_tests"):
		probe.call("clear_frame_cache_for_tests")
	probe.free()


func _function_body(path: String, func_name: String) -> String:
	var src := FileAccess.get_file_as_string(path)
	assert_true(src != "", "%s can be inspected" % path)
	var start: int = src.find("func %s" % func_name)
	assert_true(start >= 0, "%s exists in %s" % [func_name, path])
	if start < 0:
		return ""
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	return src.substr(start, end - start)


func test_dragon_skill_registry_owns_cast_controller() -> void:
	assert_true(PetRegistry.has_pet("龙息大招"), "dragon breath is registry-owned, not level.gd direct-dispatch owned")
	var cast_script: Script = PetRegistry.cast_for("龙息大招")
	assert_true(cast_script != null, "dragon breath registry entry resolves to a cast controller script")
	if cast_script != null:
		assert_eq(cast_script.resource_path, DRAGON_CAST_SCRIPT, "dragon breath resolves to its dedicated PetCast controller")


func test_dragon_skill_slots_use_clean_first_frame_avatars() -> void:
	assert_eq(LevelSkills.SKILLS.size(), 2, "bottom skill bar only keeps the two dragon slots")
	assert_eq(String(LevelSkills.SKILLS[0].get("skill", "")), "龙息大招", "baby dragon slot casts dragon breath")
	assert_eq(String(LevelSkills.SKILLS[1].get("skill", "")), "龙息大招", "youth dragon slot casts dragon breath")
	assert_eq(String(LevelSkills.SKILLS[0].get("av", "")), DRAGON_BABY_AVATAR, "left slot idles on the baby dragon first frame")
	assert_eq(String(LevelSkills.SKILLS[1].get("av", "")), DRAGON_YOUTH_FIRST_FRAME, "right slot idles on the youth dragon first frame")
	assert_eq(String(LevelSkills.SKILLS[0].get("variant", "")), "baby", "left slot declares baby dragon animation frames")
	assert_eq(String(LevelSkills.SKILLS[1].get("variant", "")), "youth", "right slot declares youth dragon animation frames")
	assert_false(bool(LevelSkills.SKILLS[0].get("flip_h", false)), "left baby dragon is not mirrored")
	assert_true(bool(LevelSkills.SKILLS[1].get("flip_h", false)), "right youth dragon is mirrored")
	assert_eq(String(LevelSkills.SKILLS[0].get("gem", "")), "red", "baby dragon charges from red gem clears")
	assert_eq(String(LevelSkills.SKILLS[1].get("gem", "")), "red", "youth dragon charges from red gem clears")
	assert_true(FileAccess.file_exists(DRAGON_BABY_AVATAR), "cleaned baby dragon avatar frame is synced under res:// assets")
	assert_true(FileAccess.file_exists("%s.import" % DRAGON_BABY_AVATAR), "cleaned baby dragon avatar is imported by Godot, not only present as a raw PNG")
	assert_true(ResourceLoader.exists(DRAGON_BABY_AVATAR), "live game resource loading can resolve the cleaned baby dragon avatar")
	assert_true(FileAccess.file_exists("%s.import" % DRAGON_YOUTH_FIRST_FRAME), "cleaned youth dragon frames are imported by Godot for the live cast animation")
	assert_true(ResourceLoader.exists(DRAGON_YOUTH_FIRST_FRAME), "live game resource loading can resolve the cleaned youth dragon animation frame")


func test_dragon_breath_visual_uses_baby_frames_from_first_to_last() -> void:
	var cast := _configured_dragon_visual(null, "baby", 0, false)
	if cast == null:
		return
	var sprite := cast.get_node_or_null(DRAGON_FRAME_NODE) as AnimatedSprite2D
	assert_true(sprite != null, "baby dragon cast builds an animated sprite")
	if sprite != null and sprite.sprite_frames != null:
		assert_eq(sprite.sprite_frames.get_frame_count("cast"), 64, "baby dragon cast plays every provided frame")
		var first := sprite.sprite_frames.get_frame_texture("cast", 0)
		var last := sprite.sprite_frames.get_frame_texture("cast", 63)
		assert_true(first != null and first.resource_path == DRAGON_BABY_AVATAR, "baby dragon cast starts at the first idle frame")
		assert_true(last != null and last.resource_path == DRAGON_BABY_LAST_FRAME, "baby dragon cast reaches the final provided frame")
		assert_eq(String(sprite.get_meta("variant", "")), "baby", "baby cast records its frame variant")
	cast.free()


func test_dragon_breath_visual_uses_youth_frames_from_first_to_last() -> void:
	var cast := _configured_dragon_visual(null, "youth", 1, true)
	if cast == null:
		return
	var sprite := cast.get_node_or_null(DRAGON_FRAME_NODE) as AnimatedSprite2D
	assert_true(sprite != null, "youth dragon cast builds an animated sprite")
	if sprite != null and sprite.sprite_frames != null:
		assert_eq(sprite.sprite_frames.get_frame_count("cast"), 280, "youth dragon cast plays every provided frame")
		var first := sprite.sprite_frames.get_frame_texture("cast", 0)
		var last := sprite.sprite_frames.get_frame_texture("cast", 279)
		assert_true(first != null and first.resource_path == DRAGON_YOUTH_FIRST_FRAME, "youth dragon cast starts at the first idle frame")
		assert_true(last != null and last.resource_path == DRAGON_YOUTH_LAST_FRAME, "youth dragon cast reaches the final provided frame")
		assert_eq(String(sprite.get_meta("variant", "")), "youth", "youth cast records its frame variant")
		assert_true(sprite.scale.x < 0.0, "right-side youth dragon cast is mirrored")
	cast.free()


func test_youth_dragon_cast_normalizes_scale_by_horn_span_not_wings() -> void:
	_clear_dragon_frame_cache()
	var cast := _configured_dragon_visual(null, "youth", 1, true)
	if cast == null:
		return
	assert_true(cast.has_method("_apply_frame_geometry"), "dragon cast exposes per-frame geometry normalization for uneven AI frame sizes")
	var sprite := cast.get_node_or_null(DRAGON_FRAME_NODE) as AnimatedSprite2D
	assert_true(sprite != null and sprite.sprite_frames != null, "youth dragon cast builds frames for normalization")
	if sprite == null or sprite.sprite_frames == null or not cast.has_method("_apply_frame_geometry"):
		cast.free()
		return
	var raw_min := INF
	var raw_max := -INF
	var horn_min := INF
	var horn_max := -INF
	var shown_horn_min := INF
	var shown_horn_max := -INF
	var shown_body_min := INF
	var shown_body_max := -INF
	for i in range(sprite.sprite_frames.get_frame_count("cast")):
		var tex := sprite.sprite_frames.get_frame_texture("cast", i)
		var rect := _texture_used_rect(tex)
		if rect.size.x <= 0.0:
			continue
		var horn_span := _texture_horn_span(tex, rect)
		if horn_span <= 16.0:
			continue
		raw_min = minf(raw_min, rect.size.x)
		raw_max = maxf(raw_max, rect.size.x)
		horn_min = minf(horn_min, horn_span)
		horn_max = maxf(horn_max, horn_span)
		cast.call("_apply_frame_geometry", i)
		var scale := absf(sprite.scale.x)
		shown_horn_min = minf(shown_horn_min, horn_span * scale)
		shown_horn_max = maxf(shown_horn_max, horn_span * scale)
		shown_body_min = minf(shown_body_min, rect.size.x * scale)
		shown_body_max = maxf(shown_body_max, rect.size.x * scale)
	assert_true(raw_max - raw_min > 40.0, "source youth dragon frames contain visibly different wing/body widths")
	assert_true(horn_max - horn_min > 20.0, "source youth dragon frames contain real horn-span scale drift")
	assert_true(shown_body_max - shown_body_min > 40.0, "runtime scale must not force wings and tail into one fixed outer width")
	assert_true(shown_horn_max - shown_horn_min <= 3.0, "runtime playback keeps the youth dragon body scale stable by matching the two-horn span")
	cast.free()


func test_dragon_visual_reuses_cached_sprite_frames_between_casts() -> void:
	var first := _configured_dragon_visual(null, "youth", 1, true)
	var second := _configured_dragon_visual(null, "youth", 1, true)
	if first == null or second == null:
		if first != null:
			first.free()
		if second != null:
			second.free()
		return
	var first_sprite := first.get_node_or_null(DRAGON_FRAME_NODE) as AnimatedSprite2D
	var second_sprite := second.get_node_or_null(DRAGON_FRAME_NODE) as AnimatedSprite2D
	assert_true(first_sprite != null and second_sprite != null, "both dragon casts build animation sprites")
	if first_sprite != null and second_sprite != null:
		assert_eq(second_sprite.sprite_frames, first_sprite.sprite_frames, "dragon casts reuse one cached SpriteFrames resource instead of rebuilding every click")
	first.free()
	second.free()


func test_level_build_requests_dragon_frame_prewarm_before_click() -> void:
	var probe := DragonBreathVisual.new()
	if probe.has_method("clear_frame_cache_for_tests"):
		probe.call("clear_frame_cache_for_tests")
	var level := _prepare_live_level_for_dragon()
	if level == null:
		probe.free()
		return
	assert_true(probe.has_method("is_variant_preload_requested"), "dragon visual exposes frame preload status")
	if probe.has_method("is_variant_preload_requested"):
		assert_true(bool(probe.call("is_variant_preload_requested", "baby")), "level build requests baby dragon frame preload before the first click")
		assert_true(bool(probe.call("is_variant_preload_requested", "youth")), "level build requests youth dragon frame preload before the first click")
	_free_live_level(level)
	probe.free()


func test_dragon_breath_direct_clear_accounts_objectives_before_mutation() -> void:
	var body := _function_body(DRAGON_CAST_SCRIPT, "_apply_dragon_effect_async")
	if body == "":
		return
	var account_idx: int = body.find("_account_dragon_clears(cells)")
	var filter_idx: int = body.find("_filtered_dragon_clear_cells(cells, acc)")
	var apply_idx: int = body.find("ME._apply_clears")
	assert_true(account_idx >= 0, "dragon breath direct clears must use the level account path so objective counters update")
	assert_true(filter_idx > account_idx, "dragon breath filters locked/objective-only cells after accounting")
	assert_true(apply_idx > filter_idx, "dragon breath applies board mutation only after objective accounting and filtering")


func test_pet_cast_finish_checks_settlement_before_unlock() -> void:
	var body := _function_body(LEVEL_SCRIPT, "_on_pet_cast_finished")
	if body == "":
		return
	var settle_idx: int = body.find("await _check_settlement()")
	var unlock_idx: int = body.find("_busy = false")
	assert_true(settle_idx >= 0, "pet skill completion must check win/loss settlement after the effect lands")
	assert_true(unlock_idx < 0 or settle_idx < unlock_idx, "pet skill completion checks settlement before releasing input")


func test_dragon_breath_visual_uses_foot_baseline() -> void:
	var cast := _configured_dragon_visual(null, "youth", 1, true)
	if cast == null:
		return
	var metrics := _dragon_visible_metrics(cast)
	assert_true(float(metrics.get("scale", 0.0)) > 0.0, "dragon visual builds with a positive sprite scale")
	assert_true(float(metrics.get("visible_left", 0.0)) > 0.0, "dragon visible left edge comes from rendered youth frame geometry")
	assert_true(float(metrics.get("visible_bottom", 0.0)) > 0.0, "dragon visible foot baseline is measurable from rendered youth frame geometry")
	cast.free()


func test_dragon_breath_anchor_stays_near_dragon_skill_slot_not_board_left() -> void:
	var cast := _configured_dragon_visual(null, "youth", 1, true)
	if cast == null:
		return
	var metrics := _dragon_visible_metrics(cast)
	var dragon_slot_center_x := LevelLayout.DESIGN_W * 1.5 / 2.0
	assert_true(float(metrics.get("visible_left", 0.0)) > 220.0, "big dragon cast should appear on the dragon slot/right side, not at the board-left edge")
	assert_true(float(metrics.get("visible_right", 0.0)) <= LevelLayout.DESIGN_W - 8.0, "right-side dragon stays inside the screen")
	assert_true(absf(float(metrics.get("visible_center_x", 0.0)) - dragon_slot_center_x) <= 55.0, "big dragon visual is centered around the dragon baby skill slot")
	cast.free()


func test_dragon_breath_footline_matches_the_visible_baby_dragon_feet() -> void:
	var cast := _configured_dragon_visual(null, "youth", 1, true)
	if cast == null:
		return
	var metrics := _dragon_visible_metrics(cast)
	var button_top := LevelLayout.SKILL_AV_Y - LevelLayout.SKILL_AV_W * 0.5
	var baby_scale := LevelLayout.SKILL_AV_W / DRAGON_BABY_TEXTURE_SIZE.x
	var baby_foot_y := button_top + DRAGON_BABY_VISIBLE_BBOX.end.y * baby_scale
	assert_true(absf(float(metrics.get("visible_bottom", 0.0)) - baby_foot_y) <= 1.0, "big dragon foot baseline matches the currently visible baby dragon feet in the skill bar")
	cast.free()


func test_dragon_breath_builds_real_youth_animation_on_skill_layer() -> void:
	var layer := CanvasLayer.new()
	var cast := _configured_dragon_visual(layer, "youth", 1, true)
	if cast == null:
		layer.free()
		return
	assert_eq(String(cast.name), DRAGON_CAST_NODE, "dragon cast node has a stable name for cleanup")
	var sprite := cast.get_node_or_null(DRAGON_FRAME_NODE) as AnimatedSprite2D
	assert_true(sprite != null, "dragon cast builds an animated youth dragon sprite")
	if sprite != null:
		assert_false(sprite.centered, "dragon youth frames use top-left placement so measured visible feet can be baseline-aligned")
		assert_true(sprite.sprite_frames != null, "dragon cast has SpriteFrames")
		if sprite.sprite_frames != null:
			assert_true(sprite.sprite_frames.has_animation("cast"), "dragon cast animation is named 'cast'")
			assert_eq(sprite.sprite_frames.get_frame_count("cast"), 280, "dragon cast uses the complete youth frame sequence")
			var first := sprite.sprite_frames.get_frame_texture("cast", 0)
			assert_true(first != null and first.resource_path == DRAGON_YOUTH_FIRST_FRAME, "dragon cast starts from the cleaned youth dragon frame under res:// assets")
		assert_eq(String(sprite.get_meta("anchor", "")), "visible_left_baseline", "dragon sprite records the foot/baseline anchor contract")
		var metrics := _dragon_visible_metrics(cast)
		var button_top := LevelLayout.SKILL_AV_Y - LevelLayout.SKILL_AV_W * 0.5
		var baby_scale := LevelLayout.SKILL_AV_W / DRAGON_BABY_TEXTURE_SIZE.x
		var baby_foot_y := button_top + DRAGON_BABY_VISIBLE_BBOX.end.y * baby_scale
		assert_true(absf(float(metrics.get("visible_bottom", 0.0)) - baby_foot_y) <= 1.0, "built dragon sprite lands on the same visible baby foot baseline")
	cast.free()
	layer.free()


func test_baby_dragon_runtime_skillbar_uses_clean_button_and_spawns_breath_visual() -> void:
	var level := _prepare_live_level_for_dragon()
	if level == null:
		return
	level.skills._skill_charge[0] = level.skills.get("SKILL_CHARGE_REQ")
	level.skills.refresh_visual()
	var btn: TextureButton = level.skills._skill_btns[0]
	assert_true(btn != null, "dragon skill button exists in the live skill bar")
	if btn != null:
		assert_true(btn.texture_normal != null, "dragon button has a visible texture")
		assert_eq(btn.texture_normal.resource_path, DRAGON_BABY_AVATAR, "live dragon button uses the cleaned baby avatar path")
	btn.emit_signal("pressed")
	var cast_controller := _find_node_with_script_path(level, DRAGON_CAST_SCRIPT)
	assert_true(cast_controller != null, "charged dragon press is owned by a PetCast controller node")
	assert_eq(level.skills._skill_charge[0], 0.0, "successful baby dragon cast consumes its charge immediately through the shared skill path")
	var rig = level.skill_bar.get_node_or_null(DRAGON_CAST_NODE)
	assert_true(rig != null, "pressing the charged live dragon button spawns the dragon breath visual through the real skill path")
	if rig != null:
		var sprite := rig.get_node_or_null(DRAGON_FRAME_NODE) as AnimatedSprite2D
		assert_true(sprite != null, "spawned baby dragon breath visual contains an animation sprite")
		if sprite != null:
			assert_eq(String(sprite.get_meta("variant", "")), "baby", "baby slot spawns the baby animation sequence")
			assert_true(sprite.scale.x > 0.0, "left baby dragon visual is not mirrored")
	_free_live_level(level)


func test_youth_dragon_runtime_skillbar_uses_clean_button_and_spawns_flipped_breath_visual() -> void:
	var level := _prepare_live_level_for_dragon()
	if level == null:
		return
	level.skills._skill_charge[1] = level.skills.get("SKILL_CHARGE_REQ")
	level.skills.refresh_visual()
	var btn: TextureButton = level.skills._skill_btns[1]
	assert_true(btn != null, "dragon skill button exists in the live skill bar")
	if btn != null:
		assert_true(btn.texture_normal != null, "dragon button has a visible texture")
		assert_eq(btn.texture_normal.resource_path, DRAGON_YOUTH_FIRST_FRAME, "live youth dragon button uses the first youth frame")
		assert_true(btn.scale.x < 0.0, "live youth dragon button is mirrored")
		btn.emit_signal("pressed")
	var cast_controller := _find_node_with_script_path(level, DRAGON_CAST_SCRIPT)
	assert_true(cast_controller != null, "charged youth dragon press is owned by a PetCast controller node")
	assert_eq(level.skills._skill_charge[1], 0.0, "successful youth dragon cast consumes its charge immediately through the shared skill path")
	var rig = level.skill_bar.get_node_or_null(DRAGON_CAST_NODE)
	assert_true(rig != null, "pressing the charged youth dragon button spawns the dragon breath visual")
	if rig != null:
		var sprite := rig.get_node_or_null(DRAGON_FRAME_NODE) as AnimatedSprite2D
		assert_true(sprite != null, "spawned youth dragon breath visual contains an animation sprite")
		if sprite != null:
			assert_eq(String(sprite.get_meta("variant", "")), "youth", "youth slot spawns the youth animation sequence")
			assert_true(sprite.scale.x < 0.0, "right youth dragon visual is mirrored")
	_free_live_level(level)


func test_dragon_idle_buttons_match_cast_visible_scale() -> void:
	var level := _prepare_live_level_for_dragon()
	if level == null:
		return
	var baby_btn: TextureButton = level.skills._skill_btns[0]
	var youth_btn: TextureButton = level.skills._skill_btns[1]
	assert_true(baby_btn != null and youth_btn != null, "both dragon idle buttons exist")
	if baby_btn != null and youth_btn != null:
		var baby_visible_w := _button_visible_width(baby_btn, DRAGON_BABY_VISIBLE_BBOX, DRAGON_BABY_TEXTURE_SIZE)
		var youth_visible_w := _button_visible_width(youth_btn, DRAGON_YOUTH_VISIBLE_BBOX, DRAGON_YOUTH_TEXTURE_SIZE)
		assert_true(absf(baby_visible_w - _expected_dragon_visible_width(level, "baby")) <= 1.0, "baby idle frame is scaled to the same visible width as its cast animation")
		assert_true(absf(youth_visible_w - _expected_dragon_visible_width(level, "youth")) <= 1.0, "youth idle frame is scaled to the same visible width as its cast animation")
	_free_live_level(level)


func test_tall_board_dragon_idle_buttons_fit_below_book() -> void:
	var level := _prepare_live_level_for_dragon(9)
	if level == null:
		return
	assert_eq(level.board.height, 9, "regression uses a tall board like the level 10 screenshot")
	var book_rect: Rect2 = LevelLayout.book_frame_rect(level.board.height, level.cell_size, level.board_origin)
	var baby_btn: TextureButton = level.skills._skill_btns[0]
	var youth_btn: TextureButton = level.skills._skill_btns[1]
	assert_true(baby_btn != null and youth_btn != null, "both dragon idle buttons exist on the tall board")
	if baby_btn != null and youth_btn != null:
		var safe_top := book_rect.end.y + 8.0
		assert_true(_button_visible_top(baby_btn, DRAGON_BABY_VISIBLE_BBOX, DRAGON_BABY_TEXTURE_SIZE) >= safe_top, "baby dragon scales down when the book grows taller")
		assert_true(_button_visible_top(youth_btn, DRAGON_YOUTH_VISIBLE_BBOX, DRAGON_YOUTH_TEXTURE_SIZE) >= safe_top, "youth dragon scales down when the book grows taller")
	_free_live_level(level)


func test_tall_board_dragon_cast_matches_height_capped_idle_size() -> void:
	var level := _prepare_live_level_for_dragon(9)
	if level == null:
		return
	level.skills._skill_charge[1] = level.skills.get("SKILL_CHARGE_REQ")
	level.skills.refresh_visual()
	var youth_btn: TextureButton = level.skills._skill_btns[1]
	assert_true(youth_btn != null, "youth dragon button exists on the tall board")
	if youth_btn != null:
		youth_btn.emit_signal("pressed")
	var rig = level.skill_bar.get_node_or_null(DRAGON_CAST_NODE)
	assert_true(rig != null, "charged tall-board youth dragon press spawns the cast visual")
	if rig != null and youth_btn != null:
		var metrics := _dragon_visible_metrics(rig)
		var idle_w := _button_visible_width(youth_btn, DRAGON_YOUTH_VISIBLE_BBOX, DRAGON_YOUTH_TEXTURE_SIZE)
		var cast_w: float = DRAGON_YOUTH_VISIBLE_BBOX.size.x * float(metrics.get("scale", 0.0))
		assert_true(absf(cast_w - idle_w) <= 1.0, "tall-board cast animation uses the same height-capped visible width as the idle frame")
		level.call("_cancel_active_cast")
	_free_live_level(level)


func test_dragon_cast_hides_static_idle_button_until_retired() -> void:
	var level := _prepare_live_level_for_dragon()
	if level == null:
		return
	level.skills._skill_charge[1] = level.skills.get("SKILL_CHARGE_REQ")
	level.skills.refresh_visual()
	var btn: TextureButton = level.skills._skill_btns[1]
	assert_true(btn != null, "youth dragon button exists")
	if btn == null:
		_free_live_level(level)
		return
	assert_true(btn.texture_normal != null and btn.texture_normal.resource_path == DRAGON_YOUTH_FIRST_FRAME, "youth dragon starts from its idle first frame")
	level.skills.set_slot_casting(1, true)
	assert_true(bool(btn.get_meta("slot_casting", false)), "casting state marks the static skill slot as occupied by the live actor")
	assert_eq(btn.texture_normal, null, "casting state hides the static idle button frame so only the live animation is visible")
	level.skills.set_slot_casting(1, false)
	assert_true(btn.texture_normal != null and btn.texture_normal.resource_path == DRAGON_YOUTH_FIRST_FRAME, "leaving casting state restores the youth dragon idle first frame")
	btn.emit_signal("pressed")
	var cast_controller := _find_node_with_script_path(level, DRAGON_CAST_SCRIPT)
	assert_true(cast_controller != null, "charged youth dragon press starts a cast controller")
	assert_true(level.skill_bar.get_node_or_null(DRAGON_CAST_NODE) != null, "cast builds the live dragon visual rig")
	if cast_controller != null and cast_controller.is_inside_tree():
		assert_true(bool(btn.get_meta("slot_casting", false)), "active cast keeps the static slot hidden while the live actor plays")
		assert_eq(btn.texture_normal, null, "active cast leaves no idle frame under the live dragon animation")
		level.call("_cancel_active_cast")
	var restored_path := btn.texture_normal.resource_path if btn.texture_normal != null else "<null>"
	assert_true(btn.texture_normal != null and btn.texture_normal.resource_path == DRAGON_YOUTH_FIRST_FRAME, "retiring the cast restores the youth dragon idle first frame; got %s, slot_casting=%s" % [restored_path, str(btn.get_meta("slot_casting", "<unset>"))])
	_free_live_level(level)


func test_uncharged_dragons_are_disabled_and_do_not_spawn_feedback() -> void:
	var level := _prepare_live_level_for_dragon()
	if level == null:
		return
	level.skills._skill_charge[0] = 0.0
	level.skills._skill_charge[1] = 0.0
	level.skills.refresh_visual()
	var before := []
	for row in level.board.grid:
		before.append(row.duplicate())
	for i in range(2):
		var btn: TextureButton = level.skills._skill_btns[i]
		assert_true(btn != null, "dragon skill button exists in the live skill bar")
		if btn != null:
			assert_true(btn.disabled, "uncharged dragon slot %d is disabled until red gems charge it" % i)
			btn.emit_signal("pressed")
	assert_eq(level.board.grid, before, "disabled uncharged dragon taps do not mutate the board")
	assert_true(_find_node_with_script_path(level, DRAGON_CAST_SCRIPT) == null, "uncharged dragon taps do not spawn a cast controller")
	assert_true(level.skill_bar.get_node_or_null(DRAGON_CAST_NODE) == null, "uncharged dragon taps do not spawn feedback visuals")
	_free_live_level(level)
	_clear_dragon_frame_cache()
