extends "res://tests/test_lib.gd"

const LM := preload("res://match3/level_motion.gd")


func _manual_position_at(start_pos: Vector2, points: Array, progress: float) -> Vector2:
	if points.is_empty():
		return start_pos
	var total := 0.0
	var prev := start_pos
	for raw_point in points:
		var point: Vector2 = raw_point
		total += prev.distance_to(point)
		prev = point
	if total <= 0.001:
		return points[points.size() - 1]
	var target_distance := total * clampf(progress, 0.0, 1.0)
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


func test_arclength_table_matches_manual_distances() -> void:
	var start := Vector2(0.0, 0.0)
	var points: Array = [Vector2(10.0, 0.0), Vector2(10.0, 20.0), Vector2(30.0, 20.0)]
	var table: Array = LM.wall_slide_arclength_table(start, points)
	assert_eq(table.size(), 3, "table size equals points size")
	assert_true(absf(table[0] - 10.0) < 0.001, "first segment: 10px horizontal")
	assert_true(absf(table[1] - 30.0) < 0.001, "second segment: 10+20px")
	assert_true(absf(table[2] - 50.0) < 0.001, "third segment: 10+20+20px")


func test_position_at_table_starts_at_source() -> void:
	var start := Vector2(0.0, 0.0)
	var points: Array = [Vector2(50.0, 0.0), Vector2(50.0, 80.0), Vector2(130.0, 80.0)]
	var table: Array = LM.wall_slide_arclength_table(start, points)
	var new_pos: Vector2 = LM.wall_slide_position_at_table(start, points, table, 0.0)
	assert_true(start.distance_to(new_pos) < 0.1, "table sampler starts at the source position")


func test_position_at_table_ends_at_target() -> void:
	var start := Vector2(0.0, 0.0)
	var points: Array = [Vector2(50.0, 0.0), Vector2(50.0, 80.0), Vector2(130.0, 80.0)]
	var table: Array = LM.wall_slide_arclength_table(start, points)
	var new_pos: Vector2 = LM.wall_slide_position_at_table(start, points, table, 1.0)
	assert_true((points[points.size() - 1] as Vector2).distance_to(new_pos) < 0.1, "table sampler ends at the final path point")


func test_position_at_table_matches_manual_midpoints() -> void:
	var start := Vector2(0.0, 0.0)
	var points: Array = [Vector2(88.0, 0.0), Vector2(88.0, 88.0), Vector2(176.0, 88.0)]
	var table: Array = LM.wall_slide_arclength_table(start, points)
	for i in range(11):
		var p := float(i) / 10.0
		var expected: Vector2 = _manual_position_at(start, points, p)
		var new_pos: Vector2 = LM.wall_slide_position_at_table(start, points, table, p)
		assert_true(expected.distance_to(new_pos) < 0.5,
			"table sampler matches manual path distance at progress=%.1f" % p)


func test_position_at_table_empty_points_returns_start() -> void:
	var start := Vector2(42.0, 17.0)
	var new_pos: Vector2 = LM.wall_slide_position_at_table(start, [], [], 0.5)
	assert_true(new_pos.distance_to(start) < 0.001, "empty points returns start_pos")


func test_arclength_table_empty_points_returns_empty_table() -> void:
	var table: Array = LM.wall_slide_arclength_table(Vector2.ZERO, [])
	assert_eq(table.size(), 0, "empty points yields empty table")


func test_arclength_table_is_monotonically_non_decreasing() -> void:
	var start := Vector2(5.0, 3.0)
	var points: Array = [Vector2(15.0, 3.0), Vector2(15.0, 40.0), Vector2(60.0, 40.0), Vector2(60.0, 10.0)]
	var table: Array = LM.wall_slide_arclength_table(start, points)
	for i in range(1, table.size()):
		assert_true(float(table[i]) >= float(table[i - 1]),
			"arclength table is non-decreasing at index %d" % i)
