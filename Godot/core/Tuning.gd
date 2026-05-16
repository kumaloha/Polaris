extends RefCounted
class_name Tuning
static var _data: Dictionary = {}
static func load_data() -> void:
	var f := FileAccess.open("res://data/tuning.json", FileAccess.READ)
	assert(f != null, "tuning.json unreadable")
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	_data = parsed if parsed is Dictionary else {}
static func reset() -> void:
	_data = {}
static func num(path: String, default = 0):
	if _data.is_empty(): load_data()
	var cur = _data
	for key in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(key): return default
		cur = cur[key]
	return cur
