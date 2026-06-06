extends RefCounted
# level_config.gd — 关卡配置（数据驱动；尺寸/颜色走数据，不硬编码）。
#
# 阶段1只用 rows/cols/colors，用于证明棋盘尺寸可变、换关不报错。
# 后续阶段在每条配置里追加 objectives / moves / obstacles 等字段即可，
# 不改 Board / level.gd 的尺寸处理逻辑。

# 阶段1示例关卡：覆盖 8×8 / 9×9 / 8列9行 / 9列10行 四种尺寸。
const LEVELS: Array = [
	{"id": 1, "rows": 8,  "cols": 8, "colors": 6},
	{"id": 2, "rows": 9,  "cols": 9, "colors": 6},
	{"id": 3, "rows": 9,  "cols": 8, "colors": 6},  # 8 列 × 9 行
	{"id": 4, "rows": 10, "cols": 9, "colors": 6},  # 9 列 × 10 行
]

static func count() -> int:
	return LEVELS.size()

static func get_level(idx: int) -> Dictionary:
	return LEVELS[clampi(idx, 0, LEVELS.size() - 1)]
