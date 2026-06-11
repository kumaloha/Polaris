extends "res://tests/test_lib.gd"

const ClearVisuals := preload("res://match3/clear_visuals.gd")
const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const LevelMotion := preload("res://match3/level_motion.gd")
const ME := preload("res://core/match_engine.gd")


func _none_fx(w: int, h: int) -> Array:
	var fx := []
	for y in h:
		var row := []
		for x in w:
			row.append(ME.SP_NONE)
		fx.append(row)
	return fx


func _prepare_level_scene_with_real_levels() -> Node:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level._levels = LevelLibrary.load_file("res://levels.json")
	level._playable = []
	for i in range(level._levels.size()):
		var objs = level._levels[i].get("objectives", [])
		if objs is Array and not objs.is_empty():
			level._playable.append(i)
	return level



func test_bomb_blast_cells_use_trigger_gem_species() -> void:
	var grid := [
		[0, 1, 2, 3, 4],
		[1, 2, 3, 4, 5],
		[2, 3, 1, 5, 0],  # center (2,2)=blue trigger gem
		[3, 4, 5, 0, 1],
		[4, 5, 0, 1, 2],
	]
	var fx := _none_fx(5, 5)
	fx[2][2] = ME.SP_BOMB
	var cells: Array = ME.special_effect_cells(grid, Vector2i(2, 2), ME.SP_BOMB)
	var species: Dictionary = ClearVisuals.special_clear_species_overrides(grid, fx, cells)
	for p in cells:
		assert_eq(species.get(p, -1), 1, "3x3 cell %s uses trigger bomb species" % str(p))


func test_virtual_colorbomb_bombs_color_their_3x3_blast_area() -> void:
	var grid := [
		[2, 3, 4, 5, 6],
		[3, 4, 5, 6, 7],
		[4, 5, 1, 7, 2],  # virtual bomb target at (2,2)=blue
		[5, 6, 7, 2, 3],
		[6, 7, 2, 3, 4],
	]
	var fx := _none_fx(5, 5)
	var virtual_fx := {Vector2i(2, 2): ME.SP_BOMB}
	var cells: Array = ME.special_effect_cells(grid, Vector2i(2, 2), ME.SP_BOMB)
	var species: Dictionary = ClearVisuals.special_clear_species_overrides(grid, fx, cells, {}, virtual_fx)
	assert_eq(species.get(Vector2i(1, 1), -1), 1, "virtual bomb corner uses target species")
	assert_eq(species.get(Vector2i(3, 3), -1), 1, "virtual bomb corner uses target species")


func test_colorbomb_virtual_stripes_have_separate_conversion_phase() -> void:
	var virtual_fx := {
		Vector2i(1, 0): ME.SP_LINE_H,
		Vector2i(2, 1): ME.SP_LINE_V,
	}
	assert_true(ClearVisuals.colorbomb_combo_has_conversion_phase(virtual_fx), "colorbomb + 4-match specials first show converted stripes")
	assert_true(ClearVisuals.colorbomb_virtual_conversion_delay(virtual_fx) >= 0.45, "conversion phase is held long enough to read before detonation")
	assert_false(ClearVisuals.colorbomb_combo_has_conversion_phase({}), "plain colorbomb clears do not add a conversion phase")
	assert_eq(ClearVisuals.colorbomb_virtual_conversion_delay({}), 0.0, "plain colorbomb clears have no conversion delay")


func test_colorbomb_preview_centers_on_virtual_conversion_targets() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_colorbomb_absorb_preview_targets"), "Level exposes colorbomb preview target selection")
	if not level.has_method("_colorbomb_absorb_preview_targets"):
		level.free()
		return
	var cb := Vector2i(0, 0)
	var cells := [
		cb,
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(3, 2),
	]
	var virtual_targets := [Vector2i(3, 2), Vector2i(1, 1)]
	var targets: Array = level.call("_colorbomb_absorb_preview_targets", cb, cells, virtual_targets, 8)
	assert_eq(targets, [Vector2i(1, 1), Vector2i(3, 2)], "colorbomb + 4-match preview should center effects on pieces that will become 4-match specials")
	var capped: Array = level.call("_colorbomb_absorb_preview_targets", cb, cells, virtual_targets, 1)
	assert_eq(capped, [Vector2i(1, 1)], "preview budget trims the virtual target list without falling back to unrelated cleared cells")
	level.free()


func test_colorbomb_conversion_outlines_cover_every_virtual_target() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_colorbomb_conversion_outline_targets"), "Level exposes uncapped conversion outline target selection")
	if not level.has_method("_colorbomb_conversion_outline_targets"):
		level.free()
		return
	var cb := Vector2i(0, 0)
	var cells := [cb]
	var virtual_targets := []
	for y in range(5):
		for x in range(5):
			var p := Vector2i(x, y)
			if p == cb:
				continue
			cells.append(p)
			virtual_targets.append(p)
	var targets: Array = level.call("_colorbomb_conversion_outline_targets", cb, cells, virtual_targets)
	assert_eq(targets.size(), virtual_targets.size(), "every same-color conversion target gets a rectangular outline, independent of absorb orb budget")
	assert_eq(targets[0], Vector2i(1, 0), "outline targets keep stable top-to-bottom ordering")
	assert_eq(targets[targets.size() - 1], Vector2i(4, 4), "outline target selection does not drop later cells")
	level.free()


func test_colorbomb_resolve_passes_virtual_targets_to_absorb_preview() -> void:
	# _resolve_colorbomb 全程 async(改板+tween), headless 不便整跑; 虚拟目标进入预览的语义已由
	# test_colorbomb_preview_centers_on_virtual_conversion_targets / outline 行为测试覆盖。
	# 这里只降级为"关键调用存在性"(函数名), 锁住 resolve 仍把工作交给 absorb preview 这条接线。
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _resolve_colorbomb")
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	assert_true(start >= 0 and end > start, "_resolve_colorbomb can be inspected")
	if start < 0 or end <= start:
		return
	var body := src.substr(start, end - start)
	# 钉源码理由: resolve 必须经 absorb preview 出彩球吸收演出(关键调用), 不能直接清子绕过演出
	assert_true(body.contains("_play_colorbomb_absorb_preview"), "colorbomb resolve drives the absorb preview that consumes the would-be 4-match cells")


func test_colorbomb_absorb_preview_leaves_residue_and_pulses_crystal() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 残影/脉冲发生在 async 吸收预览内, headless 不便整跑; 用方法存在性锁住单贴图彩球的演出接口,
	# 并证明被移除的旧金光/内星层方法确实不存在(行为化的"移除"断言)
	assert_true(level.has_method("_pulse_colorbomb_core"), "orb impact pulses the current single-texture crystal ball")
	assert_false(level.has_method("_pulse_colorbomb_gold_glow"), "single-texture colorbomb no longer references the removed gold-glow layer")
	assert_false(level.has_method("_pulse_colorbomb_inner_stars"), "single-texture colorbomb no longer references the removed inner-stars layer")
	level.free()
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _play_colorbomb_absorb_preview")
	var end: int = src.find("func _show_colorbomb_virtual_conversion", start)
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	# 钉源码理由: 每颗被吸收宝石在源格留残影星尘(Fx.spawn_absorb_residue)是已拍板的吸收演出, async 不便整跑, 锁关键调用名
	assert_true(body.contains("Fx.spawn_absorb_residue"), "each absorbed gem leaves residue stardust at its source cell")


func test_colorbomb_resolve_has_no_final_particle_burst() -> void:
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _resolve_colorbomb")
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	assert_true(start >= 0 and end > start, "_resolve_colorbomb can be inspected")
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	# 钉源码理由: 彩球收尾只走吸收演出, 决不能再补一发通用粒子爆(spawn_explosion); 这是"吸收而非爆炸"的演出契约
	assert_true(body.contains("_play_colorbomb_absorb_preview"), "colorbomb still plays the absorb sequence")
	assert_false(body.contains("Fx.spawn_explosion"), "colorbomb absorb should not add a final generic particle burst")


func test_colorbomb_clear_fx_has_bounded_final_burst_budget() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 三个预算常量存在(读真实值非 null)
	assert_true(level.get("COLORBOMB_ABSORB_TARGET_BUDGET") != null, "colorbomb absorb preview has an explicit fanout budget")
	assert_true(level.get("COLORBOMB_FINE_CLEAR_BUDGET") != null, "colorbomb final clear has an explicit fine FX budget")
	assert_true(level.get("COLORBOMB_CLEAR_FX_BATCH_SIZE") != null, "colorbomb final clear work is batched across frames")
	# 直接调真函数证明 fanout 预算被强制执行: 传入远多于预算的目标, 结果数量不得超过预算
	level.cell_size = 100.0
	var budget: int = level.get("COLORBOMB_ABSORB_TARGET_BUDGET")
	var many: Array = []
	for i in range(budget * 3):
		many.append(Vector2i(i % 9, i / 9))
	var capped: Array = level.call("_colorbomb_absorb_preview_targets", Vector2i(-1, -1), many)
	assert_true(capped.size() <= budget, "absorb preview caps fanout to the named budget instead of bursting every target")
	level.free()
	# final clear 的"先转化再分批清且对纯彩球也跑预算"是 async 演出, 用源码锁住批处理与 yield 接线
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	# 钉源码理由: 最终清除必须分批 yield(await process_frame) 且不再一帧爆 36 个基础pop, 否则末帧掉帧(性能演出契约)
	assert_true(src.contains("COLORBOMB_FINE_CLEAR_BUDGET") and not src.contains("fine_budget: int = 36"), "final clear no longer bursts dozens of basic pops in one frame")
	var start: int = src.find("func _resolve_colorbomb")
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("await get_tree().process_frame"), "final clear FX yields between batches to avoid a last-frame spike")
	# 钉源码理由: 纯彩球(无4合1转化)也要跑 fine_budget 分批, 不能只在转化combo时分批
	assert_true(body.contains("await _show_colorbomb_virtual_conversion(virtual_fx)\n\tvar fine_budget"), "final clear FX budget runs for plain colorbombs too, not only conversion combos")


func test_level_clear_pops_gem_body_before_fade() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 读真实常量并锁住"先膨胀再炸开"的数值决策: 膨胀倍率(1.32) < 炸裂倍率(1.52)
	assert_eq(level.get("CLEAR_POP_SCALE"), 1.32, "basic clear gem body swells visibly before bursting")
	assert_eq(level.get("CLEAR_POP_TIME"), 0.117, "basic clear gem body uses the requested 1.3x slower swell phase")
	assert_true(float(level.get("CLEAR_POP_SCALE")) < float(level.get("CLEAR_BURST_SCALE")), "swell scale stays below the outward burst scale so the body pops then bursts, not collapses")
	level.free()
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _play_clear")
	var end: int = src.find("## 某已存在特效棋子", start)
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	# 钉源码理由: 膨胀(POP)必须排在炸裂(BURST)之前, 且用 SINE 不用会回弹的 Back —— 这是"消除是向外炸开"的演出顺序契约
	assert_true(body.find("base_scale * CLEAR_POP_SCALE") < body.find("base_scale * CLEAR_BURST_SCALE"), "gem body swell is scheduled before the outward burst")
	assert_true(body.contains("set_trans(Tween.TRANS_SINE)"), "basic clear swell should not use an overshooting Back tween")


func test_level_clear_stops_combo_idle_before_clear_tween() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_clear")
	assert_true(start >= 0, "_play_clear exists")
	if start < 0:
		return
	var end: int = src.find("## 某已存在特效棋子", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var stop_idx: int = body.find("_stop_combo_idle(n)")
	var base_idx: int = body.find("var base_scale: Vector2 = n.scale")
	assert_true(stop_idx >= 0, "clear animation stops any special idle tween before taking over scale/modulate")
	assert_true(stop_idx >= 0 and base_idx > stop_idx, "clear tween captures the restored base scale after stopping idle")


func test_level_clear_batches_vfx_creation_across_frames() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.get("CLEAR_FX_BATCH_SIZE") != null, "level defines a clear VFX batch size")
	level.free()
	# 大批消除的 VFX 分帧创建发生在 async _play_clear 内, headless 不便整跑; 锁住批处理与 yield 接线(性能演出契约)
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _play_clear")
	var end: int = src.find("## 某已存在特效棋子", start)
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	# 钉源码理由: _play_clear 必须按 CLEAR_FX_BATCH_SIZE 计数并 await process_frame 分帧, 否则一帧创建全部特效会末帧卡顿
	assert_true(body.contains("CLEAR_FX_BATCH_SIZE") and body.contains("await get_tree().process_frame"), "large clears yield between VFX batches instead of allocating every effect in one frame")


func test_special_spawn_clear_hold_is_snappy() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_eq(level.get("CLEAR_TIME"), 0.156, "basic clear gem body uses the requested 1.3x slower total animation")
	assert_eq(level.get("CLEAR_POP_TIME"), 0.117, "the swell phase stays in the same proportion after the 1.3x slowdown")
	assert_eq(level.get("CLEAR_POP_SCALE"), 1.32, "the swell reads clearly before the special appears")
	assert_eq(level.get("ELIM_HOLD"), 0.156, "post-clear hold matches the slower basic clear animation before freeing gems")
	level.free()


func test_spawned_combo_idle_starts_after_clear_phase() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _resolve_cascades")
	assert_true(start >= 0, "_resolve_cascades exists")
	if start < 0:
		return
	var end: int = src.find("## 阶段5 消除表现", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var play_idx: int = body.find("await _play_clear(to_clear, spawns, protected_spawn_set, raw_special_fx_cells, clear_visual_timing)")
	var overlay_idx: int = body.find("if protected_spawn_set.has(p):\n\t\t\t\t_apply_fx_overlay")
	var unfiltered_overlay_idx: int = body.find("if not cleared_this_step.has(p):\n\t\t\t\t_apply_fx_overlay")
	assert_true(play_idx >= 0, "resolve cascades plays clear animation")
	assert_true(overlay_idx > play_idx, "new 4-match specials start their idle only after the clear phase, not during nearby clear animations")
	assert_true(unfiltered_overlay_idx > overlay_idx, "new 4-match specials still receive their idle overlay when their spawn cell was filtered out of to_clear")


func test_line_blast_hit_specials_keep_explosion_visual_even_if_filtered() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_special_fx_cells_for_clear_visuals"), "Level collects raw hit special cells before account filtering")
	# 直接调真函数: 给定棋盘上有线特效的格, 收集器应返回 {格: 特效kind}, 证明原始命中特效在过滤前被保留
	level.board = Board.new(3, 3, [0, 1, 2], 0, 25, 1)
	level.board.fx = _none_fx(3, 3)
	level.board.fx[1][1] = ME.SP_LINE_H
	level.board.fx[0][2] = ME.SP_BOMB
	var collected: Dictionary = level.call("_special_fx_cells_for_clear_visuals", [Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, 0)])
	assert_eq(collected.get(Vector2i(1, 1), -1), ME.SP_LINE_H, "raw line-hit special cell is collected with its kind")
	assert_false(collected.has(Vector2i(0, 0)), "plain cells are not collected as hit specials")
	# overrides(虚拟fx)路径也应被尊重, 即使棋盘该格无特效
	var with_override: Dictionary = level.call("_special_fx_cells_for_clear_visuals", [Vector2i(0, 0)], {Vector2i(0, 0): ME.SP_LINE_V})
	assert_eq(with_override.get(Vector2i(0, 0), -1), ME.SP_LINE_V, "virtual override hit specials are collected before filtering")
	level.free()
	# _play_clear 的"视觉专用命中特效在常规清除后补放且不重复"逻辑在 async 路径内, 锁住接线
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var play_start: int = src.find("func _play_clear")
	var play_end: int = src.find("## 某已存在特效棋子", play_start)
	if play_start < 0 or play_end <= play_start:
		return
	var play_body: String = src.substr(play_start, play_end - play_start)
	# 钉源码理由: 被 account-clears 过滤掉的命中线特效仍要播爆裂(_play_special_fx_delayed)且不与常规清除重复(clear_set.has(p) 跳过), 这是"命中特效不吞演出"的契约
	assert_true(play_body.contains("for p in extra_special_fx_cells:") and play_body.contains("_play_special_fx_delayed(p, fx_kind"), "visual-only hit specials play their line/bomb explosion after regular clear cells")
	assert_true(play_body.contains("if clear_set.has(p):\n\t\t\tcontinue"), "visual-only hit specials do not duplicate normal clear animations")


func test_line_blast_visual_timing_spreads_from_trigger_and_chains_hit_specials() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_clear_visual_timing_for_triggers"), "Level exposes ordered clear visual timing")
	if not level.has_method("_clear_visual_timing_for_triggers"):
		level.free()
		return
	level.board = Board.new(5, 4, [0, 1, 2], 0, 25, 1)
	level.board.grid = [
		[0, 1, 2, 0, 1],
		[1, 2, 0, 1, 2],
		[2, 0, 1, 2, 0],
		[0, 1, 2, 0, 1],
	]
	level.board.fx = _none_fx(5, 4)
	level.board.fx[1][2] = ME.SP_LINE_H
	level.board.fx[1][4] = ME.SP_LINE_V
	var timing: Dictionary = level.call("_clear_visual_timing_for_triggers", [Vector2i(2, 1)])
	var cell_delays: Dictionary = timing.get("cell_delay", {})
	var special_delays: Dictionary = timing.get("special_delay", {})
	assert_true(absf(float(cell_delays.get(Vector2i(2, 1), -1.0)) - 0.0) < 0.001, "trigger cell starts immediately")
	assert_true(absf(float(cell_delays.get(Vector2i(1, 1), -1.0)) - 0.026) < 0.001, "line blast one-cell delay is 0.02s * 1.3")
	assert_true(absf(float(cell_delays.get(Vector2i(0, 1), -1.0)) - 0.052) < 0.001, "line blast two-cell delay is 0.04s * 1.3")
	assert_true(float(cell_delays.get(Vector2i(1, 1), -1.0)) < float(cell_delays.get(Vector2i(0, 1), -1.0)), "left side clears outward from trigger")
	assert_true(float(cell_delays.get(Vector2i(3, 1), -1.0)) < float(cell_delays.get(Vector2i(4, 1), -1.0)), "right side clears outward from trigger")
	assert_true(absf(float(special_delays.get(Vector2i(4, 1), -1.0)) - float(cell_delays.get(Vector2i(4, 1), -2.0))) < 0.001, "hit line special triggers when the sweep reaches it")
	assert_true(absf(float(cell_delays.get(Vector2i(4, 0), -1.0)) - 0.078) < 0.001, "chained line blast delay also uses the 1.3x stagger")
	assert_true(float(cell_delays.get(Vector2i(4, 0), -1.0)) > float(special_delays.get(Vector2i(4, 1), -1.0)), "chained vertical blast clears after the hit special triggers")
	level.free()


func test_line_blast_clear_animation_uses_ordered_delays() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# 有序延迟的具体数值已由 test_line_blast_visual_timing_spreads_... 行为测试覆盖(调 _clear_visual_timing_for_triggers)
	# 这里只证明承接有序时间的延迟播放接口存在
	assert_true(level.has_method("_spawn_shatter_delayed"), "line-hit gems shatter on their ordered delay")
	assert_true(level.has_method("_play_special_fx_delayed"), "hit specials trigger on their ordered delay")
	level.free()
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var play_start: int = src.find("func _play_clear")
	var play_end: int = src.find("## 某已存在特效棋子", play_start)
	if play_start < 0 or play_end <= play_start:
		return
	var play_body: String = src.substr(play_start, play_end - play_start)
	# 钉源码理由: 清除阶段必须等有序横扫跑完(ELIM_HOLD + max_fx_delay)再下落, 否则线炸表现会被下落打断(演出时序契约)
	assert_true(play_body.contains("ELIM_HOLD + max_fx_delay"), "clear phase waits for the ordered sweep before falling")


func test_line_blast_uses_saturated_trigger_color_not_whitened_fx_color() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.get("GEM_FX_COLORS") != null, "special effects should use bright saturated VFX colors")
	assert_true(level.has_method("_line_fx_color"), "line blasts should have a dedicated saturated color helper")
	# 直接调真函数: 线炸触发色应等于饱和的 GEM_FX_COLORS, 且未被提白(蓝色仍蓝色主导, 不洗成白)
	var fx_colors: Dictionary = level.get("GEM_FX_COLORS")
	var keys: Array = level.get("GEM_KEYS")
	var blue_sp: int = keys.find("blue")
	var line_blue: Color = level.call("_line_fx_color", blue_sp)
	assert_true(line_blue.is_equal_approx(fx_colors["blue"]), "line blast color is the saturated trigger color, not a whitened variant")
	assert_true(line_blue.b > line_blue.r and line_blue.b > line_blue.g, "blue line blast stays blue-dominant (not pre-whitened toward white)")
	# 提白(lightened 0.25)会抬高最小通道把蓝洗灰; 证明真实色没有被提白
	assert_true(minf(line_blue.r, line_blue.g) < 0.5, "saturated trigger color keeps a low off-channel instead of the whitened floor")
	level.free()


func test_level_colorbomb_filters_locked_direct_clears() -> void:
	# _resolve_colorbomb 直清路径在 async 内改板, headless 不便整跑; 锁住"只清过滤后的格、绝不手工置空锁定格"的正确性契约
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _resolve_colorbomb")
	var end: int = src.find("func _play_colorbomb_absorb_preview", start)
	assert_true(start >= 0 and end > start, "_resolve_colorbomb can be inspected")
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	# 钉源码理由: 彩球直清必须经 account-clears 过滤(to_clear)+经 ME._apply_clears 应用, 决不能手工 board.grid[..]=EMPTY 绕过锁定格(冰/锁会被误清)
	assert_true(body.contains("ME._apply_clears(board.grid, board.fx, to_clear, [])"), "colorbomb direct clear applies only the account-filtered cells")
	assert_false(body.contains("board.grid[p.y][p.x] = ME.EMPTY"), "colorbomb must not manually clear locked cells")


func test_double_bomb_fusion_plays_both_burst_centers() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_play_double_bomb_fusion_fx"), "Level has an explicit two-center double-bomb fusion visual")
	level.free()
	# 双中心爆裂用 Fx 粒子(async), headless 不便验证两发; 锁住"委派给双中心助手且对两个交换后位置各发一发"的演出契约
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var fusion_start: int = src.find("func _play_fusion_fx_after_swap")
	var fusion_end: int = src.find("func _play_wide_line_fx", fusion_start)
	if fusion_start < 0 or fusion_end <= fusion_start:
		return
	var fusion_body: String = src.substr(fusion_start, fusion_end - fusion_start)
	# 钉源码理由: 双炸弹十字融合必须委派给双中心爆裂助手(不能只在单点爆), 这是"两颗交换炸弹各自可见爆裂"的视觉决策
	assert_true(fusion_body.contains("_play_double_bomb_fusion_fx(a_after, b_after)"), "double cross fusion delegates to a two-center burst helper")
	var helper_start: int = src.find("func _play_double_bomb_fusion_fx")
	var helper_end: int = src.find("func _play_wide_line_fx", helper_start)
	if helper_start < 0 or helper_end <= helper_start:
		return
	var helper_body: String = src.substr(helper_start, helper_end - helper_start)
	# 钉源码理由: 两个交换后炸弹中心(a_after/b_after)各发一发 local burst, 锁住"双中心"而非单中心
	assert_true(helper_body.contains("_cell_center(a_after.y, a_after.x)") and helper_body.contains("_cell_center(b_after.y, b_after.x)"), "both swapped bomb centers get a visible burst")
	assert_true(helper_body.count("Fx.spawn_local_burst") >= 2, "double cross fusion must emit two local burst effects")


func test_cascade_fall_tweens_land_linearly_before_next_match() -> void:
	# 钉源码理由: 级联下落必须线性(TRANS_LINEAR)落地、禁止 EASE_OUT 末段减速 —— 缓出会让宝石在落点前"飘一下"拖慢下一次自动匹配的节奏, 这是已拍板的下落手感决策, headless 无法量化 tween 缓动故锁文本
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var helper_start: int = src.find("func _queue_cascade_fall_tween")
	var helper_end: int = src.find("func _sync_collapse_segment", helper_start)
	assert_true(helper_start >= 0 and helper_end > helper_start, "cascade fall movement is centralized in an inspectable helper")
	if helper_start >= 0 and helper_end > helper_start:
		var helper_body: String = src.substr(helper_start, helper_end - helper_start)
		assert_true(helper_body.contains(".set_trans(Tween.TRANS_LINEAR)"), "ordinary cascade drops should not ease out and linger in the last few pixels")
	var sync_start: int = src.find("func _sync_collapse_segment")
	var sync_end: int = src.find("func _sync_fixed_cell_visual", sync_start)
	assert_true(sync_start >= 0 and sync_end > sync_start, "_sync_collapse_segment can be inspected")
	if sync_start >= 0 and sync_end > sync_start:
		var sync_body: String = src.substr(sync_start, sync_end - sync_start)
		# 钉源码理由: 新生成补位与已有节点都必须走同一个 _queue_cascade_fall_tween(同一无减速时长), 否则两类宝石下落速度不一致
		assert_true(sync_body.contains("_queue_cascade_fall_tween(tween, node, center,") and sync_body.contains("_queue_cascade_fall_tween(tween, node, target,"), "spawned refill and existing nodes use the same no-settle-slowdown fall tween")
	var wall_start: int = src.find("func _tween_wall_slide_node")
	var wall_end: int = src.find("func _source_none", wall_start)
	assert_true(wall_start >= 0 and wall_end > wall_start, "_tween_wall_slide_node can be inspected")
	if wall_start >= 0 and wall_end > wall_start:
		var wall_body: String = src.substr(wall_start, wall_end - wall_start)
		assert_true(wall_body.contains(".set_trans(Tween.TRANS_LINEAR)"), "wall-assisted cascade drops should keep the same apparent speed through landing")
		assert_false(wall_body.contains(".set_ease(Tween.EASE_OUT)"), "wall-assisted cascade drops must not decelerate before the next auto match")


func test_level_swap_passes_moved_position_to_first_cascade() -> void:
	# 钉源码理由: 4合1 线特效朝向必须由 match-engine 的 4-match 规则决定, 不能被交换方向(_line_kind_from_swap/cascade_preferred_line_kind)覆盖;
	# 首轮级联要把两个交换后位置都纳入生成偏好。这是已拍板的特效生成规则, async 路径不便整跑故锁接线。
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var swap_start: int = src.find("func _try_swap")
	assert_true(swap_start >= 0, "_try_swap exists")
	var swap_end: int = src.find("\n\t## 问题2", swap_start)
	if swap_end < 0:
		swap_end = src.find("\nfunc ", swap_start + 1)
	if swap_start < 0:
		return
	var swap_body: String = src.substr(swap_start, swap_end - swap_start)
	assert_false(swap_body.contains("_line_kind_from_swap"), "swap direction must not override generated line-special kind")
	assert_true(swap_body.contains("ME.swap_special_spawn_preference(board.grid, board.fx, board._layers(), b, a)"), "first cascade considers both post-swap positions for generated special placement")
	assert_true(swap_body.contains("_resolve_cascades(spawn_preference, true)"), "first cascade receives the selected post-swap special position")

	var resolve_start: int = src.find("func _resolve_cascades")
	assert_true(resolve_start >= 0, "_resolve_cascades exists")
	if resolve_start < 0:
		return
	var resolve_end: int = src.find("\nfunc ", resolve_start + 1)
	if resolve_end < 0:
		resolve_end = src.length()
	var resolve_body: String = src.substr(resolve_start, resolve_end - resolve_start)
	assert_true(resolve_body.contains("ME.collect_clears(board.grid, board.fx, board._layers(), cascade_preferred, ME.SP_NONE, cascade_force_preferred)"), "collect_clears receives the first-cascade target-position override")
	assert_false(resolve_body.contains("cascade_preferred_line_kind"), "line-special kind is decided by the 4-match rule, not swap direction")


func test_endgame_bonus_refills_and_stabilizes_before_result() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_endgame_bonus()")
	assert_true(start >= 0, "_play_endgame_bonus exists")
	if start < 0:
		return
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var initial_blast_idx: int = body.find("await _play_endgame_bonus_special_blast(seeds, 1)")
	var chain_idx: int = body.find("await _resolve_endgame_bonus_special_chain()")
	var result_idx: int = body.find("ENDGAME_BONUS_RESULT_HOLD")
	assert_true(initial_blast_idx >= 0, "endgame bonus sends reward specials through the shared blast helper")
	assert_true(chain_idx > initial_blast_idx, "endgame bonus starts the special-blast chain after the initial reward blast")
	assert_true(result_idx > chain_idx, "result panel waits until the board is stable")
	var blast_start: int = src.find("func _play_endgame_bonus_special_blast")
	var blast_end: int = src.find("func _resolve_endgame_bonus_special_chain", blast_start)
	assert_true(blast_start >= 0 and blast_end > blast_start, "endgame bonus blast helper can be inspected")
	if blast_start < 0 or blast_end <= blast_start:
		return
	var blast_body: String = src.substr(blast_start, blast_end - blast_start)
	var clear_idx: int = blast_body.find("ME._apply_clears(board.grid, board.fx, to_clear, [])")
	var collapse_idx: int = blast_body.find("await _collapse_and_refill()", clear_idx)
	assert_true(clear_idx >= 0, "endgame bonus applies clears")
	assert_true(collapse_idx > clear_idx, "endgame bonus refills after reward blasts")


func test_endgame_bonus_uses_in_board_conversion_matrix_before_blast() -> void:
	var f := FileAccess.open("res://match3/level.gd", FileAccess.READ)
	assert_true(f != null, "level.gd can be inspected")
	if f == null:
		return
	var level: Node = load("res://Level.tscn").instantiate()
	# 废弃的奖励光束/转化marker相关常量: 实例上读不到即证明已移除
	assert_eq(level.get("ENDGAME_BONUS_BEAM_COLOR"), null, "endgame bonus no longer has reward-beam color state")
	assert_eq(level.get("ENDGAME_BONUS_BEAM_TRAVEL"), null, "endgame bonus no longer waits on a fired beam")
	assert_eq(level.get("ENDGAME_BONUS_CONVERT_HOLD"), null, "endgame bonus uses the 5+4 conversion timing without the old extra reward-beam hold")
	assert_eq(level.get("ENDGAME_BONUS_MATRIX_PREVIEW_HOLD"), null, "endgame bonus must not add settlement-only preview timing")
	assert_eq(level.get("ENDGAME_BONUS_MATRIX_OUTLINE_FILL"), null, "endgame bonus must not use a settlement-only outline size")
	level.free()
	var src: String = f.get_as_text()
	var start: int = src.find("func _play_endgame_bonus()")
	assert_true(start >= 0, "_play_endgame_bonus exists")
	if start < 0:
		return
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	# 钉源码理由: 结算奖励改为"棋盘内 5+4 转化矩阵", 决不能再从步数数字位发射彗星光束(spawn_comet_beam)——这是已拍板的结算演出决策
	assert_false(body.contains("_topbar_moves_number_center()"), "endgame bonus does not use the moves-number anchor as a launch point")
	assert_false(body.contains("spawn_comet_beam"), "endgame bonus does not fire comet beams")
	var conversion_idx: int = body.find("await _play_endgame_bonus_conversion_matrix(picks)")
	var blast_idx: int = body.find("await _play_endgame_bonus_special_blast(seeds, 1)")
	assert_true(conversion_idx >= 0, "endgame bonus plays an in-board conversion matrix")
	assert_true(blast_idx > conversion_idx, "reward specials blast only after the conversion matrix finishes")
	var helper_start: int = src.find("func _play_endgame_bonus_conversion_matrix")
	var helper_end: int = src.find("func _play_endgame_bonus_special_blast", helper_start)
	assert_true(helper_start >= 0 and helper_end > helper_start, "endgame conversion matrix helper can be inspected")
	if helper_start < 0 or helper_end <= helper_start:
		return
	var helper_body: String = src.substr(helper_start, helper_end - helper_start)
	# 钉源码理由: 结算转化必须复用 5+4 的 absorb/conversion 预览(不发明结算专用 marker/光束), 这是"结算与 5+4 同一套演出"的统一契约; async 不便整跑故锁关键调用
	assert_true(helper_body.contains("await _play_colorbomb_absorb_preview(Vector2i(-1, -1), preview_cells, virtual_fx.keys(), _endgame_bonus_conversion_preview_center(preview_cells), false)"), "endgame bonus reuses the 5+4 absorb/matrix preview without inventing a settlement-only marker")
	assert_false(helper_body.contains("spawn_conversion_matrix_marker"), "endgame bonus does not use the abandoned custom marker")
	var outline_idx: int = helper_body.find("await _play_colorbomb_absorb_preview")
	var convert_idx: int = helper_body.find("await _show_colorbomb_virtual_conversion(virtual_fx)", outline_idx)
	assert_true(convert_idx > outline_idx, "special conversion starts after the shared 5+4 preview")
	assert_false(helper_body.contains("spawn_comet_beam"), "conversion matrix helper does not fire from the UI")


func test_endgame_bonus_reuses_colorbomb_preview_without_core_pulse() -> void:
	var level: Node = load("res://Level.tscn").instantiate()
	assert_false(level.has_method("spawn_conversion_matrix_marker"), "settlement does not keep a custom marker that differs from 5+4")
	level.free()
	# 钉源码理由: 共享的 5+4 预览必须支持(a)瞄准虚拟结算中心 end_pos_override (b)关闭核心脉冲 pulse_core, 才能被结算无源复用; 这是签名级复用契约
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _play_colorbomb_absorb_preview")
	var end: int = src.find("func _colorbomb_node_at", start)
	assert_true(start >= 0 and end > start, "colorbomb preview helper can be inspected")
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	assert_true(body.contains("end_pos_override: Variant = null"), "the shared 5+4 preview can be aimed at a virtual settlement center")
	assert_true(body.contains("if pulse_core:"), "endgame can disable the single colorbomb core pulse")


func test_endgame_bonus_spends_visible_moves_without_per_beam_fire_sequence() -> void:
	var level: Node = load("res://Level.tscn").instantiate()
	assert_true(level.has_method("_display_moves_left"), "topbar can use a temporary moves display value")
	assert_true(level.has_method("_set_moves_display_override"), "endgame bonus can update only the moves counter text")
	assert_true(level.has_method("_clear_moves_display_override"), "endgame bonus clears the temporary moves display after the animation")
	level.free()
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _play_endgame_bonus()")
	assert_true(start >= 0, "_play_endgame_bonus exists")
	if start < 0:
		return
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var capture_idx: int = body.find("var bonus_moves: int = maxi(board.moves_left, 0)")
	var prepare_idx: int = body.find("var picks: Array = board.prepare_endgame_bonus_lines()")
	var spend_idx: int = body.find("_set_moves_display_override(0)", prepare_idx)
	var conversion_idx: int = body.find("await _play_endgame_bonus_conversion_matrix(picks)", spend_idx)
	var clear_idx: int = body.find("_clear_moves_display_override()", conversion_idx)
	assert_true(capture_idx >= 0 and capture_idx < prepare_idx, "endgame bonus captures the visible moves count before Board spends it")
	assert_true(spend_idx > prepare_idx, "endgame bonus spends the visible moves count once instead of decrementing per fired beam")
	assert_true(conversion_idx > spend_idx, "board conversion starts after the moves count is visibly spent")
	assert_true(clear_idx > conversion_idx, "temporary moves display is cleared after board conversion and blasts")
	# 钉源码理由: 结算只把可见步数一次性花掉(显示置0), 决不能每发一束减一步(bonus_moves -= 1), 这是"步数一次消耗"的演出决策
	assert_false(body.contains("bonus_moves = maxi(bonus_moves - 1, 0)"), "endgame bonus no longer decrements once per beam")


func test_endgame_bonus_loops_special_blasts_until_plain_board() -> void:
	# _play_endgame_bonus 是长 async 协程(转化→爆裂→链式), headless 不便整跑; 锁住"初爆后进链式自动爆"的演出顺序契约
	var src := FileAccess.get_file_as_string("res://match3/level.gd")
	var start: int = src.find("func _play_endgame_bonus()")
	assert_true(start >= 0, "_play_endgame_bonus exists")
	if start < 0:
		return
	var end: int = src.find("# 程序绘制", start)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	# 初始奖励爆裂在前, 链式解算在后(find<find 同时隐含两者都存在)
	assert_true(body.find("await _play_endgame_bonus_special_blast(seeds, 1)") < body.find("await _resolve_endgame_bonus_special_chain()") and body.find("await _resolve_endgame_bonus_special_chain()") >= 0, "special chain starts after the initial reward blast")
	var chain_start: int = src.find("func _resolve_endgame_bonus_special_chain")
	var chain_end: int = src.find("func _endgame_bonus_special_seeds", chain_start)
	assert_true(chain_start >= 0 and chain_end > chain_start, "endgame special chain helper can be inspected")
	if chain_start < 0 or chain_end <= chain_start:
		return
	var chain_body: String = src.substr(chain_start, chain_end - chain_start)
	# 钉源码理由: 链式爆裂必须有上限护栏(ENDGAME_BONUS_SPECIAL_CHAIN_MAX)并循环"先级联成型→找新特效→自动爆", 锁住"结算自动连爆直到无特效"的演出逻辑
	assert_true(chain_body.contains("while guard < ENDGAME_BONUS_SPECIAL_CHAIN_MAX") and chain_body.contains("await _resolve_cascades()"), "endgame special chain is guarded and lets falling matches form specials each loop")
	assert_true(chain_body.contains("_endgame_bonus_special_seeds()") and chain_body.contains("await _play_endgame_bonus_special_blast(seeds"), "each loop searches for newly formed specials and auto-blasts the remaining batch")


func test_endgame_bonus_special_seed_scan_finds_only_active_specials() -> void:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	assert_true(level.has_method("_endgame_bonus_special_seeds"), "Level exposes endgame special seed scanning")
	if not level.has_method("_endgame_bonus_special_seeds"):
		level.free()
		return
	level.board = Board.new(4, 3, [0, 1, 2], 0, 25, 1)
	level.board.grid = [
		[0, 1, 2, 0],
		[1, ME.EMPTY, 2, ME.WALL],
		[2, 1, 0, 2],
	]
	level.board.fx = [
		[ME.SP_NONE, ME.SP_LINE_H, ME.SP_NONE, ME.SP_BOMB],
		[ME.SP_LINE_V, ME.SP_BOMB, ME.SP_COLORBOMB, ME.SP_LINE_H],
		[ME.SP_NONE, ME.SP_NONE, ME.SP_COLORBOMB, ME.SP_NONE],
	]
	var seeds: Array = level.call("_endgame_bonus_special_seeds")
	assert_true(seeds.has(Vector2i(1, 0)), "line special on a gem is a bonus seed")
	assert_true(seeds.has(Vector2i(3, 0)), "bomb special on a gem is a bonus seed")
	assert_true(seeds.has(Vector2i(0, 1)), "vertical line special on a gem is a bonus seed")
	assert_true(seeds.has(Vector2i(2, 1)), "colorbomb special on a gem is a bonus seed")
	assert_true(seeds.has(Vector2i(2, 2)), "newly formed colorbomb after a fall is a bonus seed")
	assert_false(seeds.has(Vector2i(1, 1)), "stale fx on empty cells is ignored")
	assert_false(seeds.has(Vector2i(3, 1)), "stale fx on wall cells is ignored")
	level.free()
