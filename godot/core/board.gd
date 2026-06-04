extends RefCounted
# board.gd — 游戏状态层（裸 Core，无 Meta）：把消除引擎包成一局可玩状态。
# 表现层(view)只跟它打交道：读 grid/score/moves_left，调 try_swap。

const ME := preload("res://core/match_engine.gd")

var width: int
var height: int
var species: Array
var target_score: int
var move_limit: int
var rng: RandomNumberGenerator

var grid: Array
var fx: Array = []   # 特效层（与 grid 同维），SP_NONE=普通
var wall_mask: Array = []  # 异形棋盘掩码（可选）
var score: int
var moves_left: int

func _init(w: int, h: int, species_set: Array, target: int, moves: int, seed_val: int, mask: Array = []) -> void:
	width = w
	height = h
	species = species_set
	target_score = target
	move_limit = moves
	wall_mask = mask
	rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	start()

func start() -> void:
	grid = ME.make_board(width, height, species, rng, wall_mask)
	fx = _blank_fx()
	score = 0
	moves_left = move_limit

func _blank_fx() -> Array:
	var f := []
	for y in height:
		var row := []
		for x in width:
			row.append(ME.SP_NONE)
		f.append(row)
	return f

func is_won() -> bool:
	return score >= target_score

func is_lost() -> bool:
	return moves_left <= 0 and score < target_score

func is_over() -> bool:
	return is_won() or is_lost()

# 尝试交换 a,b：非法/已结束则不消耗。合法则交换→级联结算→扣 1 步→死局兜底洗牌。
# 返回 {ok, gained?, cascades?, reason?}。
func try_swap(a: Vector2i, b: Vector2i) -> Dictionary:
	if is_over():
		return {"ok": false, "reason": "over"}
	if abs(a.x - b.x) + abs(a.y - b.y) != 1:
		return {"ok": false, "reason": "not_adjacent"}
	# 彩球交换引爆（无需形成普通消除，始终合法）
	if fx[a.y][a.x] == ME.SP_COLORBOMB or fx[b.y][b.x] == ME.SP_COLORBOMB:
		return _activate_colorbomb(a, b)
	if not ME.is_legal_swap(grid, a, b):
		return {"ok": false, "reason": "illegal"}
	ME._swap_cells(grid, a, b)
	ME._swap_cells(fx, a, b)   # 特效随棋子一起交换
	var res: Dictionary = ME.resolve(grid, species, rng, fx)
	score += res["score"]
	moves_left -= 1
	_settle_deadlock()
	return {"ok": true, "gained": res["score"], "cascades": res["cascades"]}

func _activate_colorbomb(a: Vector2i, b: Vector2i) -> Dictionary:
	var cb := a
	var partner := b
	if fx[b.y][b.x] == ME.SP_COLORBOMB:
		cb = b
		partner = a
	var cells := ME.colorbomb_clear_set(grid, fx, cb, partner)
	var gained := ME.score_for_clear(cells.size(), 1)
	score += gained
	ME._apply_clears(grid, fx, cells, [])   # 无 spawn，纯清除
	ME.apply_gravity(grid, fx)
	ME.refill(grid, species, rng, fx)
	var res: Dictionary = ME.resolve(grid, species, rng, fx)   # 结算余下级联
	score += res["score"]
	moves_left -= 1
	_settle_deadlock()
	return {"ok": true, "gained": gained + res["score"], "cascades": res["cascades"], "colorbomb": true}

func _settle_deadlock() -> void:
	if not is_over() and not ME.has_legal_move(grid):
		ME.reshuffle(grid, rng)
		fx = _blank_fx()   # 洗牌后特效重置（极罕见边界）
