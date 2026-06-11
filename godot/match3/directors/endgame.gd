class_name LevelEndgame
extends Node
## 通关奖励连锁 director（docs/11 §1 directors, 附录A 结算奖励簇 10 函数 177 行）。
##
## 一次性演出（不开放扩展）：通关后把剩余步数转成奖励特效, 连锁引爆直到棋盘无特效。
## 生命周期：作为 level 的子 Node（铁律2）, 随关卡子树存活。
##
## 边界：本 director 编排"奖励序列"; 共享演出原语(彩球吸收预览 / 级联循环 / 命中特效时序)
##   仍住 level（契约 E "彩球/融合演出编排暂留 level"）, 经 _level 接口调用; gem 节点经 board_view。
##   状态闸门(_busy/_settled)、结算面板(_show_result)只住 level（铁律1）, 本类只做奖励演出。

const ME := preload("res://core/match_engine.gd")

# ── 奖励连锁节拍常量(迁自 level.gd, 防腐规矩#4)──
const ENDGAME_BONUS_RESULT_HOLD := 0.45
const ENDGAME_BONUS_SPECIAL_CHAIN_MAX := 30

var _level = null   # level.gd 实例(读 board / board_view + 共享演出原语)

func setup(level) -> void:
	_level = level

## 通关奖励演出主入口（level._check_settlement 在判胜后 await）。
## 只播奖励连锁; 结束后由 level 刷 HUD + 弹结算面板(状态闸门只住 level)。
func run_win_bonus() -> void:
	var board = _level.board
	var bonus_moves: int = maxi(board.moves_left, 0)
	var picks: Array = board.prepare_endgame_bonus_lines()
	if picks.is_empty():
		_level._clear_moves_display_override()
		return
	if bonus_moves > 0:
		_level._set_moves_display_override(0)
	await _play_endgame_bonus_conversion_matrix(picks)
	var seeds := []
	for item in picks:
		seeds.append(item["pos"])
	await _play_endgame_bonus_special_blast(seeds, 1)
	await _resolve_endgame_bonus_special_chain()
	_level._clear_moves_display_override()
	await get_tree().create_timer(ENDGAME_BONUS_RESULT_HOLD).timeout

func _play_endgame_bonus_conversion_matrix(picks: Array) -> void:
	var virtual_fx := {}
	var preview_cells := []
	for item in picks:
		var p: Vector2i = item["pos"]
		var kind: int = int(item["kind"])
		if kind == ME.SP_NONE:
			continue
		var n: Sprite2D = _level.board_view.node_at(p)
		if n == null or not is_instance_valid(n):
			continue
		virtual_fx[p] = kind
		preview_cells.append(p)
	if virtual_fx.is_empty():
		return
	# 彩球吸收预览/虚拟转化演出留 level（契约 E 彩球演出暂留）, 经接口调用。
	await _level._play_colorbomb_absorb_preview(Vector2i(-1, -1), preview_cells, virtual_fx.keys(), _endgame_bonus_conversion_preview_center(preview_cells), false)
	await _level._show_colorbomb_virtual_conversion(virtual_fx)

func _endgame_bonus_conversion_preview_center(preview_cells: Array) -> Vector2:
	if preview_cells.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for p in preview_cells:
		center += _level._cell_center(p.y, p.x)
	return center / float(preview_cells.size())

func _play_endgame_bonus_special_blast(seeds: Array, score_level: int) -> bool:
	var board = _level.board
	var clear_set: Dictionary = ME._expand_triggers(board.grid, board.fx, seeds)
	var cells: Array = clear_set.keys()
	if cells.is_empty():
		return false
	var raw_special_fx_cells = _level._special_fx_cells_for_clear_visuals(cells)
	var clear_visual_timing: Dictionary = _level._clear_visual_timing_for_triggers(seeds)
	var acc: Dictionary = ME.account_clears(board.grid, cells, board.fx, board.rng, board.species, board._layers())
	board._accumulate(acc.get("by_species", {}))
	board._accumulate_progress(acc)
	_level.board_view.refresh_jelly_coat_visuals()
	var locked := {}
	for p in acc.get("locked", []):
		locked[p] = true
	var to_clear := []
	for p in cells:
		if not locked.has(p):
			to_clear.append(p)
	for bp in acc.get("cake_blast", []):
		to_clear.append(bp)
	board._gain(ME.score_for_clear(to_clear.size(), score_level))
	await _level.board_view.play_clear(to_clear, [], {}, raw_special_fx_cells, clear_visual_timing)
	ME._apply_clears(board.grid, board.fx, to_clear, [])
	for p in to_clear:
		_level.board_view.clear_node_at(p)
	await _level.board_view.collapse_and_refill()
	return true

func _resolve_endgame_bonus_special_chain() -> void:
	var guard := 0
	while guard < ENDGAME_BONUS_SPECIAL_CHAIN_MAX:
		guard += 1
		await _level._resolve_cascades()   # 级联主循环留 level（契约 E）
		var seeds := _endgame_bonus_special_seeds()
		if seeds.is_empty():
			break
		var blasted: bool = await _play_endgame_bonus_special_blast(seeds, guard + 1)
		if not blasted:
			break

func _endgame_bonus_special_seeds() -> Array:
	var seeds := []
	var board = _level.board
	if board == null or board.fx.is_empty():
		return seeds
	for y in range(board.height):
		for x in range(board.width):
			var cell: int = board.grid[y][x]
			if cell == ME.EMPTY or cell == ME.WALL:
				continue
			if int(board.fx[y][x]) != ME.SP_NONE:
				seeds.append(Vector2i(x, y))
	return seeds
