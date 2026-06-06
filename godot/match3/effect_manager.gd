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

## 消除魔法特效: 3帧发光帧(蓄力charge_up→炸裂burst→消散dissipate), additive。
## 双精灵 alpha 交叉淡化平滑过渡, 约0.34s。
const ELIM_DIR := "res://assets/fx/elim/"
const ELIM_COLORS := ["red", "blue", "green", "gold", "purple", "pink"]

func _elim_frames(color: String) -> Array:
	var c: String = color if ELIM_COLORS.has(color) else "purple"
	return [
		load(ELIM_DIR + "gem_%s_charge_up_additive.png" % c) as Texture2D,
		load(ELIM_DIR + "gem_%s_burst_additive.png" % c) as Texture2D,
		load(ELIM_DIR + "gem_%s_dissipate_additive.png" % c) as Texture2D,
	]

func spawn_elimination(color: String, pos: Vector2, target_px: float) -> void:
	var fr: Array = _elim_frames(color)
	var f0: Texture2D = fr[0]
	if f0 == null:
		return
	var f1: Texture2D = fr[1]
	var f2: Texture2D = fr[2]
	# 双精灵交叉淡化(无自定义 shader, 实机可靠): 容器统一缩放, 两层相邻帧 A淡出/B淡入重叠过渡。
	var root := Node2D.new()
	root.position = pos
	var b: float = target_px / maxf(float(f0.get_width()), 1.0)
	root.scale = Vector2(b, b)
	_layer().add_child(root)
	var la := Sprite2D.new()
	la.material = _add_mat()
	la.texture = f0  # 帧1 charge_up
	root.add_child(la)
	var lb := Sprite2D.new()
	lb.material = _add_mat()
	lb.texture = f1  # 帧2 burst(预备, 先隐)
	lb.modulate.a = 0.0
	root.add_child(lb)
	var tw := create_tween()
	# ① charge_up: 蓄力(先收)
	tw.tween_property(root, "scale", Vector2(b, b) * 0.92, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# ② charge_up ⤳ burst: la 淡出 / lb 淡入(重叠) + 放大
	tw.tween_property(la, "modulate:a", 0.0, 0.11)
	tw.parallel().tween_property(lb, "modulate:a", 1.0, 0.11)
	tw.parallel().tween_property(root, "scale", Vector2(b, b) * 1.4, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# ③ burst ⤳ dissipate: la 换帧3 淡入 / lb 淡出(重叠) + 微扩
	tw.tween_callback(func() -> void: la.texture = f2)
	tw.tween_property(la, "modulate:a", 1.0, 0.07)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.07)
	tw.parallel().tween_property(root, "scale", Vector2(b, b) * 1.5, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# ④ dissipate 淡出
	tw.tween_property(la, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(root, "scale", Vector2(b, b) * 1.56, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_auto_free(root, 0.40)

## 爆炸(炸弹/彩球): 中心亮闪 + 冲击波环 + 火花扩散。Additive。
func spawn_explosion(pos: Vector2, color: Color, power: float = 1.0) -> void:
	_flash(pos, color.lerp(Color(1, 1, 1, 1), 0.55), 140.0 * power, 0.22)
	_shockwave(pos, color, 150.0 * power, 0.40)
	var p := CPUParticles2D.new()
	p.texture = load(SPARK)
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(18.0 * power)
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = 170.0 * power
	p.initial_velocity_max = 360.0 * power
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.16
	p.scale_amount_max = 0.5
	p.color = color
	p.material = _add_mat()
	p.emitting = true
	_layer().add_child(p)
	_auto_free(p, 0.65)

## 行列光束: 宽彩辉光 + 白热核(厚度 pop) + 沿线火花。比单条更有冲击力。
func spawn_beam(from: Vector2, to: Vector2, color: Color) -> void:
	_beam_layer(from, to, color, 100.0, 0.32)
	_beam_layer(from, to, Color(1, 1, 1, 1), 30.0, 0.24)
	_beam_sparks(from, to, color)

## 中心亮闪(bokeh 放大 + 淡出)。
func _flash(pos: Vector2, color: Color, diameter: float, dur: float) -> void:
	if not ResourceLoader.exists(BOKEH):
		return
	var tex: Texture2D = load(BOKEH)
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.modulate = color
	s.material = _add_mat()
	var k: float = diameter / maxf(float(tex.get_width()), 1.0)
	s.scale = Vector2(k * 0.5, k * 0.5)
	_layer().add_child(s)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2(k * 1.05, k * 1.05), dur * 0.5)
	t.tween_property(s, "modulate:a", 0.0, dur)
	_auto_free(s, dur + 0.1)

## 冲击波环(shockwave 由小扩大 + 淡出)。
func _shockwave(pos: Vector2, color: Color, diameter: float, dur: float) -> void:
	if not ResourceLoader.exists(SHOCK):
		return
	var tex: Texture2D = load(SHOCK)
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.modulate = color
	s.material = _add_mat()
	var k: float = diameter / maxf(float(tex.get_width()), 1.0)
	s.scale = Vector2(k * 0.15, k * 0.15)
	_layer().add_child(s)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2(k, k), dur).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur)
	_auto_free(s, dur + 0.1)

## 单层光束(trail 拉伸, 厚度 pop + 淡出)。
func _beam_layer(from: Vector2, to: Vector2, color: Color, thick: float, dur: float) -> void:
	if not ResourceLoader.exists(TRAIL):
		return
	var tex: Texture2D = load(TRAIL)
	var s := Sprite2D.new()
	s.texture = tex
	s.position = (from + to) * 0.5
	var d: Vector2 = to - from
	s.rotation = d.angle()
	var sx: float = maxf(d.length(), 1.0) / maxf(float(tex.get_width()), 1.0)
	var sy: float = thick / maxf(float(tex.get_height()), 1.0)
	s.scale = Vector2(sx, sy * 0.35)
	s.modulate = color
	s.material = _add_mat()
	_layer().add_child(s)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale:y", sy, 0.09).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur)
	_auto_free(s, dur + 0.1)

## 沿光束方向两侧散出的火花。
func _beam_sparks(from: Vector2, to: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.texture = load(SPARK)
	p.position = (from + to) * 0.5
	p.rotation = (to - from).angle()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 20
	p.lifetime = 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(maxf((to - from).length() * 0.5, 1.0), 6.0)
	p.direction = Vector2(0, -1)  # 节点已转向光束方向 → 局部上=垂直光束(向两侧散)
	p.spread = 75.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 210.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.18
	p.color = color
	p.material = _add_mat()
	p.emitting = true
	_layer().add_child(p)
	_auto_free(p, 0.65)

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
