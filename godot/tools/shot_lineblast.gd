extends SceneTree
# 截图验证: 行/列横扫流星波 + 被炸棋子碎成基础爆炸粒子(spawn_shatter)。窗口模式(headless 不能截图)。
# 跑: godot --path godot -s res://tools/shot_lineblast.gd
const FxClass := preload("res://match3/effect_manager.gd")

func _initialize() -> void:
	_run()

# 一条横扫: 流星波 + 沿线被炸棋子碎成粒子
func _sweep(fx: Node, a: Vector2, b: Vector2, col: Color) -> void:
	fx.spawn_line_blast(a, b, col)
	var steps := 6
	for i in range(steps + 1):
		var pt: Vector2 = a.lerp(b, float(i) / float(steps))
		fx.spawn_shatter(pt, col)   # 路径棋子直接碎成基础爆炸粒子

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1120))
	var root := get_root()
	var bg := ColorRect.new()         # 深色背景便于看 additive 发光与染色
	bg.size = Vector2(720, 1120)
	bg.color = Color(0.06, 0.05, 0.12)
	root.add_child(bg)
	var fx: Node = FxClass.new()
	root.add_child(fx)
	var layer := Node2D.new()
	root.add_child(layer)
	fx.attach(layer)
	await process_frame
	# 行(水平横扫): 红 / 蓝 / 绿
	_sweep(fx, Vector2(50, 200), Vector2(670, 200), Color(0.69, 0.11, 0.05))
	_sweep(fx, Vector2(50, 340), Vector2(670, 340), Color(0.05, 0.30, 0.79))
	_sweep(fx, Vector2(50, 480), Vector2(670, 480), Color(0.37, 0.64, 0.05))
	# 列(转 90° 垂直横扫): 紫 / 粉
	_sweep(fx, Vector2(230, 600), Vector2(230, 1060), Color(0.33, 0.06, 0.73))
	_sweep(fx, Vector2(470, 600), Vector2(470, 1060), Color(0.78, 0.12, 0.41))
	await create_timer(0.10).timeout   # 粒子四散中 + 流星飞到中段
	for i in range(3):
		await process_frame
	var img := root.get_texture().get_image()
	var p := ProjectSettings.globalize_path("res://_shot_lineblast.png")
	img.save_png(p)
	print("shot saved ", p)
	quit()
