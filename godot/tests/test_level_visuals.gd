extends "res://tests/test_lib.gd"

const ClearVisuals := preload("res://match3/clear_visuals.gd")
const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const LevelMotion := preload("res://match3/level_motion.gd")
const ME := preload("res://core/match_engine.gd")


func _none_fx(w: int, h: int) -> Array:
	var fx := []
	for y in h:
		var row := []
		for x in w:
			row.append(ME.SP_NONE)
		fx.append(row)
	return fx


func _prepare_level_scene_with_real_levels() -> Node:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level._levels = LevelLibrary.load_file(LevelLibrary.DEFAULT_LEVELS_PATH)
	level._playable = []
	for i in range(level._levels.size()):
		var objs = level._levels[i].get("objectives", [])
		if objs is Array and not objs.is_empty():
			level._playable.append(i)
	return level


func test_bottom_row_pointer_press_is_claimed_by_board_before_skillbar() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.board = Board.new(8, 8, [0, 1, 2, 3, 4, 5], 0, 25, 7)
	level.cell_size = 70.0
	level.board_origin = Vector2(80.0, 420.0)
	level.board_view.board = level.board
	level.board_view.cell_size = level.cell_size
	level.board_view.board_origin = level.board_origin
	var nodes := []
	for y in range(level.board.height):
		var row := []
		for x in range(level.board.width):
			var node := Sprite2D.new()
			level.add_child(node)
			row.append(node)
		nodes.append(row)
	level.board_view.set("_gem_nodes", nodes)
	assert_true(level.has_method("_handle_board_pointer_press"), "Level exposes a board-first pointer handler so GUI controls cannot steal board taps")
	if not level.has_method("_handle_board_pointer_press"):
		level.free()
		return
	var bottom_cell := Vector2i(level.board.width / 2, level.board.height - 1)
	var bottom_center: Vector2 = level.call("_cell_center", bottom_cell.y, bottom_cell.x)
	var handled: bool = bool(level.call("_handle_board_pointer_press", bottom_center))
	assert_true(handled, "bottom-row taps inside the board are claimed before skill buttons can see them")
	assert_eq(level.get("_sel"), bottom_cell, "bottom-row tap selects the intended board cell")
	level.free()


func test_bottom_row_visible_tail_still_maps_to_bottom_cell() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.board = Board.new(8, 8, [0, 1, 2, 3, 4, 5], 0, 25, 7)
	level.cell_size = 70.0
	level.board_origin = Vector2(80.0, 420.0)
	level.board_view.board = level.board
	level.board_view.cell_size = level.cell_size
	level.board_view.board_origin = level.board_origin
	var nodes := []
	for y in range(level.board.height):
		var row := []
		for x in range(level.board.width):
			var node := Sprite2D.new()
			level.add_child(node)
			row.append(node)
		nodes.append(row)
	level.board_view.set("_gem_nodes", nodes)
	assert_true(level.has_method("_board_pointer_hit_cell"), "Level maps the full visible bottom-row hit area, not just the strict board rectangle")
	if not level.has_method("_board_pointer_hit_cell"):
		level.free()
		return
	var bottom_cell := Vector2i(level.board.width / 2, level.board.height - 1)
	var bottom_center: Vector2 = level.call("_cell_center", bottom_cell.y, bottom_cell.x)
	var visual_tail_point := bottom_center + Vector2(0.0, level.cell_size * 0.56)
	assert_eq(level.call("_board_pointer_hit_cell", visual_tail_point), bottom_cell, "taps on the visible lower tail of bottom-row gems still select the bottom cell")
	var handled: bool = bool(level.call("_handle_board_pointer_press", visual_tail_point))
	assert_true(handled, "bottom-row visible tail taps are handled by the board instead of falling through to skills")
	assert_eq(level.get("_sel"), bottom_cell, "bottom-row visible tail tap selects the intended board cell")
	level.free()


func test_board_input_guard_covers_bottom_row_tail_above_skillbar() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.board = Board.new(8, 8, [0, 1, 2, 3, 4, 5], 0, 25, 7)
	level.cell_size = 70.0
	level.board_origin = Vector2(80.0, 420.0)
	assert_true(level.has_method("_board_input_rect"), "Level exposes the board input guard rect used by the top-layer click shield")
	if not level.has_method("_board_input_rect"):
		level.free()
		return
	var rect: Rect2 = level.call("_board_input_rect")
	var bottom_center: Vector2 = level.call("_cell_center", level.board.height - 1, level.board.width / 2)
	assert_true(rect.has_point(bottom_center), "board input guard covers strict bottom-row cell centers")
	assert_true(rect.has_point(bottom_center + Vector2(0.0, level.cell_size * 0.56)), "board input guard extends over the visible bottom-row tail before the skillbar can catch it")
	level.free()


func test_board_input_marks_board_pointer_events_handled_before_gui() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var input_start: int = src.find("func _input(event: InputEvent)")
	var input_end: int = src.find("func _unhandled_input", input_start)
	assert_true(input_start >= 0 and input_end > input_start, "Level handles board pointer events in _input before GUI/skill buttons")
	if input_start >= 0 and input_end > input_start:
		var body: String = src.substr(input_start, input_end - input_start)
		assert_true(body.contains("_handle_board_pointer_event(event)"), "_input routes mouse/touch through the board-first pointer handler")
		assert_true(body.contains("get_viewport().set_input_as_handled()"), "board pointer events are marked handled so overlapped skill buttons cannot fire")


func test_colorbomb_idle_does_not_tween_board_position() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	if not level.board_view.has_method("_apply_colorbomb_layers"):
		level.free()
		return
	level.cell_size = 100.0
	level.board_view.cell_size = level.cell_size
	var node := Sprite2D.new()
	node.position = Vector2(123.0, 456.0)
	level.add_child(node)
	level.board_view.call("_apply_colorbomb_layers", node)
	# 行为断言: idle bob 通过 colorbomb_tween 动画 offset, 棋盘 position 不被 idle 占用(下落/交换才拥有 position)
	assert_true(node.has_meta("colorbomb_tween"), "colorbomb bob registers an idle tween")
	assert_eq(node.position, Vector2(123.0, 456.0), "colorbomb idle must not move board position; fall/swap owns board position")
	level.free()


func test_colorbomb_has_internal_color_light_cycle() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_eq(level.board_view.get("COLORBOMB_INNER_LIGHT_SHADER"), "res://match3/colorbomb_inner_light.gdshader", "5-match colorbomb owns a dedicated internal light shader")
	assert_eq(level.get("COLORBOMB_INNER_LIGHT_NAME"), "InnerLight", "internal light is a named removable colorbomb layer")
	assert_true(level.board_view.has_method("_colorbomb_inner_light_material"), "colorbomb internal light uses its own shader material")
	# 废弃的外圈流光层/rim shader: 实例上读不到/没有方法即证明已移除
	assert_false(level.has_method("_attach_colorbomb_flowing_rim"), "colorbomb no longer attaches an outer ring")
	assert_eq(level.get("COLORBOMB_RIM_SHADER"), null, "outer rim shader is not used by the colorbomb")
	# 直接调真函数挂内部光层, 断言 z序契约(3 > 核心 2)、命名、材质
	var node := Sprite2D.new()
	node.texture = load("res://assets/level/diamond_white.png")
	level.add_child(node)
	level.board_view.call("_attach_colorbomb_inner_light", node, node.texture)
	var light := node.get_node_or_null(String(level.get("COLORBOMB_INNER_LIGHT_NAME")))
	assert_true(light != null, "colorbomb application attaches an internal light layer")
	if light != null:
		assert_eq(light.z_index, 3, "internal light must draw above the diamond core (z=3 > core z=2)")
		assert_true(light.material is ShaderMaterial, "internal light uses a dedicated shader material")
	# 内部光颜色序列: 材质参数应逐个等于真实常量数组, 证明 红/绿/紫/粉/黄/蓝 顺序被原样传入(画面契约)
	var mat = level.board_view.call("_colorbomb_inner_light_material")
	var colors: Array = level.board_view.get("COLORBOMB_INNER_LIGHT_COLORS")
	assert_eq(colors.size(), 6, "internal light defines six ordered colors")
	# 锁住红绿主基调顺序: 第0色偏红(r 最大), 第1色偏绿(g 最大)
	assert_true((colors[0] as Color).r > (colors[0] as Color).g and (colors[0] as Color).r > (colors[0] as Color).b, "first internal light color reads red")
	assert_true((colors[1] as Color).g > (colors[1] as Color).r and (colors[1] as Color).g > (colors[1] as Color).b, "second internal light color reads green")
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat
		for i in range(colors.size()):
			var got = sm.get_shader_parameter("light_color_%d" % i)
			assert_true(got != null and (got as Color).is_equal_approx(colors[i]), "internal light color %d is wired in order from the defined palette" % i)
	level.free()
	# 钉源码理由: colorbomb_inner_light.gdshader 资产内容契约(headless 无法渲染); TIME 驱动变色、inner_radius 限定中心、
	# 不画 rim/不沿外缘 atan 公转, 都是已拍板的 5合1 内透光观感, 必须锁文本
	var shader := FileAccess.get_file_as_string("res://match3/colorbomb_inner_light.gdshader")
	assert_true(not shader.is_empty(), "internal light shader file exists")
	assert_true(shader.contains("TIME"), "internal light changes color over time without moving the board sprite")
	assert_true(shader.contains("inner_radius"), "shader confines the light to the diamond center, not the edge")
	assert_true(shader.contains("light_color_0") and shader.contains("light_color_5"), "shader receives the six ordered light colors")
	assert_false(shader.contains("rim_radius"), "internal light shader must not draw an outer rim")
	assert_false(shader.contains("atan("), "internal light should not orbit around the outside edge")


func test_combo_idle_uses_restrained_directional_motion() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 4合1 idle 调过的视觉参数: 摆动幅度/鼓出/偏移/方向高光强度, 直接读真实常量值断言契约
	assert_eq(level.board_view.get("COMBO_SWING_AMP"), 0.14, "4-match idle pinch is restrained, not a large wobble")
	assert_eq(level.board_view.get("COMBO_SWING_WIDEN"), 0.025, "4-match idle front-facing widen stays subtle")
	assert_eq(level.board_view.get("COMBO_SWING_OFFSET"), 3.0, "4-match idle uses a small visual offset to disambiguate direction")
	assert_eq(level.board_view.get("COMBO_VERTICAL_SWING_OFFSET"), 1.8, "vertical 4-match idle uses a smaller offset so water-drop gems do not look like they only tip upward")
	assert_eq(level.board_view.get("COMBO_LIGHT_STRENGTH"), 1.65, "directional highlight is strong enough on symmetric gems")
	assert_eq(level.board_view.get("COMBO_LIGHT_W"), 0.30, "directional highlight is narrow enough to read as one side")
	assert_eq(level.board_view.get("COMBO_LIGHT_TINT"), Color(1.0, 1.0, 1.0), "line-special highlight stays neutral white so blue gems do not shift purple")
	# 垂直 idle 偏移小于水平: 真实常量数值已锁住"竖向更克制"这一视觉决策
	assert_true(float(level.board_view.get("COMBO_VERTICAL_SWING_OFFSET")) < float(level.board_view.get("COMBO_SWING_OFFSET")), "vertical idle offset stays smaller than horizontal so symmetric gems do not read as one-directional")
	level.free()


func test_vertical_combo_idle_scales_vertically_not_sideways() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_combo_swing_scale"), "Level exposes combo idle axis scale calculation")
	if not level.board_view.has_method("_combo_swing_scale"):
		level.free()
		return
	var base := Vector2(0.80, 0.72)
	var horizontal: Vector2 = level.board_view.call("_combo_swing_scale", base, true, 1.0)
	var vertical: Vector2 = level.board_view.call("_combo_swing_scale", base, false, 1.0)
	assert_true(horizontal.x < base.x, "horizontal idle pinches the horizontal axis")
	assert_true(absf(horizontal.y - base.y) < 0.001, "horizontal idle keeps y scale stable")
	assert_true(absf(vertical.x - base.x) < 0.001, "vertical idle keeps x scale stable so pink/blue gems do not read as left-right wobble")
	assert_true(vertical.y < base.y, "vertical idle pinches the vertical axis")
	level.free()


func test_combo_idle_uses_directional_light_without_added_shadows() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# rim/specular 强度常量存在(伪3D光照线索), 直接读真实值断言其被定义
	assert_true(level.board_view.get("COMBO_RIM_STRENGTH") != null, "combo idle exposes a rim-light cue for pseudo 3D volume")
	assert_true(level.board_view.get("COMBO_SPECULAR_STRENGTH") != null, "combo idle exposes a crisp specular cue for a gem-like curved surface")
	# 这些"加阴影"常量已被废弃: 实例上读不到即证明 idle 不再加暗面/体积阴影
	assert_eq(level.get("COMBO_DARK_SIDE_STRENGTH"), null, "line-special idle must not add dark-side shadow on the gem body")
	assert_eq(level.get("COMBO_VOLUME_SHADOW_STRENGTH"), null, "line-special idle must not add volume shadow on the gem body")
	assert_eq(level.get("COMBO_SHADOW_OFFSET"), null, "line-special idle must not animate the gem shadow while wobbling")
	assert_false(level.has_method("_apply_combo_depth_pose"), "directional idle should not drive extra shadow/depth cues every frame")
	level.free()
	# 以下断言钉 directional_glow.gdshader 资产文件真实内容(GPU shader headless 无法渲染验证, 只能锁文本)
	# 钉源码理由: shader uniform/算法是已拍板的视觉契约, 任何改写都会改变 4合1 宝石的方向光照观感
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
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var shadow: Color = level.board_view.get("GEM_SHADOW_COLOR")
	assert_eq(shadow, Color(0.10, 0.08, 0.16, 0.28), "gem shape shadow uses a light tinted color instead of heavy black")
	# 真实常量值直接证明阴影是"软淡紫低alpha", 不是纯黑高alpha
	assert_true(shadow.r > 0.0 and shadow.g > 0.0 and shadow.b > 0.0, "shape shadow is tinted, not pure black")
	assert_true(shadow.a <= 0.30, "shape shadow stays low-alpha so it never reads as heavy black")
	assert_eq(level.get("GEM_SHADOW_ALPHA"), null, "shape shadow must not use a pure-black high-alpha constant")
	level.free()


func test_gem_saturation_experiment_uses_shader_not_asset_rewrites() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_eq(level.board_view.get("GEM_SATURATION"), 0.86, "gem saturation experiment uses the preferred 86% color intensity")
	assert_eq(level.board_view.get("GEM_SATURATION_SHADER"), "res://match3/gem_saturation.gdshader", "gem saturation experiment uses a reversible shader")
	# 直接调真函数: 棋盘宝石共享的 saturation 材质应是 ShaderMaterial, 用该 shader, 参数=GEM_SATURATION
	assert_true(level.board_view.has_method("_gem_saturation_material"), "Level exposes the shared saturation material factory")
	var mat = level.board_view.call("_gem_saturation_material")
	assert_true(mat is ShaderMaterial, "ordinary board gems use a shader material, not asset rewrites")
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat
		assert_eq(sm.shader.resource_path, level.board_view.get("GEM_SATURATION_SHADER"), "saturation material is driven by the reversible saturation shader")
		assert_eq(sm.get_shader_parameter("saturation"), level.board_view.get("GEM_SATURATION"), "saturation material inherits the 86% saturation factor")
	level.free()
	# 钉源码理由: 以下钉 gem_saturation.gdshader 资产真实内容; GPU shader headless 无法渲染自检,
	# 其降饱和算法(从 COLOR 出发、luminance gray、mix 不二次乘纹理)是已拍板的画面契约, 必须锁文本防回归
	var shader := FileAccess.get_file_as_string("res://match3/gem_saturation.gdshader")
	assert_true(shader.contains("uniform float saturation"), "gem saturation shader exposes a single saturation parameter")
	assert_true(shader.contains("uniform float saturation : hint_range(0.0, 1.5) = 0.86;"), "gem saturation shader preview default matches the 86% experiment")
	assert_true(shader.contains("vec3 gray"), "gem saturation shader computes luminance gray")
	assert_true(shader.contains("mix(gray, col.rgb, saturation)"), "gem saturation shader reduces saturation without darkening by simple RGB multiply")
	assert_true(shader.contains("vec4 col = COLOR"), "gem saturation shader starts from Godot's modulated sprite color")
	assert_false(shader.contains("texture(TEXTURE, UV)"), "gem saturation shader must not multiply the texture color twice")
	assert_false(shader.contains("col.rgb *= tint.rgb"), "gem saturation shader must not darken gems by multiplying modulate after a manual texture sample")
	# 钉源码理由: directional_glow.gdshader 必须继承同一 base_saturation, 否则 4合1 宝石会比棋盘其它宝石更鲜艳(画面契约)
	var dir_shader := FileAccess.get_file_as_string("res://match3/directional_glow.gdshader")
	assert_true(dir_shader.contains("uniform float base_saturation"), "directional glow shader can keep 4-match gems at the same base saturation")
	assert_true(dir_shader.contains("mix(base_gray, col.rgb, base_saturation)"), "directional glow desaturates before adding hue-safe highlights")


func test_pet_skill_charge_requirement_is_halved() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_eq(level.skills.get("SKILL_CHARGE_REQ"), 10.0, "pet skill progress should fill twice as fast by halving the shared charge requirement")
	level.free()


func test_combo_idle_reapply_same_fx_does_not_restart() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(level)
	assert_true(level.board_view.has_method("_apply_fx_overlay") and level.board_view.has_method("_fx_overlay_is_current"), "Level exposes fx overlay apply + reusable current-state check")
	var node := Sprite2D.new()
	node.texture = load("res://art/gems/base/gem_star.png")
	node.scale = Vector2(0.5, 0.5)
	level.add_child(node)
	# 行为断言: 首次施加 4合1 idle 建一个 combo_tween, 之后同 kind 再施加应保持同一 tween(幂等, 不重启)
	level.board_view.call("_apply_fx_overlay", node, ME.SP_LINE_H)
	assert_true(level.board_view.call("_fx_overlay_is_current", node, ME.SP_LINE_H), "same-kind 4-match idle is considered current while its tween is valid")
	var first_tween = node.get_meta("combo_tween") if node.has_meta("combo_tween") else null
	assert_true(first_tween is Tween, "4-match idle stores a combo_tween")
	level.board_view.call("_apply_fx_overlay", node, ME.SP_LINE_H)
	var second_tween = node.get_meta("combo_tween") if node.has_meta("combo_tween") else null
	assert_eq(second_tween, first_tween, "re-applying the same fx keeps the existing idle tween instead of replaying it")
	# 切到不同 kind 才会重建; SP_NONE 视为 current 仅当没有任何 idle tween
	level.board_view.call("_apply_fx_overlay", node, ME.SP_NONE)
	assert_true(level.board_view.call("_fx_overlay_is_current", node, ME.SP_NONE), "clearing fx leaves no running idle tween")
	assert_false(level.board_view.call("_fx_overlay_is_current", node, ME.SP_LINE_H), "after clearing, the stale 4-match kind is no longer current")
	node.queue_free()
	level.queue_free()


func test_board_layout_centers_playable_books_between_topbar_and_skills() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	for dims in [Vector2i(8, 8), Vector2i(8, 10), Vector2i(9, 11)]:
		var level := scene.instantiate()
		assert_true(level.has_method("_compute_layout"), "Level exposes board layout calculation")
		if not level.has_method("_compute_layout"):
			level.free()
			return
		level.board = Board.new(dims.x, dims.y, [0, 1, 2, 3, 4, 5], 0, 25, 1)
		level.board_view.board = level.board
		level.call("_compute_layout")
		var board_h: float = float(level.board.height) * level.cell_size
		var visual_center_y: float = level.board_origin.y + board_h * 0.5
		var topbar_bottom: float = -48.0 + float(level.hud.call("_topbar_height"))
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
	level.board_view.board = level.board
	level.call("_compute_layout")
	var topbar_bottom: float = -48.0 + float(level.hud.call("_topbar_height"))
	var skill_top: float = 1374.0 - 132.0 * 0.5
	var book_y: float = level.board_origin.y - 21.0
	var book_bottom: float = level.board_origin.y + float(level.board.height) * level.cell_size + 56.0
	var ribbons_bottom: float = book_bottom + 726.0 * 77.0 / 982.0
	assert_true(book_y >= topbar_bottom + 40.0, "tallest playable book leaves breathing room under the raised topbar")
	assert_true(ribbons_bottom <= skill_top - 40.0, "tallest playable book leaves breathing room above the skill portraits")
	level.free()


func test_bomb_combo_idle_uses_lub_dub_heartbeat_cadence() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 读真实心跳常量值, 并断言"lub-dub"的视觉决策关系(第一跳大于第二跳、有短间隔再长休止)
	var first_amp: float = level.board_view.get("COMBO_HEARTBEAT_FIRST_AMP")
	var second_amp: float = level.board_view.get("COMBO_HEARTBEAT_SECOND_AMP")
	var up: float = level.board_view.get("COMBO_HEARTBEAT_UP")
	var down: float = level.board_view.get("COMBO_HEARTBEAT_DOWN")
	var gap: float = level.board_view.get("COMBO_HEARTBEAT_GAP")
	var rest: float = level.board_view.get("COMBO_HEARTBEAT_REST")
	assert_eq(first_amp, 0.16, "bomb idle first heartbeat peak is the larger lub")
	assert_eq(second_amp, 0.09, "bomb idle second heartbeat peak is the smaller dub")
	assert_eq(up, 0.12, "heartbeat rises quickly instead of slowly swelling")
	assert_eq(down, 0.10, "heartbeat falls quickly after each beat")
	assert_eq(gap, 0.07, "two heartbeat beats have a short gap")
	assert_eq(rest, 0.58, "heartbeat loop has a longer rest after the second beat")
	assert_true(first_amp > second_amp, "lub (first beat) is louder than dub (second beat)")
	assert_true(rest > gap, "the rest after the lub-dub pair is longer than the in-pair gap")
	level.free()


func test_bomb_combo_idle_brightens_body_without_outline_glow() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(level)
	var node := Sprite2D.new()
	node.texture = load("res://art/gems/base/gem_star.png")
	node.scale = Vector2(0.5, 0.5)
	level.add_child(node)
	level.board_view.call("_apply_fx_overlay", node, ME.SP_BOMB)
	var glow := node.get_node_or_null("combo_glow")
	assert_eq(glow, null, "bomb combo idle should brighten the gem body without adding a white outline glow")
	node.queue_free()
	level.queue_free()


func test_level_consumed_move_paths_share_board_settlement() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_finish_consumed_move"), "Level exposes one consumed-move finish path")
	level.free()
	# 钉源码理由: 三条消费步数的路径(交换/彩球/融合)必须统一走 _finish_consumed_move(Board 结算),
	# 不能各自做局部 move-only 记账 —— 这正是本次重构要保护的"单一结算入口"契约, async 不便整跑故锁接线
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
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


func test_level_consumed_move_paths_record_time_rewind_history_before_mutation() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_remember_time_rewind_snapshot"), "Level exposes a shared time-rewind history hook")
	level.free()
	# 钉源码理由: 每条真实关卡移动必须在改板(swap/apply_clears)之前先记快照, 否则时间倒流会丢一步(回退正确性契约)
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	for name in ["func _try_swap", "func _resolve_colorbomb", "func _resolve_fusion"]:
		var start: int = src.find(name)
		assert_true(start >= 0, "%s exists" % name)
		if start < 0:
			continue
		var end: int = src.find("\nfunc ", start + 1)
		if end < 0:
			end = src.length()
		var body: String = src.substr(start, end - start)
		var history_idx: int = body.find("_remember_time_rewind_snapshot()")
		assert_true(history_idx >= 0, "%s records a rewind snapshot for real level-page moves" % name)
		var mutation_idx: int = body.find("ME._swap_cells")
		if mutation_idx < 0:
			mutation_idx = body.find("ME._apply_clears")
		assert_true(mutation_idx < 0 or history_idx < mutation_idx, "%s records the snapshot before mutating the board" % name)


func test_level_finish_consumed_move_does_not_full_rerender() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 增量快照动画路径迁至 board_view(契约 E); level 经接口委派。
	assert_true(level.board_view.has_method("animate_board_changes_from_snapshot"), "move finish has a snapshot-based animation path")
	level.free()
	# 钉源码理由: 消除收尾必须委派 Board 结算并用快照动画过渡, 决不能整屏重渲(_sync_visuals_to_board)或瞬移已变格 —— 这是"不每步全量重渲"的性能/演出契约, async 不便整跑故锁接线
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _finish_consumed_move")
	var end: int = src.find("\nfunc ", start + 1)
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("board._settle_consumed_move"), "finish path still delegates move settlement to Board")
	assert_false(body.contains("_sync_visuals_to_board()") or body.contains("_sync_changed_visuals_to_board()"), "move finish must not full-rerender or snap changed board visuals to their final cells")
	assert_true(body.contains("await board_view.animate_board_changes_from_snapshot"), "move finish animates post-settlement board changes instead of jumping")


func test_last_move_win_settlement_awaits_result_flow() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var check_start: int = src.find("func _check_settlement")
	assert_true(check_start >= 0, "_check_settlement exists")
	if check_start < 0:
		return
	var check_end: int = src.find("\nfunc ", check_start + 1)
	if check_end < 0:
		check_end = src.length()
	var check_body: String = src.substr(check_start, check_end - check_start)
	var win_idx: int = check_body.find("if board.is_won():")
	# P6: 奖励连锁演出迁至 endgame director; 胜利结算仍 await 它(+弹面板)再放行。
	var await_win_idx: int = check_body.find("await endgame.run_win_bonus()", win_idx)
	assert_true(await_win_idx > win_idx, "win settlement must await the result flow even when no bonus moves remain")

	var finish_start: int = src.find("func _finish_consumed_move")
	assert_true(finish_start >= 0, "_finish_consumed_move exists")
	if finish_start < 0:
		return
	var finish_end: int = src.find("\nfunc ", finish_start + 1)
	if finish_end < 0:
		finish_end = src.length()
	var finish_body: String = src.substr(finish_start, finish_end - finish_start)
	var hud_idx: int = finish_body.find("_refresh_hud()")
	var await_settle_idx: int = finish_body.find("await _check_settlement()", hud_idx)
	assert_true(await_settle_idx > hud_idx, "move finish must await settlement before releasing the final frame")


func test_opening_drop_starts_gems_above_the_board() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_opening_drop_start_position"), "Level exposes opening drop start calculation")
	assert_true(level.opening.has_method("_opening_drop_delay"), "Level exposes opening drop delay calculation")
	if not level.board_view.has_method("_opening_drop_start_position") or not level.opening.has_method("_opening_drop_delay"):
		level.free()
		return
	level.board_origin = Vector2(90, 420)
	level.board_view.board_origin = level.board_origin
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	var top_center := Vector2(125, 455)
	var low_center := Vector2(125, 455 + 5.0 * level.cell_size)
	var top_start: Vector2 = level.board_view.call("_opening_drop_start_position", top_center, 0)
	var low_start: Vector2 = level.board_view.call("_opening_drop_start_position", low_center, 5)
	assert_true(top_start.y < level.board_origin.y, "top-row gem begins above the board")
	assert_true(low_start.y < level.board_origin.y, "lower-row gem also begins above the board")
	assert_eq(top_start.y, low_start.y, "all opening gems enter from the same empty-board line")
	var top_delay: float = level.opening.call("_opening_drop_delay", 0, 10)
	var bottom_delay: float = level.opening.call("_opening_drop_delay", 9, 10)
	assert_true(bottom_delay < top_delay, "bottom row starts first so the board fills from bottom to top")
	assert_true(top_delay - bottom_delay >= 0.25, "opening drop is slow enough to read")
	level.free()


func test_all_real_playable_levels_share_opening_timing_caps() -> void:
	var level := _prepare_level_scene_with_real_levels()
	assert_true(level.opening.has_method("_opening_drop_window"), "Level exposes the total opening drop timing window")
	assert_true(level.opening.has_method("_opening_freeze_window"), "Level exposes the total opening stone timing window")
	assert_true(level.opening.has_method("_opening_freeze_delay"), "Level distributes opening stone casts inside a capped window")
	if not level.opening.has_method("_opening_drop_window") or not level.opening.has_method("_opening_freeze_window") or not level.opening.has_method("_opening_freeze_delay"):
		level.free()
		return
	var saw_level_ten := false
	for raw_idx in level._playable:
		level.board = LevelLibrary.to_board(level._levels[raw_idx])
		level.board_view.board = level.board
		level.call("_compute_layout")
		var display_level: int = level.call("_display_level_number", raw_idx)
		saw_level_ten = saw_level_ten or display_level == 10
		var label := "playable level %d raw %d %dx%d" % [display_level, raw_idx, level.board.width, level.board.height]
		var drop_window: float = level.opening.call("_opening_drop_window", level.board.height)
		assert_true(drop_window <= 0.861, "%s opening gems do not fall slower just because the board is tall (%.3fs)" % [label, drop_window])
		var wall_count := 0
		for row in level.board.grid:
			for v in row:
				if v == ME.WALL:
					wall_count += 1
		var freeze_window: float = level.opening.call("_opening_freeze_window", wall_count)
		assert_true(freeze_window <= 0.341, "%s opening wall casts are batched inside a global timing cap (%.3fs)" % [label, freeze_window])
		if wall_count > 1:
			var first_delay: float = level.opening.call("_opening_freeze_delay", 0, wall_count)
			var last_delay: float = level.opening.call("_opening_freeze_delay", wall_count - 1, wall_count)
			assert_true(last_delay > first_delay, "%s still staggers wall casts visually" % label)
			assert_true(last_delay <= 0.18, "%s wall-cast stagger does not scale with wall count" % label)
	assert_true(saw_level_ten, "opening cap regression includes the last generated first-ten level")
	level.free()


func test_opening_drop_skips_temporary_gems_for_ice_cells() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_opening_visual_species"), "Level exposes opening visual species calculation")
	if not level.board_view.has_method("_opening_visual_species"):
		level.free()
		return
	var coat := [
		[1, 0],
		[0, 0],
	]
	level.board = Board.new(2, 2, [0, 1], 0, 10, 1, [], [], [], coat)
	level.board_view.board = level.board
	assert_eq(level.board.grid[0][0], ME.EMPTY, "ice logic cell still has no hidden gem")
	var visual_sp: int = level.board_view.call("_opening_visual_species", 0, 0)
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
	level.board_view.board = level.board
	level.board_origin = Vector2(90, 420)
	level.board_view.board_origin = level.board_origin
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	level.board_view.rebuild(level.board, level.cell_size, level.board_origin, true)
	assert_eq(level.board_view._gem_nodes[0][0], null, "opening ice cell does not create a standalone temporary gem")
	var marker: Sprite2D = level.board_view._coat_nodes[0][0]
	assert_true(marker != null, "opening ice marker is created immediately")
	if marker != null:
		assert_true(marker.position.y < level.board_origin.y, "opening ice marker starts above the board and falls in")
	level.free()


func test_ice_marker_position_is_horizontally_centered_in_cell() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_coat_marker_position"), "Level exposes ice marker position calculation")
	if not level.board_view.has_method("_coat_marker_position"):
		level.free()
		return
	level.board_origin = Vector2(90, 420)
	level.board_view.board_origin = level.board_origin
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	var center: Vector2 = level.call("_cell_center", 0, 0)
	var marker_position: Vector2 = level.board_view.call("_coat_marker_position", 0, 0)
	assert_eq(marker_position.x, center.x, "ice marker should be horizontally centered in its cell")
	level.free()

func test_cascade_does_not_remove_destroyed_ice_before_refill() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _resolve_cascades")
	var end: int = src.find("func _special_fx_cells_for_clear_visuals", start)
	assert_true(start >= 0 and end > start, "_resolve_cascades can be inspected")
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	var early_refresh_idx: int = body.find("board_view.refresh_jelly_coat_visuals()")
	var play_step_idx: int = body.find("await board_view.play_step")
	assert_true(play_step_idx >= 0, "cascade still delegates visual clear/collapse to board_view.play_step")
	# 钉源码理由: account_clears 会先把被破掉的冰格 grid 置 EMPTY；若此时立刻刷新冰层，
	# 玩家会在 collapse/refill 前看到裸空洞。冰层视觉必须等 play_step 的清除+补位收口后再刷新。
	assert_true(early_refresh_idx < 0 or early_refresh_idx > play_step_idx, "destroyed ice markers are not removed before refill can put a gem into the exposed slot")


func test_opening_drop_uses_temporary_gems_for_wall_cells() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_opening_visual_species"), "Level exposes opening visual species calculation")
	if not level.board_view.has_method("_opening_visual_species"):
		level.free()
		return
	var wall_mask := [
		[true, false],
		[false, false],
	]
	level.board = Board.new(2, 2, [0, 1], 0, 10, 1, wall_mask)
	level.board_view.board = level.board
	assert_eq(level.board.grid[0][0], ME.WALL, "stone logic cell is still a wall")
	var visual_sp: int = level.board_view.call("_opening_visual_species", 0, 0)
	assert_true(level.board.species.has(visual_sp), "stone opening visual uses a temporary falling gem species")
	level.free()


func test_opening_obstacle_markers_replace_temporary_gems() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 冰已不再有独立 boss-cast 替换路径: 实例上没有该方法即证明
	assert_false(level.has_method("_show_opening_coat_marker"), "ice opening marker no longer has a separate boss-cast replacement path")
	level.free()
	# 石头标记渲染迁至 board_view.show_opening_wall_marker(契约 E)。
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var wall_start: int = src.find("func show_opening_wall_marker")
	var wall_end: int = src.find("func _make_gem", wall_start)
	assert_true(wall_start >= 0 and wall_end > wall_start, "wall opening marker function can be inspected")
	if wall_start < 0 or wall_end <= wall_start:
		return
	var wall_body: String = src.substr(wall_start, wall_end - wall_start)
	# 钉源码理由: 石头登场前必须先清掉占位的临时宝石(clear_node_at), 否则石头与宝石叠在同格
	assert_true(wall_body.contains("clear_node_at(pos)"), "stone cast removes the temporary gem before showing the stone")


func test_opening_stone_casts_from_boss_but_ice_does_not() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 冰不再由 boss 冰冻光束生成: 相关常量/方法在实例上不存在即证明
	assert_eq(level.get("OPENING_FREEZE_COLOR"), null, "initial ice is not generated by a boss freeze beam")
	assert_false(level.has_method("_show_opening_coat_marker"), "initial ice marker is not spawned after the opening drop")
	level.free()
	# 开局石头施法演出迁至 directors/opening.gd(P6)。
	var src := FileAccess.get_file_as_string("res://match3/directors/opening.gd")
	var freeze_start: int = src.find("func _play_opening_freeze")
	assert_true(freeze_start >= 0, "opening freeze phase exists")
	if freeze_start < 0:
		return
	var freeze_end: int = src.find("func _apply_opening_freeze_instant", freeze_start)
	if freeze_end < 0:
		freeze_end = src.length()
	var freeze_body: String = src.substr(freeze_start, freeze_end - freeze_start)
	var finish_idx: int = src.find("_finish_opening_drop(generation)", freeze_start)
	# 钉源码理由: 石头开局必须从 boss 位发光束(Fx.spawn_beam(BOSS_C))后再出石头标记, 这是已拍板的"boss 施法生成石头"演出顺序
	var beam_idx: int = freeze_body.find("Fx.spawn_beam(BOSS_C")
	var marker_idx: int = freeze_body.find("show_opening_wall_marker(p, true)")
	assert_true(beam_idx >= 0, "opening stone generation still casts beams from the boss position")
	assert_true(marker_idx > beam_idx, "stone marker appears after the boss beam")
	assert_true(finish_idx > freeze_start, "input unlock waits until opening obstacles are settled")
