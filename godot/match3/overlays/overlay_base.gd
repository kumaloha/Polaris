class_name OverlayBase
extends Node2D
## 障碍物 Overlay 基类（契约 B, docs/11 §3.2）。
## 一个格子上一种障碍层的视觉体。
## board_view 按注册表实例化 / 定位 / 回收, 自身不碰引擎数据（只读）。
##
## z 序约定（§3.4, 写死在此; 子类禁止覆写 z_index）：
##   z=1  board_cell 格底
##   z=2  jelly（棋子之下的底片）
##   z=3  gem 棋子本体
##   z=4  ing（替换 gem 形象, 与 gem 互斥）
##   z=5  coat / mystery / choco / popcorn / cake（罩在棋子上的壳）
##   z=6  bomb 倒计时 Label / cannon 装置
##   z=10 受击演出特效（短暂置顶）

# ── z 序常量（§3.4）──
const Z_BOARD_CELL  := 1
const Z_JELLY       := 2
const Z_GEM         := 3
const Z_ING         := 4
const Z_SHELL       := 5   # coat / mystery / choco / popcorn / cake
const Z_BOMB        := 6   # 倒计时 Label / cannon 装置
const Z_HIT_FX      := 10  # 受击演出特效（短暂置顶）

# ── 实例状态 ──
var cell: Vector2i            # 本格坐标
var _board                    # core/board.gd 实例，只读
var _cell_px: float           # 格子像素尺寸

## board_view 创建时调用一次。读层现值定初始贴图分级。
func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	cell = p_cell
	_board = p_board
	_cell_px = p_cell_px
	z_index = z_band()

## 每级联步分发（契约 A）。从 report.account 判断本层是否有变化,
## 再 current_value() 自查本格现值，播对应演出。
func on_step(report: Dictionary) -> void:
	pass

## 自查本格本层现值（数据源唯一: board._layers()[layer_key()]）。
func current_value() -> int:
	if _board == null:
		return 0
	var layers: Dictionary = _board._layers()
	var layer_data = layers.get(layer_key(), [])
	if layer_data is Array and cell.y < layer_data.size():
		var row = layer_data[cell.y]
		if row is Array and cell.x < row.size():
			return row[cell.x]
	return 0

## 归零回收钩子。默认 queue_free；子类可先播退场动画再 free（自己负责，不阻塞主循环）。
func on_cleared() -> void:
	queue_free()

# ── static 元信息（注册表 / 目标卡用）──

## 本层在 board._layers() 中的 key（子类必须覆写）。
static func layer_key() -> String:
	return ""

## 目标卡图标（子类覆写；无图标返回 null 即可）。
static func objective_icon() -> Texture2D:
	return null

## z 序段（§3.4; 子类必须覆写）。
static func z_band() -> int:
	return 5
