extends "res://tests/test_lib.gd"

const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const LevelLayout := preload("res://match3/level_layout.gd")
const LevelSkills := preload("res://match3/skills.gd")
const PetRegistry := preload("res://match3/pets/pet_registry.gd")

const DRAGON_BABY_AVATAR := "res://assets/pets/dragon_baby/frames/dragon_00.png"
const DRAGON_YOUTH_FIRST_FRAME := "res://assets/pets/dragon_youth/frames/frame_001.png"
const DRAGON_VISUAL_SCRIPT := "res://match3/pets/dragon_breath_visual.gd"
const DRAGON_CAST_SCRIPT := "res://match3/pets/dragon_breath_cast.gd"
const DRAGON_CAST_NODE := "DragonBreathCast"
const DRAGON_FRAME_NODE := "DragonBreathFrame"
const DRAGON_BABY_TEXTURE_SIZE := Vector2(512.0, 512.0)
const DRAGON_BABY_VISIBLE_BBOX := Rect2(Vector2(44.0, 41.0), Vector2(387.0, 418.0))


func _configured_dragon_visual(skill_layer: CanvasLayer = null) -> Node:
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
	var bbox: Rect2 = cast.get("FRAME_VISIBLE_BBOX")
	var scale := sprite.scale.x
	var visible_left := sprite.position.x + bbox.position.x * scale
	var visible_center_x := visible_left + bbox.size.x * scale * 0.5
	var visible_right := sprite.position.x + bbox.end.x * scale
	var visible_bottom := sprite.position.y + bbox.end.y * scale
	return {
		"sprite": sprite,
		"scale": scale,
		"visible_left": visible_left,
		"visible_center_x": visible_center_x,
		"visible_right": visible_right,
		"visible_bottom": visible_bottom,
	}


func _prepare_live_level_for_dragon() -> Node:
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
	level.load_level(1)
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


func test_dragon_skill_registry_owns_cast_controller() -> void:
	assert_true(PetRegistry.has_pet("龙息大招"), "dragon breath is registry-owned, not level.gd direct-dispatch owned")
	var cast_script: Script = PetRegistry.cast_for("龙息大招")
	assert_true(cast_script != null, "dragon breath registry entry resolves to a cast controller script")
	if cast_script != null:
		assert_eq(cast_script.resource_path, DRAGON_CAST_SCRIPT, "dragon breath resolves to its dedicated PetCast controller")


func test_dragon_skill_uses_clean_baby_avatar() -> void:
	assert_eq(String(LevelSkills.SKILLS[2].get("skill", "")), "龙息大招", "test guards the dragon skill slot")
	assert_eq(String(LevelSkills.SKILLS[2].get("av", "")), DRAGON_BABY_AVATAR, "bottom dragon slot uses the cleaned baby dragon frame, not the old placeholder avatar")
	assert_true(FileAccess.file_exists(DRAGON_BABY_AVATAR), "cleaned baby dragon avatar frame is synced under res:// assets")
	assert_true(FileAccess.file_exists("%s.import" % DRAGON_BABY_AVATAR), "cleaned baby dragon avatar is imported by Godot, not only present as a raw PNG")
	assert_true(ResourceLoader.exists(DRAGON_BABY_AVATAR), "live game resource loading can resolve the cleaned baby dragon avatar")
	assert_true(FileAccess.file_exists("%s.import" % DRAGON_YOUTH_FIRST_FRAME), "cleaned youth dragon frames are imported by Godot for the live cast animation")
	assert_true(ResourceLoader.exists(DRAGON_YOUTH_FIRST_FRAME), "live game resource loading can resolve the cleaned youth dragon animation frame")


func test_dragon_breath_visual_uses_youth_frames_and_foot_baseline() -> void:
	var cast := _configured_dragon_visual()
	if cast == null:
		return
	var metrics := _dragon_visible_metrics(cast)
	assert_true(float(metrics.get("scale", 0.0)) > 0.0, "dragon visual builds with a positive sprite scale")
	assert_true(float(metrics.get("visible_left", 0.0)) > 0.0, "dragon visible left edge comes from rendered youth frame geometry")
	assert_true(float(metrics.get("visible_bottom", 0.0)) > 0.0, "dragon visible foot baseline is measurable from rendered youth frame geometry")
	cast.free()


func test_dragon_breath_anchor_stays_near_dragon_skill_slot_not_board_left() -> void:
	var cast := _configured_dragon_visual()
	if cast == null:
		return
	var metrics := _dragon_visible_metrics(cast)
	var dragon_slot_center_x := LevelLayout.DESIGN_W * 2.5 / 4.0
	assert_true(float(metrics.get("visible_left", 0.0)) > 220.0, "big dragon cast should appear on the dragon slot/right side, not at the board-left edge")
	assert_true(float(metrics.get("visible_right", 0.0)) <= LevelLayout.DESIGN_W - 8.0, "right-side dragon stays inside the screen")
	assert_true(absf(float(metrics.get("visible_center_x", 0.0)) - dragon_slot_center_x) <= 55.0, "big dragon visual is centered around the dragon baby skill slot")
	cast.free()


func test_dragon_breath_footline_matches_the_visible_baby_dragon_feet() -> void:
	var cast := _configured_dragon_visual()
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
	var cast := _configured_dragon_visual(layer)
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
			assert_true(sprite.sprite_frames.get_frame_count("cast") >= 24, "dragon cast uses enough real youth frames to read as an animation")
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


func test_dragon_runtime_skillbar_uses_clean_button_and_spawns_breath_visual() -> void:
	var level := _prepare_live_level_for_dragon()
	if level == null:
		return
	level.skills._skill_charge[2] = level.skills.get("SKILL_CHARGE_REQ")
	level.skills.refresh_visual()
	var btn: TextureButton = level.skills._skill_btns[2]
	assert_true(btn != null, "dragon skill button exists in the live skill bar")
	if btn != null:
		assert_true(btn.texture_normal != null, "dragon button has a visible texture")
		assert_eq(btn.texture_normal.resource_path, DRAGON_BABY_AVATAR, "live dragon button uses the cleaned baby avatar path")
	btn.emit_signal("pressed")
	var cast_controller := _find_node_with_script_path(level, DRAGON_CAST_SCRIPT)
	assert_true(cast_controller != null, "charged dragon press is owned by a PetCast controller node")
	assert_eq(level.skills._skill_charge[2], 0.0, "successful dragon cast consumes its charge immediately through the shared skill path")
	var rig = level.skill_bar.get_node_or_null(DRAGON_CAST_NODE)
	assert_true(rig != null, "pressing the charged live dragon button spawns the dragon breath visual through the real skill path")
	if rig != null:
		assert_true(rig.get_node_or_null(DRAGON_FRAME_NODE) is AnimatedSprite2D, "spawned dragon breath visual contains the youth animation sprite")
	_free_live_level(level)


func test_uncharged_dragon_press_spawns_feedback_without_mutating_board() -> void:
	var level := _prepare_live_level_for_dragon()
	if level == null:
		return
	level.skills._skill_charge[2] = 0.0
	level.skills.refresh_visual()
	var before := []
	for row in level.board.grid:
		before.append(row.duplicate())
	var btn: TextureButton = level.skills._skill_btns[2]
	assert_true(btn != null, "dragon skill button exists in the live skill bar")
	if btn != null:
		assert_false(btn.disabled, "dragon remains clickable while uncharged so it can play feedback")
		btn.emit_signal("pressed")
	var cast_controller := _find_node_with_script_path(level, DRAGON_CAST_SCRIPT)
	assert_true(cast_controller != null, "uncharged dragon feedback is still routed through the cast controller")
	assert_eq(level.board.grid, before, "uncharged dragon feedback does not mutate the board")
	assert_eq(level.skills._skill_charge[2], 0.0, "uncharged dragon feedback does not change skill charge")
	var rig = level.skill_bar.get_node_or_null(DRAGON_CAST_NODE)
	assert_true(rig != null, "uncharged dragon feedback creates the visible dragon cast node")
	_free_live_level(level)
