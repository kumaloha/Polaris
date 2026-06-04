extends RefCounted

const MANIFEST_PATH := "resources/characters/characters.json"
const CHARACTER_DIR := "resources/characters"

const DISPLAY_NAMES := {
	"borrrower": "借贷",
	"breaker": "破障",
	"chainbonus": "连消奖步",
	"collector": "连击收集",
	"colorshield": "彩球护盾",
	"foresight": "预知",
	"gravityflip": "重力翻转",
	"longswap": "隔位对换",
	"lucky": "默认精灵",
	"sametypeclear": "同类消除",
	"snapshot": "存档快照",
	"timerewind": "时间回退",
}


static func resolve_file_path(path: String) -> String:
	if path.is_empty():
		return path
	if path.begins_with("res://") or path.begins_with("user://") or path.begins_with("/"):
		return path
	return ProjectSettings.globalize_path("res://../%s" % path).simplify_path()


static func load_manifest() -> Dictionary:
	var manifest_path := resolve_file_path(MANIFEST_PATH)
	if not FileAccess.file_exists(manifest_path):
		return {}
	var text := FileAccess.get_file_as_string(manifest_path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func load_characters() -> Array:
	var manifest := load_manifest()
	var declared := _declared_characters_by_id(manifest)
	var image_paths := discover_character_images()
	var out := []
	if not image_paths.is_empty():
		for path in image_paths:
			var image_path := String(path)
			var id: String = image_path.get_file().get_basename()
			var declared_item = declared.get(id, {})
			var item: Dictionary = {}
			if typeof(declared_item) == TYPE_DICTIONARY:
				item = declared_item.duplicate(true)
			if item.is_empty():
				item = _default_character(id, image_path)
			else:
				_normalize_character(item, id, image_path)
			out.append(item)
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 999)) < int(b.get("order", 999)))
		return out

	for item in declared.values():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = item.duplicate(true)
		_normalize_character(normalized, String(normalized.get("id", "")), String(normalized.get("portrait", normalized.get("image", ""))))
		if _is_valid_character(normalized):
			out.append(normalized)
	return out



static func discover_character_images() -> Array:
	var dir := DirAccess.open(resolve_file_path(CHARACTER_DIR))
	if dir == null:
		return []
	var paths := []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
			paths.append("%s/%s" % [CHARACTER_DIR, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


static func _declared_characters_by_id(manifest: Dictionary) -> Dictionary:
	var by_id := {}
	var raw = manifest.get("characters", [])
	if typeof(raw) != TYPE_ARRAY:
		return by_id
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := String(item.get("id", ""))
		if id.is_empty():
			continue
		by_id[id] = item
	return by_id


static func _default_character(id: String, path: String) -> Dictionary:
	return {
		"id": id,
		"name": String(DISPLAY_NAMES.get(id, _display_name(id))),
		"subtitle": "Magic Skill",
		"accent": "#8b54e8",
		"image": path,
		"card": path,
		"portrait": path,
		"playable": true,
		"passive": false,
	}


static func _normalize_character(item: Dictionary, fallback_id: String, fallback_path: String) -> void:
	if not item.has("id") or String(item["id"]).is_empty():
		item["id"] = fallback_id
	var id := String(item["id"])
	if not item.has("name") or String(item["name"]).is_empty():
		item["name"] = String(DISPLAY_NAMES.get(id, _display_name(id)))
	if not item.has("subtitle"):
		item["subtitle"] = "Magic Skill"
	if not item.has("accent"):
		item["accent"] = "#8b54e8"
	if not item.has("image"):
		item["image"] = fallback_path
	if not item.has("card"):
		item["card"] = String(item.get("image", fallback_path))
	if not item.has("portrait"):
		item["portrait"] = String(item.get("image", fallback_path))
	if not item.has("playable"):
		item["playable"] = true
	if not item.has("passive"):
		item["passive"] = false


static func _is_valid_character(item: Dictionary) -> bool:
	return item.has("id") and item.has("name") and item.has("card") and item.has("portrait")


static func _display_name(id: String) -> String:
	return id.replace("_", " ").replace("-", " ").capitalize()
