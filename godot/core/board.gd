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

# ───── Meta 技能层（见 02/10 §7）。框架模式：技能 = 一个 id + 自己的状态 + 自己的方法 + 在 is_won 挂钩。 ─────
var skill: String = ""          # 本局所带技能 id（""=裸 Core 无技能；锦上添花非雪中送炭）
# 借贷(#1)：一局一次借一个特效（生债），本关内必须还（降格一个特效），欠债未还不过关。
var borrow_used: bool = false
var borrow_debt: int = 0

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
	borrow_used = false   # 技能状态随开局重置（skill 装备本身保留）
	borrow_debt = 0

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
	if borrow_debt > 0:
		return false  # 借贷铁律：欠债未还 → 不算过关（即使分数/目标已达成）
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

# ───── 借贷(#1) 技能方法 ─────
# 借：在一个普通棋子格放一个特效(kind)，生一笔债。一局一次（看广告续用留作后续）。
func skill_borrow(cell: Vector2i, kind: int) -> bool:
	if skill != "borrow" or borrow_used or is_over():
		return false
	if kind == ME.SP_NONE:
		return false
	if grid[cell.y][cell.x] < 0 or fx[cell.y][cell.x] != ME.SP_NONE:
		return false  # 须落在普通棋子格（非墙/空/已有特效）
	fx[cell.y][cell.x] = kind
	borrow_debt += 1
	borrow_used = true
	return true

# 还：把某个特效降格成普通棋子（玩家自选牺牲哪个，借来的或自然形成的都行），还一笔债。
func skill_repay(cell: Vector2i) -> bool:
	if borrow_debt <= 0:
		return false
	if fx[cell.y][cell.x] == ME.SP_NONE:
		return false  # 该格无特效可还
	fx[cell.y][cell.x] = ME.SP_NONE
	borrow_debt -= 1
	return true

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
	# 彩球直清的格计入目标（COLLECT/果冻/涂层）；经典锁语义下锁住格只破锁、不被清。
	# 须在 _apply_clears 清空 grid 之前结算（account_clears 读取被清格的 species）。
	var acc := ME.account_clears(grid, cells, jelly, coat)
	_accumulate(acc["by_species"])
	jelly_cleared += acc["jelly_cleared"]
	blocker_cleared += acc["blocker_cleared"]
	var locked_set := {}
	for p in acc["locked"]:
		locked_set[p] = true
	var to_clear := []
	for p in cells:
		if not locked_set.has(p):
			to_clear.append(p)   # 锁住格不清（只破锁）
	var gained := ME.score_for_clear(to_clear.size(), 1)
	score += gained
	ME._apply_clears(grid, fx, to_clear, [])   # 无 spawn，纯清除
	ME.apply_gravity(grid, fx, coat)   # coat 感知：锁住格在重力下固定
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
		ME.reshuffle(grid, rng, coat)   # coat 感知洗牌，避免洗完仍无真实合法步
		fx = _blank_fx()   # 洗牌后特效重置（极罕见边界）
