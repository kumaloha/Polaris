extends RefCounted
# Local playtest telemetry recorder.
#
# This is intentionally local-first: it writes a JSONL event stream plus a
# compact PlayerContext snapshot under user:// so manual testing can feed the
# Python generate-next loop without a backend.

static var LOG_PATH := "user://playtest_sessions.jsonl"
static var CONTEXT_PATH := "user://player_context.json"
static var PLAYER_ID := "local_playtester"
static var MAX_CONTEXT_RECORDS := 200


static func record(result: Dictionary, level_index: int, level_record: Dictionary = {}) -> Dictionary:
	var event := _event_from_result(result, level_index, level_record)
	_append_jsonl(LOG_PATH, event)
	_append_player_context(CONTEXT_PATH, event)
	return event


static func clear_test_files() -> void:
	_remove_file(LOG_PATH)
	_remove_file(CONTEXT_PATH)


static func _event_from_result(result: Dictionary, level_index: int, level_record: Dictionary) -> Dictionary:
	var now_unix := int(Time.get_unix_time_from_system())
	var coordinate := int(result.get("level_coordinate", level_index + 1))
	var assigned := str(result.get("assigned_instance_id", ""))
	if assigned.is_empty():
		assigned = str(level_record.get("level_id", level_record.get("id", "level_%03d_library_%d" % [coordinate, level_index])))
	var objectives: Array = result.get("objectives", []) if result.get("objectives", []) is Array else []
	var progress: Array = result.get("objective_progress", []) if result.get("objective_progress", []) is Array else []
	var completion := _objective_completion_rate(progress)
	var won := bool(result.get("won", false))
	var fail_reasons := _fail_reasons(result, completion)
	var moves_left := int(result.get("moves_left", 0))
	var move_limit := int(result.get("move_limit", max(0, moves_left)))
	return {
		"schema_version": 1,
		"event_type": "playtest_result",
		"event_id": "playtest_%d_%d_%d" % [now_unix, coordinate, Time.get_ticks_usec() % 1000000],
		"recorded_at": Time.get_datetime_string_from_system(true),
		"recorded_at_unix": now_unix,
		"player_id": PLAYER_ID,
		"level_index": level_index,
		"level_coordinate": coordinate,
		"assigned_instance_id": assigned,
		"level_id": str(level_record.get("level_id", assigned)),
		"variant": str(result.get("variant", level_record.get("variant", ""))),
		"won": won,
		"lost": bool(result.get("lost", not won)),
		"stars": int(result.get("stars", 0)),
		"score": int(result.get("score", 0)),
		"moves_left": moves_left,
		"move_limit": move_limit,
		"moves_used": max(0, move_limit - moves_left),
		"objectives": objectives.duplicate(true),
		"objective_progress": progress.duplicate(true),
		"objective_completion_rate": completion,
		"mechanisms_present": _mechanisms_from_objectives(objectives),
		"mechanism_activation_rate": completion,
		"fail_reasons": fail_reasons,
		"is_scrolling": bool(result.get("is_scrolling", false)),
	}


static func _append_jsonl(path: String, event: Dictionary) -> void:
	var old_text := ""
	if FileAccess.file_exists(path):
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf != null:
			old_text = rf.get_as_text()
			rf.close()
	var wf := FileAccess.open(path, FileAccess.WRITE)
	if wf == null:
		push_warning("playtest_recorder: unable to write " + path)
		return
	wf.store_string(old_text)
	wf.store_string(JSON.stringify(event) + "\n")
	wf.close()


static func _append_player_context(path: String, event: Dictionary) -> void:
	var ctx := {
		"player_id": PLAYER_ID,
		"cold_start_prior": "unknown",
		"played_levels": [],
	}
	if FileAccess.file_exists(path):
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf != null:
			var parsed = JSON.parse_string(rf.get_as_text())
			rf.close()
			if parsed is Dictionary:
				ctx = parsed
	if not ctx.has("played_levels") or not (ctx["played_levels"] is Array):
		ctx["played_levels"] = []
	ctx["player_id"] = str(ctx.get("player_id", PLAYER_ID))
	ctx["generated_at"] = Time.get_datetime_string_from_system(true)
	ctx["played_levels"].append(_context_record_from_event(event))
	while ctx["played_levels"].size() > MAX_CONTEXT_RECORDS:
		ctx["played_levels"].pop_front()
	var wf := FileAccess.open(path, FileAccess.WRITE)
	if wf == null:
		push_warning("playtest_recorder: unable to write " + path)
		return
	wf.store_string(JSON.stringify(ctx, "\t"))
	wf.close()


static func _context_record_from_event(event: Dictionary) -> Dictionary:
	return {
		"level_coordinate": int(event.get("level_coordinate", 0)),
		"assigned_instance_id": str(event.get("assigned_instance_id", "")),
		"variant": str(event.get("variant", "")),
		"attempts": 1,
		"won": bool(event.get("won", false)),
		"moves_left": int(event.get("moves_left", 0)),
		"stars": int(event.get("stars", 0)),
		"fail_reasons": event.get("fail_reasons", {}),
		"mechanism_activation_rate": float(event.get("mechanism_activation_rate", 0.0)),
		"active_mechanisms": event.get("mechanisms_present", []),
		"had_reward": _had_reward(event),
	}


static func _objective_completion_rate(progress: Array) -> float:
	var current := 0.0
	var target := 0.0
	for item in progress:
		if item is Dictionary:
			current += float(item.get("current", 0.0))
			target += max(0.0, float(item.get("target", 0.0)))
	if target <= 0.0:
		return 1.0
	return clampf(current / target, 0.0, 1.0)


static func _fail_reasons(result: Dictionary, completion: float) -> Dictionary:
	if bool(result.get("won", false)):
		return {}
	if int(result.get("moves_left", 0)) <= 0:
		return {"out_of_moves": 1}
	if completion < 0.35:
		return {"low_target_progress": 1}
	if completion < 0.85:
		return {"ran_out_before_completion": 1}
	return {"unknown_loss": 1}


static func _mechanisms_from_objectives(objectives: Array) -> Array:
	var out: Array = []
	for item in objectives:
		if not (item is Dictionary):
			continue
		match str(item.get("type", "")):
			"CLEAR_JELLY":
				_add_unique(out, "target_mark")
			"CLEAR_BLOCKER":
				_add_unique(out, "crystal_shell")
			"COLLECT_INGREDIENT":
				_add_unique(out, "drop_relic")
			"CLEAR_CHOCO":
				_add_unique(out, "creep_growth")
			"DEFUSE_BOMB":
				_add_unique(out, "timed_core")
			_:
				pass
	return out


static func _had_reward(event: Dictionary) -> bool:
	for mechanism in event.get("mechanisms_present", []):
		var id := String(mechanism)
		if id in ["line_h_gem", "line_v_gem", "burst_gem", "color_bomb_gem"]:
			return true
	return false


static func _add_unique(items: Array, value: String) -> void:
	if not items.has(value):
		items.append(value)


static func _remove_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
