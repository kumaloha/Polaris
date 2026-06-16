extends "res://tests/test_lib.gd"
## board_view 子控制器行为测试（契约 E, docs/11 §6）。
## 行为断言优先：经 level.board_view 公开接口验证节点所有权 / 增量同步 / 选中态 / 站立特效 / overlay 消费。
## 不做 contains 源码断言（视觉决策保护由 test_level_visuals / test_level_clear 承担）。

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")


func _prepare_level(width: int, height: int, board: Board = null) -> Node:
	# 入树让 @onready 层就位 + combo idle 的 node.create_tween() 可用; 手动绑层防 _ready 时序空引用。
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.background_layer = level.get_node("BackgroundLayer")
	level.board_layer = level.get_node("BoardLayer")
	level.gem_layer = level.get_node("GemLayer")
	level.character_layer = level.get_node("CharacterLayer")
	level.ui_layer = level.get_node("UILayer")
	level.skill_bar = level.get_node("SkillBar")
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(level)
	if board == null:
		board = Board.new(width, height, [0, 1, 2, 3, 4], 999999, 30, 7)
	level.board = board
	level.call("_compute_layout")   # 同步 board_view 几何副本
	return level


func test_board_view_is_child_controller_of_level() -> void:
	var level := _prepare_level(4, 4)
	assert_true(level.board_view != null, "level owns a board_view sub-controller")
	assert_true(level.board_view.get_parent() == level, "board_view is a child node of level (lifecycle aligned to scene tree)")
	level.free()


func test_rebuild_populates_node_grid_matching_board() -> void:
	var level := _prepare_level(5, 6)
	level.board_view.rebuild(level.board)
	var bv = level.board_view
	assert_eq(bv._gem_nodes.size(), level.board.height, "rebuild creates one visual row per board row")
	var present := 0
	for r in range(level.board.height):
		assert_eq(bv._gem_nodes[r].size(), level.board.width, "each visual row matches board width")
		for c in range(level.board.width):
			var sp: int = level.board.grid[r][c]
			var node = bv.node_at(Vector2i(c, r))
			if sp >= 0:
				assert_true(node != null, "node exists where the board has a gem")
				if node != null:
					assert_eq(int(node.get_meta("species")), sp, "node species matches board grid")
					present += 1
			else:
				assert_true(node == null, "no node where the board has no gem")
	assert_true(present > 0, "a normal board produces visible gem nodes")
	level.free()


func test_rebuild_hides_gem_under_ingredient_overlay() -> void:
	var b := Board.new(4, 4, [0, 1, 2, 3], 999999, 30, 7)
	b.ing = [
		[0, 0, 0, 0],
		[0, 1, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	b.grid[1][1] = 0
	var level := _prepare_level(4, 4, b)
	level.board_view.rebuild(level.board)
	var overlay = level.board_view._overlay_nodes.get(["ing", Vector2i(1, 1)])
	assert_true(level.board_view.node_at(Vector2i(1, 1)) == null, "ingredient/lost-cub cells do not also render a normal gem")
	assert_true(overlay != null, "ingredient overlay remains visible as the actual objective actor")
	if overlay != null:
		assert_eq(overlay.get_parent(), level.gem_layer, "ingredient overlay renders in GemLayer instead of the plain BoardView node, so it is not hidden behind CanvasLayers")
		var sprite := (overlay as Node).get_node_or_null("Sprite2D") as Sprite2D
		assert_true(sprite != null and sprite.texture != null, "ingredient overlay has a non-blank generated texture")
	level.free()


func test_collapse_refill_collects_lost_cub_already_on_bottom_exit() -> void:
	var b := Board.new(3, 3, [0, 1, 2], 0, 10, 7, [], [{"type": "COLLECT_INGREDIENT", "species": -1, "target": 1}])
	b.exit_cols = [1]
	b.grid = [
		[0, 1, 2],
		[1, 2, 0],
		[2, ME.EMPTY, 0],
	]
	b.fx = b._blank_fx()
	b.ing = b._blank_fx()
	b.ing[2][1] = 1
	var level := _prepare_level(3, 3, b)
	level.board_view.rebuild(level.board)
	level.board_view.collapse_and_refill()
	assert_eq(level.board.ingredient_collected, 1, "front-end collapse/refill path collects a lost cub that reaches the bottom exit")
	assert_eq(level.board.ing[2][1], 0, "collected lost cub is removed from the ingredient layer")
	assert_true(level.board.is_won(), "COLLECT_INGREDIENT objective wins as soon as the cub reaches the exit")
	level.free()


func test_node_at_out_of_bounds_is_null_not_crash() -> void:
	var level := _prepare_level(3, 3)
	level.board_view.rebuild(level.board)
	assert_true(level.board_view.node_at(Vector2i(-1, 0)) == null, "negative cell returns null")
	assert_true(level.board_view.node_at(Vector2i(0, 99)) == null, "out-of-range row returns null")
	assert_true(level.board_view.node_at(Vector2i(99, 0)) == null, "out-of-range col returns null")
	level.free()


func test_clear_node_at_frees_and_nulls_cell() -> void:
	var level := _prepare_level(4, 4)
	level.board_view.rebuild(level.board)
	# 找一个有节点的格
	var target := Vector2i(-1, -1)
	for r in range(level.board.height):
		for c in range(level.board.width):
			if level.board_view.node_at(Vector2i(c, r)) != null:
				target = Vector2i(c, r)
				break
		if target.x >= 0:
			break
	assert_true(target.x >= 0, "found a populated cell to clear")
	if target.x < 0:
		level.free()
		return
	level.board_view.clear_node_at(target)
	assert_true(level.board_view.node_at(target) == null, "clear_node_at nulls the cell so callers see an empty slot")
	level.free()


func test_swap_nodes_exchanges_visual_references() -> void:
	var level := _prepare_level(4, 4)
	level.board_view.rebuild(level.board)
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var na = level.board_view.node_at(a)
	var nb = level.board_view.node_at(b)
	if na == null or nb == null:
		level.free()
		return
	level.board_view.swap_nodes(a, b)
	assert_eq(level.board_view.node_at(a), nb, "swap_nodes moves b's node reference to a")
	assert_eq(level.board_view.node_at(b), na, "swap_nodes moves a's node reference to b")
	level.free()


func test_set_selected_then_clear_restores_visual() -> void:
	var level := _prepare_level(4, 4)
	level.board_view.rebuild(level.board)
	var cell := Vector2i(0, 0)
	var node = level.board_view.node_at(cell)
	if node == null:
		level.free()
		return
	var base_scale: Vector2 = node.scale
	var base_z: int = node.z_index
	level.board_view.set_selected(cell)
	assert_true(node.scale.length() > base_scale.length(), "selection enlarges the gem")
	assert_true(node.z_index > base_z, "selection raises the gem above its neighbors")
	level.board_view.clear_selected()
	assert_true(node.scale.is_equal_approx(base_scale), "clearing selection restores the original scale")
	assert_eq(node.z_index, 0, "clearing selection restores the base z-index")
	level.free()


func test_apply_fx_overlay_marks_special_and_is_idempotent() -> void:
	var level := _prepare_level(4, 4)
	level.board_view.rebuild(level.board)
	var cell := Vector2i(0, 0)
	var node = level.board_view.node_at(cell)
	if node == null:
		level.free()
		return
	level.board_view.apply_fx_overlay(node, ME.SP_LINE_H)
	assert_eq(int(node.get_meta("fx", ME.SP_NONE)), ME.SP_LINE_H, "applying a line special records the fx kind on the node")
	assert_true(node.has_meta("combo_tween"), "line special starts a standing idle tween")
	var first = node.get_meta("combo_tween")
	level.board_view.apply_fx_overlay(node, ME.SP_LINE_H)
	assert_eq(node.get_meta("combo_tween"), first, "re-applying the same fx keeps the existing idle tween (idempotent)")
	level.board_view.apply_fx_overlay(node, ME.SP_NONE)
	assert_eq(int(node.get_meta("fx", ME.SP_NONE)), ME.SP_NONE, "clearing fx resets the node back to a plain gem")
	level.free()


func test_rebuild_builds_jelly_overlays_for_jelly_layer() -> void:
	# 契约B §3.3: board_view 建格时经 OverlayRegistry 维护 jelly overlay。
	var board := Board.new(3, 3, [0, 1, 2], 999999, 30, 7)
	board.jelly = board._blank_fx()
	board.jelly[0][0] = 1
	var level := _prepare_level(3, 3, board)
	level.board_view.rebuild(board)
	var has_jelly_overlay := false
	for key in level.board_view._overlay_nodes:
		if key is Array and key.size() == 2 and String(key[0]) == "jelly":
			has_jelly_overlay = true
			break
	assert_true(has_jelly_overlay, "board_view instantiates a jelly overlay where the jelly layer is set (overlay registry consumption)")
	level.free()


func test_rebuild_after_layer_cleared_removes_overlay() -> void:
	var board := Board.new(3, 3, [0, 1, 2], 999999, 30, 7)
	board.jelly = board._blank_fx()
	board.jelly[0][0] = 2
	var level := _prepare_level(3, 3, board)
	level.board_view.rebuild(board)
	# 清掉该格 jelly 层后重建 → overlay 应被回收
	board.jelly[0][0] = 0
	level.board_view.rebuild(board)
	var still_has := false
	for key in level.board_view._overlay_nodes:
		if key is Array and key.size() == 2 and String(key[0]) == "jelly" and key[1] == Vector2i(0, 0):
			still_has = true
			break
	assert_false(still_has, "clearing the jelly layer and rebuilding removes the jelly overlay")
	level.free()


func test_rebuild_uses_native_coat_marker_without_generic_overlay_duplicate() -> void:
	var coat := [
		[3, 0, 0],
		[0, 0, 0],
		[0, 0, 0],
	]
	var board := Board.new(3, 3, [0, 1, 2], 999999, 30, 7, [], [], [], coat)
	var level := _prepare_level(3, 3, board)
	level.board_view.rebuild(board)
	var cell := Vector2i(0, 0)
	assert_false(level.board_view._overlay_nodes.has(["coat", cell]),
		"coat/晶壳由 BoardView 原生 marker 渲染，不能再创建通用 CoatOverlay 叠层")
	var marker: Sprite2D = level.board_view._coat_nodes[0][0]
	assert_true(marker != null, "native coat marker remains visible")
	if marker != null and marker.texture != null:
		var drawn_size: Vector2 = marker.texture.get_size() * marker.scale
		assert_true(maxf(drawn_size.x, drawn_size.y) <= level.board_view.cell_size,
			"native coat marker must stay within one board cell, actual=%s cell=%.2f" % [str(drawn_size), level.board_view.cell_size])
	level.free()
