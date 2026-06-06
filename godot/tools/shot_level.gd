extends SceneTree
# shot_level.gd — 渲染截图（需窗口模式，有 GPU；headless 无法截图）。
# 跑法：godot --path godot -s res://tools/shot_level.gd
# 产物：res://_stage1_shot.png（存项目目录，与现有 screenshot.gd 一致；
#       user:// 路径含空格会导致 save_png 写出畸形文件）。

var _frames: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1520))
	var scene: Node = load("res://Level.tscn").instantiate()
	get_root().add_child(scene)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	var img: Image = get_root().get_texture().get_image()
	if img != null:
		print("IMG_SIZE:", img.get_size())
		img.save_png("res://_stage1_shot.png")
		print("SHOT_SAVED:res://_stage1_shot.png")
	else:
		print("no image (renderer unavailable)")
	quit()
	return true
