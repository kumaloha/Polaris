extends "res://tests/test_lib.gd"

const Board := preload("res://core/board.gd")
const LevelLayout := preload("res://match3/level_layout.gd")
const LevelSkills := preload("res://match3/skills.gd")

const DRAGON_BABY_AVATAR := "res://assets/pets/dragon_baby/frames/dragon_00.png"
const DRAGON_YOUTH_FIRST_FRAME := "res://assets/pets/dragon_youth/frames/frame_001.png"
const DRAGON_VISUAL_SCRIPT := "res://match3/pets/dragon_breath_visual.gd"
const DRAGON_CAST_NODE := "DragonBreathCast"
const DRAGON_FRAME_NODE := "DragonBreathFrame"
const DRAGON_BABY_TEXTURE_SIZE := Vector2(512.0, 512.0)
const DRAGON_BABY_VISIBLE_BBOX := Rect2(Vector2(44.0, 41.0), Vector2(387.0, 418.0))


func test_dragon_skill_uses_clean_baby_avatar() -> void:
	assert_eq(String(LevelSkills.SKILLS[2].get("skill", "")), "龙息大招", "test guards the dragon skill slot")
	assert_eq(String(LevelSkills.SKILLS[2].get("av", "")), DRAGON_BABY_AVATAR, "bottom dragon slot uses the cleaned baby dragon frame, not the old placeholder avatar")
	assert_true(FileAccess.file_exists(DRAGON_BABY_AVATAR), "cleaned baby dragon avatar frame is synced under res:// assets")
	assert_true(FileAccess.file_exists("%s.import" % DRAGON_BABY_AVATAR), "cleaned baby dragon avatar is imported by Godot, not only present as a raw PNG")
	assert_true(ResourceLoader.exists(DRAGON_BABY_AVATAR), "live game resource loading can resolve the cleaned baby dragon avatar")
	assert_true(FileAccess.file_exists("%s.import" % DRAGON_YOUTH_FIRST_FRAME), "cleaned youth dragon frames are imported by Godot for the live cast animation")
	assert_true(ResourceLoader.exists(DRAGON_YOUTH_FIRST_FRAME), "live game resource loading can resolve the cleaned youth dragon animation frame")


func test_dragon_breath_visual_uses_youth_frames_and_foot_baseline() -> void:
	var script := load(DRAGON_VISUAL_SCRIPT)
	assert_true(script != null, "dragon breath visual helper exists")
	if script == null:
		return
	var cast = script.new()
	assert_true(cast.has_method("_placement_for_visible_left_baseline"), "dragon visual exposes foot/baseline placement helper")
	if not cast.has_method("_placement_for_visible_left_baseline"):
		cast.free()
		return
	var bbox := Rect2(Vector2(279.0, 434.0), Vector2(883.0, 571.0))
	var anchor := Vector2(42.0, 1288.0)
	var placement: Dictionary = cast.call("_placement_for_visible_left_baseline", anchor, bbox, 430.0)
	var scale: float = float(placement.get("scale", 0.0))
	var pos: Vector2 = placement.get("position", Vector2.ZERO)
	assert_true(scale > 0.0, "dragon placement returns a positive scale")
	assert_true(absf(pos.x + bbox.position.x * scale - anchor.x) <= 0.01, "dragon visible left edge is anchored, not texture canvas left")
	assert_true(absf(pos.y + bbox.end.y * scale - anchor.y) <= 0.01, "dragon foot/bottom baseline lands exactly on the requested baseline")
	cast.free()


func test_dragon_breath_anchor_stays_near_dragon_skill_slot_not_board_left() -> void:
	var script := load(DRAGON_VISUAL_SCRIPT)
	assert_true(script != null, "dragon breath visual helper exists")
	if script == null:
		return
	var cast = script.new()
	var board := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 25, 7)
	var layout: Dictionary = LevelLayout.compute_layout(board.width, board.height)
	cast.setup({
		"skill_bar": null,
		"board": board,
		"cell_size": float(layout["cell_size"]),
		"board_origin": layout["board_origin"],
	})
	var visible_left: Vector2 = cast.call("_visible_left_baseline_anchor")
	var visible_width: float = cast.call("_visible_width")
	var dragon_slot_center_x := LevelLayout.DESIGN_W * 2.5 / 4.0
	assert_true(visible_left.x > 220.0, "big dragon cast should appear on the dragon slot/right side, not at the board-left edge")
	assert_true(visible_left.x + visible_width <= LevelLayout.DESIGN_W - 8.0, "right-side dragon stays inside the screen")
	assert_true(absf((visible_left.x + visible_width * 0.5) - dragon_slot_center_x) <= 55.0, "big dragon visual is centered around the dragon baby skill slot")
	cast.free()


func test_dragon_breath_footline_matches_the_visible_baby_dragon_feet() -> void:
	var script := load(DRAGON_VISUAL_SCRIPT)
	assert_true(script != null, "dragon breath visual helper exists")
	if script == null:
		return
	var cast = script.new()
	var board := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 25, 7)
	var layout: Dictionary = LevelLayout.compute_layout(board.width, board.height)
	cast.setup({
		"skill_bar": null,
		"board": board,
		"cell_size": float(layout["cell_size"]),
		"board_origin": layout["board_origin"],
	})
	var anchor: Vector2 = cast.call("_visible_left_baseline_anchor")
	var button_top := LevelLayout.SKILL_AV_Y - LevelLayout.SKILL_AV_W * 0.5
	var baby_scale := LevelLayout.SKILL_AV_W / DRAGON_BABY_TEXTURE_SIZE.x
	var baby_foot_y := button_top + DRAGON_BABY_VISIBLE_BBOX.end.y * baby_scale
	assert_true(absf(anchor.y - baby_foot_y) <= 1.0, "big dragon foot baseline matches the currently visible baby dragon feet in the skill bar")
	cast.free()


func test_dragon_breath_builds_real_youth_animation_on_skill_layer() -> void:
	var script := load(DRAGON_VISUAL_SCRIPT)
	assert_true(script != null, "dragon breath visual helper exists")
	if script == null:
		return
	var layer := CanvasLayer.new()
	var cast = script.new()
	var board := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 25, 7)
	var layout: Dictionary = LevelLayout.compute_layout(board.width, board.height)
	cast.setup({
		"skill_bar": layer,
		"board": board,
		"cell_size": float(layout["cell_size"]),
		"board_origin": layout["board_origin"],
	})
	layer.add_child(cast)
	cast.call("_build_visuals")
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
		var bbox: Rect2 = cast.get("FRAME_VISIBLE_BBOX")
		var baseline: Vector2 = cast.call("_visible_left_baseline_anchor")
		assert_true(absf(sprite.position.y + bbox.end.y * sprite.scale.y - baseline.y) <= 1.0, "built dragon sprite lands on the same foot baseline used by the layout helper")
	cast.free()
	layer.free()


func test_dragon_runtime_skillbar_uses_clean_button_and_spawns_breath_visual() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "test runs with a SceneTree for the real pressed-signal path")
	if tree == null:
		level.free()
		return
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
	level.load_level(1)
	level.skills._skill_charge[2] = level.skills.get("SKILL_CHARGE_REQ")
	level.skills.refresh_visual()
	var btn: TextureButton = level.skills._skill_btns[2]
	assert_true(btn != null, "dragon skill button exists in the live skill bar")
	if btn != null:
		assert_true(btn.texture_normal != null, "dragon button has a visible texture")
		assert_eq(btn.texture_normal.resource_path, DRAGON_BABY_AVATAR, "live dragon button uses the cleaned baby avatar path")
	btn.emit_signal("pressed")
	var rig = level.skill_bar.get_node_or_null(DRAGON_CAST_NODE)
	assert_true(rig != null, "pressing the charged live dragon button spawns the dragon breath visual through the real skill path")
	if rig != null:
		assert_true(rig.get_node_or_null(DRAGON_FRAME_NODE) is AnimatedSprite2D, "spawned dragon breath visual contains the youth animation sprite")
	tree.root.remove_child(level)
	level.free()
