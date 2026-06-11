class_name LevelOpening
extends Node
## 开局演出 director（docs/11 §1 directors, 附录A 开局演出簇 16 函数 166 行）。
##
## 一次性演出（不开放扩展）：开局棋子掉落 + boss 施石(freeze reveal)。
## 生命周期：作为 level 的子 Node（铁律2）。tween 绑自身(self.create_tween)：换关 level 子树 free
##   → _exit_tree → cancel() → tween 随节点死。level 仍持 _level_generation, 经参数传入做代际守卫;
##   级联/输入/状态闸门(_busy)留 level(铁律1), 收尾经 opening_finished 信号请求解锁。
##
## 涉及 gem/coat 节点的演出全部经 board_view 接口（契约 E, 阶段1已就位）。

signal opening_finished   # 开局演出结束(掉落+施石完成或同代结束) → level: _busy = false

# ── 开局演出节拍常量(迁自 level.gd, 防腐规矩#4 常量跟模块走)──
const OPENING_DROP_TIME := 0.56
const OPENING_DROP_ROW_STAGGER := 0.045
const OPENING_DROP_MAX_STAGGER := 0.30
const OPENING_FREEZE_STAGGER := 0.018
const OPENING_FREEZE_MAX_STAGGER := 0.18
const OPENING_FREEZE_SETTLE := 0.16
const OPENING_STONE_COLOR := Color(0.62, 0.56, 0.50)
const BOSS_C := Vector2(562, 336)   # boss 施法发光束的源点(开局施石用)

var _level = null          # level.gd 实例(读 board / board_view / _level_generation)
var _drop_tween: Tween = null

func setup(level) -> void:
	_level = level

func _exit_tree() -> void:
	kill_drop_tween()   # 换关兜底: 绑 self 的 tween 随节点死, 不留跨代回调

# ───────── 时序参数(纯计算)─────────

func _opening_drop_delay(row: int, height: int = -1) -> float:
	var h: int = height if height > 0 else _level.board.height
	if h <= 1:
		return 0.0
	var row_from_bottom: int = clampi(h - 1 - row, 0, h - 1)
	var full_span := float(h - 1) * OPENING_DROP_ROW_STAGGER
	var capped_span := minf(full_span, OPENING_DROP_MAX_STAGGER)
	return capped_span * float(row_from_bottom) / float(h - 1)

func _opening_drop_window(height: int = -1) -> float:
	var h: int = height if height > 0 else _level.board.height
	return OPENING_DROP_TIME + _opening_drop_delay(0, h)

func _opening_freeze_delay(index: int, count: int = -1) -> float:
	var wall_count: int = count if count > 0 else _level.board_view.opening_wall_cells().size()
	if wall_count <= 1:
		return 0.0
	var safe_index: int = clampi(index, 0, wall_count - 1)
	return minf(float(safe_index) * OPENING_FREEZE_STAGGER, OPENING_FREEZE_MAX_STAGGER)

func _opening_freeze_window(wall_count: int) -> float:
	if wall_count <= 0:
		return 0.0
	return _opening_freeze_delay(wall_count - 1, wall_count) + OPENING_FREEZE_SETTLE

# ───────── 演出 ─────────

func _settle_opening_gems(generation: int) -> bool:
	if generation != _level._level_generation:
		return false
	var board = _level.board
	var gem_nodes: Array = _level.board_view.gem_nodes()
	for r in range(board.height):
		for c in range(board.width):
			var n: Sprite2D = gem_nodes[r][c]
			if n != null and is_instance_valid(n):
				n.position = _level.board_view.cell_center(r, c)
	return true

func _settle_opening_coat_markers(generation: int) -> bool:
	if generation != _level._level_generation:
		return false
	var coat_nodes: Array = _level.board_view.coat_nodes()
	for r in range(coat_nodes.size()):
		var row = coat_nodes[r]
		if not (row is Array):
			continue
		for c in range(row.size()):
			var n: Sprite2D = row[c]
			if n != null and is_instance_valid(n):
				n.position = _level.board_view.coat_marker_position(r, c)
	return true

func _play_opening_freeze(generation: int) -> void:
	var wall_cells: Array = _level.board_view.opening_wall_cells()
	if wall_cells.is_empty() or generation != _level._level_generation:
		return
	var last_delay := 0.0
	for i in range(wall_cells.size()):
		var delay := _opening_freeze_delay(i, wall_cells.size())
		if delay > last_delay:
			await get_tree().create_timer(delay - last_delay).timeout
			last_delay = delay
		if generation != _level._level_generation:
			return
		var p: Vector2i = wall_cells[i]
		Fx.spawn_beam(BOSS_C, _level.board_view.cell_center(p.y, p.x), OPENING_STONE_COLOR)
		_level.board_view.show_opening_wall_marker(p, true)
	await get_tree().create_timer(OPENING_FREEZE_SETTLE).timeout
	if generation != _level._level_generation:
		return

func _apply_opening_freeze_instant(generation: int) -> void:
	if generation != _level._level_generation:
		return
	_settle_opening_coat_markers(generation)
	for p in _level.board_view.opening_wall_cells():
		_level.board_view.show_opening_wall_marker(p, false)

## 开局掉落入口（level.load_level 调）。掉落 gem/coat → 施石 → 收尾(emit opening_finished)。
func play_drop(generation: int) -> void:
	if not is_inside_tree():
		if _settle_opening_gems(generation):
			_settle_opening_coat_markers(generation)
			_apply_opening_freeze_instant(generation)
			_finish_opening_drop(generation)
		return
	var board = _level.board
	var t: Tween = null
	var any := false
	var gem_nodes: Array = _level.board_view.gem_nodes()
	for r in range(board.height):
		for c in range(board.width):
			var n: Sprite2D = gem_nodes[r][c]
			if n == null or not is_instance_valid(n):
				continue
			if t == null:
				t = create_tween().set_parallel(true)
				_drop_tween = t
			var target: Vector2 = _level.board_view.cell_center(r, c)
			_queue_opening_drop_node(t, n, target, r)
			any = true
	var coat_nodes: Array = _level.board_view.coat_nodes()
	for r in range(coat_nodes.size()):
		var row = coat_nodes[r]
		if not (row is Array):
			continue
		for c in range(row.size()):
			var n: Sprite2D = row[c]
			if n == null or not is_instance_valid(n):
				continue
			if t == null:
				t = create_tween().set_parallel(true)
				_drop_tween = t
			_queue_opening_drop_node(t, n, _level.board_view.coat_marker_position(r, c), r)
			any = true
	if any and t != null:
		t.finished.connect(_on_opening_drop_finished.bind(generation, t), CONNECT_ONE_SHOT)
		return
	_on_opening_drop_finished(generation, null)

func _on_opening_drop_finished(generation: int, tween: Tween) -> void:
	if _drop_tween == tween:
		_drop_tween = null
	if not _settle_opening_gems(generation):
		return
	if not _settle_opening_coat_markers(generation):
		return
	await _play_opening_freeze(generation)
	_finish_opening_drop(generation)

func _queue_opening_drop_node(t: Tween, n: Node2D, target: Vector2, row: int) -> void:
	var delay := _opening_drop_delay(row)
	var tw := t.tween_property(n, "position", target, OPENING_DROP_TIME)
	tw.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## 换关/退场杀掉开局 tween（level.load_level / _exit_tree 经接口调）。
func kill_drop_tween() -> void:
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	_drop_tween = null

func _finish_opening_drop(generation: int) -> void:
	if generation != _level._level_generation:
		return
	emit_signal("opening_finished")   # 状态闸门只住 level(铁律1): 请求解锁, 由 level 置 _busy=false
