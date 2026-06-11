extends SceneTree
# 录制「宝石炸裂」普通消除特效: Level.tscn 开局掉落完 → 自动走一步最佳交换 → 连续截帧。
# 跑: godot --path godot -s res://tools/shot_gem_burst.gd   → res://_burst_frames/f###.png
const ME := preload("res://core/match_engine.gd")

var _level: Node
var _frames := 0
var _recording := false
var _rec_count := 0
var _swapped := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://_burst_frames")
	_level = load("res://Level.tscn").instantiate()
	get_root().add_child(_level)

func _process(_delta: float) -> bool:
	_frames += 1
	# 等开局掉落演出结束(~2.5s)再触发交换
	if _frames == 150 and not _swapped:
		_swapped = true
		var b = _level.board
		var mvs: Array = ME.best_moves(b.grid, 1, b._layers(), b.objectives)
		if mvs.is_empty():
			print("no legal move")
			quit()
			return true
		print("swap ", mvs[0][0], " <-> ", mvs[0][1])
		_level.call("_try_swap", mvs[0][0], mvs[0][1])
		_recording = true
	if _recording and _rec_count < 60:
		var img := get_root().get_texture().get_image()
		if img != null:
			img.save_png("res://_burst_frames/f%03d.png" % _rec_count)
			_rec_count += 1
		if _rec_count >= 60:
			print("frames saved: ", _rec_count)
			quit()
	return false
