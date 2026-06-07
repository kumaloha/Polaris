extends Node
## 特效管理器(autoload "Fx")。所有特效集中在此, 不散落到棋子脚本。
## 发光类(火花/光束)用 CanvasItemMaterial Additive + modulate 染色; 碎片类用普通 alpha 染色。
## Level._ready() 调 Fx.attach(fx_layer, shake_node) 注册画布层与震动目标。

const SPARK := "res://assets/fx/fx_spark_star.png"  # 火花/星
const SMOKE := "res://assets/fx/fx_smoke.png"       # 烟/碎屑
const TRAIL := "res://assets/fx/fx_trail.png"       # 拖尾/光束
const SHOCK := "res://assets/fx/fx_shockwave.png"   # 冲击波
const BOKEH := "res://assets/fx/fx_bokeh.png"       # 光斑
const COMET := "res://assets/fx/beam_comet_white.png"  # 流星拖尾(纯白, 行列横扫波, modulate 染色)
const MAGIC_BASIC_FLASH_BLOB := "res://art/vfx/basic_pop/vfx_basic_flash_blob.png"
const MAGIC_BASIC_FLASH_STAR := "res://art/vfx/basic_pop/vfx_basic_flash_star.png"
const MAGIC_BASIC_RING_SOFT := "res://art/vfx/basic_pop/vfx_basic_ring_soft.png"
const MAGIC_DUST_DOT := "res://art/vfx/basic_pop/vfx_dust_dot.png"
const MAGIC_DUST_STAR := "res://art/vfx/basic_pop/vfx_dust_star.png"
const MAGIC_GEM_SHARDS := [
	"res://art/vfx/basic_pop/vfx_gem_shard_01.png",
	"res://art/vfx/basic_pop/vfx_gem_shard_02.png",
	"res://art/vfx/basic_pop/vfx_gem_shard_03.png",
	"res://art/vfx/basic_pop/vfx_gem_shard_04.png",
	"res://art/vfx/basic_pop/vfx_gem_shard_05.png",
	"res://art/vfx/basic_pop/vfx_gem_shard_06.png",
]
const MAGIC_LINE_BEAM_CORE := "res://art/vfx/line_blast/vfx_beam_core.png"
const MAGIC_LINE_BEAM_GLOW := "res://art/vfx/line_blast/vfx_beam_glow.png"
const MAGIC_LINE_BEAM_CAP := "res://art/vfx/line_blast/vfx_beam_cap.png"
const MAGIC_LINE_BEAM_SPARK := "res://art/vfx/line_blast/vfx_beam_spark.png"
const MAGIC_LINE_CELL_GLOW_H := "res://art/vfx/line_blast/cell_glow_horizontal.png"
const MAGIC_LINE_CELL_GLOW_V := "res://art/vfx/line_blast/cell_glow_vertical.png"
const MAGIC_AREA_SQUARE_WAVE := "res://art/vfx/area_blast/vfx_area_square_wave.png"
const MAGIC_AREA_CUBE_FRAME := "res://art/vfx/area_blast/vfx_area_cube_frame.png"
const MAGIC_AREA_GRID_3X3 := "res://art/vfx/area_blast/vfx_area_grid_3x3.png"
const MAGIC_AREA_CUBE_SHARDS := [
	"res://art/vfx/area_blast/vfx_cube_shard_01.png",
	"res://art/vfx/area_blast/vfx_cube_shard_02.png",
	"res://art/vfx/area_blast/vfx_cube_shard_03.png",
	"res://art/vfx/area_blast/vfx_cube_shard_04.png",
]
const MAGIC_ABSORB_ORB := "res://art/vfx/color_absorb/vfx_absorb_orb.png"
const MAGIC_ABSORB_TRAIL := "res://art/vfx/color_absorb/vfx_absorb_trail.png"
const MAGIC_ABSORB_LINE := "res://art/vfx/color_absorb/vfx_absorb_line.png"
const MAGIC_ABSORB_HIT_FLASH := "res://art/vfx/color_absorb/vfx_absorb_hit_flash.png"
const MAGIC_ABSORB_TARGET_OUTLINE := "res://art/vfx/color_absorb/cell_target_outline.png"
const MAGIC_ABSORB_RESIDUE_TEXTURES := [MAGIC_DUST_STAR, MAGIC_DUST_DOT, MAGIC_BASIC_FLASH_STAR]
const ABSORB_RESIDUE_COUNT_MIN := 5
const ABSORB_RESIDUE_COUNT_MAX := 8
const ABSORB_RESIDUE_SCALE_MIN := 0.35
const ABSORB_RESIDUE_SCALE_MAX := 0.75
const ABSORB_RESIDUE_MOVE_MIN := 8.0
const ABSORB_RESIDUE_MOVE_MAX := 22.0
const ABSORB_RESIDUE_ALPHA_START := 0.8
const ABSORB_RESIDUE_ALPHA_END := 0.0
const ABSORB_RESIDUE_DURATION_MIN := 0.35
const ABSORB_RESIDUE_DURATION_MAX := 0.55
const LOCAL_BURST_CLEAR_CELLS := 9
const LOCAL_BURST_FLASH_DIAMETER_RATIO := 0.85
const LOCAL_BURST_FLASH_PEAK_SCALE := 1.05
const LOCAL_BURST_PARTICLE_TRAVEL_RATIO := 0.72
const LOCAL_BURST_INNER_STAR_COUNT := 9
const LOCAL_BURST_OUTER_WISP_COUNT := 7
const LOCAL_BURST_INNER_STAR_RADIUS_RATIO := 0.46
const LOCAL_BURST_OUTER_WISP_RADIUS_RATIO := 0.82
const LOCAL_BURST_SPIRAL_TURN_RADIANS := 1.08
const LINE_BLAST_STAGGER_SEC := 0.02

var _target: Node = null      # 特效挂载层(FXLayer)
var _shake_node: CanvasLayer = null  # 震动目标(棋子层)

func attach(target: Node, shake_node: CanvasLayer = null) -> void:
	_target = target
	_shake_node = shake_node

func _layer() -> Node:
	if _target != null and is_instance_valid(_target):
		return _target
	return get_tree().current_scene

func _asset_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		err = image.load(path)
	if err != OK:
		push_warning("Unable to load PNG texture: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

static func magic_vfx_paths() -> Dictionary:
	return {
		"basic_flash_blob": MAGIC_BASIC_FLASH_BLOB,
		"basic_flash_star": MAGIC_BASIC_FLASH_STAR,
		"basic_ring": MAGIC_BASIC_RING_SOFT,
		"line_beam_core": MAGIC_LINE_BEAM_CORE,
		"line_beam_glow": MAGIC_LINE_BEAM_GLOW,
		"line_cell_glow_h": MAGIC_LINE_CELL_GLOW_H,
		"line_cell_glow_v": MAGIC_LINE_CELL_GLOW_V,
		"area_square_wave": MAGIC_AREA_SQUARE_WAVE,
		"area_cube_frame": MAGIC_AREA_CUBE_FRAME,
		"area_grid": MAGIC_AREA_GRID_3X3,
		"absorb_orb": MAGIC_ABSORB_ORB,
		"absorb_trail": MAGIC_ABSORB_TRAIL,
		"absorb_line": MAGIC_ABSORB_LINE,
		"absorb_hit_flash": MAGIC_ABSORB_HIT_FLASH,
		"absorb_target_outline": MAGIC_ABSORB_TARGET_OUTLINE,
		"absorb_residue_star": MAGIC_DUST_STAR,
		"absorb_residue_dot": MAGIC_DUST_DOT,
		"absorb_residue_flash_star": MAGIC_BASIC_FLASH_STAR,
	}

func absorb_residue_profile() -> Dictionary:
	return {
		"count_min": ABSORB_RESIDUE_COUNT_MIN,
		"count_max": ABSORB_RESIDUE_COUNT_MAX,
		"scale_min": ABSORB_RESIDUE_SCALE_MIN,
		"scale_max": ABSORB_RESIDUE_SCALE_MAX,
		"move_min_px": ABSORB_RESIDUE_MOVE_MIN,
		"move_max_px": ABSORB_RESIDUE_MOVE_MAX,
		"alpha_start": ABSORB_RESIDUE_ALPHA_START,
		"alpha_end": ABSORB_RESIDUE_ALPHA_END,
		"duration_min": ABSORB_RESIDUE_DURATION_MIN,
		"duration_max": ABSORB_RESIDUE_DURATION_MAX,
	}

static func area_blast_profile(cell_size: float, clear_cells: int = LOCAL_BURST_CLEAR_CELLS) -> Dictionary:
	var cells_per_side := 3.0 if clear_cells <= LOCAL_BURST_CLEAR_CELLS else 5.0
	var diameter := cell_size * cells_per_side
	return {
		"clear_cells": clear_cells,
		"grid_diameter_px": diameter * 0.96,
		"square_wave_diameter_px": diameter * 0.98,
		"cube_frame_diameter_px": diameter * 0.72,
		"cube_shard_count": MAGIC_AREA_CUBE_SHARDS.size() * (2 if clear_cells <= LOCAL_BURST_CLEAR_CELLS else 3),
		"uses_round_shockwave": false,
	}

static func line_blast_profile(line_length_px: float, cell_size: float) -> Dictionary:
	return {
		"beam_core": MAGIC_LINE_BEAM_CORE,
		"beam_glow": MAGIC_LINE_BEAM_GLOW,
		"beam_cap": MAGIC_LINE_BEAM_CAP,
		"cell_glow_count": maxi(1, int(roundf(line_length_px / maxf(cell_size, 1.0)))),
		"stagger_sec": LINE_BLAST_STAGGER_SEC,
	}

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
	if _asset_exists(MAGIC_BASIC_FLASH_BLOB):
		_spawn_magic_basic_pop(pos, _color_key_to_magic_color(color), target_px)
		return
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

func spawn_target_outline(pos: Vector2, color: Color, diameter: float, delay: float = 0.0) -> void:
	_magic_flash_sprite(MAGIC_ABSORB_TARGET_OUTLINE, pos, color, diameter * 0.72, diameter, 0.42, delay)

func spawn_absorb_residue(global_pos: Vector2, color: Color) -> void:
	var count := randi_range(ABSORB_RESIDUE_COUNT_MIN, ABSORB_RESIDUE_COUNT_MAX)
	var layer := _layer()
	for i in range(count):
		var path: String = String(MAGIC_ABSORB_RESIDUE_TEXTURES[i % MAGIC_ABSORB_RESIDUE_TEXTURES.size()])
		if not _asset_exists(path):
			continue
		var tex := _load_texture(path)
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		var dust_color := color.lerp(Color(1, 1, 1, 1), 0.16)
		dust_color.a = ABSORB_RESIDUE_ALPHA_START
		s.modulate = dust_color
		s.rotation = randf_range(-0.35, 0.35)
		var start_scale := randf_range(ABSORB_RESIDUE_SCALE_MIN, ABSORB_RESIDUE_SCALE_MAX)
		s.scale = Vector2(start_scale, start_scale)
		layer.add_child(s)
		s.global_position = global_pos
		var angle := TAU * (float(i) / float(count)) + randf_range(-0.35, 0.35)
		var dist := randf_range(ABSORB_RESIDUE_MOVE_MIN, ABSORB_RESIDUE_MOVE_MAX)
		var dur := randf_range(ABSORB_RESIDUE_DURATION_MIN, ABSORB_RESIDUE_DURATION_MAX)
		var end_pos := global_pos + Vector2.RIGHT.rotated(angle) * dist
		var t := create_tween().set_parallel(true)
		t.tween_property(s, "global_position", end_pos, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "rotation", s.rotation + randf_range(-0.75, 0.75), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "scale", s.scale * randf_range(0.55, 0.86), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "modulate:a", ABSORB_RESIDUE_ALPHA_END, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_auto_free(s, dur + 0.08)

func spawn_color_absorb_orb(from: Vector2, to: Vector2, color: Color, delay: float = 0.0, dur: float = 0.46) -> void:
	if not _asset_exists(MAGIC_ABSORB_ORB):
		return
	var tex := _load_texture(MAGIC_ABSORB_ORB)
	if tex == null:
		return
	var orb := Sprite2D.new()
	orb.texture = tex
	orb.position = from
	orb.modulate = color.lerp(Color(1, 1, 1, 1), 0.42)
	orb.material = _add_mat()
	orb.scale = Vector2(0.10, 0.10)
	_layer().add_child(orb)
	var control := (from + to) * 0.5 + Vector2(-(to - from).y, (to - from).x).normalized() * 48.0
	_spawn_absorb_trail(from, to, control, color, delay + dur * 0.16, dur * 0.94)
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(orb, "scale", Vector2(0.18, 0.18), dur * 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void: orb.position = _quad_bezier(from, control, to, v), 0.0, 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(orb, "scale", Vector2(0.04, 0.04), dur * 0.38).set_delay(dur * 0.62)
	t.parallel().tween_property(orb, "modulate:a", 0.0, dur * 0.22).set_delay(dur * 0.78)
	t.tween_callback(func() -> void:
		_magic_flash_sprite(MAGIC_ABSORB_HIT_FLASH, to, color.lerp(Color(1, 1, 1, 1), 0.34), 22.0, 62.0, 0.22)
	)
	_auto_free(orb, delay + dur + 0.22)

func _spawn_absorb_trail(from: Vector2, to: Vector2, control: Vector2, color: Color, delay: float, dur: float) -> void:
	if not _asset_exists(MAGIC_ABSORB_TRAIL):
		return
	var tex := _load_texture(MAGIC_ABSORB_TRAIL)
	if tex == null:
		return
	var direction := to - from
	var angle := direction.angle()
	var trail_color := color.lerp(Color(1, 1, 1, 1), 0.24)
	trail_color.a = 0.42
	for i in range(3):
		var trail := Sprite2D.new()
		trail.texture = tex
		trail.position = from
		trail.rotation = angle
		trail.modulate = trail_color
		trail.material = _add_mat()
		trail.scale = Vector2(0.18 - 0.035 * float(i), 0.10 - 0.018 * float(i))
		_layer().add_child(trail)
		var step_delay := delay + 0.055 * float(i)
		var t := create_tween()
		if step_delay > 0.0:
			t.tween_interval(step_delay)
		t.set_parallel(true)
		t.tween_method(func(v: float) -> void:
			trail.position = _quad_bezier(from, control, to, v)
		, 0.0, 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(trail, "modulate:a", 0.0, dur).set_delay(dur * 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(trail, "scale", trail.scale * 0.55, dur).set_delay(dur * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_auto_free(trail, step_delay + dur + 0.10)

## 局部爆裂(炸弹/十字 3x3 或十字+十字 5x5): 纯粒子全向爆发 + 小中心闪, 扩散严格卡在 radius_px(实际清除边界)内,
## 不放冲击波环(那个会外溢)。美术原则: 动画范围 ≤ 实际效果范围。
static func local_burst_bounds(clear_radius_px: float, clear_cells: int = LOCAL_BURST_CLEAR_CELLS) -> Dictionary:
	var flash_diameter := clear_radius_px * LOCAL_BURST_FLASH_DIAMETER_RATIO
	var outer_wisp_radius := clear_radius_px * LOCAL_BURST_OUTER_WISP_RADIUS_RATIO
	return {
		"clear_cells": clear_cells,
		"clear_radius_px": clear_radius_px,
		"flash_diameter_px": flash_diameter,
		"flash_peak_radius_px": flash_diameter * LOCAL_BURST_FLASH_PEAK_SCALE * 0.5,
		"particle_max_distance_px": maxf(clear_radius_px * LOCAL_BURST_PARTICLE_TRAVEL_RATIO, outer_wisp_radius),
		"inner_star_count": LOCAL_BURST_INNER_STAR_COUNT,
		"outer_wisp_count": LOCAL_BURST_OUTER_WISP_COUNT,
		"inner_star_radius_px": clear_radius_px * LOCAL_BURST_INNER_STAR_RADIUS_RATIO,
		"outer_wisp_radius_px": outer_wisp_radius,
		"spiral_turn_radians": LOCAL_BURST_SPIRAL_TURN_RADIANS,
	}

func spawn_local_burst(pos: Vector2, color: Color, radius_px: float, clear_cells: int = LOCAL_BURST_CLEAR_CELLS) -> void:
	if _asset_exists(MAGIC_AREA_GRID_3X3):
		_spawn_magic_area_blast(pos, color, radius_px, clear_cells)
		return
	var bounds := local_burst_bounds(radius_px, clear_cells)
	# 中心闪: 直径压在范围内
	_flash(pos, color.lerp(Color(1, 1, 1, 1), 0.5), bounds["flash_diameter_px"], 0.18)
	var star_color: Color = color.lerp(Color(1, 1, 1, 1), 0.30)
	var wisp_color: Color = color.lerp(Color(1, 1, 1, 1), 0.42)
	wisp_color.a = 0.78
	var inner_count: int = int(bounds["inner_star_count"])
	for i in range(inner_count):
		var f: float = float(i) / float(inner_count)
		var angle: float = TAU * f + (0.18 if i % 2 == 0 else -0.11)
		var twist: float = bounds["spiral_turn_radians"] * (1.0 if i % 2 == 0 else -0.72)
		var end_radius: float = bounds["inner_star_radius_px"] * (0.82 + 0.07 * float(i % 3))
		var delay: float = 0.012 * float(i % 3)
		_magic_burst_sprite(SPARK, pos, star_color, angle, radius_px * 0.08, end_radius, twist, radius_px * 0.15, radius_px * 0.045, delay, 0.36)
	var outer_count: int = int(bounds["outer_wisp_count"])
	for i in range(outer_count):
		var f: float = (float(i) + 0.5) / float(outer_count)
		var angle: float = TAU * f
		var twist: float = -bounds["spiral_turn_radians"] * (0.45 + 0.08 * float(i % 2))
		var end_radius: float = bounds["outer_wisp_radius_px"] * (0.86 + 0.05 * float(i % 3))
		var delay: float = 0.024 + 0.014 * float(i % 4)
		_magic_burst_sprite(BOKEH, pos, wisp_color, angle, radius_px * 0.18, end_radius, twist, radius_px * 0.18, radius_px * 0.07, delay, 0.44)

func _magic_burst_sprite(tex_path: String, pos: Vector2, color: Color, angle: float, start_radius: float, end_radius: float, twist: float, start_diameter: float, end_diameter: float, delay: float, dur: float) -> void:
	if not _asset_exists(tex_path):
		return
	var tex := _load_texture(tex_path)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos + Vector2.RIGHT.rotated(angle) * start_radius
	s.modulate = color
	s.rotation = angle
	s.material = _add_mat()
	var start_scale: float = start_diameter / maxf(float(tex.get_width()), 1.0)
	var end_scale: float = end_diameter / maxf(float(tex.get_width()), 1.0)
	s.scale = Vector2(start_scale, start_scale)
	_layer().add_child(s)
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(s, "position", pos + Vector2.RIGHT.rotated(angle + twist) * end_radius, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "rotation", angle + twist * 1.6, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "scale", Vector2(end_scale, end_scale), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur).set_delay(dur * 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_auto_free(s, delay + dur + 0.12)

func _color_key_to_magic_color(color_key: String) -> Color:
	match color_key:
		"red":
			return Color(1.0, 0.18, 0.08, 1.0)
		"blue":
			return Color(0.1, 0.75, 1.0, 1.0)
		"green":
			return Color(0.45, 1.0, 0.1, 1.0)
		"gold":
			return Color(1.0, 0.78, 0.12, 1.0)
		"purple":
			return Color(0.55, 0.25, 1.0, 1.0)
		"pink":
			return Color(1.0, 0.25, 0.65, 1.0)
		_:
			return Color(1, 1, 1, 1)

func _quad_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

func _spawn_magic_basic_pop(pos: Vector2, color: Color, target_px: float) -> void:
	var hot := color.lerp(Color(1, 1, 1, 1), 0.62)
	_magic_flash_sprite(MAGIC_BASIC_FLASH_BLOB, pos, hot, target_px * 0.42, target_px * 1.05, 0.18, 0.08)
	_magic_flash_sprite(MAGIC_BASIC_FLASH_STAR, pos, Color(1, 1, 1, 1), target_px * 0.28, target_px * 1.16, 0.18, 0.10)
	_magic_flash_sprite(MAGIC_BASIC_RING_SOFT, pos, color, target_px * 0.36, target_px * 1.08, 0.24, 0.11)
	_magic_shard_burst(MAGIC_GEM_SHARDS, pos, hot, 8, target_px * 0.52, 0.28, 0.10)
	_magic_shard_burst([MAGIC_DUST_DOT, MAGIC_DUST_STAR], pos, color.lerp(Color(1, 1, 1, 1), 0.35), 7, target_px * 0.38, 0.34, 0.16)

func _spawn_magic_area_blast(pos: Vector2, color: Color, radius_px: float, clear_cells: int) -> void:
	var cells_per_side := 3.0 if clear_cells <= LOCAL_BURST_CLEAR_CELLS else 5.0
	var cell_size := radius_px / (cells_per_side * 0.5)
	var profile := area_blast_profile(cell_size, clear_cells)
	var glow := color.lerp(Color(1, 1, 1, 1), 0.45)
	_magic_flash_sprite(MAGIC_AREA_CUBE_FRAME, pos, glow, float(profile["cube_frame_diameter_px"]) * 0.35, float(profile["cube_frame_diameter_px"]), 0.34, 0.05, PI * 0.25)
	_magic_flash_sprite(MAGIC_AREA_GRID_3X3, pos, glow, float(profile["grid_diameter_px"]) * 0.65, float(profile["grid_diameter_px"]), 0.38, 0.10)
	_magic_flash_sprite(MAGIC_AREA_SQUARE_WAVE, pos, color, float(profile["square_wave_diameter_px"]) * 0.40, float(profile["square_wave_diameter_px"]), 0.48, 0.16)
	_magic_shard_burst(MAGIC_AREA_CUBE_SHARDS, pos, glow, int(profile["cube_shard_count"]), radius_px * 0.78, 0.46, 0.16)
	_flash(pos, Color(1, 1, 1, 1), radius_px * 0.68, 0.16)

func _spawn_magic_line_blast(from: Vector2, to: Vector2, color: Color) -> void:
	var dir: Vector2 = to - from
	var full_len: float = maxf(dir.length(), 1.0)
	var u: Vector2 = dir / full_len
	var center := (from + to) * 0.5
	var angle := u.angle()
	var vertical := absf(u.y) > absf(u.x)
	_magic_beam_sprite(MAGIC_LINE_BEAM_GLOW, center, angle, full_len, 112.0, color, 0.42, 0.0)
	_magic_beam_sprite(MAGIC_LINE_BEAM_CORE, center, angle, full_len, 30.0, Color(1, 1, 1, 1), 0.26, 0.02)
	_magic_beam_cap(from, angle, color, 0.32)
	_magic_beam_cap(to, angle + PI, color, 0.32)
	var profile := line_blast_profile(full_len, 88.0)
	var cell_count: int = int(profile["cell_glow_count"])
	var glow_path := MAGIC_LINE_CELL_GLOW_V if vertical else MAGIC_LINE_CELL_GLOW_H
	for i in range(cell_count):
		var f: float = 0.0 if cell_count <= 1 else float(i) / float(cell_count - 1)
		var pt: Vector2 = from.lerp(to, f)
		var delay: float = absf(f - 0.5) * 2.0 * 0.12
		_magic_flash_sprite(glow_path, pt, color, 54.0, 88.0, 0.24, delay)
	_magic_shard_burst([MAGIC_LINE_BEAM_SPARK], center, color.lerp(Color(1, 1, 1, 1), 0.35), 6, full_len * 0.14, 0.26, 0.04, angle)
	_beam_sparks(from, to, color)

func _magic_flash_sprite(tex_path: String, pos: Vector2, color: Color, start_diameter: float, end_diameter: float, dur: float, delay: float = 0.0, rotation: float = 0.0) -> void:
	if not _asset_exists(tex_path):
		return
	var tex := _load_texture(tex_path)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.rotation = rotation
	s.modulate = color
	s.material = _add_mat()
	var start_scale := start_diameter / maxf(float(tex.get_width()), 1.0)
	var end_scale := end_diameter / maxf(float(tex.get_width()), 1.0)
	s.scale = Vector2(start_scale, start_scale)
	_layer().add_child(s)
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2(end_scale, end_scale), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur).set_delay(dur * 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_auto_free(s, delay + dur + 0.12)

func _magic_shard_burst(tex_paths: Array, pos: Vector2, color: Color, count: int, radius: float, dur: float, delay: float = 0.0, angle_offset: float = 0.0) -> void:
	if tex_paths.is_empty() or count <= 0:
		return
	for i in range(count):
		var path: String = String(tex_paths[i % tex_paths.size()])
		if not _asset_exists(path):
			continue
		var tex := _load_texture(path)
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.position = pos
		var angle := angle_offset + TAU * float(i) / float(count) + 0.18 * float(i % 3)
		s.rotation = angle
		s.modulate = color
		s.material = _add_mat()
		var base_scale := 0.06 + 0.018 * float(i % 3)
		s.scale = Vector2(base_scale, base_scale)
		_layer().add_child(s)
		var end_pos := pos + Vector2.RIGHT.rotated(angle) * radius * (0.72 + 0.08 * float(i % 4))
		var t := create_tween()
		if delay > 0.0:
			t.tween_interval(delay + 0.012 * float(i % 4))
		t.set_parallel(true)
		t.tween_property(s, "position", end_pos, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "rotation", angle + PI * (0.8 + 0.15 * float(i % 3)), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "scale", Vector2(base_scale * 0.35, base_scale * 0.35), dur).set_delay(dur * 0.42)
		t.tween_property(s, "modulate:a", 0.0, dur).set_delay(dur * 0.32)
		_auto_free(s, delay + dur + 0.18)

func _magic_beam_sprite(tex_path: String, center: Vector2, angle: float, length_px: float, thickness_px: float, color: Color, dur: float, delay: float = 0.0) -> void:
	if not _asset_exists(tex_path):
		return
	var tex := _load_texture(tex_path)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.position = center
	s.rotation = angle
	s.modulate = color
	s.material = _add_mat()
	s.scale = Vector2(length_px / maxf(float(tex.get_width()), 1.0), thickness_px / maxf(float(tex.get_height()), 1.0))
	_layer().add_child(s)
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(s, "scale:y", s.scale.y * 1.16, dur * 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur).set_delay(dur * 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_auto_free(s, delay + dur + 0.14)

func _magic_beam_cap(pos: Vector2, angle: float, color: Color, dur: float) -> void:
	if not _asset_exists(MAGIC_LINE_BEAM_CAP):
		return
	var tex := _load_texture(MAGIC_LINE_BEAM_CAP)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.rotation = angle
	s.modulate = color.lerp(Color(1, 1, 1, 1), 0.25)
	s.material = _add_mat()
	s.scale = Vector2(0.28, 0.28)
	_layer().add_child(s)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2(0.42, 0.42), dur * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur).set_delay(dur * 0.35)
	_auto_free(s, dur + 0.12)

## 行列光束: 宽彩辉光 + 白热核(厚度 pop) + 沿线火花。比单条更有冲击力。
func spawn_beam(from: Vector2, to: Vector2, color: Color) -> void:
	_beam_layer(from, to, color, 100.0, 0.32)
	_beam_layer(from, to, Color(1, 1, 1, 1), 30.0, 0.24)
	_beam_sparks(from, to, color)

## 行列横扫(升级版): 一道流星头(纯白拖尾素材 × color, additive)朝飞行方向从 from 飞到 to,
## 叠加"从中心向两端错峰的亮点", 营造扫过依次炸开。逐格棋子消除由 Level._play_clear 负责,
## 此处只做横扫表现, 不重复 spawn_elimination(避免每格双播)。
func spawn_line_blast(from: Vector2, to: Vector2, color: Color) -> void:
	var dir: Vector2 = to - from
	var full_len: float = maxf(dir.length(), 1.0)
	var u: Vector2 = dir / full_len
	var origin: Vector2 = (from + to) * 0.5
	if _asset_exists(MAGIC_LINE_BEAM_CORE):
		_spawn_magic_line_blast(from, to, color)
		return
	if not ResourceLoader.exists(COMET):
		spawn_beam(from, to, color)   # 素材缺失时降级回静态光束, 不丢特效
		return
	# 流星头: 纯白素材染色 + additive, 朝飞行方向(行/列自动适配), 从一端飞到另一端。
	var tex: Texture2D = load(COMET)
	var b := Sprite2D.new()
	b.texture = tex
	b.modulate = color
	b.rotation = u.angle()
	b.material = _add_mat()
	var head_len: float = 140.0   # 流星头约 1.5~2 格宽
	var thick: float = 84.0
	b.scale = Vector2(head_len / maxf(float(tex.get_width()), 1.0), thick / maxf(float(tex.get_height()), 1.0))
	b.global_position = from
	_layer().add_child(b)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(b, "global_position", to, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(b, "modulate:a", 0.0, 0.30).set_delay(0.13).set_trans(Tween.TRANS_CUBIC)
	_auto_free(b, 0.42)
	# 从中心向两端错峰的小亮点(纯视觉节奏感)。
	var glow: Color = color.lerp(Color(1, 1, 1, 1), 0.4)
	var steps: int = clampi(int(full_len / 88.0), 1, 12)
	for i in range(steps + 1):
		var f: float = float(i) / float(steps) - 0.5    # -0.5(头)..0.5(尾)
		var pt: Vector2 = origin + u * (f * full_len)
		var delay: float = 0.20 * absf(f) * 2.0          # 中心 0 → 端点 ~0.20s
		get_tree().create_timer(delay).timeout.connect(_flash.bind(pt, glow, 66.0, 0.24))
	# 沿线两侧火花(复用)。
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
