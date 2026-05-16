extends RefCounted
class_name Tuning
static var _data: Dictionary = {}
static func load_data() -> void:
	var f := FileAccess.open("res://data/tuning.json", FileAccess.READ)
	_data = JSON.parse_string(f.get_as_text())
	f.close()
static func num(path: String, default = 0):
	if _data.is_empty(): load_data()
	var cur = _data
	for key in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(key): return default
		cur = cur[key]
	return cur
