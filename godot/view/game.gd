extends Node2D
# game.gd — 消除 Core 表现层（v1：无特效/无障碍）。
# 只跟 board.gd 打交道：读 grid/score/moves_left，调 try_swap。
# 操作：点一个水果再点相邻水果 → 交换（滑动动画）。R 重开一局。

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")

const W := 8
const H := 8
const SPECIES := [0, 1, 2, 3, 4]
const CELL := 78.0
const GAP := 6.0
const ORIGIN := Vector2(36.0, 160.0)
const TARGET := 2000
const MOVES := 25

# 5 种水果：颜色 + 形状符号双重区分（呼应 06：小尺寸靠形状不只靠色）
var COLORS := [Color("e74c3c"), Color("f5b301"), Color("27ae60"), Color("2e86de"), Color("8e44ad")]
const SYMBOLS := ["●", "▲", "■", "◆", "✶"]
# 特效标记：SP_NONE/LINE_H/LINE_V/BOMB/COLORBOMB
const FX_GLYPH := ["", "▬", "▮", "✸", "◎"]

var board: Board
var cur_seed := 12345
var tiles := []          # tiles[y][x] -> ColorRect
var labels := []         # labels[y][x] -> Label
var selected := Vector2i(-1, -1)
var input_locked := false

var score_label: Label
var moves_label: Label
var status_label: Label
var hint_label: Label
var sel_frame: ColorRect


func _ready() -> void:
	_build_hud()
	_build_tiles()
	_new_game()


func _new_game() -> void:
	board = Board.new(W, H, SPECIES, TARGET, MOVES, cur_seed)
	selected = Vector2i(-1, -1)
	input_locked = false
	_render()


func _build_hud() -> void:
	var bg := ColorRect.new()
	bg.color = Color("171b26")
	bg.size = Vector2(2400, 2400)
	bg.position = Vector2(-200, -200)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	score_label = _mk_label(Vector2(36, 40), 32)
	moves_label = _mk_label(Vector2(36, 86), 28)
	status_label = _mk_label(Vector2(360, 40), 34)
	hint_label = _mk_label(Vector2(36, 850), 20)
	hint_label.text = "点一个水果，再点相邻水果交换 · 按 R 重开"


func _mk_label(pos: Vector2, fsize: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _build_tiles() -> void:
	sel_frame = ColorRect.new()
	sel_frame.color = Color(1, 1, 1, 0.28)
	sel_frame.size = Vector2(CELL, CELL)
	sel_frame.visible = false
	sel_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_frame.z_index = 5
	add_child(sel_frame)

	tiles.resize(H)
	labels.resize(H)
	for y in H:
		tiles[y] = []
		labels[y] = []
		for x in W:
			var rect := ColorRect.new()
			rect.size = Vector2(CELL, CELL)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(rect)
			tiles[y].append(rect)

			var lab := Label.new()
			lab.size = Vector2(CELL, CELL)
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lab.add_theme_font_size_override("font_size", 36)
			lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lab.z_index = 1
			add_child(lab)
			labels[y].append(lab)


func _cell_pos(x: int, y: int) -> Vector2:
	return ORIGIN + Vector2(x * (CELL + GAP), y * (CELL + GAP))


func _render() -> void:
	for y in H:
		for x in W:
			var sp: int = board.grid[y][x]
			var f: int = board.fx[y][x]
			var p := _cell_pos(x, y)
			var rect: ColorRect = tiles[y][x]
			rect.position = p
			if sp < 0:
				rect.color = Color(0, 0, 0, 0)
			elif f != ME.SP_NONE:
				rect.color = COLORS[sp].lightened(0.28)  # 特效格提亮
			else:
				rect.color = COLORS[sp]
			var lab: Label = labels[y][x]
			lab.position = p
			if f != ME.SP_NONE:
				lab.text = FX_GLYPH[f]      # 特效格显示特效标记
			else:
				lab.text = SYMBOLS[sp] if sp >= 0 else ""
	score_label.text = "分数 %d / %d" % [board.score, TARGET]
	moves_label.text = "步数 %d" % board.moves_left
	if board.is_won():
		status_label.text = "🎉 过关！(R 重开)"
	elif board.is_lost():
		status_label.text = "步数耗尽 (R 重开)"
	else:
		status_label.text = ""
	sel_frame.visible = selected.x >= 0
	if selected.x >= 0:
		sel_frame.position = _cell_pos(selected.x, selected.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		cur_seed += 1
		_new_game()
		return
	if input_locked or board.is_over():
		return
	var pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos == Vector2.INF:
		return
	var cell := _cell_from(pos)
	if cell.x < 0:
		return
	if selected.x < 0:
		selected = cell
		_render()
	elif _adjacent(selected, cell):
		var a := selected
		selected = Vector2i(-1, -1)
		_render()
		_attempt(a, cell)
	else:
		selected = cell
		_render()


func _cell_from(pos: Vector2) -> Vector2i:
	var local := pos - ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var x := int(local.x / (CELL + GAP))
	var y := int(local.y / (CELL + GAP))
	# 排除落在格间空隙上的点击
	if local.x - x * (CELL + GAP) > CELL or local.y - y * (CELL + GAP) > CELL:
		return Vector2i(-1, -1)
	if x >= 0 and x < W and y >= 0 and y < H:
		return Vector2i(x, y)
	return Vector2i(-1, -1)


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1


func _attempt(a: Vector2i, b: Vector2i) -> void:
	input_locked = true
	var pa := _cell_pos(a.x, a.y)
	var pb := _cell_pos(b.x, b.y)
	var nodes := [tiles[a.y][a.x], labels[a.y][a.x], tiles[b.y][b.x], labels[b.y][b.x]]

	await _slide(nodes, [pb, pb, pa, pa], 0.12)

	var r: Dictionary = board.try_swap(a, b)
	if not r["ok"]:
		await _slide(nodes, [pa, pa, pb, pb], 0.12)  # 非法 → 滑回
		_render()
		input_locked = false
		return

	_render()
	await _pop_flash()
	input_locked = false


func _slide(nodes: Array, targets: Array, dur: float) -> void:
	var tw := create_tween().set_parallel(true)
	for i in nodes.size():
		tw.tween_property(nodes[i], "position", targets[i], dur)
	await tw.finished


# 消除后整盘轻微"脉冲"提示发生了变化（v1 简化版反馈；逐级联动画留待 v1.x）
func _pop_flash() -> void:
	modulate = Color(1.15, 1.15, 1.15)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1), 0.14)
	await tw.finished
