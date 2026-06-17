class_name DragonBreathCast
extends "res://match3/pets/pet_cast.gd"
## 龙宝宝「龙息大招」施法控制器。
##
## 本 slice 只迁移 Dragon：技能栏点击仍由 level.gd 管闸门，具体龙息视觉、棋盘清除、
## collapse/refill/cascade 结算由这个 PetCast owner 承接。

const ME := preload("res://core/match_engine.gd")
const DragonBreathVisual := preload("res://match3/pets/dragon_breath_visual.gd")

var skill_bar: CanvasLayer = null
var board = null
var board_view = null
var cell_size: float = 0.0
var board_origin: Vector2 = Vector2.ZERO
var _cast_effect: bool = true
var _resolve_cascades_cb: Callable = Callable()
var _fx_color_cb: Callable = Callable()


func setup(ctx: Dictionary) -> void:
	skill_bar = ctx.get("skill_bar", null)
	board = ctx.get("board", null)
	board_view = ctx.get("board_view", null)
	cell_size = float(ctx.get("cell_size", 0.0))
	board_origin = ctx.get("board_origin", Vector2.ZERO)
	_cast_effect = bool(ctx.get("cast_effect", true))
	_resolve_cascades_cb = ctx.get("resolve_cascades", Callable())
	_fx_color_cb = ctx.get("fx_color", Callable())


func _can_cast() -> bool:
	if board == null or skill_bar == null:
		return false
	if not _cast_effect:
		return true
	return board_view != null and not _dragon_target_cells(_best_species()).is_empty()


func _build_visuals() -> void:
	if skill_bar == null:
		return
	var old := skill_bar.get_node_or_null(DragonBreathVisual.CAST_NODE)
	if old != null:
		_detach_and_free_later(old)
	var visual := DragonBreathVisual.new()
	visual.setup({
		"skill_bar": skill_bar,
		"board": board,
		"cell_size": cell_size,
		"board_origin": board_origin,
	})
	skill_bar.add_child(visual)
	visual.play_and_retire()


func _run_cast(t: Tween) -> void:
	if not _cast_effect:
		t.tween_interval(0.32)
		t.tween_callback(Callable(self, "_finish"))
		return
	t.tween_interval(0.05)
	t.tween_callback(Callable(self, "_commit_dragon_async"))


func _apply_effect() -> bool:
	# Dragon effect is async because it must await collapse/refill/cascades.
	return false


func _commit_dragon_async() -> void:
	if _state != State.CASTING:
		return
	var did := await _apply_dragon_effect_async()
	if did:
		emit_signal("cast_committed")
	_state = State.COMMITTED
	_finish()


func _apply_dragon_effect_async() -> bool:
	if board == null or board_view == null:
		return false
	var best_sp := _best_species()
	if best_sp < 0:
		return false
	var cells := _dragon_target_cells(best_sp)
	if cells.is_empty():
		return false
	var mid: int = board.height / 2

	var fx_node := _fx_node()
	if fx_node != null:
		var top: Vector2 = _cell_center(0, board.width / 2) - Vector2(0, cell_size)
		fx_node.spawn_beam(top, _cell_center(mid, board.width / 2), _fx_color(best_sp))
		for p in cells:
			fx_node.spawn_explosion(_cell_center(p.y, p.x), _fx_color(board.grid[p.y][p.x]), 1.4)
		fx_node.shake(14.0)
	ME._apply_clears(board.grid, board.fx, cells, [])
	for p in cells:
		board_view.clear_node_at(p)
	await board_view.collapse_and_refill()
	if not _resolve_cascades_cb.is_null():
		await _resolve_cascades_cb.call()
	return true


func _best_species() -> int:
	var best_sp: int = -1
	var best_n: int = 0
	for sp in board.species:
		var cnt: int = ME.cells_of_species(board.grid, sp).size()
		if cnt > best_n:
			best_n = cnt
			best_sp = sp
	return best_sp


func _dragon_target_cells(best_sp: int) -> Array:
	if board == null or best_sp < 0:
		return []
	var cell_set := {}
	for p in ME.cells_of_species(board.grid, best_sp):
		cell_set[p] = true
	var mid: int = board.height / 2
	for c in range(board.width):
		if board.grid[mid][c] >= 0:
			cell_set[Vector2i(c, mid)] = true
	return cell_set.keys()


func _restore_avatar() -> void:
	# Dragon does not hide the static skill avatar while casting.
	pass


func _dispose_visuals() -> void:
	if skill_bar == null:
		return
	if _state == State.RETIRED:
		# Normal completion leaves DragonBreathVisual to finish its own fade-out.
		return
	var visual := skill_bar.get_node_or_null(DragonBreathVisual.CAST_NODE)
	if visual != null:
		_detach_and_free_later(visual)


func _cell_center(row: int, col: int) -> Vector2:
	return board_origin + Vector2((float(col) + 0.5) * cell_size, (float(row) + 0.5) * cell_size)


func _fx_color(species: int) -> Color:
	if not _fx_color_cb.is_null():
		return _fx_color_cb.call(species)
	return Color.WHITE


func _fx_node() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("Fx")


func _detach_and_free_later(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var was_inside := node.is_inside_tree()
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if was_inside:
		node.queue_free()
	else:
		node.free()
