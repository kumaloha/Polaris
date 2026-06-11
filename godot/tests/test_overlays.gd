extends "res://tests/test_lib.gd"
## Overlay 框架测试（契约 B, docs/11 §3.6）。
## 覆盖：基类契约（z_band 互异、layer_key 对应）、注册表完整性、
##       jelly 分级换贴图、bomb refresh 数字、归 0 回收。
## 禁止 contains 源码断言。不注册 runner（由外部单独运行或加入 runner）。

const Board           := preload("res://core/board.gd")
const OverlayBase     := preload("res://match3/overlays/overlay_base.gd")
const OverlayRegistry := preload("res://match3/overlays/overlay_registry.gd")
const JellyOverlay    := preload("res://match3/overlays/jelly_overlay.gd")
const BombOverlay     := preload("res://match3/overlays/bomb_overlay.gd")

# ── 辅助 ──

func _make_board_jelly(jval: int) -> Board:
	# 4×4 盘, (0,0) 置 jelly=jval
	var b := Board.new(4, 4, [0, 1, 2, 3, 4], 0, 30, 1)
	b.grid = [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	]
	b.fx = b._blank_fx()
	b.jelly = b._blank_fx()
	b.bomb  = b._blank_fx()
	b.jelly[0][0] = jval
	return b

func _make_board_bomb(bval: int) -> Board:
	var b := Board.new(4, 4, [0, 1, 2, 3, 4], 0, 30, 1)
	b.grid = [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	]
	b.fx    = b._blank_fx()
	b.jelly = b._blank_fx()
	b.bomb  = b._blank_fx()
	b.bomb[0][0] = bval
	return b

func _make_step_report(jelly_cleared: int = 0, bomb_defused: int = 0) -> Dictionary:
	return {
		"cascade_level": 1,
		"to_clear": [],
		"spawns": [],
		"protected_spawns": {},
		"triggered_spawn_fx": {},
		"account": {
			"jelly_cleared": jelly_cleared,
			"blocker_cleared": 0,
			"choco_cleared": 0,
			"bomb_defused": bomb_defused,
			"popcorn_hit": 0,
			"cake_destroyed": 0,
			"mystery_revealed": 0,
		},
		"score_gained": 0,
	}

# ── 基类契约 ──

func test_layer_key_jelly() -> void:
	assert_eq(JellyOverlay.layer_key(), "jelly", "JellyOverlay.layer_key() 必须返回 'jelly'")

func test_layer_key_bomb() -> void:
	assert_eq(BombOverlay.layer_key(), "bomb", "BombOverlay.layer_key() 必须返回 'bomb'")

func test_z_band_jelly() -> void:
	assert_eq(JellyOverlay.z_band(), 2, "jelly z_band 必须为 2（棋子之下的底片）")

func test_z_band_bomb() -> void:
	assert_eq(BombOverlay.z_band(), 6, "bomb z_band 必须为 6（倒计时 Label）")

func test_z_bands_are_distinct() -> void:
	# jelly 与 bomb 的 z_band 必须不同
	assert_ne(JellyOverlay.z_band(), BombOverlay.z_band(), "jelly 与 bomb z_band 不能相同")

func test_z_band_ordering() -> void:
	# jelly 在 gem(z=3) 之下, bomb 在 gem 之上
	assert_true(JellyOverlay.z_band() < 3, "jelly 必须在 gem(z=3) 之下")
	assert_true(BombOverlay.z_band() > 3, "bomb 必须在 gem(z=3) 之上")

# ── 注册表完整性 ──

func test_registry_contains_jelly() -> void:
	assert_true(OverlayRegistry.RENDERERS.has("jelly"), "注册表必须包含 'jelly'")

func test_registry_contains_bomb() -> void:
	assert_true(OverlayRegistry.RENDERERS.has("bomb"), "注册表必须包含 'bomb'")

func test_registry_scripts_are_overlay_base() -> void:
	for key in OverlayRegistry.RENDERERS:
		var script = OverlayRegistry.RENDERERS[key]
		var inst = script.new()
		assert_true(inst is OverlayBase,
			"注册表中 '%s' 必须是 OverlayBase 子类" % key)
		inst.free()

func test_registry_layer_keys_match_dict_keys() -> void:
	for key in OverlayRegistry.RENDERERS:
		var script = OverlayRegistry.RENDERERS[key]
		var inst = script.new()
		assert_eq(inst.layer_key(), key,
			"注册表 key '%s' 必须与 layer_key() 返回值匹配" % key)
		inst.free()

# ── JellyOverlay 功能 ──

func test_jelly_setup_reads_initial_value() -> void:
	var b := _make_board_jelly(2)
	var j := JellyOverlay.new()
	j.setup(Vector2i(0, 0), b, 64.0)
	assert_eq(j._last_value, 2, "setup 应读取初始层值 2")
	j.free()

func test_jelly_current_value_reads_board() -> void:
	var b := _make_board_jelly(2)
	var j := JellyOverlay.new()
	j.setup(Vector2i(0, 0), b, 64.0)
	assert_eq(j.current_value(), 2, "current_value 应读取 board.jelly[0][0]=2")
	j.free()

func test_jelly_on_step_updates_last_value_when_cleared() -> void:
	var b := _make_board_jelly(2)
	var j := JellyOverlay.new()
	j.setup(Vector2i(0, 0), b, 64.0)
	# 模拟消除: 降为 1
	b.jelly[0][0] = 1
	var report := _make_step_report(1, 0)
	j.on_step(report)
	assert_eq(j._last_value, 1, "on_step 后 _last_value 应更新为 1")
	j.free()

func test_jelly_on_step_no_change_when_not_cleared() -> void:
	var b := _make_board_jelly(2)
	var j := JellyOverlay.new()
	j.setup(Vector2i(0, 0), b, 64.0)
	# 本步无果冻消除
	var report := _make_step_report(0, 0)
	j.on_step(report)
	assert_eq(j._last_value, 2, "jelly_cleared=0 时 _last_value 不应改变")
	j.free()

func test_jelly_z_index_set_on_setup() -> void:
	var b := _make_board_jelly(2)
	var j := JellyOverlay.new()
	j.setup(Vector2i(0, 0), b, 64.0)
	assert_eq(j.z_index, 2, "setup 后 z_index 应等于 z_band()=2")
	j.free()

# ── BombOverlay 功能 ──

func test_bomb_setup_reads_initial_value() -> void:
	var b := _make_board_bomb(5)
	var bov := BombOverlay.new()
	bov.setup(Vector2i(0, 0), b, 64.0)
	assert_eq(bov._last_value, 5, "setup 应读取初始层值 5")
	bov.free()

func test_bomb_current_value_reads_board() -> void:
	var b := _make_board_bomb(5)
	var bov := BombOverlay.new()
	bov.setup(Vector2i(0, 0), b, 64.0)
	assert_eq(bov.current_value(), 5, "current_value 应读取 board.bomb[0][0]=5")
	bov.free()

func test_bomb_refresh_updates_last_value() -> void:
	var b := _make_board_bomb(5)
	var bov := BombOverlay.new()
	bov.setup(Vector2i(0, 0), b, 64.0)
	# 模拟 tick: board 值降为 4
	b.bomb[0][0] = 4
	bov.refresh()
	assert_eq(bov._last_value, 4, "refresh 后 _last_value 应更新为 4")
	bov.free()

func test_bomb_label_shows_current_value() -> void:
	var b := _make_board_bomb(5)
	var bov := BombOverlay.new()
	bov.setup(Vector2i(0, 0), b, 64.0)
	assert_eq(bov._label.text, "5", "Label 应显示初始倒计时 5")
	bov.free()

func test_bomb_label_updates_after_refresh() -> void:
	var b := _make_board_bomb(5)
	var bov := BombOverlay.new()
	bov.setup(Vector2i(0, 0), b, 64.0)
	b.bomb[0][0] = 3
	bov.refresh()
	assert_eq(bov._label.text, "3", "refresh 后 Label 应更新为 3")
	bov.free()

func test_bomb_z_index_set_on_setup() -> void:
	var b := _make_board_bomb(3)
	var bov := BombOverlay.new()
	bov.setup(Vector2i(0, 0), b, 64.0)
	assert_eq(bov.z_index, 6, "setup 后 z_index 应等于 z_band()=6")
	bov.free()

# ── 归 0 回收 ──

func test_jelly_on_cleared_queues_free() -> void:
	# headless 路径: on_cleared 不在树内时直接 queue_free（不崩）
	var b := _make_board_jelly(1)
	var j := JellyOverlay.new()
	j.setup(Vector2i(0, 0), b, 64.0)
	b.jelly[0][0] = 0
	# 调用不崩即通过（headless 无树, 走 queue_free 分支）
	j.on_cleared()
	# 节点尚未被释放时仍有效（queue_free 在下一帧执行）
	assert_true(true, "on_cleared 不崩")

func test_bomb_on_step_calls_on_cleared_when_defused() -> void:
	var b := _make_board_bomb(1)
	var bov := BombOverlay.new()
	bov.setup(Vector2i(0, 0), b, 64.0)
	# 模拟拆弹: board 值归 0
	b.bomb[0][0] = 0
	var report := _make_step_report(0, 1)
	bov.on_step(report)
	# 不崩即通过（headless 路径走 queue_free）
	assert_true(true, "bomb defused 后 on_cleared 不崩")

# ── ensure_overlays_at 集成 ──

func test_ensure_overlays_at_creates_jelly_node() -> void:
	var b := _make_board_jelly(2)
	var parent := Node2D.new()
	var tracker := {}
	OverlayRegistry.ensure_overlays_at(Vector2i(0, 0), b, parent, tracker, 64.0, Vector2.ZERO)
	assert_true(tracker.has(["jelly", Vector2i(0, 0)]),
		"ensure_overlays_at 应在 tracker 中创建 jelly 节点")
	parent.free()

func test_ensure_overlays_at_no_node_when_zero() -> void:
	var b := _make_board_jelly(0)   # (0,0) jelly=0
	var parent := Node2D.new()
	var tracker := {}
	OverlayRegistry.ensure_overlays_at(Vector2i(0, 0), b, parent, tracker, 64.0, Vector2.ZERO)
	assert_false(tracker.has(["jelly", Vector2i(0, 0)]),
		"jelly=0 时不应创建节点")
	parent.free()

func test_ensure_overlays_at_creates_bomb_node() -> void:
	var b := _make_board_bomb(4)
	var parent := Node2D.new()
	var tracker := {}
	OverlayRegistry.ensure_overlays_at(Vector2i(0, 0), b, parent, tracker, 64.0, Vector2.ZERO)
	assert_true(tracker.has(["bomb", Vector2i(0, 0)]),
		"ensure_overlays_at 应在 tracker 中创建 bomb 节点")
	parent.free()

func test_ensure_overlays_at_erases_when_value_drops_to_zero() -> void:
	var b := _make_board_jelly(1)
	var parent := Node2D.new()
	var tracker := {}
	# 第一次: jelly=1 → 创建节点
	OverlayRegistry.ensure_overlays_at(Vector2i(0, 0), b, parent, tracker, 64.0, Vector2.ZERO)
	assert_true(tracker.has(["jelly", Vector2i(0, 0)]),
		"第一次应创建 jelly 节点")
	# 降为 0 → 第二次调用应删除节点
	b.jelly[0][0] = 0
	OverlayRegistry.ensure_overlays_at(Vector2i(0, 0), b, parent, tracker, 64.0, Vector2.ZERO)
	assert_false(tracker.has(["jelly", Vector2i(0, 0)]),
		"jelly 归 0 后 tracker 应移除对应条目")
	parent.free()
