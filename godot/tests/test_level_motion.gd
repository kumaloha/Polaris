extends "res://tests/test_lib.gd"

const LM := preload("res://match3/level_motion.gd")


func test_arclength_table_matches_manual_distances() -> void:
	var start := Vector2(0.0, 0.0)
	var points: Array = [Vector2(10.0, 0.0), Vector2(10.0, 20.0), Vector2(30.0, 20.0)]
	var table: Array = LM.wall_slide_arclength_table(start, points)
	assert_eq(table.size(), 3, "table size equals points size")
	assert_true(absf(table[0] - 10.0) < 0.001, "first segment: 10px horizontal")
	assert_true(absf(table[1] - 30.0) < 0.001, "second segment: 10+20px")
	assert_true(absf(table[2] - 50.0) < 0.001, "third segment: 10+20+20px")


func test_position_at_table_equals_position_at_at_progress_0() -> void:
	var start := Vector2(0.0, 0.0)
	var points: Array = [Vector2(50.0, 0.0), Vector2(50.0, 80.0), Vector2(130.0, 80.0)]
	var table: Array = LM.wall_slide_arclength_table(start, points)
	var old_pos: Vector2 = LM.wall_slide_position_at(start, points, 0.0)
	var new_pos: Vector2 = LM.wall_slide_position_at_table(start, points, table, 0.0)
	assert_true(old_pos.distance_to(new_pos) < 0.1, "table version equals legacy at progress=0")


func test_position_at_table_equals_position_at_at_progress_1() -> void:
	var start := Vector2(0.0, 0.0)
	var points: Array = [Vector2(50.0, 0.0), Vector2(50.0, 80.0), Vector2(130.0, 80.0)]
	var table: Array = LM.wall_slide_arclength_table(start, points)
	var old_pos: Vector2 = LM.wall_slide_position_at(start, points, 1.0)
	var new_pos: Vector2 = LM.wall_slide_position_at_table(start, points, table, 1.0)
	assert_true(old_pos.distance_to(new_pos) < 0.1, "table version equals legacy at progress=1")


func test_position_at_table_equals_position_at_at_midpoints() -> void:
	var start := Vector2(0.0, 0.0)
	var points: Array = [Vector2(88.0, 0.0), Vector2(88.0, 88.0), Vector2(176.0, 88.0)]
	var table: Array = LM.wall_slide_arclength_table(start, points)
	for i in range(11):
		var p := float(i) / 10.0
		var old_pos: Vector2 = LM.wall_slide_position_at(start, points, p)
		var new_pos: Vector2 = LM.wall_slide_position_at_table(start, points, table, p)
		assert_true(old_pos.distance_to(new_pos) < 0.5,
			"table version matches legacy at progress=%.1f" % p)


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
