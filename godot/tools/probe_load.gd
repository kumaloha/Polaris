extends SceneTree
# 脚本加载探针: 逐文件验证编译/实例化, 揪出 Parse error 与挂死(合并新文件后的收口必用)。
# 跑: godot --headless --path godot -s res://tools/probe_load.gd -- <res路径> [new]
#   省略 new = 仅 load(编译); 带 new = load + .new()(触发 static/成员初始化)
# 背景: headless 不刷新 .godot/global_script_class_cache.cfg——合并含 class_name 的新文件后
#       必须先 `godot --headless --path godot --import` 刷缓存, 再 probe, 否则裸类名 extends 全部假死。
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else ""
	print("LOADING ", path)
	var s = load(path)
	print("LOADED ", s != null)
	if args.size() > 1 and args[1] == "new" and s is GDScript:
		var inst = s.new()
		print("NEWED ", inst != null)
	quit(0)
