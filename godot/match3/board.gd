extends RefCounted
# board.gd (match3) — 棋盘数据层（GAME_SPEC 新视图体系 · 阶段1）。
#
# 职责：数据驱动地存一局棋盘的棋子颜色。行列数构造时传入，严禁硬编码尺寸。
# 表现层(level.gd)只读 cells / 调 getter，不关心填充细节。
#
# 注意：这是为 SPEC 新视图重写的「干净 Board」，独立于护城河 core/board.gd
# （后者含 10+ 障碍层/技能层，是 C++ 镜像逻辑核，本阶段不涉及）。

var rows: int          # 行数 (height)
var cols: int          # 列数 (width)
var colors: int        # 颜色种类数 (棋子 species 取值 0..colors-1)
var cells: Array = []  # cells[row][col] = 颜色索引
var _rng: RandomNumberGenerator

# p_rows×p_cols 棋盘，随机填 p_colors 色，保证无初始三连。
# seed_val != 0 时用固定种子（测试/复现用）；否则随机。
func _init(p_rows: int, p_cols: int, p_colors: int = 6, seed_val: int = 0) -> void:
	rows = p_rows
	cols = p_cols
	colors = p_colors
	_rng = RandomNumberGenerator.new()
	if seed_val != 0:
		_rng.seed = seed_val
	else:
		_rng.randomize()
	_fill_no_initial_match()

func get_cell(row: int, col: int) -> int:
	return cells[row][col]

func set_cell(row: int, col: int, v: int) -> void:
	cells[row][col] = v

func in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < rows and col >= 0 and col < cols

# 逐格随机填充，排除会立即形成横/纵三连的颜色。
# 左侧两格同色 → 禁该色；上方两格同色 → 禁该色。6 色下最多禁 2 色，必有可用色。
func _fill_no_initial_match() -> void:
	cells = []
	for r in range(rows):
		var row_arr: Array = []
		for c in range(cols):
			var banned: Dictionary = {}
			if c >= 2 and row_arr[c - 1] == row_arr[c - 2]:
				banned[row_arr[c - 1]] = true
			if r >= 2 and cells[r - 1][c] == cells[r - 2][c]:
				banned[cells[r - 1][c]] = true
			var choice: int = _rng.randi_range(0, colors - 1)
			var guard: int = 0
			while banned.has(choice) and guard < colors:
				choice = (choice + 1) % colors
				guard += 1
			row_arr.append(choice)
		cells.append(row_arr)

# 自检：是否存在任何横/纵 3+ 同色。生成后应恒为 false（供测试断言）。
func has_any_match() -> bool:
	for r in range(rows):
		for c in range(cols):
			var v: int = cells[r][c]
			if c >= 2 and cells[r][c - 1] == v and cells[r][c - 2] == v:
				return true
			if r >= 2 and cells[r - 1][c] == v and cells[r - 2][c] == v:
				return true
	return false
