extends Node
## 特效管理器(autoload "Fx")。所有特效集中在此, 不散落到棋子脚本。
## 发光类(火花/光束)用 CanvasItemMaterial Additive + modulate 染色; 碎片类用普通 alpha 染色。
## Level._ready() 调 Fx.attach(fx_layer, shake_node) 注册画布层与震动目标。

const SPARK := "res://assets/fx/fx_spark_star.png"  # 火花/星
const SMOKE := "res://assets/fx/fx_smoke.png"       # 烟/碎屑
const TRAIL := "res://assets/fx/fx_trail.png"       # 拖尾/光束
const SHOCK := "res://assets/fx/fx_shockwave.png"   # 冲击波
const BOKEH := "res://assets/fx/fx_bokeh.png"       # 光斑

var _target: Node = null      # 特效挂载层(FXLayer)
var _shake_node: CanvasLayer = null  # 震动目标(棋子层)

func attach(target: Node, shake_node: CanvasLayer = null) -> void:
	_target = target
	_shake_node = shake_node

func _layer() -> Node:
	if _target != null and is_instance_valid(_target):
		return _target
	return get_tree().current_scene

## 碎裂: 小亮星四散 + 轻微下落 + Additive 发光(不挡视线, 快速消散)。普通三连用。
func spawn_shatter(pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.texture = load(SPARK)
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 7
	p.lifetime = 0.38
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 210.0
	p.gravity = Vector2(0, 360)
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.17
	p.color = color
	p.material = _add_mat()  # Additive: 发光叠加, 不挡棋盘
	p.emitting = true
	_layer().add_child(p)
	_auto_free(p, 0.55)

## 火花扩散: 无重力 + Additive。特殊棋子/爆炸用。
func spawn_explosion(pos: Vector2, color: Color, power: float = 1.0) -> void:
	var p := CPUParticles2D.new()
	p.texture = load(SPARK)
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(14.0 * power)
	p.lifetime = 0.45
	p.spread = 180.0
	p.initial_velocity_min = 150.0 * power
	p.initial_velocity_max = 330.0 * power
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.18
	p.scale_amount_max = 0.45
	p.color = color
	p.material = _add_mat()
	p.emitting = true
	_layer().add_child(p)
	_auto_free(p, 0.6)

## 行列光束: fx_trail 拉伸到 from→to + Additive + 淡出。特殊棋子行列消除用。
func spawn_beam(from: Vector2, to: Vector2, color: Color) -> void:
	if not ResourceLoader.exists(TRAIL):
		return
	var s := Sprite2D.new()
	s.texture = load(TRAIL)
	s.position = (from + to) * 0.5
	var d: Vector2 = to - from
	s.rotation = d.angle()
	var tw: float = float(s.texture.get_width())
	var th: float = float(s.texture.get_height())
	s.scale = Vector2(maxf(d.length(), 1.0) / tw, 70.0 / th)
	s.modulate = color
	s.material = _add_mat()
	_layer().add_child(s)
	var t := create_tween()
	t.tween_property(s, "modulate:a", 0.0, 0.3)
	t.tween_callback(s.queue_free)

## 屏幕震动: 抖动注册的画布层 offset。
func shake(intensity: float = 6.0) -> void:
	if _shake_node == null or not is_instance_valid(_shake_node):
		return
	var t := create_tween()
	for i in range(5):
		var off := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		t.tween_property(_shake_node, "offset", off, 0.035)
	t.tween_property(_shake_node, "offset", Vector2.ZERO, 0.05)

func _add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _auto_free(n: Node, delay: float) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(n.queue_free)
