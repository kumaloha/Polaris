extends "res://tests/test_lib.gd"


func test_no_orphan_gd_uid_files() -> void:
	var orphan_paths: Array[String] = []
	_collect_orphan_gd_uid_files("res://", orphan_paths)
	orphan_paths.sort()
	assert_eq(orphan_paths, [], "orphan .gd.uid files should be deleted with their scripts")


func _collect_orphan_gd_uid_files(dir_path: String, orphan_paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		failures.append("unable to open directory %s" % dir_path)
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var path := dir_path.path_join(name)
		if dir.current_is_dir():
			_collect_orphan_gd_uid_files(path, orphan_paths)
		elif name.ends_with(".gd.uid"):
			var script_path := path.substr(0, path.length() - ".uid".length())
			if not FileAccess.file_exists(script_path):
				orphan_paths.append(path)
	dir.list_dir_end()
