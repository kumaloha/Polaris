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
# 连消奖步(#10, 被动) / 连击收集(#11, 被动)
var chain_threshold: int = 4    # 连锁≥此值奖 1 步（等级越高越低）
var bonus_moves: int = 0        # 本局累计奖励步数
var fragments: int = 0          # 本局连击额外攒的铭文碎片
# 时间回退(#2) / 存档快照(#3)
var move_history: Array = []    # 每步前的快照栈（仅 timerewind 维护）
var rewind_used: bool = false
var rewind_steps: int = 5       # 回退最近 N 步（等级越高越多）
var saved_state = null          # 存档快照槽
var snapshot_used: bool = false
# 彩球护盾(#6)：引爆时彩球本体保留，只消耗护盾
var colorbomb_shield: int = 0
var shield_used: bool = false
# 引擎原语类主动技能(重力翻转#5/同类消除#7/破障#9/预知#8)的一局一次标志
var active_used: bool = false
# 隔位对换(#4)：armed 时下一次交换允许隔一格(span=2)，用完消耗
var longswap_armed: bool = false
# 看广告续用：重置技能"已用"标志再用一次，有上限（卖机会非强度）
var ad_continues: int = 0
var ad_continue_cap: int = 2
# 铭文/养成喂参（Meta 系统设置，量变/随级成长）：铭文 +步数(开局多几步) / 技能等级
var extra_moves: int = 0
var skill_level: int = 1
var score_mult: float = 1.0   # 铭文 +积分：计分倍率
# 滚动关(挖矿)：补充从 feed 出而非随机；feed[x]=列 x 的预设深层队列。is_scrolling 时通关=feed 耗尽(挖穿长盘)。
var is_scrolling: bool = false
var feed: Array = []

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
	moves_left = move_limit + extra_moves   # 铭文 +步数
	borrow_used = false   # 技能状态随开局重置（skill 装备本身保留）
	borrow_debt = 0
	bonus_moves = 0
	fragments = 0
	move_history = []
	rewind_used = false
	saved_state = null
	snapshot_used = false
	colorbomb_shield = 0
	shield_used = false
	active_used = false
	longswap_armed = false
	ad_continues = 0
	score_mult = 1.0

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
	if is_scrolling:
		return _feed_empty()  # 滚动关：挖穿长盘（feed 耗尽）= 过关
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

func _feed_empty() -> bool:
	for col in feed:
		if not col.is_empty():
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
	var span := 2 if longswap_armed else 1   # 隔位对换#4：armed 时允许隔一格
	var ok_range: bool = (a.y == b.y and abs(a.x - b.x) == span) or (a.x == b.x and abs(a.y - b.y) == span)
	if not ok_range:
		return {"ok": false, "reason": "not_adjacent"}
	# 彩球交换引爆（仅相邻；隔位不引爆彩球）
	if span == 1 and (fx[a.y][a.x] == ME.SP_COLORBOMB or fx[b.y][b.x] == ME.SP_COLORBOMB):
		return _activate_colorbomb(a, b)
	# 两个(非彩球)特效相邻交换 → 主动融合（始终合法，无需形成普通消除）
	if span == 1 and fx[a.y][a.x] != ME.SP_NONE and fx[b.y][b.x] != ME.SP_NONE:
		return _activate_fusion(a, b)
	if not ME.is_legal_swap(grid, a, b, coat, span):
		return {"ok": false, "reason": "illegal"}
	if longswap_armed:
		longswap_armed = false   # 隔位对换消耗
	_push_history()   # 时间回退#2：记录走子前局面
	ME._swap_cells(grid, a, b)
	ME._swap_cells(fx, a, b)   # 特效随棋子一起交换
	var res: Dictionary = ME.resolve(grid, species, rng, fx, jelly, coat, feed)
	_gain(res["score"])
	_accumulate(res.get("by_species", {}))
	jelly_cleared += res.get("jelly_cleared", 0)
	blocker_cleared += res.get("blocker_cleared", 0)
	moves_left -= 1
	_on_move_resolved(res["cascades"])   # 被动技能 #10/#11
	_settle_deadlock()
	return {"ok": true, "gained": res["score"], "cascades": res["cascades"]}

func _activate_colorbomb(a: Vector2i, b: Vector2i) -> Dictionary:
	var cb := a
	var partner := b
	if fx[b.y][b.x] == ME.SP_COLORBOMB:
		cb = b
		partner = a
	_push_history()   # 时间回退#2：记录走子前局面
	var cells := ME.colorbomb_clear_set(grid, fx, cb, partner)
	# 彩球护盾(#6)：护盾在则彩球本体(cb)不被清——保留之，只消耗一层护盾。
	var protect := colorbomb_shield > 0
	var eff := []
	for p in cells:
		if not (protect and p == cb):
			eff.append(p)
	if protect:
		colorbomb_shield -= 1
	# 直清的格计入目标（COLLECT/果冻/涂层）；锁住格只破锁、不被清。须在清空 grid 前结算。
	var acc := ME.account_clears(grid, eff, jelly, coat)
	_accumulate(acc["by_species"])
	jelly_cleared += acc["jelly_cleared"]
	blocker_cleared += acc["blocker_cleared"]
	var locked_set := {}
	for p in acc["locked"]:
		locked_set[p] = true
	var to_clear := []
	for p in eff:
		if not locked_set.has(p):
			to_clear.append(p)   # 锁住格不清（只破锁）；彩球护盾时 cb 已排除
	var gained := ME.score_for_clear(to_clear.size(), 1)
	_gain(gained)
	ME._apply_clears(grid, fx, to_clear, [])   # 无 spawn，纯清除
	ME.apply_gravity(grid, fx, coat)   # coat 感知：锁住格在重力下固定
	ME.refill(grid, species, rng, fx, feed)
	var res: Dictionary = ME.resolve(grid, species, rng, fx, jelly, coat, feed)   # 结算余下级联
	_gain(res["score"])
	_accumulate(res.get("by_species", {}))
	jelly_cleared += res.get("jelly_cleared", 0)
	blocker_cleared += res.get("blocker_cleared", 0)
	moves_left -= 1
	_on_move_resolved(res["cascades"])   # 被动技能 #10/#11
	_settle_deadlock()
	return {"ok": true, "gained": gained + res["score"], "cascades": res["cascades"], "colorbomb": true}

# 两个特效融合引爆：按几何(十字/粗十字/5x5)清除 + 链式展开被卷入的特效，锁住格只破锁不清。
func _activate_fusion(a: Vector2i, b: Vector2i) -> Dictionary:
	var ka: int = fx[a.y][a.x]
	var kb: int = fx[b.y][b.x]
	var seeds := ME.special_fusion_cells(grid, b, ka, kb)
	seeds.append(a)
	seeds.append(b)
	_push_history()
	var to_set := ME._expand_triggers(grid, fx, seeds)   # 链式展开被卷入的直线/爆炸
	var cells: Array = to_set.keys()
	var acc := ME.account_clears(grid, cells, jelly, coat)
	_accumulate(acc["by_species"])
	jelly_cleared += acc["jelly_cleared"]
	blocker_cleared += acc["blocker_cleared"]
	var locked := {}
	for p in acc["locked"]:
		locked[p] = true
	var to_clear := []
	for p in cells:
		if not locked.has(p):
			to_clear.append(p)
	var gained := ME.score_for_clear(to_clear.size(), 1)
	_gain(gained)
	ME._apply_clears(grid, fx, to_clear, [])
	ME.apply_gravity(grid, fx, coat)
	ME.refill(grid, species, rng, fx, feed)
	var res: Dictionary = ME.resolve(grid, species, rng, fx, jelly, coat, feed)
	_gain(res["score"])
	_accumulate(res.get("by_species", {}))
	jelly_cleared += res.get("jelly_cleared", 0)
	blocker_cleared += res.get("blocker_cleared", 0)
	moves_left -= 1
	_on_move_resolved(res["cascades"])
	_settle_deadlock()
	return {"ok": true, "gained": gained + res["score"], "cascades": res["cascades"], "fusion": true}

func _settle_deadlock() -> void:
	if not is_over() and not ME.has_legal_move(grid, coat):
		ME.reshuffle(grid, rng, coat)   # coat 感知洗牌，避免洗完仍无真实合法步
		fx = _blank_fx()   # 洗牌后特效重置（极罕见边界）


# ───── 被动技能 #10/#11：走子结算后按连锁奖步/攒碎片 ─────
func _on_move_resolved(cascades: int) -> void:
	if skill == "chainbonus" and cascades >= chain_threshold:
		moves_left += 1
		bonus_moves += 1
	elif skill == "collector" and cascades >= 2:
		fragments += cascades

# ───── 局面快照（时间回退#2 / 存档快照#3 共用）─────
func _snapshot() -> Dictionary:
	return {
		"grid": grid.duplicate(true), "fx": fx.duplicate(true),
		"coat": coat.duplicate(true), "jelly": jelly.duplicate(true),
		"score": score, "moves_left": moves_left,
		"collected": collected.duplicate(true),
		"jelly_cleared": jelly_cleared, "blocker_cleared": blocker_cleared,
		"borrow_debt": borrow_debt, "rng_state": rng.state,
	}

func _restore(s: Dictionary) -> void:
	grid = s["grid"].duplicate(true)
	fx = s["fx"].duplicate(true)
	coat = s["coat"].duplicate(true)
	jelly = s["jelly"].duplicate(true)
	score = s["score"]
	moves_left = s["moves_left"]
	collected = s["collected"].duplicate(true)
	jelly_cleared = s["jelly_cleared"]
	blocker_cleared = s["blocker_cleared"]
	borrow_debt = s["borrow_debt"]
	rng.state = s["rng_state"]

func _push_history() -> void:
	if skill != "timerewind":
		return
	move_history.append(_snapshot())
	if move_history.size() > rewind_steps:
		move_history.pop_front()   # 只留最近 rewind_steps 步

# 时间回退(#2)：回到最近 rewind_steps 步之前（现有最早快照），一局一次。
func skill_rewind() -> bool:
	if skill != "timerewind" or rewind_used or move_history.is_empty():
		return false
	_restore(move_history[0])
	move_history.clear()
	rewind_used = true
	return true

# 存档快照(#3)：存当前局面（一局一存）。
func skill_save() -> bool:
	if skill != "snapshot" or snapshot_used:
		return false
	saved_state = _snapshot()
	snapshot_used = true
	return true

# 跳回已存的快照（消耗存档）。
func skill_load() -> bool:
	if saved_state == null:
		return false
	_restore(saved_state)
	saved_state = null
	return true

# 彩球护盾(#6)：这局保彩球一次——引爆时彩球本体保留，只掉护盾。一局一次。
func skill_shield() -> bool:
	if skill != "colorshield" or shield_used or is_over():
		return false
	colorbomb_shield += 1
	shield_used = true
	return true

# ───── 引擎原语类主动技能（统一走 board，含一局一次 + 结算 + 死局兜底）─────

# 重力翻转(#5)：翻转盘面（行序倒置=上下颠倒），再重排下落。满盘上"反向下落"是 no-op，
# 故用"翻转盘面+重排"做出可见效果（Flip the World）。
func skill_gravity_flip() -> bool:
	if skill != "gravityflip" or active_used or is_over():
		return false
	grid.reverse()
	fx.reverse()
	if not coat.is_empty():
		coat.reverse()
	if not jelly.is_empty():
		jelly.reverse()
	ME.apply_gravity(grid, fx, coat)
	ME.refill(grid, species, rng, fx, feed)
	_settle_after_skill()
	active_used = true
	return true

# 同类消除(#7)：清掉某 species 全场（锁住格只破锁不清，复用经典锁语义）。
func skill_clear_species(sp: int) -> bool:
	if skill != "sametypeclear" or active_used or is_over():
		return false
	var cells := ME.cells_of_species(grid, sp)
	if cells.is_empty():
		return false
	var acc := ME.account_clears(grid, cells, jelly, coat)
	_accumulate(acc["by_species"])
	jelly_cleared += acc["jelly_cleared"]
	blocker_cleared += acc["blocker_cleared"]
	var locked := {}
	for p in acc["locked"]:
		locked[p] = true
	var to_clear := []
	for p in cells:
		if not locked.has(p):
			to_clear.append(p)
	_gain(ME.score_for_clear(to_clear.size(), 1))
	ME._apply_clears(grid, fx, to_clear, [])
	ME.apply_gravity(grid, fx, coat)
	ME.refill(grid, species, rng, fx, feed)
	_settle_after_skill()
	active_used = true
	return true

# 破障(#9)：直接清掉至多 n 个锁住格（n 看等级）。
func skill_break(n: int = 0) -> bool:
	if skill != "breaker" or active_used or is_over():
		return false
	if n <= 0:
		n = skill_level   # 等级越高破越多（1级破1，高级破2-3）
	var broke := ME.break_blockers(coat, n)
	blocker_cleared += broke
	active_used = true
	_settle_deadlock()
	return broke > 0

# 预知(#8)：返回最优的 k 步走法（不改盘面，供视图高亮）。
func skill_foresight(k: int = 0) -> Array:
	if skill != "foresight" or active_used or is_over():
		return []
	if k <= 0:
		k = maxi(1, skill_level)   # 等级越高亮越多步（1级亮1，高级3-5）
	active_used = true
	return ME.best_moves(grid, k, coat, objectives)

# 技能改动盘面后结算余下级联 + 死局兜底（不消耗步数，技能是免费动作）。
func _settle_after_skill() -> void:
	var res: Dictionary = ME.resolve(grid, species, rng, fx, jelly, coat, feed)
	_gain(res.get("score", 0))
	_accumulate(res.get("by_species", {}))
	jelly_cleared += res.get("jelly_cleared", 0)
	blocker_cleared += res.get("blocker_cleared", 0)
	_settle_deadlock()

# ───── 默认提示(#0) / 看广告续用 / 结算数据 ─────

# 默认精灵提示(#0)：返回最优 k 步（卡住引路；非战斗，无一局一次约束）。
func hint(k: int = 1) -> Array:
	return ME.best_moves(grid, k, coat, objectives)

# 看广告续用：重置当前技能的"已用"标志让它再用一次，有上限。返回是否成功。
func ad_continue() -> bool:
	if ad_continues >= ad_continue_cap:
		return false
	match skill:
		"borrow":
			borrow_used = false
		"timerewind":
			rewind_used = false
		"snapshot":
			snapshot_used = false
		"colorshield":
			shield_used = false
		"gravityflip", "sametypeclear", "breaker", "foresight":
			active_used = false
		_:
			return false   # 被动技能无需续用
	ad_continues += 1
	return true

# 一局结算数据（给 UI 的 result 界面）。星级/碎片是占位公式，数值待策划调。
func result() -> Dictionary:
	var won := is_won()
	var stars := 0
	if won:
		stars = 1
		if moves_left > 0:
			stars += 1
		if not objectives.is_empty() and moves_left >= int(move_limit / 3.0):
			stars += 1
		elif objectives.is_empty() and score >= target_score * 2:
			stars += 1
		stars = clampi(stars, 1, 3)
	var earned_fragments := fragments + int(score / 100.0)   # 连击收集 + 分数派生（占位）
	return {
		"won": won,
		"lost": is_lost(),
		"score": score,
		"moves_left": moves_left,
		"stars": stars,
		"fragments": earned_fragments,
	}

# ───── 铭文计分 / Meta loadout 总入口 / 开局奖励 ─────

# 计分入口：吃铭文 +积分倍率(score_mult)，返回实际加的分。
func _gain(raw: int) -> int:
	var g := int(round(raw * score_mult))
	score += g
	return g

# Meta 总入口：把 loadout()(技能+等级+铭文聚合) 应用到本局 board。在 level 起始调用。
func apply_loadout(lo: Dictionary) -> void:
	skill = String(lo.get("skill", ""))
	skill_level = int(lo.get("skill_level", 1))
	score_mult = float(lo.get("score_mult", 1.0))
	extra_moves = int(lo.get("extra_moves", 0))
	ad_continue_cap = 2 + int(lo.get("extra_skill_uses", 0))
	moves_left = move_limit + extra_moves   # 铭文 +步数（level 起始重算）
	var op := int(lo.get("opening_special", 0))
	if op != 0:
		_place_opening(op)

# 开局奖励铭文：在一个普通格放一个特效(kind)。
func _place_opening(kind: int) -> void:
	var spots := []
	for y in height:
		for x in width:
			if grid[y][x] >= 0 and fx[y][x] == ME.SP_NONE and (coat.is_empty() or coat[y][x] == 0):
				spots.append(Vector2i(x, y))
	if spots.is_empty():
		return
	var p: Vector2i = spots[rng.randi() % spots.size()]
	fx[p.y][p.x] = kind
