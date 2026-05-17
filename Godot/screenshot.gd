extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene := (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var path := "res://reskin_home.png"
	var err := img.save_png(path)
	if err == OK:
		print("SCREENSHOT OK ", ProjectSettings.globalize_path(path))
	else:
		print("SCREENSHOT FAIL err=", err)
	quit(0)
