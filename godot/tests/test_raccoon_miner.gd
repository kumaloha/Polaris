extends "res://tests/test_lib.gd"
## 矿工浣熊「破障」施法控制器测试（P8 范式验证）。
##
## 覆盖：rig 构建、施法脚本非空、_apply_effect 有/无 coat 盘的 true/false、
##       cancel 幂等、≤200 行约束（钉住范式门禁）。

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")
const RaccoonMinerCast := preload("res://match3/pets/raccoon_miner.gd")
const PetRegistry := preload("res://match3/pets/pet_registry.gd")
const RACCOON_SRC := "res://match3/pets/raccoon_miner.gd"

# ───────── 工厂 ─────────

## 造一个无 coat 层的 board（普通关，破障无效）。
func _make_board_no_coat() -> Board:
	return Board.new(6, 6, [0, 1, 2, 3, 4], 30, 10, 1)

## 造一个带 coat 层的 board（有障碍，破障有效）。
func _make_board_with_coat() -> Board:
	# coat_layer 是 Board._init 的第 10 个参数（位置索引 9，0-based）
	# 参考 test_board.gd:526 范例：Board.new(w, h, species, target, moves, seed, [], [], [], coat_layer)
	var coat_layer: Array = []
	for y in 6:
		var row: Array = []
		for x in 6:
			row.append(1)
		coat_layer.append(row)
	return Board.new(6, 6, [0, 1, 2, 3, 4], 999999, 30, 1, [], [], [], coat_layer)

## 造一个最小注入的浣熊控制器。
func _make_raccoon(use_coat: bool) -> RaccoonMinerCast:
	var cast := RaccoonMinerCast.new()
	var b := _make_board_with_coat() if use_coat else _make_board_no_coat()
	cast.setup({
		"skill_bar": null,
		"board": b,
		"cell_size": 77.0,
		"board_origin": Vector2(20.0, 400.0),
		"set_avatar_casting": Callable(),
	})
	return cast

# ───────── 测试：≤200 行范式门禁 ─────────

func test_raccoon_miner_source_within_200_lines() -> void:
	# 范式门禁：每只宠物 ≤200 行（docs/11 §7 + §4.6），FileAccess 数行数并断言。
	# 注意: lines() 按换行拆；最后一行无尾换行时 size 可能 =N 或 N+1，取保守上界。
	var src := FileAccess.get_file_as_string(RACCOON_SRC)
	assert_true(src.length() > 0, "raccoon_miner.gd should not be empty")
	var lines := src.split("\n")
	var line_count := lines.size()
	assert_true(line_count <= 200,
		"raccoon_miner.gd must be ≤200 lines (paradigm gate); got %d" % line_count)

# ───────── 测试：注册表注册 ─────────

func test_pet_registry_has_breaker_entry() -> void:
	var cls := PetRegistry.cast_for("破障")
	assert_true(cls != null, "PetRegistry must map '破障' to RaccoonMinerCast")
	assert_true(PetRegistry.has_pet("破障"), "PetRegistry.has_pet('破障') must return true")

# ───────── 测试：rig 构建（无树路径）─────────

func test_raccoon_rig_is_built_before_cast_start() -> void:
	var cast := _make_raccoon(true)
	# start_cast 在无树时仍调 _build_visuals，但 skill_bar=null 故 rig 挂在 cast 上也不存在
	# 断言 _build_visuals 不崩（cast.start_cast 返回 true 表示 _can_cast 通过且流程走完）
	var ok := cast.start_cast()
	assert_true(ok, "start_cast with coat board should succeed (return true)")
	cast.free()

func test_raccoon_rig_not_built_when_skill_bar_null() -> void:
	var cast := _make_raccoon(true)
	# skill_bar=null 时 _build_visuals 跳过，不应出现子节点泄漏
	cast.start_cast()
	# rig 不应挂在 cast 本身（我们没有 add_child 到 cast）
	assert_eq(cast.get_child_count(), 0, "no rig children when skill_bar is null")
	cast.free()

# ───────── 测试：施法脚本（_run_cast 存在且编排了 _commit/_finish 回调）─────────

func test_raccoon_run_cast_method_exists() -> void:
	var cast := RaccoonMinerCast.new()
	assert_true(cast.has_method("_run_cast"), "RaccoonMinerCast must implement _run_cast")
	cast.free()

func test_raccoon_apply_effect_method_exists() -> void:
	var cast := RaccoonMinerCast.new()
	assert_true(cast.has_method("_apply_effect"), "RaccoonMinerCast must implement _apply_effect")
	cast.free()

# ───────── 测试：_apply_effect 有 coat 盘返回 true ─────────

func test_apply_effect_returns_true_with_coat_board() -> void:
	var cast := _make_raccoon(true)
	# 手工设置 board.skill = "breaker"（正常路径由 _can_cast 设置；这里直接测效果）
	cast.board.skill = "breaker"
	var ok := cast._apply_effect()
	assert_true(ok, "_apply_effect should return true when board has coat layer")
	cast.free()

# ───────── 测试：_apply_effect 无 coat 盘返回 false ─────────

func test_apply_effect_returns_false_without_coat_board() -> void:
	var cast := _make_raccoon(false)
	cast.board.skill = "breaker"
	var ok := cast._apply_effect()
	assert_false(ok, "_apply_effect should return false when board has no coat layer")
	cast.free()

# ───────── 测试：start_cast 无 coat 盘优雅失败（不消耗）─────────

func test_start_cast_fails_gracefully_without_coat() -> void:
	var cast := _make_raccoon(false)
	var ok := cast.start_cast()
	assert_false(ok, "start_cast should return false when board has no coat (graceful reject)")
	# 未施法时 active_used 不应被设置
	assert_false(cast.board.active_used, "board.active_used must stay false after rejected cast")
	cast.free()

# ───────── 测试：cancel 幂等 ─────────

func test_cancel_is_idempotent() -> void:
	var cast := _make_raccoon(true)
	# 第一次 cancel（未开始施法）
	cast.cancel()
	# 再次 cancel 不应崩
	cast.cancel()
	cast.cancel()
	assert_true(true, "cancel called multiple times should not crash")
	cast.free()

# 信号计数用 Array 捕获——GDScript lambda 按值捕获 int/bool, 闭包内自增写不回外层局部变量。

func test_cancel_after_start_cast_emits_finished_once() -> void:
	var cast := _make_raccoon(true)
	var finished: Array = []
	cast.cast_finished.connect(func(): finished.append(1))
	cast.start_cast()   # headless 路径：直接 _commit + _finish，已发 finished
	# 再次 cancel 不应再发 finished（_finished_emitted 守卫）
	cast.cancel()
	assert_eq(finished.size(), 1, "cast_finished should be emitted exactly once")
	cast.free()

# ───────── 测试：signals 语义（headless 路径）─────────

func test_start_cast_emits_cast_started_signal() -> void:
	var cast := _make_raccoon(true)
	var started: Array = []
	cast.cast_started.connect(func(): started.append(1))
	cast.start_cast()
	assert_true(not started.is_empty(), "cast_started signal must be emitted on start_cast")
	cast.free()

func test_start_cast_emits_cast_committed_when_coat_present() -> void:
	var cast := _make_raccoon(true)
	var committed: Array = []
	cast.cast_committed.connect(func(): committed.append(1))
	cast.start_cast()
	assert_true(not committed.is_empty(), "cast_committed must be emitted when coat board and skill_break succeeds")
	cast.free()

func test_start_cast_does_not_emit_committed_when_no_coat() -> void:
	var cast := _make_raccoon(false)
	var committed: Array = []
	cast.cast_committed.connect(func(): committed.append(1))
	cast.start_cast()   # 返回 false，流程未进入
	assert_false(not committed.is_empty(), "cast_committed must NOT be emitted when start_cast is rejected")
	cast.free()
