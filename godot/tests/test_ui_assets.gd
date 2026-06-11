extends "res://tests/test_lib.gd"

const CharacterData := preload("res://ui/character_data.gd")
const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const LevelLayout := preload("res://match3/level_layout.gd")
const ME := preload("res://core/match_engine.gd")
# P3(契约 C): 时兔施法控制器(PetCast 子类)。施法演出/落地从 level.gd 抽到此处。
const TimeRabbitCast := preload("res://match3/pets/time_rabbit.gd")
const BARRIER_ICE_SOURCE := "resources/barrier/ob_ice.png"
const BARRIER_ICE_SYNCED := "res://assets/obstacles/ob_ice.png"
const BARRIER_MARKER_NAME := "CoatBarrierSprite"
const JELLY_GOAL_ICON := "res://assets/obstacles/ob_bubble.png"
const JELLY_MARKER_NAME := "JellyGoalSprite"
const WALL_STONE_SYNCED := "res://assets/obstacles/ob_stone.png"
const WALL_MARKER_NAME := "WallStoneSprite"
const COLORBOMB_CORE_SOURCE := "resources/0.02/gem/diamond_white.png"
const COLORBOMB_CORE_SYNCED := "res://assets/level/diamond_white.png"
const PINK_GEM_SOURCE := "resources/0.02/gem/heart_neon.png"
const PINK_GEM_SYNCED := "res://art/gems/base/heart_neon.png"
const BG3_SOURCE := "resources/0.02/bg3.png"
const BACKGROUND_SYNCED := "res://assets/level/background.png"
const BOOK_RIBBONS_SOURCE := "resources/0.02/board/book_ribbons_new.png"
const BOOK_RIBBONS_SYNCED := "res://assets/level/book_ribbons.png"
const BOOK_FRAME_SYNCED := "res://assets/level/book_frame.png"
const RABBIT_TIMEREWIND_SOURCE := "resources/0.02/rabbit_timerewind_set/rabbit_avatar.png"
const RABBIT_TIMEREWIND_SYNCED := "res://assets/pets/timerewind/rabbit_avatar.png"
const RABBIT_TIMEREWIND_K1 := "res://assets/pets/timerewind/rabbit_k1_peektop.png"
const RABBIT_TIMEREWIND_K2 := "res://assets/pets/timerewind/rabbit_k2_peek.png"
const RABBIT_TIMEREWIND_K5 := "res://assets/pets/timerewind/rabbit_k5_leap.png"
const RABBIT_TIMEREWIND_K8 := "res://assets/pets/timerewind/rabbit_k8_cast.png"
const RABBIT_TIMEREWIND_HOURGLASS := "res://assets/pets/timerewind/rabbit_prop_hourglass.png"
const RABBIT_REWIND_CAST_NODE := "TimeRabbitRewindCast"
const RABBIT_REWIND_CAST_EFFECT_NODE := "TimeRewindCastEffect"
const RABBIT_REWIND_FRAME_NODE := "RabbitFrame"
const RABBIT_REWIND_HOURGLASS_NODE := "RabbitHourglass"
const RABBIT_AVATAR_FRAME_NODE := "TimeRabbitAvatarFrame"
const RABBIT_AVATAR_FRAME_BG_NODE := "TimeRabbitAvatarFrameBg"
const RABBIT_AVATAR_FRAME_SYNCED := "res://assets/level/pet_avatar_frame.png"
const RABBIT_REWIND_POCKET_NODE := "RabbitPocket"
const RABBIT_REWIND_RING_FULL_NODE := "RabbitPocketRingFull"
const RABBIT_REWIND_RING_TOP_NODE := "RabbitPocketRingTopLip"
const BOOK_RIBBONS_NODE := "BookRibbons"
const BOOK_INNER_INLAY_NODE := "BookInnerInlay"
const BOOK_INLAY_MASK_LEFT_NODE := "BookInlayMaskLeft"
const BOOK_INLAY_MASK_RIGHT_NODE := "BookInlayMaskRight"
const TOPBAR_SYNCED := "res://assets/level/top_transparent.png"
const TOPBAR_STAR_GOLD := "res://assets/level/star_gold.png"
const MAGIC_ART_REQUIRED := [
	"res://art/gems/base/gem_water.png",
	"res://art/gems/base/gem_clover.png",
	PINK_GEM_SYNCED,
	"res://art/gems/base/gem_orb.png",
	"res://art/gems/base/gem_ruby.png",
	"res://art/gems/base/gem_star.png",
	COLORBOMB_CORE_SYNCED,
	"res://art/vfx/basic_pop/vfx_basic_flash_blob.png",
	"res://art/vfx/basic_pop/vfx_basic_flash_star.png",
	"res://art/vfx/basic_pop/vfx_basic_ring_soft.png",
	"res://art/vfx/line_blast/vfx_beam_core.png",
	"res://art/vfx/line_blast/vfx_beam_glow.png",
	"res://art/vfx/line_blast/vfx_beam_cap.png",
	"res://art/vfx/area_blast/vfx_area_square_wave.png",
	"res://art/vfx/area_blast/vfx_area_cube_frame.png",
	"res://art/vfx/area_blast/vfx_area_grid_3x3.png",
	"res://art/vfx/color_absorb/vfx_absorb_orb.png",
	"res://art/vfx/color_absorb/vfx_absorb_trail.png",
	"res://art/vfx/color_absorb/cell_target_outline.png",
]


func _filled_layer(w: int, h: int, value: int) -> Array:
	var out := []
	for y in range(h):
		var row := []
		for x in range(w):
			row.append(value)
		out.append(row)
	return out


func _repo_path(path: String) -> String:
	return ProjectSettings.globalize_path("res://../%s" % path).simplify_path()


func _count_positive_layer(layer: Array) -> int:
	var count := 0
	for row in layer:
		for value in row:
			if int(value) > 0:
				count += 1
	return count


func _count_grid_value(grid: Array, expected: int) -> int:
	var count := 0
	for row in grid:
		for value in row:
			if int(value) == expected:
				count += 1
	return count


func _count_group_nodes(root: Node, group_name: String) -> int:
	var count := 0
	if root.is_in_group(group_name):
		count += 1
	for child in root.get_children():
		count += _count_group_nodes(child, group_name)
	return count


func _find_named_node(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_named_node(child, node_name)
		if found != null:
			return found
	return null


func _count_label_text(root: Node, text: String) -> int:
	var count := 0
	if root is Label and (root as Label).text == text:
		count += 1
	for child in root.get_children():
		count += _count_label_text(child, text)
	return count


func _count_sprite_texture(root: Node, texture_path: String) -> int:
	var count := 0
	if root is Sprite2D:
		var sprite := root as Sprite2D
		if sprite.texture != null and sprite.texture.resource_path == texture_path:
			count += 1
	for child in root.get_children():
		count += _count_sprite_texture(child, texture_path)
	return count


func _count_texture_rect_texture(root: Node, texture_path: String) -> int:
	var count := 0
	if root is TextureRect:
		var rect := root as TextureRect
		if rect.texture != null and rect.texture.resource_path == texture_path:
			count += 1
	for child in root.get_children():
		count += _count_texture_rect_texture(child, texture_path)
	return count


func _count_texture_button_texture(root: Node, texture_path: String) -> int:
	var count := 0
	if root is TextureButton:
		var btn := root as TextureButton
		if btn.texture_normal != null and btn.texture_normal.resource_path == texture_path:
			count += 1
	for child in root.get_children():
		count += _count_texture_button_texture(child, texture_path)
	return count


func _find_texture_button_texture(root: Node, texture_path: String) -> TextureButton:
	if root is TextureButton:
		var btn := root as TextureButton
		if btn.texture_normal != null and btn.texture_normal.resource_path == texture_path:
			return btn
	for child in root.get_children():
		var found := _find_texture_button_texture(child, texture_path)
		if found != null:
			return found
	return null


func _prepare_level_scene() -> Node:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.background_layer = level.get_node("BackgroundLayer")
	level.board_layer = level.get_node("BoardLayer")
	level.gem_layer = level.get_node("GemLayer")
	level.character_layer = level.get_node("CharacterLayer")
	level.ui_layer = level.get_node("UILayer")
	level.skill_bar = level.get_node("SkillBar")
	level._levels = LevelLibrary.load_file("res://levels.json")
	level._playable = []
	for i in range(level._levels.size()):
		var objs = level._levels[i].get("objectives", [])
		if objs is Array and not objs.is_empty():
			level._playable.append(i)
	return level


# 造一个挂在 level 之上、注入 level 上下文的时兔施法控制器(契约 C)。
# 不入树→施法走 headless 路径(立即落地+收尾); 测试可直接调 _build_visuals/_apply_effect/_finish 钩子检查演出。
func _make_rabbit_cast(level, cast_effect: bool = true) -> TimeRabbitCast:
	var cast := TimeRabbitCast.new()
	cast.setup({
		"skill_bar": level.skill_bar,
		"board": level.board,
		"cell_size": level.cell_size,
		"board_origin": level.board_origin,
		"cast_effect": cast_effect,
		"load_texture": Callable(level, "_load_texture"),
		"set_avatar_casting": Callable(level.skills, "_set_time_rabbit_avatar_casting"),
		"refresh_skill_ui": Callable(level.skills, "refresh_visual"),
	})
	return cast


func test_character_manifest_loads_available_png_characters() -> void:
	var characters := CharacterData.load_characters()
	var image_paths := CharacterData.discover_character_images()
	assert_eq(characters.size(), image_paths.size(), "one playable character per PNG")
	var ids := []
	for character in characters:
		ids.append(character["id"])
	assert_eq(ids[0], "lucky", "default mascot follows docs order")
	assert_true(ids.has("longswap"), "new flat character resources are loaded")
	assert_true(ids.has("gravityflip"), "new flat character resources are loaded")
	assert_true(ids.has("timerewind"), "new flat character resources are loaded")


func test_character_image_paths_exist() -> void:
	for character in CharacterData.load_characters():
		var card_path := CharacterData.resolve_file_path(character["card"])
		var portrait_path := CharacterData.resolve_file_path(character["portrait"])
		assert_true(FileAccess.file_exists(card_path), "card exists: %s" % card_path)
		assert_true(FileAccess.file_exists(portrait_path), "portrait exists: %s" % portrait_path)
		assert_false(String(character["portrait"]).contains("/portraits/"), "flat character path")
		assert_false(String(character["card"]).contains("/cards/"), "flat character path")


func test_character_metadata_comes_from_docs() -> void:
	var by_id := {}
	for character in CharacterData.load_characters():
		by_id[character["id"]] = character
	assert_eq(by_id["lucky"]["name"], "默认精灵", "doc row #0")
	assert_eq(by_id["lucky"]["playable"], false, "default mascot is not playable")
	assert_eq(by_id["borrrower"]["skill_desc"], "借一个特效(4连直线/T·L爆炸/5连彩球效果),本关内必须还;不还不算过关。", "borrower skill from docs")
	assert_eq(by_id["chainbonus"]["type"], "被动型·整局生效", "passive type from docs")


func test_collector_uses_flat_character_art_without_bee_rig_metadata() -> void:
	var by_id := {}
	for character in CharacterData.load_characters():
		by_id[character["id"]] = character
	assert_true(by_id.has("collector"), "collector character is declared")
	if not by_id.has("collector"):
		return
	var collector: Dictionary = by_id["collector"]
	assert_eq(collector.get("rig", ""), "", "collector no longer declares the removed bee rig")
	assert_false(collector.has("rig_parts"), "collector no longer carries bee part metadata")
	assert_eq(String(collector.get("portrait", "")), "res://art/characters/collector.png", "collector keeps its flat portrait")


func test_bee_rig_code_and_assets_are_removed() -> void:
	assert_false(ResourceLoader.exists("res://ui/bee_rig.gd"), "removed bee rig script must not be loadable")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://art/characters/bee_rig")), "removed bee rig asset directory must not exist")



func test_level_page_does_not_render_removed_bee() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	var rig := _find_named_node(level.character_layer, "LevelBeeRig")
	assert_eq(rig, null, "level page must not render the removed bee rig")
	assert_eq(_count_label_text(level.skill_bar, "瓢虫"), 1, "level skill bar keeps the original lucky skill companion")
	level.free()


func test_level_first_pet_slot_uses_time_rewind_rabbit_avatar() -> void:
	assert_true(FileAccess.file_exists(_repo_path(RABBIT_TIMEREWIND_SOURCE)), "source rabbit time-rewind avatar exists")
	assert_true(FileAccess.file_exists(RABBIT_TIMEREWIND_SYNCED), "synced rabbit time-rewind avatar exists under res://")
	var src := Image.load_from_file(_repo_path(RABBIT_TIMEREWIND_SOURCE))
	var dst := Image.load_from_file(ProjectSettings.globalize_path(RABBIT_TIMEREWIND_SYNCED))
	assert_true(src != null and not src.is_empty(), "source rabbit avatar loads")
	assert_true(dst != null and not dst.is_empty(), "synced rabbit avatar loads")
	if src != null and not src.is_empty() and dst != null and not dst.is_empty():
		assert_eq(dst.get_width(), src.get_width(), "rabbit avatar keeps source width")
		assert_eq(dst.get_height(), src.get_height(), "rabbit avatar keeps source height")
		assert_true(dst.detect_alpha() != Image.ALPHA_NONE, "rabbit avatar remains transparent for the bottom skill slot")
	var level := _prepare_level_scene()
	level.load_level(1)
	assert_eq(_count_texture_button_texture(level.skill_bar, RABBIT_TIMEREWIND_SYNCED), 1, "first bottom pet slot renders the rabbit avatar button")
	assert_eq(_count_label_text(level.skill_bar, "时兔"), 1, "first bottom pet slot is labeled as the time rabbit")
	assert_eq(_count_label_text(level.skill_bar, "星鹿"), 0, "first bottom pet slot no longer shows the old deer hint pet")
	level.free()


func test_level_first_pet_time_rewind_skill_restores_board_history() -> void:
	# P3: 时间回退技能经 _cast_pet → TimeRabbitCast 接管。headless 下立即落地(commit)并由
	# level._on_pet_cast_committed 重渲染棋盘。语义不变: 恢复历史盘面/步数 + 重渲染。
	var level := _prepare_level_scene()
	assert_true(level.has_method("_cast_pet"), "Level exposes the pet-cast entry point")
	if not level.has_method("_cast_pet"):
		level.free()
		return
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 30, 7)
	b.skill = "timerewind"
	var start_grid: Array = b.grid.duplicate(true)
	var start_moves: int = b.moves_left
	b._push_history()
	b.grid[0][0] = (int(b.grid[0][0]) + 1) % b.species.size()
	b.moves_left -= 3
	assert_ne(b.grid, start_grid, "test setup mutates the board after history is recorded")
	level.board = b
	level._cur_cfg = {"id": 1}
	level.call("_compute_layout")
	var did: bool = level.call("_cast_pet", 0, true)
	assert_true(did, "time rewind skill succeeds when the board has history")
	assert_eq(b.grid, start_grid, "time rewind restores the saved board grid")
	assert_eq(b.moves_left, start_moves, "time rewind restores moves from the saved board state")
	assert_eq(level.board_view._gem_nodes.size(), b.height, "time rewind rerenders the board visuals after restoring")
	level.free()


func test_level_time_rewind_skill_spawns_rabbit_cast_animation() -> void:
	# P3: 施法演出节点由 TimeRabbitCast._build_visuals() 在 skill_bar 上搭(原 _play_time_rewind_pet_animation)。
	var level := _prepare_level_scene()
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 30, 7)
	b.skill = "timerewind"
	b._push_history()
	b.grid[0][0] = (int(b.grid[0][0]) + 1) % b.species.size()
	level.board = b
	level._cur_cfg = {"id": 1}
	level.call("_compute_layout")
	var cast := _make_rabbit_cast(level, true)
	cast.call("_build_visuals")
	var rig := _find_named_node(level.skill_bar, RABBIT_REWIND_CAST_NODE)
	assert_true(rig != null, "time rewind should spawn the documented rabbit cast animation on the top skill layer")
	if rig != null:
		var frame := _find_named_node(rig, RABBIT_REWIND_FRAME_NODE) as Sprite2D
		var hourglass := _find_named_node(level.skill_bar, RABBIT_REWIND_HOURGLASS_NODE) as Sprite2D
		assert_true(frame != null and frame.texture != null, "rabbit cast animation has a visible frame sprite")
		assert_true(hourglass != null and hourglass.texture != null, "rabbit cast animation includes the hourglass prop")
		assert_eq(hourglass.texture.resource_path, RABBIT_TIMEREWIND_HOURGLASS, "hourglass prop uses the time-rewind document asset")
		assert_true(rig.has_meta("frame_sequence"), "rabbit cast animation records the keyframe sequence from the document")
		var sequence: PackedStringArray = rig.get_meta("frame_sequence", PackedStringArray())
		assert_true(sequence.has(RABBIT_TIMEREWIND_K1), "sequence starts from the K1 peek/climb frame")
		assert_true(sequence.has(RABBIT_TIMEREWIND_K5), "sequence includes the K5 leap frame")
		assert_true(sequence.has(RABBIT_TIMEREWIND_K8), "sequence includes the K8 cast frame")
	level.free()


func test_time_rabbit_cast_hides_bottom_avatar_until_retired() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	var btn := _find_texture_button_texture(level.skill_bar, RABBIT_TIMEREWIND_SYNCED)
	assert_true(btn != null, "time rabbit button exists")
	if btn == null:
		level.free()
		return
	assert_true(btn.visible, "time rabbit avatar starts visible in the bottom skill slot")
	# P3: 演出 = TimeRabbitCast._build_visuals(); 收尾 = _finish()(复原头像 + 回收 rig)。
	var cast := _make_rabbit_cast(level, false)
	cast.call("_build_visuals")
	var rig := _find_named_node(level.skill_bar, RABBIT_REWIND_CAST_NODE)
	assert_true(rig != null, "time rabbit cast rig is created")
	assert_true(btn.visible, "bottom avatar slot stays present while the rabbit jumps out")
	assert_eq(btn.texture_normal, null, "bottom avatar texture is removed while the live rabbit actor is outside the frame")
	var frame_bg := _find_named_node(level.skill_bar, RABBIT_AVATAR_FRAME_BG_NODE) as Polygon2D
	assert_true(frame_bg != null, "empty time-rabbit frame keeps a beige translucent magic background")
	if frame_bg != null:
		assert_true(frame_bg.color.r >= 0.85 and frame_bg.color.g >= 0.72 and frame_bg.color.b >= 0.50, "avatar frame background is warm beige")
		assert_true(frame_bg.color.a >= 0.32 and frame_bg.color.a <= 0.72, "avatar frame background is translucent, not opaque")
	if rig != null:
		cast.call("_finish")
		assert_true(not is_instance_valid(rig) or not rig.visible, "retired rabbit actor is hidden or freed immediately")
		assert_true(btn.visible, "bottom avatar returns after the cast rig is retired")
		assert_eq(btn.modulate.a, 1.0, "bottom avatar returns to full opacity after the rabbit is collected")
		assert_true(btn.texture_normal != null and btn.texture_normal.resource_path == RABBIT_TIMEREWIND_SYNCED, "bottom avatar texture returns after the rabbit is collected")
	cast.free()
	level.free()


func test_time_rabbit_cast_uses_empty_avatar_frame_and_top_layer_hourglass() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	var btn := _find_texture_button_texture(level.skill_bar, RABBIT_TIMEREWIND_SYNCED)
	assert_true(btn != null, "time rabbit button exists")
	var cast := _make_rabbit_cast(level, true)
	cast.call("_build_visuals")
	var rig := _find_named_node(level.skill_bar, RABBIT_REWIND_CAST_NODE) as Node2D
	assert_true(rig != null, "time rabbit cast rig is created")
	if rig == null:
		cast.free()
		level.free()
		return
	assert_true(ResourceLoader.exists(RABBIT_AVATAR_FRAME_SYNCED) or FileAccess.file_exists(RABBIT_AVATAR_FRAME_SYNCED), "time rabbit slot has a real avatar frame asset")
	var frame_slot := _find_named_node(level.skill_bar, RABBIT_AVATAR_FRAME_NODE)
	assert_true(frame_slot != null, "time rabbit has a visible avatar frame separate from the avatar texture")
	var frame_bg := _find_named_node(level.skill_bar, RABBIT_AVATAR_FRAME_BG_NODE) as Polygon2D
	assert_true(frame_bg != null, "time rabbit avatar frame has a persistent beige translucent center")
	if frame_slot != null:
		assert_true((frame_slot as CanvasItem).z_index < rig.z_index, "rabbit actor draws above the avatar frame border while emerging")
	if frame_bg != null:
		assert_true(frame_bg.z_index < rig.z_index, "rabbit actor draws above the beige magic center while emerging")
	assert_true(_find_named_node(level.skill_bar, RABBIT_REWIND_POCKET_NODE) == null, "rabbit cast does not create a separate magic ring/pocket effect")
	if btn != null:
		assert_eq(btn.texture_normal, null, "avatar frame is empty after the rabbit actor jumps out")
	var frame := _find_named_node(rig, RABBIT_REWIND_FRAME_NODE) as Sprite2D
	assert_true(frame != null and frame.texture != null, "time rabbit actor has a visible frame")
	if frame != null and frame.texture != null:
		assert_eq(frame.texture.resource_path, RABBIT_TIMEREWIND_SYNCED, "the live actor starts as the same image as the avatar frame")
	var hourglass := _find_named_node(level.skill_bar, RABBIT_REWIND_HOURGLASS_NODE) as Sprite2D
	assert_true(hourglass != null and hourglass.texture != null, "top-layer hourglass prop exists")
	if hourglass != null:
		assert_eq(hourglass.get_parent(), level.skill_bar, "hourglass is independent of the rabbit rig so it cannot be hidden behind the book or rabbit")
		assert_true(hourglass.z_index > rig.z_index, "hourglass draws above the rabbit cast rig")
		assert_true(hourglass.scale.x >= 0.07 and hourglass.scale.x <= 0.09, "hourglass starts as a readable prop without becoming a screen-tall tower")
	cast.free()
	level.free()


func test_time_rabbit_peek_frames_crop_source_bottom_edge() -> void:
	# P3: 逐帧贴图/锚点由 TimeRabbitCast._set_frame / _set_avatar_frame 处理(原 level._set_time_rabbit_frame)。
	var level := _prepare_level_scene()
	var cast := _make_rabbit_cast(level, true)
	var sprite := Sprite2D.new()
	cast.call("_set_frame", sprite, RABBIT_TIMEREWIND_K2, 172.0, false)
	assert_true(sprite.texture != null, "peek frame texture loads")
	assert_true(sprite.region_enabled, "peek frame crops away the source image bottom edge instead of showing a horizontal cut line")
	if sprite.texture != null:
		assert_true(sprite.region_rect.size.y <= sprite.texture.get_size().y - 16.0, "peek frame crop removes enough bottom pixels to hide the hard source edge")
	var display_h := sprite.region_rect.size.y * sprite.scale.y
	assert_true(absf(sprite.position.y + display_h * 0.5) <= 0.25, "cropped peek frame still uses the visible bottom as its anchor")
	cast.call("_set_avatar_frame", sprite, 132.0)
	assert_false(sprite.region_enabled, "switching back to the avatar frame clears the peek-frame crop")
	sprite.free()
	cast.free()
	level.free()


func test_time_rabbit_retire_clears_actor_hourglass_and_restores_avatar() -> void:
	# P3: 收尾信号从 level.time_rabbit_sequence_done 变为 TimeRabbitCast.cast_finished(契约 C)。
	var level := _prepare_level_scene()
	level.load_level(1)
	var btn := _find_texture_button_texture(level.skill_bar, RABBIT_TIMEREWIND_SYNCED)
	assert_true(btn != null, "time rabbit button exists")
	var cast := _make_rabbit_cast(level, true)
	cast.set_meta("rabbit_done", false)
	cast.cast_finished.connect(func(): cast.set_meta("rabbit_done", true))
	cast.call("_build_visuals")
	var rig := _find_named_node(level.skill_bar, RABBIT_REWIND_CAST_NODE) as Node2D
	assert_true(rig != null, "time rabbit cast rig is created")
	assert_true(_find_named_node(level.skill_bar, RABBIT_REWIND_HOURGLASS_NODE) != null, "hourglass exists before retire")
	cast.call("_finish")
	assert_true(bool(cast.get_meta("rabbit_done", false)), "retiring the actor emits the finished signal")
	assert_true(_find_named_node(level.skill_bar, RABBIT_REWIND_CAST_NODE) == null, "rabbit actor is removed from the skill layer")
	assert_true(_find_named_node(level.skill_bar, RABBIT_REWIND_HOURGLASS_NODE) == null, "hourglass is removed with the rabbit sequence")
	if btn != null:
		assert_true(btn.texture_normal != null and btn.texture_normal.resource_path == RABBIT_TIMEREWIND_SYNCED, "avatar texture is restored into the frame after retire")
	cast.free()
	level.free()


func test_level_time_rewind_cast_commit_restores_board_and_shows_effect() -> void:
	# P3: 显式提交点 = TimeRabbitCast._apply_effect()(board.skill_rewind + 倒流棋盘特效)。
	var level := _prepare_level_scene()
	var cast := _make_rabbit_cast(level, true)
	assert_true(cast.has_method("_apply_effect"), "time rabbit cast has an explicit commit point")
	var b := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 30, 7)
	b.skill = "timerewind"
	var start_grid: Array = b.grid.duplicate(true)
	var start_moves: int = b.moves_left
	b._push_history()
	b.grid[0][0] = (int(b.grid[0][0]) + 1) % b.species.size()
	b.moves_left -= 2
	level.board = b
	level._cur_cfg = {"id": 1}
	level.call("_compute_layout")
	# 让控制器对准 level 当前的 board/layout, 再调提交点。
	cast.setup({
		"skill_bar": level.skill_bar, "board": level.board,
		"cell_size": level.cell_size, "board_origin": level.board_origin,
		"cast_effect": true,
		"load_texture": Callable(level, "_load_texture"),
		"set_avatar_casting": Callable(level.skills, "_set_time_rabbit_avatar_casting"),
		"refresh_skill_ui": Callable(level.skills, "refresh_visual"),
	})
	var did: bool = cast.call("_apply_effect")
	assert_true(did, "applying the rewind effect succeeds when the board has history")
	assert_eq(b.grid, start_grid, "cast commit restores the saved board grid")
	assert_eq(b.moves_left, start_moves, "cast commit restores the saved move count")
	var effect := _find_named_node(level.skill_bar, RABBIT_REWIND_CAST_EFFECT_NODE)
	assert_true(effect != null, "cast commit leaves a visible time-rewind effect on the board")
	if effect != null:
		var flash := _find_named_node(effect, "TimeRewindBoardFlash") as ColorRect
		assert_true(flash != null and flash.color.a >= 0.34, "time rewind release has a readable cool flash")
		var sand_count := 0
		for child in effect.get_children():
			if String(child.name).begins_with("TimeRewindSand"):
				sand_count += 1
		assert_true(sand_count >= 18, "time rewind release has enough reverse sand particles to register in sampled frames")
	cast.free()
	level.free()


func test_level_time_rabbit_frames_use_bottom_anchor() -> void:
	# P3: 逐帧贴图脚/底锚由 TimeRabbitCast._set_frame 设(原 level._make_time_rabbit_sprite)。
	var level := _prepare_level_scene()
	var cast := _make_rabbit_cast(level, true)
	var frame := Sprite2D.new()
	cast.call("_set_frame", frame, RABBIT_TIMEREWIND_K8, 150.0, false)
	assert_eq(String(frame.get_meta("anchor", "")), "bottom", "time rabbit keyframes are foot/bottom anchored so cropped frame sizes do not shift the landing point")
	if frame.texture != null:
		var display_h: float = frame.texture.get_size().y * frame.scale.y
		assert_true(absf(frame.position.y + display_h * 0.5) <= 1.0, "rabbit sprite bottom sits on the rig origin")
	frame.free()
	cast.free()
	level.free()


func test_level_time_rewind_button_enables_from_history_not_charge() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	var btn := _find_texture_button_texture(level.skill_bar, RABBIT_TIMEREWIND_SYNCED)
	assert_true(btn != null, "time rabbit button exists")
	if btn == null:
		level.free()
		return
	level.skills._skill_charge[0] = 0.0
	level.board._push_history()
	level.skills.call("refresh_visual")
	assert_false(btn.disabled, "time rewind becomes clickable from board history even with zero gem charge")
	assert_eq(btn.modulate.a, 1.0, "time rewind button looks ready when history is available")
	level.free()


func test_level_time_rewind_button_accepts_clicks_before_history() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	var btn := _find_texture_button_texture(level.skill_bar, RABBIT_TIMEREWIND_SYNCED)
	assert_true(btn != null, "time rabbit button exists")
	if btn == null:
		level.free()
		return
	assert_false(btn.disabled, "time rabbit remains clickable before rewind history exists so taps can give feedback")
	assert_true(btn.modulate.a < 1.0, "time rabbit still looks not-ready before there is history to rewind")
	# P3: 未充满(无历史)但可点 → _on_skill_pressed 走 _cast_pet(0, false) 的 peek 反馈, 而非只缩放按钮。
	# 该状态门控 + peek 演出节点由 TimeRabbitCast._build_visuals 搭建(headless 下立即收尾, 故直接观察 build)。
	assert_true(level.skills.call("_skill_clickable", 0) and not level.skills.call("_skill_ready", 0), "rabbit is in the clickable-but-not-ready state that taps give feedback for")
	var cast := _make_rabbit_cast(level, false)
	cast.call("_build_visuals")
	assert_true(_find_named_node(level.skill_bar, RABBIT_REWIND_CAST_NODE) != null, "time rabbit tap feedback uses the documented rabbit animation instead of only button scaling")
	cast.free()
	level.free()


func test_level_time_rewind_progress_bar_still_uses_purple_charge() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	assert_true(level.skills._skill_bar_fills.size() > 0, "time rabbit charge bar exists")
	if level.skills._skill_bar_fills.is_empty():
		level.free()
		return
	var fill: Panel = level.skills._skill_bar_fills[0]
	var initial_w: float = fill.size.x
	level.skills.call("charge", {4: 5})
	assert_eq(level.skills._skill_charge[0], 5.0, "purple clears still charge the time rabbit slot")
	assert_true(fill.size.x > initial_w, "time rabbit progress bar grows from purple clears even before rewind history exists")
	level.free()


func test_magic_match_art_pack_is_available_under_res_art() -> void:
	for path in MAGIC_ART_REQUIRED:
		assert_true(ResourceLoader.exists(path) or FileAccess.file_exists(path), "magic art asset exists: %s" % path)


func test_background_art_is_synced_to_bg3() -> void:
	var src := Image.load_from_file(_repo_path(BG3_SOURCE))
	var dst := Image.load_from_file(ProjectSettings.globalize_path(BACKGROUND_SYNCED))
	assert_true(src != null and not src.is_empty(), "bg3 source art loads")
	assert_true(dst != null and not dst.is_empty(), "synced game background loads")
	if src == null or src.is_empty() or dst == null or dst.is_empty():
		return
	assert_eq(dst.get_width(), src.get_width(), "game background keeps bg3 width")
	assert_eq(dst.get_height(), src.get_height(), "game background keeps bg3 height")
	for p in [Vector2i(50, 50), Vector2i(470, 200), Vector2i(750, 700), Vector2i(200, 1300)]:
		assert_eq(dst.get_pixel(p.x, p.y), src.get_pixel(p.x, p.y), "game background pixel matches bg3 at %s" % str(p))


func test_background_render_uses_current_bg3_pixels() -> void:
	var src := Image.load_from_file(_repo_path(BG3_SOURCE))
	assert_true(src != null and not src.is_empty(), "bg3 source art loads")
	if src == null or src.is_empty():
		return
	var level := _prepare_level_scene()
	var layer := CanvasLayer.new()
	level.add_child(layer)
	level.background_layer = layer
	level.call("_render_background")
	var rendered: TextureRect = null
	for child in layer.get_children():
		if child is TextureRect:
			rendered = child as TextureRect
	assert_true(rendered != null, "background renders a TextureRect")
	if rendered == null or rendered.texture == null:
		level.free()
		return
	var img := rendered.texture.get_image()
	assert_true(img != null and not img.is_empty(), "rendered background texture exposes image pixels")
	if img == null or img.is_empty():
		level.free()
		return
	for p in [Vector2i(50, 50), Vector2i(470, 200), Vector2i(750, 700), Vector2i(200, 1300)]:
		assert_eq(img.get_pixel(p.x, p.y), src.get_pixel(p.x, p.y), "rendered background pixel matches bg3 at %s" % str(p))
	level.free()


func test_book_ribbons_art_is_synced_to_new_full_width_asset() -> void:
	var src := Image.load_from_file(_repo_path(BOOK_RIBBONS_SOURCE))
	var dst := Image.load_from_file(ProjectSettings.globalize_path(BOOK_RIBBONS_SYNCED))
	var frame := Image.load_from_file(ProjectSettings.globalize_path(BOOK_FRAME_SYNCED))
	assert_true(src != null and not src.is_empty(), "book_ribbons_new source art loads")
	assert_true(dst != null and not dst.is_empty(), "synced book ribbons loads")
	assert_true(frame != null and not frame.is_empty(), "book frame art loads")
	if src == null or src.is_empty() or dst == null or dst.is_empty() or frame == null or frame.is_empty():
		return
	assert_eq(src.get_width(), frame.get_width(), "new ribbons source has the same width as book_frame")
	assert_eq(dst.get_width(), src.get_width(), "game ribbons use the new full-width art")
	assert_eq(dst.get_height(), src.get_height(), "game ribbons keep the new art height")
	if dst.get_width() != src.get_width() or dst.get_height() != src.get_height():
		return
	for p in [Vector2i(20, 20), Vector2i(491, 30), Vector2i(900, 60)]:
		assert_eq(dst.get_pixel(p.x, p.y), src.get_pixel(p.x, p.y), "game ribbons pixel matches new art at %s" % str(p))


func test_pink_gem_art_is_synced_to_heart_neon() -> void:
	var src := Image.load_from_file(_repo_path(PINK_GEM_SOURCE))
	var dst := Image.load_from_file(ProjectSettings.globalize_path(PINK_GEM_SYNCED))
	assert_true(src != null and not src.is_empty(), "heart_neon source art loads")
	assert_true(dst != null and not dst.is_empty(), "synced pink gem heart_neon loads")
	if src == null or src.is_empty() or dst == null or dst.is_empty():
		return
	assert_eq(dst.get_width(), src.get_width(), "pink gem keeps heart_neon width")
	assert_eq(dst.get_height(), src.get_height(), "pink gem keeps heart_neon height")
	for p in [Vector2i(50, 50), Vector2i(380, 360), Vector2i(700, 650)]:
		assert_eq(dst.get_pixel(p.x, p.y), src.get_pixel(p.x, p.y), "pink gem pixel matches heart_neon at %s" % str(p))


func test_book_ribbons_render_full_width_under_frame() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "1"], level._levels.size())
	level.load_level(raw_idx)
	var layer := CanvasLayer.new()
	level.add_child(layer)
	level.board_layer = layer
	level.board_view.call("_render_board_panel")
	var rib := _find_named_node(layer, BOOK_RIBBONS_NODE) as Control
	assert_true(rib != null, "book ribbons render as a named control")
	if rib == null:
		level.free()
		return
	var board_h: float = level.board.height * level.cell_size
	var expected_w := 726.0
	var expected_bottom: float = level.board_origin.y + board_h + 56.0
	assert_eq(int(roundf(rib.size.x)), int(expected_w), "book ribbons render at the same display width as the book frame")
	assert_eq(int(roundf(rib.position.x)), int(roundf(360.0 - expected_w * 0.5)), "book ribbons left edge aligns with the frame left edge")
	assert_eq(int(roundf(rib.position.y)), int(roundf(expected_bottom)), "book ribbons top edge touches the frame bottom edge")
	assert_true(absf((rib.size.x / rib.size.y) - (982.0 / 77.0)) <= 0.02, "book ribbons keep the new asset aspect ratio")
	assert_true(rib is NinePatchRect, "book ribbons use the same horizontal nine-slice mapping as the book frame")
	if rib is NinePatchRect:
		var np := rib as NinePatchRect
		assert_eq(np.patch_margin_left, 54, "book ribbons keep the frame left slice width")
		assert_eq(np.patch_margin_right, 54, "book ribbons keep the frame right slice width")
	level.free()


func test_third_level_book_frame_still_touches_screen_sides() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "3"], level._levels.size())
	level.load_level(raw_idx)
	assert_eq(level.board.width, 8, "third playable level keeps the narrow eight-column board")
	assert_eq(level.board.height, 10, "third playable level is height-limited by ten rows")
	var layer := CanvasLayer.new()
	level.add_child(layer)
	level.board_layer = layer
	level.board_view.call("_render_board_panel")
	var rib := _find_named_node(layer, BOOK_RIBBONS_NODE) as Control
	assert_true(rib != null, "book ribbons render for the third level")
	if rib != null:
		var expected_w := 726.0
		assert_eq(int(roundf(rib.size.x)), int(expected_w), "third level book keeps the same full-bleed width as wider boards")
		assert_eq(int(roundf(rib.position.x)), int(roundf(360.0 - expected_w * 0.5)), "third level book left edge bleeds to the screen side")
		assert_eq(int(roundf(rib.position.x + rib.size.x)), int(roundf(360.0 + expected_w * 0.5)), "third level book right edge bleeds to the screen side")
	level.free()


func test_playable_board_widths_fill_the_book_inner_inlay() -> void:
	for dims in [Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10), Vector2i(9, 9), Vector2i(9, 10), Vector2i(9, 11)]:
		var level := _prepare_level_scene()
		level.board = Board.new(dims.x, dims.y, [0, 1, 2, 3, 4, 5], 0, 25, 1)
		level.call("_compute_layout")
		var baked_rect: Rect2 = level.board_view.call("_book_baked_inner_rect")
		var board_rect: Rect2 = level.board_view.call("_book_board_inner_rect")
		assert_eq(int(roundf(board_rect.position.x)), int(roundf(baked_rect.position.x)), "board left edge aligns to book inner inlay for %dx%d" % [dims.x, dims.y])
		assert_eq(int(roundf(board_rect.size.x)), int(roundf(baked_rect.size.x)), "board width fills book inner inlay for %dx%d" % [dims.x, dims.y])
		var layer := CanvasLayer.new()
		level.add_child(layer)
		level.board_layer = layer
		level.board_view.call("_render_board_panel")
		assert_eq(_find_named_node(layer, BOOK_INLAY_MASK_LEFT_NODE), null, "width-filled boards do not need a left inlay mask for %dx%d" % [dims.x, dims.y])
		assert_eq(_find_named_node(layer, BOOK_INLAY_MASK_RIGHT_NODE), null, "width-filled boards do not need a right inlay mask for %dx%d" % [dims.x, dims.y])
		assert_eq(_find_named_node(layer, BOOK_INNER_INLAY_NODE), null, "width-filled boards use the book art's native inner inlay for %dx%d" % [dims.x, dims.y])
		level.free()


func test_all_real_playable_boards_fill_the_book_inner_inlay() -> void:
	var level := _prepare_level_scene()
	for raw_idx in level._playable:
		level.board = LevelLibrary.to_board(level._levels[raw_idx])
		level.call("_compute_layout")
		var baked_rect: Rect2 = level.board_view.call("_book_baked_inner_rect")
		var board_rect: Rect2 = level.board_view.call("_book_board_inner_rect")
		var label := "playable level %d raw %d %dx%d" % [level.call("_display_level_number", raw_idx), raw_idx, level.board.width, level.board.height]
		assert_eq(int(roundf(board_rect.position.x)), int(roundf(baked_rect.position.x)), "%s left edge aligns to book inner inlay" % label)
		assert_eq(int(roundf(board_rect.size.x)), int(roundf(baked_rect.size.x)), "%s width fills book inner inlay" % label)
	level.free()


func test_level_layout_module_matches_level_book_geometry() -> void:
	for dims in [Vector2i(8, 8), Vector2i(8, 10), Vector2i(9, 9), Vector2i(9, 11)]:
		var level := _prepare_level_scene()
		level.board = Board.new(dims.x, dims.y, [0, 1, 2, 3, 4, 5], 0, 25, 1)
		level.call("_compute_layout")
		var layout: Dictionary = LevelLayout.compute_layout(level.board.width, level.board.height)
		assert_eq(int(roundf(float(layout["cell_size"]))), int(roundf(level.cell_size)), "layout module matches level cell size for %dx%d" % [dims.x, dims.y])
		assert_eq(layout["board_origin"], level.board_origin, "layout module matches level board origin for %dx%d" % [dims.x, dims.y])
		assert_eq(LevelLayout.book_frame_rect(level.board.height, level.cell_size, level.board_origin), level.board_view.call("_book_frame_rect"), "layout module matches book frame rect for %dx%d" % [dims.x, dims.y])
		assert_eq(LevelLayout.book_baked_inner_rect(level.board.height, level.cell_size, level.board_origin), level.board_view.call("_book_baked_inner_rect"), "layout module matches baked inner rect for %dx%d" % [dims.x, dims.y])
		assert_eq(LevelLayout.book_board_inner_rect(level.board.width, level.board.height, level.cell_size, level.board_origin), level.board_view.call("_book_board_inner_rect"), "layout module matches board rect for %dx%d" % [dims.x, dims.y])
		level.free()


func test_topbar_art_background_fill_is_transparent() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(TOPBAR_SYNCED))
	assert_true(img != null and not img.is_empty(), "topbar art image loads")
	if img == null or img.is_empty():
		return
	assert_eq(img.get_width(), 1024, "topbar uses the new transparent source art width")
	assert_eq(img.get_height(), 1536, "topbar keeps the original tall transparent source art")
	var samples := [
		Vector2i(512, 360),
		Vector2i(512, 846),
		Vector2i(512, 1000),
		Vector2i(900, 360),
	]
	for p in samples:
		assert_true(img.get_pixel(p.x, p.y).a <= 0.05, "topbar fill sample %s should let the stage background show through" % str(p))
	assert_true(img.get_pixel(512, 700).a >= 0.95, "topbar visible frame remains opaque inside the selected art")


func test_topbar_uses_transparent_source_region_without_squashing() -> void:
	var level := _prepare_level_scene()
	assert_true(level.hud.has_method("_topbar_texture"), "Level exposes the topbar texture region")
	assert_true(level.hud.has_method("_topbar_height"), "Level exposes topbar display height")
	if not level.hud.has_method("_topbar_texture") or not level.hud.has_method("_topbar_height"):
		level.free()
		return
	var tex: Variant = level.hud.call("_topbar_texture")
	assert_true(tex is AtlasTexture, "topbar renders a cropped region from the tall transparent art")
	if tex is AtlasTexture:
		var atlas := tex as AtlasTexture
		assert_eq(int(atlas.region.position.x), 0, "topbar source crop keeps full art width")
		assert_eq(int(atlas.region.position.y), 340, "topbar source crop skips the tall transparent/empty lead-in")
		assert_eq(int(atlas.region.size.x), 1024, "topbar source crop keeps full art width")
		assert_eq(int(atlas.region.size.y), 507, "topbar source crop excludes the transparent lower canvas")
		var th: float = level.hud.call("_topbar_height")
		assert_true(absf(th - 720.0 * atlas.region.size.y / atlas.region.size.x) <= 0.01, "topbar display height follows the cropped source region")
		assert_true(absf(th - 356.5) <= 0.5, "frame and round ornaments stay at the old topbar height instead of shrinking with the 9:16 canvas")
	level.free()


func test_level_can_load_magic_match_pngs_before_import_metadata_exists() -> void:
	var level := _prepare_level_scene()
	assert_true(level.has_method("_load_texture"), "Level has a PNG fallback texture loader")
	var tex := level.call("_load_texture", "res://art/gems/base/gem_ruby.png") as Texture2D
	assert_true(tex != null, "raw magic art PNG loads as Texture2D")
	if tex != null:
		assert_true(tex.get_width() > 0 and tex.get_height() > 0, "loaded magic art texture has dimensions")
	level.free()


func test_colorbomb_core_uses_synced_diamond_white_art() -> void:
	assert_true(FileAccess.file_exists(_repo_path(COLORBOMB_CORE_SOURCE)), "source diamond_white.png 5-match art exists")
	assert_true(FileAccess.file_exists(COLORBOMB_CORE_SYNCED), "synced diamond_white 5-match art exists")
	# 彩球核心贴图常量迁至 board_view(契约 E)。
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	assert_true(src.contains('const COLORBOMB_CORE := "%s"' % COLORBOMB_CORE_SYNCED), "5-match colorbomb core uses synced diamond_white art")
	var img := Image.load_from_file(ProjectSettings.globalize_path(COLORBOMB_CORE_SYNCED))
	assert_true(img != null and img.detect_alpha() != Image.ALPHA_NONE, "synced diamond_white keeps transparency so it does not render as a square")


func test_colorbomb_core_keeps_cell_sized_fit_after_art_swap() -> void:
	var level := _prepare_level_scene()
	assert_true(level.has_method("_fit_scale"), "Level exposes texture fit scaling")
	assert_true(level.has_method("_load_texture"), "Level can load the raw 5-match PNG")
	level.cell_size = 70.0
	var tex := level.call("_load_texture", COLORBOMB_CORE_SYNCED) as Texture2D
	# 彩球贴图 fit 路径(_apply_colorbomb_layers)迁至 board_view(契约 E)。
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	assert_true(src.contains("const COLORBOMB_FILL := 0.74"), "5-match crystal ball should be smaller than the previous oversized 0.86 fit")
	assert_true(tex != null, "diamond_white 5-match art loads as a texture")
	if tex != null:
		var scale: Vector2 = level.call("_fit_scale", tex, level.cell_size * 0.74)
		var fitted_max := maxf(tex.get_width() * scale.x, tex.get_height() * scale.y)
		assert_true(absf(fitted_max - level.cell_size * 0.74) <= 0.01, "5-match art is fitted to the smaller COLORBOMB_FILL instead of raw image pixels")
	assert_true(src.contains("node.scale = _fit_scale(core, cell_size * COLORBOMB_FILL)"), "colorbomb visual keeps the shared cell-size fit path")
	level.free()


func test_project_default_scene_uses_level_entry() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://Level.tscn", "project starts directly in Level.tscn")


func test_level_scene_launch_level_arg_is_one_based() -> void:
	var level := _prepare_level_scene()
	assert_true(level.has_method("_launch_level_idx_from_args"), "Level.tscn path parses direct level launch args")
	if not level.has_method("_launch_level_idx_from_args"):
		level.free()
		return
	assert_eq(level.call("_launch_level_idx_from_args", ["--level", "5"], level._levels.size()), 5, "--level 5 opens the fifth playable level, raw exported level 6")
	assert_eq(level.call("_launch_level_idx_from_args", ["--level=5"], level._levels.size()), 5, "--level=5 opens the fifth playable level, raw exported level 6")
	assert_eq(level.call("_launch_level_idx_from_args", ["--level", "0"], 126), -1, "Level.tscn level numbers are one-based")
	assert_eq(level.call("_launch_level_idx_from_args", ["--level", "127"], 126), -1, "out of range Level.tscn levels are ignored")
	level.free()


func test_level_scene_displays_playable_level_number() -> void:
	var level := _prepare_level_scene()
	level.load_level(5)
	assert_eq(level._cur_cfg.get("id", -1), 5, "raw exported level 6 is player-facing level 5")
	level.free()


func test_level_objective_view_names_clear_jelly() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var objs := [{"type": "CLEAR_JELLY", "species": -1, "target": 65}]
	level.board = Board.new(8, 9, [0, 1, 2, 3, 4, 5], 0, 25, 1, [], objs, _filled_layer(8, 9, 1))
	var view: Array = level.hud.call("_objectives_view")
	assert_eq(view.size(), 1, "one objective card")
	assert_eq(view[0].get("label", ""), "清果冻", "jelly objective says what action clears the level")
	assert_eq(view[0].get("icon", ""), JELLY_GOAL_ICON, "jelly objective uses a readable jelly/bubble icon instead of a placeholder")
	assert_eq(view[0].get("progress", -1), 0, "jelly starts at zero progress")
	assert_eq(view[0].get("target", -1), 65, "fifth-level jelly target is shown")
	level.free()


func test_topbar_objective_counter_shows_remaining_amount() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.hud.has_method("_objective_counter_text"), "Level exposes topbar objective counter formatting")
	if not level.hud.has_method("_objective_counter_text"):
		level.free()
		return
	assert_eq(level.hud.call("_objective_counter_text", {"progress": 0, "target": 42}), "42", "fresh objective shows full remaining count")
	assert_eq(level.hud.call("_objective_counter_text", {"progress": 5, "target": 42}), "37", "objective counter decreases as progress increases")
	assert_eq(level.hud.call("_objective_counter_text", {"progress": 99, "target": 42}), "0", "completed objective never shows a negative remaining count")
	assert_eq(level.hud.call("_objective_counter_text", {"n": "16"}), "16", "demo fallback keeps its literal number")
	level.free()


func test_topbar_objective_render_uses_remaining_count_from_progress() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "6"], level._levels.size())
	level.load_level(raw_idx)
	level.board.collected[5] = 5
	var layer := CanvasLayer.new()
	level.add_child(layer)
	level.ui_layer = layer
	level.hud.call("_render_topbar_v2", level._cur_cfg)
	assert_true(_count_label_text(layer, "37") > 0, "topbar renders remaining objective count after progress")
	assert_eq(_count_label_text(layer, "42"), 0, "topbar no longer renders the total target after progress exists")
	level.free()


func test_topbar_objective_slots_keep_number_near_icon() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.hud.has_method("_topbar_objective_slot"), "Level exposes topbar objective slot layout")
	if not level.hud.has_method("_topbar_objective_slot"):
		level.free()
		return
	var first: Dictionary = level.hud.call("_topbar_objective_slot", 0, 2, 720.0, 356.0)
	var second: Dictionary = level.hud.call("_topbar_objective_slot", 1, 2, 720.0, 356.0)
	var icon_text_gap: float = absf((first["text"] as Vector2).x - (first["icon"] as Vector2).x)
	var objective_gap: float = absf((second["icon"] as Vector2).x - (first["text"] as Vector2).x)
	assert_true(icon_text_gap <= 58.0, "number sits close to its own objective icon")
	assert_true(objective_gap > icon_text_gap, "space between two objectives is larger than icon-to-number spacing")
	assert_eq(int(roundf((first["icon"] as Vector2).y)), 233, "objective icon moves up with the shortened-chain topbar")
	assert_eq(int(roundf((first["text"] as Vector2).y)), 233, "objective number moves up with the shortened-chain topbar")
	var third: Dictionary = level.hud.call("_topbar_objective_slot", 2, 3, 720.0, 356.0)
	assert_true((third["text"] as Vector2).x <= 640.0, "three objectives still fit inside the topbar target area")
	var src := FileAccess.get_file_as_string("res://match3/hud.gd")
	assert_true(src.contains("const TB_OBJ_ICON_MAX := 80.0"), "topbar objective icons are large enough to read")
	assert_true(src.contains("const TB_OBJ_ICON_TEXT_GAP := 58.0"), "topbar objective number leaves room for larger icons")
	level.free()


func test_topbar_moves_number_center_matches_transparent_art() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.hud.has_method("_topbar_moves_number_center"), "Level exposes the moves-number text anchor")
	if not level.hud.has_method("_topbar_moves_number_center"):
		level.free()
		return
	var center: Vector2 = level.hud.call("_topbar_moves_number_center")
	assert_eq(int(roundf(center.x)), 140, "moves-number anchor is nudged slightly left after following the label")
	assert_eq(int(roundf(center.y)), 234, "moves-number anchor moves up with the shortened-chain topbar")
	level.free()


func test_topbar_text_anchors_align_with_transparent_art() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.hud.has_method("_topbar_level_label_center"), "Level exposes the level label anchor")
	assert_true(level.hud.has_method("_topbar_moves_label_center"), "Level exposes the moves label anchor")
	if not level.hud.has_method("_topbar_level_label_center") or not level.hud.has_method("_topbar_moves_label_center"):
		level.free()
		return
	var level_center: Vector2 = level.hud.call("_topbar_level_label_center")
	var moves_label: Vector2 = level.hud.call("_topbar_moves_label_center")
	assert_eq(int(roundf(level_center.x)), 142, "level title sits slightly right on the new red ribbon")
	assert_eq(int(roundf(level_center.y)), 128, "level title moves up with the shortened-chain topbar")
	assert_eq(int(roundf(moves_label.x)), 146, "moves label shifts farther right in the transparent-art left counter panel")
	assert_eq(int(roundf(moves_label.y)), 189, "moves label moves up with the shortened-chain topbar")
	level.free()


func test_topbar_star_icons_align_with_transparent_art_slots() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.hud.has_method("_topbar_star_center"), "Level exposes topbar star slot anchors")
	if not level.hud.has_method("_topbar_star_center"):
		level.free()
		return
	var first: Vector2 = level.hud.call("_topbar_star_center", 0, 720.0, 356.0)
	assert_eq(int(roundf(first.x)), 360, "first star stays centered over the first topbar slot")
	assert_eq(int(roundf(first.y)), 151, "stars move up with the shortened-chain topbar")
	level.free()


func test_topbar_renders_only_first_star_overlay() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "1"], level._levels.size())
	level.load_level(raw_idx)
	var layer := CanvasLayer.new()
	level.add_child(layer)
	level.ui_layer = layer
	level.hud.call("_render_topbar_v2", level._cur_cfg)
	var topbar_rect: TextureRect = null
	for child in layer.get_children():
		if child is TextureRect:
			topbar_rect = child as TextureRect
			break
	assert_true(topbar_rect != null, "topbar background texture renders")
	if topbar_rect != null:
		assert_eq(int(roundf(topbar_rect.position.y)), -48, "topbar background moves up to shorten the visible chains")
	assert_eq(_count_sprite_texture(layer, TOPBAR_STAR_GOLD), 1, "topbar renders only the first gold star overlay")
	level.free()


func test_topbar_objective_icons_use_consistent_max_dimension() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var layer := CanvasLayer.new()
	level.add_child(layer)
	assert_true(level.has_method("_sprite_fit"), "Level can draw objective icons by max dimension")
	if not level.has_method("_sprite_fit"):
		level.free()
		return
	var gem := level.call("_sprite_fit", layer, PINK_GEM_SYNCED, Vector2.ZERO, 80.0, false) as Sprite2D
	var jelly := level.call("_sprite_fit", layer, JELLY_GOAL_ICON, Vector2.ZERO, 80.0, false) as Sprite2D
	assert_true(gem != null and jelly != null, "objective icon sprites are created")
	if gem != null:
		var gem_size: Vector2 = gem.texture.get_size() * gem.scale
		assert_true(maxf(gem_size.x, gem_size.y) >= 79.9, "gem objective icon uses the larger topbar target size")
		assert_true(maxf(gem_size.x, gem_size.y) <= 80.1, "gem objective icon is capped by max dimension")
	if jelly != null:
		var jelly_size: Vector2 = jelly.texture.get_size() * jelly.scale
		assert_true(maxf(jelly_size.x, jelly_size.y) >= 79.9, "jelly objective icon uses the larger topbar target size")
		assert_true(maxf(jelly_size.x, jelly_size.y) <= 80.1, "jelly objective icon is capped by max dimension")
	level.free()


func test_twelfth_playable_level_shows_jelly_goal_and_board_markers() -> void:
	assert_true(FileAccess.file_exists(JELLY_GOAL_ICON), "jelly goal icon exists")
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "12"], level._levels.size())
	assert_eq(raw_idx, 17, "player level 12 maps to raw exported lvl_17 after score-only gaps are skipped")
	level.load_level(raw_idx)
	var view: Array = level.hud.call("_objectives_view")
	assert_eq(view.size(), 1, "twelfth playable level has one objective card")
	assert_eq(view[0].get("label", ""), "清果冻", "twelfth playable level explicitly asks the player to clear jelly tiles")
	assert_eq(view[0].get("icon", ""), JELLY_GOAL_ICON, "twelfth playable level uses the jelly goal icon")
	assert_eq(view[0].get("target", -1), 63, "twelfth playable level target count is shown")
	var expected := _count_positive_layer(level.board.jelly)
	assert_true(expected > 0, "twelfth playable level has jelly cells")
	assert_eq(_count_group_nodes(level, JELLY_MARKER_NAME), expected, "every remaining jelly cell renders a visible board marker")
	level.free()

func test_jelly_board_markers_do_not_use_round_goal_icon() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "12"], level._levels.size())
	level.load_level(raw_idx)
	var marker := _find_named_node(level, JELLY_MARKER_NAME)
	assert_true(marker != null, "jelly board marker exists")
	if marker is Sprite2D:
		var sprite := marker as Sprite2D
		assert_true(sprite.texture == null or sprite.texture.resource_path != JELLY_GOAL_ICON, "board jelly marker must not reuse the round goal icon under gems")
	level.free()


func test_sixth_playable_level_objective_view_shows_collect_goal() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "6"], level._levels.size())
	assert_eq(raw_idx, 7, "player level 6 maps to raw exported lvl_7 after score-only gaps are skipped")
	level.load_level(raw_idx)
	var view: Array = level.hud.call("_objectives_view")
	assert_eq(view.size(), 1, "sixth playable level has one objective card")
	assert_eq(view[0].get("label", ""), "收集", "sixth playable level is a collect goal")
	assert_eq(view[0].get("icon", ""), PINK_GEM_SYNCED, "sixth playable level collects the heart jelly 3 pink gem")
	assert_eq(view[0].get("target", -1), 42, "sixth playable level target is shown")
	level.free()


func test_score_fallback_level_objective_view_shows_score_target() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.board = Board.new(3, 3, [0, 1, 2], 5119, 25, 1)
	var view: Array = level.hud.call("_objectives_view")
	assert_eq(view.size(), 1, "score-only levels still show one real objective card")
	if view.is_empty():
		level.free()
		return
	assert_eq(view[0].get("label", ""), "分数", "score-only level is labeled as score")
	assert_eq(view[0].get("progress", -1), 0, "score-only level starts at zero score progress")
	assert_eq(view[0].get("target", -1), 5119, "score-only level target score is shown")
	level.free()


func test_level_blocker_objective_uses_resources_barrier_ice_icon() -> void:
	assert_true(FileAccess.file_exists(_repo_path(BARRIER_ICE_SOURCE)), "source barrier image exists")
	assert_true(FileAccess.file_exists(BARRIER_ICE_SYNCED), "synced Godot barrier image exists")
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var objs := [{"type": "CLEAR_BLOCKER", "species": -1, "target": 9}]
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1, [], objs, [], _filled_layer(3, 3, 1))
	var view: Array = level.hud.call("_objectives_view")
	assert_eq(view.size(), 1, "one objective card")
	assert_eq(view[0].get("icon", ""), BARRIER_ICE_SYNCED, "blocker objective uses resources/barrier synced art")
	level.free()


func test_level_scene_renders_blockers_as_keyed_barrier_ice_sprites() -> void:
	var level := _prepare_level_scene()
	level.load_level(5)
	var expected := _count_positive_layer(level.board.coat)
	assert_true(expected > 0, "raw level 6 contains blocker coat cells")
	for y in level.board.coat.size():
		for x in level.board.coat[y].size():
			if level.board.coat[y][x] > 0:
				assert_eq(level.board.grid[y][x], ME.EMPTY, "visible blocker has no hidden gem underneath")
	assert_eq(_count_group_nodes(level, BARRIER_MARKER_NAME), expected, "every blocker coat cell renders one visible barrier sprite")
	var marker := _find_named_node(level, BARRIER_MARKER_NAME)
	assert_true(marker is Sprite2D, "barrier marker is a sprite")
	if marker is Sprite2D:
		var sprite := marker as Sprite2D
		assert_eq(sprite.texture.resource_path, BARRIER_ICE_SYNCED, "barriers use resources/barrier synced ice art")
		assert_true(sprite.material is ShaderMaterial, "barriers key out the magenta source background")
		# ob_ice 实体冰晶仅占贴图~0.69(四周透明边), 放大补偿使可见实体≈cell*0.86 在格内;
		# 整图(含透明边)尺寸=cell*1.26, 故阈值按实体0.90对应的整图(0.90/0.686≈1.31)放宽。
		var drawn_size: Vector2 = sprite.texture.get_size() * sprite.scale
		assert_true(drawn_size.x <= level.cell_size * 1.31 and drawn_size.y <= level.cell_size * 1.31, "barrier visible art stays inside one board cell")
	level.free()


func test_level_scene_renders_wall_cells_as_stone_sprites() -> void:
	assert_true(FileAccess.file_exists(WALL_STONE_SYNCED), "wall stone art exists")
	var level := _prepare_level_scene()
	level.load_level(13)
	var expected := _count_grid_value(level.board.grid, ME.WALL)
	assert_true(expected > 0, "raw level 9 contains wall cells")
	assert_eq(_count_group_nodes(level, WALL_MARKER_NAME), expected, "every wall cell renders one visible stone sprite")
	var marker := _find_named_node(level, WALL_MARKER_NAME)
	assert_true(marker is Sprite2D, "wall marker is a sprite")
	if marker is Sprite2D:
		var sprite := marker as Sprite2D
		assert_eq(sprite.texture.resource_path, WALL_STONE_SYNCED, "walls use stone obstacle art")
		var drawn_size: Vector2 = sprite.texture.get_size() * sprite.scale
		assert_true(drawn_size.x <= level.cell_size * 0.92 and drawn_size.y <= level.cell_size * 0.92, "wall art stays inside one board cell")
	level.free()


func test_wall_slide_source_map_replays_gravity_order() -> void:
	var level := _prepare_level_scene()
	level.board = Board.new(3, 4, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board.is_scrolling = true
	var E := ME.EMPTY
	var W := ME.WALL
	var before_grid := [
		[10, W, 11],
		[5, E, 6],
		[7, E, 9],
		[1, 2, 3],
	]
	assert_true(level.board_view.has_method("_build_wall_slide_tracking_maps"), "wall slide visuals can replay gravity to map targets to exact old sources")
	if not level.board_view.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	var maps: Dictionary = level.board_view.call("_build_wall_slide_tracking_maps", before_grid)
	var source_map: Array = maps["source"]
	assert_eq(source_map[2][1], Vector2i(2, 1), "lower blocked slot uses the immediate right-above tile, matching gravity order")
	assert_eq(source_map[1][1], Vector2i(2, 0), "upper blocked slot then uses the top right tile after the lower move")
	level.free()


func test_wall_slide_source_map_tracks_spawn_source_column() -> void:
	var level := _prepare_level_scene()
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	var E := ME.EMPTY
	var W := ME.WALL
	var before_grid := [
		[E, W, E],
		[5, E, 6],
		[7, 8, 9],
	]
	assert_true(level.board_view.has_method("_build_wall_slide_tracking_maps"), "wall slide visuals can replay spawned sources")
	if not level.board_view.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	var maps: Dictionary = level.board_view.call("_build_wall_slide_tracking_maps", before_grid)
	var source_map: Array = maps["source"]
	var source: Vector2i = source_map[1][1]
	assert_eq(source.x, 2, "new piece filling the wall pocket should enter from the right top column, matching gravity's right-above priority")
	assert_true(source.y < 0, "spawned source is marked as a new piece rather than an old board node")
	level.free()


func test_wall_slide_path_map_preserves_delayed_diagonal_step() -> void:
	var level := _prepare_level_scene()
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board.is_scrolling = true
	var E := ME.EMPTY
	var W := ME.WALL
	var before_grid := [
		[E, E, 11],
		[E, W, E],
		[7, E, 9],
	]
	assert_true(level.board_view.has_method("_build_wall_slide_tracking_maps"), "wall slide visuals record each gravity step, not just final source")
	if not level.board_view.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	var maps: Dictionary = level.board_view.call("_build_wall_slide_tracking_maps", before_grid)
	var path_map: Array = maps["path"]
	assert_eq(path_map[2][1], [Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 2)], "piece falls vertically first, then diagonally into the wall pocket")
	level.free()


func test_wall_slide_tracking_maps_stress_paths_are_contiguous() -> void:
	var level := _prepare_level_scene()
	level.board = Board.new(6, 7, [0, 1, 2, 3], 0, 25, 1)
	level.board_view.board = level.board
	assert_true(level.board_view.has_method("_build_wall_slide_tracking_maps"), "wall slide visuals expose source/path tracking maps for stress validation")
	if not level.board_view.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	for seed in range(48):
		level.board.is_scrolling = seed % 2 == 0
		var before_grid := []
		for row in range(level.board.height):
			var out_row := []
			for col in range(level.board.width):
				var roll: int = int((seed * 31 + row * 17 + col * 13 + row * col * 7) % 12)
				if roll == 0 and row > 0 and row < level.board.height - 1:
					out_row.append(ME.WALL)
				elif roll <= 3:
					out_row.append(ME.EMPTY)
				else:
					out_row.append(seed * 100 + row * level.board.width + col)
			before_grid.append(out_row)
		var maps: Dictionary = level.board_view.call("_build_wall_slide_tracking_maps", before_grid)
		var source_map: Array = maps["source"]
		var path_map: Array = maps["path"]
		for row in range(level.board.height):
			for col in range(level.board.width):
				var path: Array = path_map[row][col]
				if path.is_empty():
					continue
				assert_eq(path[path.size() - 1], Vector2i(col, row), "path ends at its visual target for seed %d cell (%d,%d)" % [seed, col, row])
				var source: Vector2i = source_map[row][col]
				if source.y >= 0:
					assert_eq(path[0], source, "old piece path starts at the exact source for seed %d cell (%d,%d)" % [seed, col, row])
				elif source.y == -2:
					assert_eq(path[0], Vector2i(source.x, 0), "spawned path starts at the top entry column for seed %d cell (%d,%d)" % [seed, col, row])
				for idx in range(1, path.size()):
					var prev: Vector2i = path[idx - 1]
					var next: Vector2i = path[idx]
					assert_eq(next.y - prev.y, 1, "gravity path never skips a row for seed %d cell (%d,%d)" % [seed, col, row])
					assert_true(absi(next.x - prev.x) <= 1, "gravity path never jumps across columns for seed %d cell (%d,%d)" % [seed, col, row])
	level.free()
