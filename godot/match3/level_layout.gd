extends RefCounted

const DESIGN_W := 720.0
const BOOK_FRAME_EXTRA_W := 6.0
const BOOK_RIBBONS_W := 982.0
const BOOK_RIBBONS_H := 77.0

# 书页内金线框(book_frame 内边线, PIL实测 982x980)相对 book 边缘的像素 inset。
const BOOK_INNER_L := 53.0
const BOOK_INNER_T := 21.0
const BOOK_INNER_R := 53.0
const BOOK_INNER_B := 56.0

const BOARD_VISUAL_CENTER_Y := 762.0
const SKILL_AV_Y := 1374.0
const SKILL_AV_W := 132.0


static func compute_layout(cols: int, rows: int) -> Dictionary:
	var cell_size := board_cell_size_for_grid(cols, rows)
	var board_w: float = float(cols) * cell_size
	var board_h: float = float(rows) * cell_size
	return {
		"cell_size": cell_size,
		"board_origin": Vector2((DESIGN_W - board_w) * 0.5, BOARD_VISUAL_CENTER_Y - board_h * 0.5),
	}


static func board_cell_size_for_grid(cols: int, rows: int) -> float:
	var safe_cols := maxf(1.0, float(cols))
	var safe_rows := maxf(1.0, float(rows))
	var inner_w: float = book_frame_width_for_board() - BOOK_INNER_L - BOOK_INNER_R
	var width_fit: float = inner_w / safe_cols
	var ribbons_h: float = book_frame_width_for_board() * BOOK_RIBBONS_H / BOOK_RIBBONS_W
	var skill_top: float = SKILL_AV_Y - SKILL_AV_W * 0.5
	var max_board_h: float = maxf(1.0, (skill_top - BOOK_INNER_B - ribbons_h - BOARD_VISUAL_CENTER_Y) * 2.0)
	return minf(width_fit, max_board_h / safe_rows)


static func book_frame_width_for_board() -> float:
	return DESIGN_W + BOOK_FRAME_EXTRA_W


static func book_frame_rect(rows: int, cell_size: float, board_origin: Vector2) -> Rect2:
	var board_h: float = float(rows) * cell_size
	var book_h: float = board_h + BOOK_INNER_T + BOOK_INNER_B
	var book_y: float = board_origin.y - BOOK_INNER_T
	var book_w: float = book_frame_width_for_board()
	return Rect2(Vector2(DESIGN_W * 0.5 - book_w * 0.5, book_y), Vector2(book_w, book_h))


static func book_baked_inner_rect(rows: int, cell_size: float, board_origin: Vector2) -> Rect2:
	var book_rect := book_frame_rect(rows, cell_size, board_origin)
	return Rect2(
		book_rect.position + Vector2(BOOK_INNER_L, BOOK_INNER_T),
		book_rect.size - Vector2(BOOK_INNER_L + BOOK_INNER_R, BOOK_INNER_T + BOOK_INNER_B)
	)


static func book_board_inner_rect(cols: int, rows: int, cell_size: float, board_origin: Vector2) -> Rect2:
	return Rect2(board_origin, Vector2(float(cols) * cell_size, float(rows) * cell_size))


static func cell_center(row: int, col: int, cell_size: float, board_origin: Vector2) -> Vector2:
	return board_origin + Vector2(col, row) * cell_size + Vector2(cell_size, cell_size) * 0.5


static func pos_to_cell(p: Vector2, cols: int, rows: int, cell_size: float, board_origin: Vector2) -> Vector2i:
	var c: int = int(floor((p.x - board_origin.x) / cell_size))
	var r: int = int(floor((p.y - board_origin.y) / cell_size))
	if r < 0 or r >= rows or c < 0 or c >= cols:
		return Vector2i(-1, -1)
	return Vector2i(c, r)
