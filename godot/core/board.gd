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
var objectives: Array = []  # [{type:"SCORE"/"COLLECT"/"CLEAR_JELLY", species:int, target:int}]；空=旧式按 target_score
var collected: Dictionary = {}  # species -> 累计消除数
var init_jelly: Array = []  # 初始果冻层（底层目标，可选）
var jelly: Array = []       # 当前果冻层（随消除递减）
var jelly_cleared: int = 0  # 累计清掉的果冻层
var init_coat: Array = []   # 初始涂层冰/锁（可选）
var coat: Array = []        # 当前涂层（随消除破层）
var blocker_cleared: int = 0  # 累计破掉的涂层
var score: int
var moves_left: int

func _init(w: int, h: int, species_set: Array, target: int, moves: int, seed_val: int, mask: Array = [], objs: Array = [], jelly_layer: Array = [], coat_layer: Array = []) -> void:
	width = w
	height = h
	species = species_set
	target_score = target
	move_limit = moves
	wall_mask = mask
	objectives = objs
	init_jelly = jelly_layer
	init_coat = coat_layer
	rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	start()

func start() -> void:
	grid = ME.make_board(width, height, species, rng, wall_mask)
	fx = _blank_fx()
	collected = {}
	jelly = init_jelly.duplicate(true)
	jelly_cleared = 0
	coat = init_coat.duplicate(true)
	blocker_cleared = 0
	score = 0
	moves_left = move_limit

func _accumulate(by_species: Dictionary) -> void:
	for k in by_species:
		collected[k] = collected.get(k, 0) + by_species[k]

func _blank_fx() -> Array:
	var f := []
	for y in height:
		var row := []
		for x in width:
			row.append(ME.SP_NONE)
		f.append(row)
	return f

func is_won() -> bool:
	if objectives.is_empty():
		return score >= target_score  # 旧式
	for o in objectives:
		if o["type"] == "SCORE":
			if score < o["target"]:
				return false
		elif o["type"] == "COLLECT":
			if collected.get(o["species"], 0) < o["target"]:
				return false
		elif o["type"] == "CLEAR_JELLY":
			if jelly_cleared < o["target"]:
				return false
		elif o["type"] == "CLEAR_BLOCKER":
			if blocker_cleared < o["target"]:
				return false
	return true

func is_lost() -> bool:
	# 步数耗尽且还没赢 = 负。必须用 is_won()（覆盖分数关 + 目标关），
	# 不能只看 target_score——纯目标关 target_score=0 时 score<0 恒假 → 永不判负、卡死。
	return moves_left <= 0 and not is_won()

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
	if not ME.is_legal_swap(grid, a, b, coat):
		return {"ok": false, "reason": "illegal"}
	ME._swap_cells(grid, a, b)
	ME._swap_cells(fx, a, b)   # 特效随棋子一起交换
	var res: Dictionary = ME.resolve(grid, species, rng, fx, jelly, coat)
	score += res["score"]
	_accumulate(res.get("by_species", {}))
	jelly_cleared += res.get("jelly_cleared", 0)
	blocker_cleared += res.get("blocker_cleared", 0)
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
	# 彩球直清的格也要计入目标（COLLECT/果冻/涂层），否则目标关白清。
	# 须在 _apply_clears 清空 grid 之前结算（account_clears 读取被清格的 species）。
	var acc := ME.account_clears(grid, cells, jelly, coat)
	_accumulate(acc["by_species"])
	jelly_cleared += acc["jelly_cleared"]
	blocker_cleared += acc["blocker_cleared"]
	ME._apply_clears(grid, fx, cells, [])   # 无 spawn，纯清除
	ME.apply_gravity(grid, fx)
	ME.refill(grid, species, rng, fx)
	var res: Dictionary = ME.resolve(grid, species, rng, fx, jelly, coat)   # 结算余下级联
	score += res["score"]
	_accumulate(res.get("by_species", {}))
	jelly_cleared += res.get("jelly_cleared", 0)
	blocker_cleared += res.get("blocker_cleared", 0)
	moves_left -= 1
	_settle_deadlock()
	return {"ok": true, "gained": gained + res["score"], "cascades": res["cascades"], "colorbomb": true}

func _settle_deadlock() -> void:
	if not is_over() and not ME.has_legal_move(grid, coat):
		ME.reshuffle(grid, rng)
		fx = _blank_fx()   # 洗牌后特效重置（极罕见边界）
