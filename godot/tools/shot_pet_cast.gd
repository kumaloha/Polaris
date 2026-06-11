extends SceneTree
# P3 验收: 录时兔施法动画全程(PetCast 平移后真机对照)。
# 跑: godot --path godot -s res://tools/shot_pet_cast.gd  → res://_cast_frames/c###.png
const ME := preload("res://core/match_engine.gd")

var _level: Node
var _frames := 0
var _rec := -1

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://_cast_frames")
	_level = load("res://Level.tscn").instantiate()
	get_root().add_child(_level)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 150:
		# 先走一步让 move_history 非空(rewind 前置条件)
		var b = _level.board
		var mvs: Array = ME.best_moves(b.grid, 1, b._layers(), b.objectives)
		if not mvs.is_empty():
			_level.call("_try_swap", mvs[0][0], mvs[0][1])
	if _frames == 320:
		var ok: bool = _level.call("_cast_pet", 0, true)
		print("cast started: ", ok)
		if not ok:
			quit()
			return true
		_rec = 0
	if _rec >= 0:
		if _rec % 2 == 0:
			var img := get_root().get_texture().get_image()
			if img != null:
				img.save_png("res://_cast_frames/c%03d.png" % (_rec / 2))
		_rec += 1
		if _rec >= 340:
			print("frames: ", _rec / 2)
			quit()
	return false
