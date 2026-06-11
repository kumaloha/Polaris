## 障碍物 Overlay 注册表（契约 B, docs/11 §3.3）。
## RENDERERS: layer_key → GDScript(OverlayBase 子类)。
## 加一种障碍 = 这里一行 + 一个新文件，board_view / level.gd 零改动。
##
## ensure_overlays_at: board_view 按单格同步 overlay 节点的标准入口。

const RENDERERS := {
	"jelly": preload("res://match3/overlays/jelly_overlay.gd"),
	"bomb":  preload("res://match3/overlays/bomb_overlay.gd"),
	# 其余七种留待 P7 批量落地：
	# "coat":    preload("res://match3/overlays/coat_overlay.gd"),
	# "choco":   preload("res://match3/overlays/choco_overlay.gd"),
	# "ing":     preload("res://match3/overlays/ing_overlay.gd"),
	# "cannon":  preload("res://match3/overlays/cannon_overlay.gd"),
	# "popcorn": preload("res://match3/overlays/popcorn_overlay.gd"),
	# "cake":    preload("res://match3/overlays/cake_overlay.gd"),
	# "mystery": preload("res://match3/overlays/mystery_overlay.gd"),
}

## 在 cell 上同步全部已注册的 overlay 节点。
## board_view 的 _sync_overlays_at(cell) 直接调此函数即可，无需再了解各 key。
##
## 参数：
##   cell      : Vector2i   — 目标格坐标
##   board               — core/board.gd 实例（只读）
##   parent    : Node    — overlay 节点的父节点（一般是 board_view 本体）
##   tracker   : Dictionary — {[key,cell] -> OverlayBase} 由 board_view 持有的节点索引
##   cell_px   : float   — 格子像素尺寸（用于 setup）
##   cell_world: Vector2 — 格子世界坐标（overlay.position）
static func ensure_overlays_at(
		cell: Vector2i,
		board,
		parent: Node,
		tracker: Dictionary,
		cell_px: float,
		cell_world: Vector2) -> void:
	for key: String in RENDERERS:
		var value: int = _layer_value(key, cell, board)
		var existing = tracker.get([key, cell])
		if value > 0 and existing == null:
			var script = RENDERERS[key]
			var node: OverlayBase = script.new()
			node.position = cell_world
			parent.add_child(node)
			node.setup(cell, board, cell_px)
			tracker[[key, cell]] = node
		elif value <= 0 and existing != null:
			existing.on_cleared()
			tracker.erase([key, cell])

## 对 board 上所有格子做全量初始化（换关时调用）。
static func rebuild_all(
		board,
		parent: Node,
		tracker: Dictionary,
		cell_px: float,
		cell_world_fn: Callable) -> void:
	# 先清理旧节点
	for node in tracker.values():
		if is_instance_valid(node):
			node.queue_free()
	tracker.clear()
	# 逐格建立
	for y in board.height:
		for x in board.width:
			var c := Vector2i(x, y)
			ensure_overlays_at(c, board, parent, tracker, cell_px, cell_world_fn.call(c))

## 向 tracker 内所有 overlay 广播 on_step。
static func broadcast_step(tracker: Dictionary, report: Dictionary) -> void:
	for node in tracker.values():
		if is_instance_valid(node):
			node.on_step(report)

# 读取 board._layers() 中指定 key 在 cell 的值。
static func _layer_value(key: String, cell: Vector2i, board) -> int:
	var layers: Dictionary = board._layers()
	var layer_data = layers.get(key, [])
	if layer_data is Array and cell.y < layer_data.size():
		var row = layer_data[cell.y]
		if row is Array and cell.x < row.size():
			return row[cell.x]
	return 0
