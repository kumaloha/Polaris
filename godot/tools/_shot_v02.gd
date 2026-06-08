extends SceneTree
# 截新对局页(match3/level.gd via Level.tscn)。窗口模式(headless 无 GPU 不能截图)。
#   godot --path godot -s res://tools/_shot_v02.gd -- --level 28
# 等开局动画落定后截屏存 res://_shot_v02.png。

const ME := preload("res://core/match_engine.gd")
var _frames := 0
var _node: Node

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1520))
	var scene: PackedScene = load("res://Level.tscn")
	_node = scene.instantiate()
	get_root().add_child(_node)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 160:  # ~2.6s @60fps, 等开局掉落+冻结落定
		var img := get_root().get_texture().get_image()
		if img != null:
			img.save_png("res://_shot_v02.png")
			print("saved res://_shot_v02.png")
		else:
			print("no image (renderer unavailable)")
		quit()
	return false
