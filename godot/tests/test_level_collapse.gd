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
	level._levels = LevelLibrary.load_file("res://levels.json")
	level._playable = []
	for i in range(level._levels.size()):
		var objs = level._levels[i].get("objectives", [])
		if objs is Array and not objs.is_empty():
			level._playable.append(i)
	return level



func test_level_collapse_refill_uses_core_layers_and_feed() -> void:
	# _collapse_and_refill 是 async 改板, headless 不便整跑; 锁住"委派 core 引力/补充、尊重 feed、不整屏重渲、不手摇随机"的正确性契约
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var start: int = src.find("func _collapse_and_refill")
	assert_true(start >= 0, "_collapse_and_refill exists")
	if start < 0:
		return
	var end: int = src.find("func collapse_and_refill", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	# 钉源码理由: 视觉塌落/补充必须委派 core 的 apply_gravity/refill(含 board.feed 滚动喂入), 用 _sync_collapse_segment 增量移动节点; 决不能 _sync_visuals_to_board 整屏重渲, 也决不能 board.rng.randi()%species 手摇随机(会与 core 棋盘不一致)
	assert_true(body.contains("ME.apply_gravity(board.grid, board.fx, false, board._layers())") and body.contains("ME.refill(board.grid, board.species, board.rng, board.fx") and body.contains("board.feed"), "visual collapse uses core gravity/refill and respects scrolling feed so all layers stay aligned")
	assert_true(body.contains("_sync_collapse_segment"), "visual collapse moves existing gem nodes instead of rebuilding the whole board")
	assert_false(body.contains("_sync_visuals_to_board()") or body.contains("board.rng.randi() % board.species.size()"), "visual collapse must not full-rerender the board nor hand-roll random refill")


func test_level_collapse_refill_repairs_missing_visual_gems() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_repair_missing_gem_nodes_from_board"), "Level exposes a targeted visual hole repair helper")
	level.free()
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var start: int = src.find("func _collapse_and_refill")
	assert_true(start >= 0, "_collapse_and_refill exists")
	if start < 0:
		return
	var end: int = src.find("func collapse_and_refill", start)
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
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_sync_wall_slide_visuals"), "Level has a wall-aware cross-column visual collapse helper")
	assert_true(level.board_view.has_method("_grid_has_fall_obstacle"), "Level detects all gravity-blocking cells, not only stone walls")
	# 直接调真函数: 有墙的棋盘判定为有落体障碍, 普通棋盘则无 —— 证明障碍检测真实生效(不只是源码里出现函数名)
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board.fx = _none_fx(3, 3)
	var plain := [[0, 1, 2], [1, 2, 0], [2, 0, 1]]
	assert_false(level.board_view.call("_grid_has_fall_obstacle", plain), "a plain board has no fall obstacle")
	var walled := [[0, ME.WALL, 2], [1, 2, 0], [2, 0, 1]]
	assert_true(level.board_view.call("_grid_has_fall_obstacle", walled), "a board with a wall is detected as having a fall obstacle")
	level.free()
	# _collapse_and_refill 据此分流到 cross-column slide 同步, 该接线在 async 内, 锁住关键调用
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var start: int = src.find("func _collapse_and_refill")
	var end: int = src.find("func collapse_and_refill", start)
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	# 钉源码理由: 障碍棋盘必须走 _sync_wall_slide_visuals 跨列滑落, 而非只按列分段同步(否则障碍下方斜向补位错乱)
	assert_true(body.contains("_sync_wall_slide_visuals(before_grid, old_nodes"), "obstacle boards use cross-column slide visuals instead of per-column segment-only syncing")


func test_wall_slide_tracking_maps_include_coat_blockers() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_build_wall_slide_tracking_maps"), "Level can replay visual gravity routes")
	if not level.board_view.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
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
	var maps: Dictionary = level.board_view.call("_build_wall_slide_tracking_maps", level.board.grid.duplicate(true))
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
	assert_true(level.board_view.has_method("_build_wall_slide_tracking_maps"), "Level can replay visual gravity routes")
	if not level.board_view.has_method("_build_wall_slide_tracking_maps"):
		level.free()
		return
	level.board = Board.new(3, 4, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board.grid = [
		[ME.EMPTY, ME.WALL, ME.EMPTY],
		[10, 12, 11],
		[5, ME.EMPTY, 6],
		[7, ME.EMPTY, 9],
	]
	level.board.fx = _none_fx(3, 4)
	var maps: Dictionary = level.board_view.call("_build_wall_slide_tracking_maps", level.board.grid.duplicate(true))
	var source_map: Array = maps["source"]
	var path_map: Array = maps["path"]
	assert_eq(source_map[3][1], Vector2i(1, 1), "visual gravity keeps the lower pocket on the same-column source while vertical fill is possible")
	assert_false(source_map[3][1] == Vector2i(2, 2), "visual gravity must not steal the right-above candidate before the vertical chain resolves")
	assert_eq(path_map[3][1], [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)], "visual path shows a continuous vertical fall, not a diagonal jump")
	level.free()


func test_level_wall_slide_visuals_tween_cell_steps() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	const LM := preload("res://match3/level_motion.gd")
	assert_true(LM.WALL_SLIDE_STEP_TIME != null, "wall slide animation has a per-cell step duration")
	assert_true(level.board_view.has_method("_wall_slide_path_points"), "Level exposes a path builder for wall slide visuals")
	assert_true(level.board_view.has_method("_wall_slide_position_at"), "Level samples wall slide paths continuously")
	assert_true(level.board_view.has_method("_tween_wall_slide_node"), "Level tweens wall slide nodes through path steps")
	# 直接调真函数: 沿路径采样, progress=0 落在起点附近、progress=1 落在终点附近, 证明是连续采样的滑落而非一跳到位
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.cell_size = 100.0
	level.board_view.cell_size = level.cell_size
	var sp := Vector2(0.0, 0.0)
	var tp := Vector2(200.0, 300.0)
	var pts: Array = level.board_view.call("_wall_slide_path_points", sp, tp)
	var at0: Vector2 = level.board_view.call("_wall_slide_position_at", sp, pts, 0.0)
	var at1: Vector2 = level.board_view.call("_wall_slide_position_at", sp, pts, 1.0)
	assert_true(at0.distance_to(sp) < 1.0, "wall slide sampling starts at the source position")
	assert_true(at1.distance_to(tp) < 1.0, "wall slide sampling ends at the target position")
	level.free()
	# 连续 tween(tween_method 一条曲线扫完整路径)的实现细节用源码锁住, 防退回逐格 tween_property 跳变(动作手感契约)
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var tween_start: int = src.find("func _tween_wall_slide_node")
	var tween_end: int = src.find("func _take_wall_slide_source", tween_start)
	if tween_start < 0 or tween_end <= tween_start:
		return
	var tween_body: String = src.substr(tween_start, tween_end - tween_start)
	# 钉源码理由: 墙滑必须用一条连续 tween_method 扫完整步进路径, 决不能逐格 tween_property(node,"position",...)重启(否则每格顿挫, 失去顺滑下滑手感)
	assert_true(tween_body.contains("tween_method"), "wall slide uses one continuous tween across the stepped path instead of restarting at every cell")
	assert_false(tween_body.contains("tween_property(node, \"position\""), "wall slide helper should not chain per-cell position tweens")


func test_wall_slide_spawned_piece_enters_vertically_before_sliding() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_wall_slide_path_points"), "Level exposes wall slide path calculation")
	if not level.board_view.has_method("_wall_slide_path_points"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board_origin = Vector2(90, 420)
	level.board_view.board_origin = level.board_origin
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	var start := Vector2(90 + 2.5 * level.cell_size, level.board_origin.y - 2.0 * level.cell_size)
	var target := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y + 2.5 * level.cell_size)
	var points: Array = level.board_view.call("_wall_slide_path_points", start, target)
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
	assert_true(level.board_view.has_method("_wall_slide_cell_path_points"), "Level can convert recorded gravity cells into visual path points")
	if not level.board_view.has_method("_wall_slide_cell_path_points"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board_origin = Vector2(90, 420)
	level.board_view.board_origin = level.board_origin
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	var start := Vector2(90 + 2.5 * level.cell_size, level.board_origin.y + 0.5 * level.cell_size)
	var target := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y + 2.5 * level.cell_size)
	var route := [Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 2)]
	var points: Array = level.board_view.call("_wall_slide_cell_path_points", start, route, target)
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
	assert_true(level.board_view.has_method("_wall_slide_duration_for_points"), "Level exposes wall slide duration calculation")
	if not level.board_view.has_method("_wall_slide_duration_for_points"):
		level.free()
		return
	var points := []
	for idx in range(10):
		points.append(Vector2(0, float(idx) * 70.0))
	var duration: float = level.board_view.call("_wall_slide_duration_for_points", points)
	assert_true(duration >= 0.39, "ten cell-steps still read as movement, not a teleport")
	assert_true(duration <= 0.43, "ten cell-steps use the same brisk cap as ordinary falls so blocker levels do not feel slower")
	level.free()


func test_player_level_eleven_blocker_falls_use_global_fall_cap() -> void:
	var level := _prepare_level_scene_with_real_levels()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "11"], level._levels.size())
	assert_eq(raw_idx, 15, "player-facing level 11 maps to the blocker-heavy exported level that exposed the slow branch")
	level.board = LevelLibrary.to_board(level._levels[raw_idx])
	level.board_view.board = level.board
	level.call("_compute_layout")
	var points := []
	for idx in range(10):
		points.append(Vector2(0, float(idx) * level.cell_size))
	var blocker_branch_duration: float = level.board_view.call("_wall_slide_duration_for_points", points)
	var ordinary_duration: float = level.board_view.call("_fall_duration_for_positions", Vector2.ZERO, Vector2(0.0, level.cell_size * 10.0))
	assert_true(blocker_branch_duration <= ordinary_duration + 0.01, "level 11's obstacle visual branch must not fall slower than ordinary levels")
	level.free()


func test_all_real_playable_levels_share_fall_timing_caps() -> void:
	var level := _prepare_level_scene_with_real_levels()
	for raw_idx in level._playable:
		level.board = LevelLibrary.to_board(level._levels[raw_idx])
		level.board_view.board = level.board
		level.call("_compute_layout")
		var label := "playable level %d raw %d %dx%d" % [level.call("_display_level_number", raw_idx), raw_idx, level.board.width, level.board.height]
		var long_cells: int = maxi(10, level.board.width + level.board.height)
		var ordinary_duration: float = level.board_view.call("_fall_duration_for_positions", Vector2.ZERO, Vector2(0.0, level.cell_size * float(long_cells)))
		assert_true(ordinary_duration <= 0.43, "%s ordinary long fall stays globally capped" % label)
		var wall_points := []
		for idx in range(long_cells):
			wall_points.append(Vector2(0.0, level.cell_size * float(idx)))
		var wall_duration: float = level.board_view.call("_wall_slide_duration_for_points", wall_points)
		assert_true(wall_duration <= ordinary_duration + 0.01, "%s obstacle/wall branch does not pace slower than ordinary falling" % label)
		var refill_start: Vector2 = level.board_view.call("_ordinary_refill_start_position", level.board.height - 1, 0, 0, level.board.height)
		var refill_target: Vector2 = level.board_view.call("_cell_center", level.board.height - 1, 0)
		var refill_duration: float = level.board_view.call("_ordinary_refill_duration_for_positions", refill_start, refill_target)
		assert_true(refill_duration <= 0.39, "%s spawned refill stays under its global cap" % label)
	level.free()


func test_level_motion_module_matches_level_fall_helpers() -> void:
	var level := _prepare_level_scene_with_real_levels()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "11"], level._levels.size())
	level.board = LevelLibrary.to_board(level._levels[raw_idx])
	level.board_view.board = level.board
	level.call("_compute_layout")
	var target: Vector2 = level.board_view.call("_cell_center", level.board.height - 1, 0)
	var refill_start: Vector2 = LevelMotion.ordinary_refill_start_position(target, level.cell_size, level.board.height)
	assert_eq(refill_start, level.board_view.call("_ordinary_refill_start_position", level.board.height - 1, 0, 0, level.board.height), "motion module matches ordinary refill start")
	assert_eq(LevelMotion.fall_duration_for_positions(Vector2.ZERO, Vector2(0.0, level.cell_size * 10.0), level.cell_size), level.board_view.call("_fall_duration_for_positions", Vector2.ZERO, Vector2(0.0, level.cell_size * 10.0)), "motion module matches ordinary fall duration")
	var start := Vector2(level.board_origin.x + level.cell_size * 2.5, level.board_origin.y - level.cell_size * 2.0)
	var slide_target := Vector2(level.board_origin.x + level.cell_size * 1.5, level.board_origin.y + level.cell_size * 3.5)
	assert_eq(LevelMotion.wall_slide_path_points(start, slide_target, level.board_origin, level.cell_size, level.board.width, level.board.height), level.board_view.call("_wall_slide_path_points", start, slide_target), "motion module matches wall-slide path points")
	var maps: Dictionary = LevelMotion.build_wall_slide_tracking_maps(level.board.grid.duplicate(true), level.board.coat, level.board.choco, level.board.cannon, level.board.is_scrolling)
	assert_eq(maps, level.board_view.call("_build_wall_slide_tracking_maps", level.board.grid.duplicate(true)), "motion module matches wall-slide tracking maps")
	level.free()


func test_wall_slide_replacement_node_starts_at_recorded_source() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_wall_slide_visual_start_position"), "Level can place replacement visuals at the recorded source")
	if not level.board_view.has_method("_wall_slide_visual_start_position"):
		level.free()
		return
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board_origin = Vector2(90, 420)
	level.board_view.board_origin = level.board_origin
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
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
	var start: Vector2 = level.board_view.call("_wall_slide_visual_start_position", source_map, path_map, 2, 1)
	assert_eq(start, Vector2(90 + 2.5 * level.cell_size, level.board_origin.y + 0.5 * level.cell_size), "replacement node starts where the logical source was, not above the target column")
	level.free()


func test_ordinary_long_falls_keep_per_cell_pacing() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_fall_duration_for_positions"), "Level exposes ordinary fall duration calculation")
	if not level.board_view.has_method("_fall_duration_for_positions"):
		level.free()
		return
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	var duration: float = level.board_view.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 700))
	assert_true(duration >= 0.39, "ordinary ten-cell fall still reads as movement, not a teleport")
	assert_true(duration <= 0.44, "ordinary ten-cell fall is capped so tall or blocker-heavy levels do not feel slower")
	level.free()


func test_ordinary_refill_nodes_start_above_board() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_ordinary_refill_start_position"), "Level exposes ordinary refill start calculation")
	if not level.board_view.has_method("_ordinary_refill_start_position"):
		level.free()
		return
	level.board = Board.new(5, 8, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board_origin = Vector2(90, 420)
	level.board_view.board_origin = level.board_origin
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	var spawn_count := 8
	var deep_target_start: Vector2 = level.board_view.call("_ordinary_refill_start_position", 6, 2, 1, spawn_count)
	var next_spawn_start: Vector2 = level.board_view.call("_ordinary_refill_start_position", 5, 2, 2, spawn_count)
	var top_target_start: Vector2 = level.board_view.call("_ordinary_refill_start_position", 0, 2, 7, spawn_count)
	var deep_target: Vector2 = level.board_view.call("_cell_center", 6, 2)
	var top_target: Vector2 = level.board_view.call("_cell_center", 0, 2)
	assert_true(level.board_view.has_method("_ordinary_refill_duration_for_positions"), "Level exposes ordinary refill duration calculation")
	assert_true(deep_target_start.y < level.board_origin.y, "deep ordinary refill must enter from above the board, not appear inside a lower hole")
	assert_true(next_spawn_start.y < deep_target_start.y, "later spawned refill nodes stay stacked above earlier ones")
	assert_eq(deep_target_start.x, level.board_view.call("_cell_center", 0, 2).x, "ordinary refill starts in the target column")
	assert_true(absf((deep_target.y - deep_target_start.y) - (top_target.y - top_target_start.y)) < 0.01, "ordinary refill stack keeps equal travel distance so it falls as a column, not top-to-bottom paint")
	if level.board_view.has_method("_ordinary_refill_duration_for_positions"):
		var refill_duration: float = level.board_view.call("_ordinary_refill_duration_for_positions", deep_target_start, deep_target)
		assert_true(refill_duration <= 0.64, "full-column refill stays bounded even though all nodes travel the same visual distance")
	# 上面已用行为断言证明起点几何/时长上限正确; 这里只锁住增量塌落确实调用了起点助手这条接线(降级为关键调用名)
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	# 钉源码理由: 普通塌落必须用 _ordinary_refill_start_position 把补位节点放到棋盘上方再落下, 否则新宝石会"凭空出现在洞里"
	assert_true(src.contains("_ordinary_refill_start_position(row, col, spawn_i, first_old_slot)"), "ordinary collapse uses the above-board refill stack start position")
	level.free()


func test_fall_durations_scale_with_each_cell_step() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	var one_cell: float = level.board_view.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 70))
	var two_cells: float = level.board_view.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 140))
	var ten_cells: float = level.board_view.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 700))
	assert_true(one_cell >= 0.16, "one-cell fall should not feel instant")
	assert_true(one_cell <= 0.17, "one-cell fall should be brisk")
	assert_true(two_cells > one_cell, "a two-cell fall still reads as a longer fall")
	assert_true(two_cells < one_cell * 1.6, "fall timing accelerates instead of adding a full duration per cell")
	assert_true(ten_cells >= 0.39, "long falls should remain readable")
	assert_true(ten_cells <= 0.44, "long falls must not feel sluggish during auto cascades")
	var very_long: float = level.board_view.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 1400))
	assert_true(very_long <= 0.43, "very long falls share the same brisk cap instead of making tall levels feel different")
	var wall_one: float = level.board_view.call("_wall_slide_duration_for_points", [Vector2(0, 70)])
	var wall_three: float = level.board_view.call("_wall_slide_duration_for_points", [Vector2(0, 70), Vector2(0, 140), Vector2(70, 210)])
	assert_true(wall_three > wall_one, "multi-step wall slide still takes longer than one step")
	assert_true(wall_three < wall_one * 2.5, "multi-step wall slide also accelerates")
	level.free()


func test_refill_duration_cap_stays_near_long_fall_speed() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	var long_fall: float = level.board_view.call("_fall_duration_for_positions", Vector2(0, 0), Vector2(0, 700))
	var long_refill: float = level.board_view.call("_ordinary_refill_duration_for_positions", Vector2(0, -735), Vector2(0, 0))
	assert_true(long_refill >= long_fall - 0.07, "long refill should stay visually connected to an equally long existing-gem fall")
	assert_true(long_refill <= long_fall - 0.02, "long refill should finish a little sooner so automatic cascades do not feel late")
	level.free()


func test_level_fall_animation_timing_is_slightly_slower() -> void:
	# 直接读 level_motion 真实常量值, 并锁住墙滑与普通下落共享同一加速/上限的关系契约
	const LM := preload("res://match3/level_motion.gd")
	assert_eq(LM.FALL_TIME, 0.16, "ordinary one-cell falling is readable without dragging")
	assert_eq(LM.FALL_EXTRA_CELL_TIME, 0.030, "longer falls add only a small accelerated increment per extra cell")
	assert_eq(LM.FALL_MAX_TIME, 0.42, "long ordinary falls have a global cap so levels do not feel differently paced")
	assert_eq(LM.ORDINARY_REFILL_MAX_TIME, 0.38, "spawned refill stays brisk without collapsing into a paint effect")
	assert_eq(LM.WALL_SLIDE_STEP_TIME, LM.FALL_EXTRA_CELL_TIME, "wall slide uses the same per-step acceleration as ordinary falls")
	assert_eq(LM.WALL_SLIDE_MAX_TIME, LM.FALL_MAX_TIME, "wall slide wait cap matches ordinary falls so blocker lanes do not feel slower")


func test_level_wall_slide_visuals_only_cross_columns_under_fall_obstacles() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_wall_slide_target_has_fall_obstacle_above"), "Level can tell whether a target is under a gravity-blocking obstacle")
	level.free()
	# 跨列取源的"非墙目标拒绝邻列源 + 障碍上方才允许斜向"逻辑在 async sync 内, 锁住关键调用接线
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	if sync_start < 0 or sync_end <= sync_start:
		return
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	# 钉源码理由: 只有真正落体障碍下方的格(_wall_slide_target_has_fall_obstacle_above)才允许斜向取源, 否则普通格会错误地从邻列借宝石
	assert_true(sync_body.contains("_wall_slide_target_has_fall_obstacle_above(before_grid, row, col)"), "only cells below actual fall blockers may use diagonal visual sourcing")


func test_level_wall_slide_source_prefers_right_above_before_left_above() -> void:
	# 直接调真静态函数: 优先级数值越小越优先(消费方取最小)。右上源(target_col+1)应比左上源(target_col-1)更优先(数更小); 同列源最优先
	const LM := preload("res://match3/level_motion.gd")
	var right_above: int = LM.wall_slide_source_priority(1, 2, 2, 1, true)   # col=target_col+1
	var left_above: int = LM.wall_slide_source_priority(1, 0, 2, 1, true)    # col=target_col-1
	var same_col: int = LM.wall_slide_source_priority(1, 1, 2, 1, true)      # col==target_col
	assert_true(right_above < left_above, "right-above source outranks left-above source (smaller priority number wins)")
	assert_true(right_above > 0 and left_above > 0, "both adjacent-above sources are valid candidates")
	assert_true(same_col < right_above, "same-column source is the most preferred, ahead of any cross-column band")
	var below: int = LM.wall_slide_source_priority(3, 1, 2, 1, true)         # row>target_row
	assert_eq(below, -1, "a source below the target is never used")
	# sync 用该优先级从重放源图取旧节点的接线在 async 内, 锁住关键调用
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	if sync_start < 0 or sync_end <= sync_start:
		return
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	# 钉源码理由: 墙滑视觉必须先重放引力建源/路径图(_build_wall_slide_tracking_maps)再据此取旧节点, 否则跨列宝石身份错配
	assert_true(sync_body.contains("_build_wall_slide_tracking_maps(before_grid)"), "wall slide visuals build source and path maps by replaying gravity")


func test_level_wall_refill_start_uses_spawn_source_map() -> void:
	# 起点据 source_map 计算的几何已由 test_wall_refill_spawn_stack_falls_from_top_together 行为覆盖;
	# 这里只锁住"sync 把重放的 source/path 图传进起点计算, 而非仅凭 allow_cross_column 猜列"这条关键接线(防回归到旧的猜列写法)
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	assert_true(sync_start >= 0 and sync_end > sync_start, "_sync_wall_slide_visuals can be inspected")
	if sync_start < 0 or sync_end <= sync_start:
		return
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	# 钉源码理由: 墙滑补位起点必须传入重放的 source_map/path_map(_wall_slide_visual_start_position), 决不能只凭 allow_cross_column 猜起始列(会把新宝石的入场列算错)
	assert_true(sync_body.contains("_wall_slide_visual_start_position(source_map, path_map, row, col)"), "wall-slide visual refill passes the replayed source and path maps into start-position calculation")
	assert_false(sync_body.contains("_wall_refill_start_position(row, col, allow_cross_column)"), "wall-slide visual refill must not guess the start column from allow_cross_column alone")


func test_wall_refill_spawn_stack_falls_from_top_together() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_wall_refill_start_position"), "Level exposes wall refill start calculation")
	if not level.board_view.has_method("_wall_refill_start_position"):
		level.free()
		return
	level.board = Board.new(3, 7, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board_origin = Vector2(90, 420)
	level.board_view.board_origin = level.board_origin
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
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
	var top_start: Vector2 = level.board_view.call("_wall_refill_start_position", 0, 1, source_map)
	var deep_start: Vector2 = level.board_view.call("_wall_refill_start_position", 6, 1, source_map)
	var top_target: Vector2 = level.board_view.call("_cell_center", 0, 1)
	var deep_target: Vector2 = level.board_view.call("_cell_center", 6, 1)
	assert_true(top_start.y < level.board_origin.y, "top spawned wall refill enters from above the board")
	assert_true(deep_start.y < level.board_origin.y, "deep spawned wall refill must still enter from above the board, not pop in near the hole")
	assert_true(absf((deep_target.y - deep_start.y) - (top_target.y - top_start.y)) < 0.01, "wall-slide refill keeps equal travel distance so vertical clears fall as a stack, not a top-to-bottom paint")
	level.free()


func test_wall_refill_spawned_targets_use_snappy_refill_cap() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_wall_slide_target_refill_cap"), "Level exposes spawned wall-refill duration capping")
	if not level.board_view.has_method("_wall_slide_target_refill_cap"):
		level.free()
		return
	var N := Vector2i(-1, -1)
	var source_map := [
		[N, Vector2i(1, -2), N],
		[N, Vector2i(1, 0), N],
	]
	var spawned_cap: float = level.board_view.call("_wall_slide_target_refill_cap", source_map, 0, 1)
	var old_node_cap: float = level.board_view.call("_wall_slide_target_refill_cap", source_map, 1, 1)
	assert_true(spawned_cap > 0.0 and spawned_cap <= 0.56, "spawned wall refill uses the same bounded duration as ordinary refill")
	assert_true(old_node_cap < 0.0, "existing wall-slide nodes keep per-step timing instead of refill capping")
	level.free()
	# 上面已用行为断言证明 refill cap 计算正确; sync 把 cap 传进 tween 的接线在 async 内, 降级锁关键调用
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	if sync_start < 0 or sync_end <= sync_start:
		return
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	# 钉源码理由: 生成型墙滑补位必须把 refill_cap 传进 tween 时长(_tween_wall_slide_node(...refill_cap)), 否则长路径补位会比普通补位慢一截
	assert_true(sync_body.contains("_tween_wall_slide_node(node, target, visual_path, refill_cap)"), "spawned wall-slide refills pass the per-target cap into tween timing")


func test_wall_refill_spawned_targets_do_not_replay_top_to_bottom_path() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_wall_slide_target_visual_path"), "Level can choose a visual path per wall-slide target")
	if not level.board_view.has_method("_wall_slide_target_visual_path"):
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
	assert_eq(level.board_view.call("_wall_slide_target_visual_path", source_map, path_map, 0, 1), [], "spawned refill uses a continuous fall path instead of replaying row0-to-rowN visual steps")
	assert_eq(level.board_view.call("_wall_slide_target_visual_path", source_map, path_map, 1, 1), old_route, "old wall-slide pieces still replay the recorded gravity route")
	level.free()
	# 上面行为断言已证明"生成型补位返回空路径(连续下落)、旧节点重放记录路径"; sync 调用接线在 async 内, 降级锁关键调用
	var src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var sync_start: int = src.find("func _sync_wall_slide_visuals")
	var sync_end: int = src.find("func _collapse_and_refill", sync_start)
	if sync_start < 0 or sync_end <= sync_start:
		return
	var sync_body: String = src.substr(sync_start, sync_end - sync_start)
	# 钉源码理由: sync 必须按 _wall_slide_target_visual_path 的判定决定是否重放路径, 锁住"生成补位不走 row0→rowN 逐格重放"的接线
	assert_true(sync_body.contains("var visual_path := _wall_slide_target_visual_path(source_map, path_map, row, col)"), "wall-slide sync asks the target whether recorded path replay is appropriate")


func test_wall_refill_spawned_targets_use_same_duration_for_short_and_long_paths() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.board_view.has_method("_wall_slide_duration_for_target"), "Level can force a shared duration for spawned refill targets")
	if not level.board_view.has_method("_wall_slide_duration_for_target"):
		level.free()
		return
	level.board = Board.new(3, 7, [0, 1, 2], 0, 25, 1)
	level.board_view.board = level.board
	level.board_origin = Vector2(90, 420)
	level.board_view.board_origin = level.board_origin
	level.cell_size = 70.0
	level.board_view.cell_size = level.cell_size
	var top_start := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y - 7.0 * level.cell_size)
	var top_target: Vector2 = level.board_view.call("_cell_center", 0, 1)
	var deep_start := Vector2(90 + 1.5 * level.cell_size, level.board_origin.y - 1.0 * level.cell_size)
	var deep_target: Vector2 = level.board_view.call("_cell_center", 6, 1)
	var top_points: Array = level.board_view.call("_wall_slide_path_points", top_start, top_target)
	var deep_points: Array = level.board_view.call("_wall_slide_path_points", deep_start, deep_target)
	var top_uncapped: float = level.board_view.call("_wall_slide_duration_for_points", top_points)
	var deep_uncapped: float = level.board_view.call("_wall_slide_duration_for_points", deep_points)
	assert_true(top_uncapped < deep_uncapped, "short top refill paths would otherwise arrive before deep refill paths")
	var forced_duration := 0.52
	var top_forced: float = level.board_view.call("_wall_slide_duration_for_target", top_points, forced_duration)
	var deep_forced: float = level.board_view.call("_wall_slide_duration_for_target", deep_points, forced_duration)
	assert_eq(top_forced, deep_forced, "spawned refill targets share one duration so upper cells do not settle before lower cells")
	assert_eq(top_forced, forced_duration, "shared spawned-refill duration uses the configured refill time")
	level.free()


func test_opening_boss_casts_stones_only_and_ice_falls_with_board() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 冰不再被 boss 收集施法: 相关方法在实例上不存在即证明
	assert_false(level.has_method("_opening_coat_cells"), "ice cells are not gathered for boss casting")
	assert_false(level.has_method("_show_opening_coat_marker"), "boss opening phase no longer spawns ice markers")
	level.free()
	# 渲染分流(石头留空 / 冰随板落)迁至 board_view._render_board(契约 E)。
	var bv_src := FileAccess.get_file_as_string("res://match3/board_view.gd")
	var render_start: int = bv_src.find("func _render_board")
	var render_end: int = bv_src.find("func _blank_visual_rows", render_start)
	assert_true(render_start >= 0 and render_end > render_start, "_render_board can be inspected")
	if render_start < 0 or render_end <= render_start:
		return
	var render_body: String = bv_src.substr(render_start, render_end - render_start)
	# 钉源码理由: 开局掉落时墙石必须留空(_blank_visual_rows)直到 boss 施法才出现, 而冰必须立即渲染(_render_opening_coat_visuals)随棋盘一起落 —— 这是"石头 boss 施法 / 冰随板落"的演出分流决策
	assert_true(render_body.contains("if opening_drop:\n\t\t_wall_nodes = _blank_visual_rows()\n\telse:\n\t\t_render_wall_visuals()"), "opening drop keeps wall stones hidden until the boss casts them")
	assert_true(render_body.contains("if opening_drop:\n\t\t_render_opening_coat_visuals()\n\telse:\n\t\t_render_coat_visuals()"), "opening drop renders ice markers immediately so they fall with the board")

	# 开局石头施法演出迁至 directors/opening.gd(P6); 经 board_view 接口取格/出标记。
	var src := FileAccess.get_file_as_string("res://match3/directors/opening.gd")
	var freeze_start: int = src.find("func _play_opening_freeze")
	var freeze_end: int = src.find("func _apply_opening_freeze_instant", freeze_start)
	assert_true(freeze_start >= 0 and freeze_end > freeze_start, "opening freeze phase can be inspected")
	if freeze_start < 0 or freeze_end <= freeze_start:
		return
	var freeze_body: String = src.substr(freeze_start, freeze_end - freeze_start)
	# 钉源码理由: 石头开局收集墙格(opening_wall_cells)、用 boss 光束色(OPENING_STONE_COLOR)、光束后才出石头标记, 锁住 boss 施石顺序
	var wall_cells_idx: int = freeze_body.find("opening_wall_cells()")
	var wall_beam_idx: int = freeze_body.find("OPENING_STONE_COLOR")
	var wall_marker_idx: int = freeze_body.find("show_opening_wall_marker(p, true)")
	assert_true(wall_cells_idx >= 0, "opening freeze gathers wall stone cells")
	assert_true(wall_beam_idx >= 0, "stone generation uses a boss beam color")
	assert_true(wall_marker_idx > wall_beam_idx, "stone marker appears after the boss beam")
