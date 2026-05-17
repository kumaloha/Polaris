extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene := (load("res://scenes/Peek.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if scene.has_method("open_reveal"):
		scene.open_reveal("evan")
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var path := "res://peek_reveal.png"
	var err := img.save_png(path)
	if err == OK:
		print("PEEK SHOT OK ", ProjectSettings.globalize_path(path))
	else:
		print("PEEK SHOT FAIL err=", err)
	quit(0)
