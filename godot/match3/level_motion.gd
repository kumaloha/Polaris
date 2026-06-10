extends RefCounted

const ME := preload("res://core/match_engine.gd")
const LevelLayout := preload("res://match3/level_layout.gd")

const FALL_TIME := 0.16
const FALL_EXTRA_CELL_TIME := 0.030
const FALL_MAX_TIME := 0.42
const ORDINARY_REFILL_MAX_TIME := 0.38
const ORDINARY_REFILL_TOP_POUR := 2.5
const WALL_SLIDE_STEP_TIME := FALL_EXTRA_CELL_TIME
const WALL_SLIDE_MAX_TIME := FALL_MAX_TIME


static func fall_barrier_in_grid(grid_snapshot: Array, coat: Array, choco: Array, row: int, col: int) -> bool:
	if row < 0 or row >= grid_snapshot.size() or col < 0 or col >= grid_snapshot[row].size():
		return false
	return grid_snapshot[row][col] == ME.WALL or _layer_value(coat, row, col) > 0 or _layer_value(choco, row, col) > 0


static func grid_has_fall_obstacle(grid_data: Array, coat: Array, choco: Array) -> bool:
	for row in range(grid_data.size()):
		for col in range(grid_data[row].size()):
			if fall_barrier_in_grid(grid_data, coat, choco, row, col):
				return true
	return false


static func ordinary_refill_start_position(target_center: Vector2, cell_size: float, spawn_count: int, top_pour: float = ORDINARY_REFILL_TOP_POUR) -> Vector2:
	var travel_cells := maxf(1.5, float(spawn_count) + 0.5) + top_pour
	return target_center - Vector2(0.0, cell_size * travel_cells)


static func ordinary_refill_duration_for_positions(start_pos: Vector2, target: Vector2, cell_size: float) -> float:
	return minf(fall_duration_for_positions(start_pos, target, cell_size), ORDINARY_REFILL_MAX_TIME)


static func fall_duration_for_positions(start_pos: Vector2, target: Vector2, cell_size: float) -> float:
	var size := maxf(1.0, cell_size)
	var cells := maxf(1.0, start_pos.distance_to(target) / size)
	return minf(FALL_TIME + maxf(0.0, cells - 1.0) * FALL_EXTRA_CELL_TIME, FALL_MAX_TIME)


static func wall_refill_start_position(row: int, col: int, source_map: Array, board_origin: Vector2, cell_size: float) -> Vector2:
	var source_col := wall_slide_spawn_source_col(source_map, row, col)
	if source_col < 0:
		source_col = col
		return LevelLayout.cell_center(0, source_col, cell_size, board_origin) - Vector2(0.0, cell_size * float(row + 1.5))
	var travel_cells := wall_slide_spawn_travel_cells(source_map, source_col)
	return LevelLayout.cell_center(row, source_col, cell_size, board_origin) - Vector2(0.0, cell_size * travel_cells)


static func wall_slide_target_has_fall_obstacle_above(grid_data: Array, coat: Array, choco: Array, cannon: Array, row: int, col: int) -> bool:
	if row <= 0 or grid_data.is_empty() or col < 0 or col >= grid_data[0].size():
		return false
	for y in range(row):
		if _layer_value(cannon, y, col) > 0:
			continue
		if fall_barrier_in_grid(grid_data, coat, choco, y, col):
			return true
	return false


static func wall_slide_path_points(start_pos: Vector2, target: Vector2, board_origin: Vector2, cell_size: float, board_width: int, board_height: int) -> Array:
	var points := []
	var cur := start_pos
	var top_entry_y := board_origin.y + cell_size * 0.5
	if cur.y < top_entry_y - 0.5 and target.y >= top_entry_y:
		cur = Vector2(cur.x, top_entry_y)
		points.append(cur)
	var safety: int = board_width + board_height + 8
	while safety > 0 and cur.distance_to(target) > 0.5:
		safety -= 1
		var dx := target.x - cur.x
		var dy := target.y - cur.y
		var step_x := 0.0
		if absf(dx) > cell_size * 0.35 and dy > cell_size * 0.35:
			step_x = signf(dx) * minf(cell_size, absf(dx))
		var step_y := minf(cell_size, maxf(0.0, dy))
		if step_y <= 0.0 and absf(dx) > 0.5:
			step_x = signf(dx) * minf(cell_size, absf(dx))
		var next := cur + Vector2(step_x, step_y)
		if next.distance_to(target) < cell_size * 0.35:
			next = target
		points.append(next)
		cur = next
	if points.is_empty() or points[points.size() - 1] != target:
		points.append(target)
	return points


static func wall_slide_cell_path_points(start_pos: Vector2, cell_path: Array, target: Vector2, board_origin: Vector2, cell_size: float, board_width: int, board_height: int) -> Array:
	if cell_path.is_empty():
		return wall_slide_path_points(start_pos, target, board_origin, cell_size, board_width, board_height)
	var points := []
	for raw_cell in cell_path:
		var cell: Vector2i = raw_cell
		if cell.y < 0 or cell.x < 0:
			continue
		var point := LevelLayout.cell_center(cell.y, cell.x, cell_size, board_origin)
		if point.distance_to(start_pos) <= 0.5:
			continue
		if not points.is_empty() and point.distance_to(points[points.size() - 1]) <= 0.5:
			continue
		points.append(point)
	if points.is_empty() or points[points.size() - 1].distance_to(target) > 0.5:
		points.append(target)
	return points


static func wall_slide_position_at(start_pos: Vector2, points: Array, progress: float) -> Vector2:
	if points.is_empty():
		return start_pos
	var clamped := clampf(progress, 0.0, 1.0)
	var total := 0.0
	var prev := start_pos
	for raw_point in points:
		var point: Vector2 = raw_point
		total += prev.distance_to(point)
		prev = point
	if total <= 0.001:
		return points[points.size() - 1]
	var target_distance := total * clamped
	var traveled := 0.0
	prev = start_pos
	for raw_point in points:
		var point: Vector2 = raw_point
		var segment := prev.distance_to(point)
		if segment <= 0.001:
			prev = point
			continue
		if traveled + segment >= target_distance:
			var local_progress := clampf((target_distance - traveled) / segment, 0.0, 1.0)
			return prev.lerp(point, local_progress)
		traveled += segment
		prev = point
	return points[points.size() - 1]


static func wall_slide_duration_for_points(points: Array) -> float:
	if points.is_empty():
		return 0.0
	var steps := maxf(1.0, float(points.size()))
	return minf(FALL_TIME + maxf(0.0, steps - 1.0) * WALL_SLIDE_STEP_TIME, WALL_SLIDE_MAX_TIME)


static func wall_slide_duration_for_target(points: Array, duration_override: float = -1.0) -> float:
	if duration_override > 0.0:
		return duration_override
	return wall_slide_duration_for_points(points)


static func source_none() -> Vector2i:
	return Vector2i(-1, -1)


static func source_spawn(col: int) -> Vector2i:
	return Vector2i(col, -2)


static func wall_slide_path_rows(grid_snapshot: Array) -> Array:
	var rows := []
	for row in range(grid_snapshot.size()):
		var out_row := []
		for col in range(grid_snapshot[row].size()):
			if grid_snapshot[row][col] >= 0:
				out_row.append([Vector2i(col, row)])
			else:
				out_row.append([])
		rows.append(out_row)
	return rows


static func wall_slide_source_rows(grid_snapshot: Array) -> Array:
	var rows := []
	for row in range(grid_snapshot.size()):
		var out_row := []
		for col in range(grid_snapshot[row].size()):
			if grid_snapshot[row][col] >= 0:
				out_row.append(Vector2i(col, row))
			else:
				out_row.append(source_none())
		rows.append(out_row)
	return rows


static func build_wall_slide_tracking_maps(before_grid: Array, coat: Array, choco: Array, cannon: Array, is_scrolling: bool) -> Dictionary:
	var tracking_grid: Array = before_grid.duplicate(true)
	var source_map := wall_slide_source_rows(tracking_grid)
	var path_map := wall_slide_path_rows(tracking_grid)
	if _grid_height(tracking_grid) <= 0 or _grid_width(tracking_grid) <= 0:
		return {"source": source_map, "path": path_map}
	_apply_wall_slide_tracking_gravity(tracking_grid, source_map, path_map, coat, choco, cannon)
	if is_scrolling:
		return {"source": source_map, "path": path_map}
	var max_steps: int = maxi(1, _grid_height(tracking_grid) * _grid_width(tracking_grid) * 2)
	for _i in range(max_steps):
		_apply_wall_slide_tracking_gravity(tracking_grid, source_map, path_map, coat, choco, cannon)
		var spawned := false
		for col in range(_grid_width(tracking_grid)):
			if not _wall_slide_tracking_empty_cell(tracking_grid, coat, choco, 0, col):
				continue
			tracking_grid[0][col] = 0
			source_map[0][col] = source_spawn(col)
			path_map[0][col] = [Vector2i(col, 0)]
			spawned = true
		if not spawned:
			_apply_wall_slide_tracking_gravity(tracking_grid, source_map, path_map, coat, choco, cannon)
			return {"source": source_map, "path": path_map}
	_apply_wall_slide_tracking_gravity(tracking_grid, source_map, path_map, coat, choco, cannon)
	return {"source": source_map, "path": path_map}


static func wall_slide_source_priority(row: int, col: int, target_row: int, target_col: int, allow_cross_column: bool) -> int:
	if row > target_row:
		return -1
	if col == target_col:
		return target_row - row
	if not allow_cross_column or row >= target_row:
		return -1
	if col == target_col + 1:
		return 1000 + target_row - row
	if col == target_col - 1:
		return 2000 + target_row - row
	return 3000 + absi(col - target_col) * 100 + target_row - row


static func wall_slide_spawn_source_col(source_map: Array, row: int, col: int) -> int:
	if source_map.is_empty() or row < 0 or row >= source_map.size():
		return -1
	if col < 0 or col >= source_map[row].size():
		return -1
	var source: Vector2i = source_map[row][col]
	if source.y != -2:
		return -1
	return source.x


static func wall_slide_spawn_travel_cells(source_map: Array, source_col: int) -> float:
	if source_col < 0:
		return 1.5
	var spawn_count := 0
	var deepest_row := -1
	for row in range(source_map.size()):
		if not (source_map[row] is Array):
			continue
		var source_row: Array = source_map[row]
		for col in range(source_row.size()):
			var source: Vector2i = source_row[col]
			if source.y == -2 and source.x == source_col:
				spawn_count += 1
				deepest_row = maxi(deepest_row, row)
	if spawn_count <= 0:
		return 1.5
	return maxf(float(spawn_count) + 0.5, float(deepest_row) + 1.5)


static func wall_slide_target_refill_cap(source_map: Array, row: int, col: int) -> float:
	if wall_slide_spawn_source_col(source_map, row, col) >= 0:
		return ORDINARY_REFILL_MAX_TIME
	return -1.0


static func wall_slide_target_path(path_map: Array, row: int, col: int) -> Array:
	if path_map.is_empty() or row < 0 or row >= path_map.size():
		return []
	if col < 0 or col >= path_map[row].size():
		return []
	return path_map[row][col]


static func wall_slide_target_visual_path(source_map: Array, path_map: Array, row: int, col: int) -> Array:
	if wall_slide_spawn_source_col(source_map, row, col) >= 0:
		return []
	return wall_slide_target_path(path_map, row, col)


static func wall_slide_visual_start_position(source_map: Array, path_map: Array, row: int, col: int, board_origin: Vector2, cell_size: float) -> Vector2:
	if not source_map.is_empty() and row >= 0 and row < source_map.size() and col >= 0 and col < source_map[row].size():
		var source: Vector2i = source_map[row][col]
		if source.y >= 0 and source.x >= 0:
			return LevelLayout.cell_center(source.y, source.x, cell_size, board_origin)
		if source.y == -2:
			return wall_refill_start_position(row, col, source_map, board_origin, cell_size)
	var path: Array = wall_slide_target_path(path_map, row, col)
	if not path.is_empty():
		var first: Vector2i = path[0]
		if first.y >= 0 and first.x >= 0:
			return LevelLayout.cell_center(first.y, first.x, cell_size, board_origin)
	return wall_refill_start_position(row, col, source_map, board_origin, cell_size)


static func _apply_wall_slide_tracking_gravity(grid_snapshot: Array, source_map: Array, path_map: Array, coat: Array, choco: Array, cannon: Array) -> void:
	var moved := true
	var guard := 0
	var max_steps: int = maxi(1, _grid_height(grid_snapshot) * _grid_width(grid_snapshot) * 2)
	while moved and guard < max_steps:
		moved = false
		guard += 1
		for row in range(_grid_height(grid_snapshot) - 1, 0, -1):
			for col in range(_grid_width(grid_snapshot)):
				moved = _try_fill_wall_slide_tracking_slot(grid_snapshot, source_map, path_map, coat, choco, cannon, row, col) or moved


static func _try_fill_wall_slide_tracking_slot(grid_snapshot: Array, source_map: Array, path_map: Array, coat: Array, choco: Array, cannon: Array, target_row: int, target_col: int) -> bool:
	if target_row <= 0 or not _wall_slide_tracking_empty_cell(grid_snapshot, coat, choco, target_row, target_col):
		return false
	var source_row := target_row - 1
	var candidates := [Vector2i(target_col, source_row)]
	if _wall_slide_tracking_blocked_above(grid_snapshot, coat, choco, cannon, target_row, target_col) and not _wall_slide_tracking_has_vertical_source_above(grid_snapshot, coat, choco, target_row, target_col):
		candidates.append(Vector2i(target_col + 1, source_row))
		candidates.append(Vector2i(target_col - 1, source_row))
	for p in candidates:
		if _wall_slide_tracking_movable_cell(grid_snapshot, coat, choco, p.y, p.x):
			_move_wall_slide_tracking_cell(grid_snapshot, source_map, path_map, p.y, p.x, target_row, target_col)
			return true
	return false


static func _move_wall_slide_tracking_cell(grid_snapshot: Array, source_map: Array, path_map: Array, from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	grid_snapshot[to_row][to_col] = grid_snapshot[from_row][from_col]
	grid_snapshot[from_row][from_col] = ME.EMPTY
	source_map[to_row][to_col] = source_map[from_row][from_col]
	source_map[from_row][from_col] = source_none()
	var path: Array = path_map[from_row][from_col].duplicate()
	path.append(Vector2i(to_col, to_row))
	path_map[to_row][to_col] = path
	path_map[from_row][from_col] = []


static func _wall_slide_tracking_fixed_cell(grid_snapshot: Array, coat: Array, choco: Array, row: int, col: int) -> bool:
	return grid_snapshot[row][col] == ME.WALL or _layer_value(coat, row, col) > 0 or _layer_value(choco, row, col) > 0


static func _wall_slide_tracking_empty_cell(grid_snapshot: Array, coat: Array, choco: Array, row: int, col: int) -> bool:
	if row < 0 or row >= _grid_height(grid_snapshot) or col < 0 or col >= _grid_width(grid_snapshot):
		return false
	return grid_snapshot[row][col] == ME.EMPTY and not _wall_slide_tracking_fixed_cell(grid_snapshot, coat, choco, row, col)


static func _wall_slide_tracking_movable_cell(grid_snapshot: Array, coat: Array, choco: Array, row: int, col: int) -> bool:
	if row < 0 or row >= _grid_height(grid_snapshot) or col < 0 or col >= _grid_width(grid_snapshot):
		return false
	return grid_snapshot[row][col] >= 0 and not _wall_slide_tracking_fixed_cell(grid_snapshot, coat, choco, row, col)


static func _wall_slide_tracking_blocked_above(grid_snapshot: Array, coat: Array, choco: Array, cannon: Array, row: int, col: int) -> bool:
	if row <= 0 or col < 0 or col >= _grid_width(grid_snapshot):
		return false
	for y in range(row):
		if _layer_value(cannon, y, col) > 0:
			continue
		if _wall_slide_tracking_fixed_cell(grid_snapshot, coat, choco, y, col):
			return true
	return false


static func _wall_slide_tracking_has_vertical_source_above(grid_snapshot: Array, coat: Array, choco: Array, row: int, col: int) -> bool:
	if row <= 0 or col < 0 or col >= _grid_width(grid_snapshot):
		return false
	for y in range(row - 1, -1, -1):
		if _wall_slide_tracking_fixed_cell(grid_snapshot, coat, choco, y, col):
			return false
		if _wall_slide_tracking_movable_cell(grid_snapshot, coat, choco, y, col):
			return true
	return false


static func _layer_value(layer: Array, row: int, col: int) -> int:
	if layer.is_empty() or row < 0 or row >= layer.size():
		return 0
	var row_data = layer[row]
	if not (row_data is Array) or col < 0 or col >= row_data.size():
		return 0
	return int(row_data[col])


static func _grid_height(grid_data: Array) -> int:
	return grid_data.size()


static func _grid_width(grid_data: Array) -> int:
	if grid_data.is_empty() or not (grid_data[0] is Array):
		return 0
	return grid_data[0].size()
