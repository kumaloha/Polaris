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
var init_choco: Array = []  # 初始巧克力层（障碍压力源，可选）
var choco: Array = []       # 当前巧克力层（choco[y][x]=1=巧克力格；被相邻消除则啃掉、零啃食则蔓延）
var choco_cleared: int = 0  # 累计啃掉的巧克力格
var init_ing: Array = []    # 初始原料层（运料关，可选；ing[y][x]=1=原料格，随重力下落、不可消不可换）
var ing: Array = []         # 当前原料层（落到底部出口列即被收集移除）
var exit_cols: Array = []   # 出口列：grid 物理最底行(y=h-1)的这些列 = 出口；空=默认整最底行皆出口
var ingredient_collected: int = 0  # 累计落到出口被收的原料数
var init_bomb: Array = []   # 初始炸弹层（倒计时炸弹关，可选；bomb[y][x]=N=该格剩余 N 步倒计时，0=无炸弹）
var bomb: Array = []        # 当前炸弹层（炸弹格 grid 是普通棋子，bomb 是叠加倒计时；随重力下落、被消除则拆除）
var bomb_defused: int = 0   # 累计因消除而拆掉的炸弹数（OBJ_DEFUSE_BOMB 目标）
var bomb_exploded: bool = false  # 是否有炸弹倒计时归零引爆（任一爆 → 对局立即失败，核心张力）
var init_cannon: Array = []  # 初始糖果炮层（生成器关，可选；cannon[y][x]=0 无炮/1 产普通糖/2 产原料）
var cannon: Array = []       # 当前炮层（炮口格 grid 复用 WALL=不可消不可动；每有效步从炮口下方产棋子，持续供给）
var cannon_spawned: int = 0  # 累计从炮口产出的棋子数（供测试/调试断言；非胜负目标）
var init_popcorn: Array = []  # 初始爆米花层（可选；popcorn[y][x]=N=该格被特效砸 N 次后变彩球，0=无爆米花）
var popcorn: Array = []       # 当前爆米花层（爆米花格 grid 是普通 species 占位；不可消不可换、随重力下落、特效命中-1、归0变彩球）
var popcorn_hit: int = 0      # 累计被特效命中递减的爆米花次数（供测试/调试断言；OBJ_POP_POPCORN 目标）
var init_cake: Array = []     # 初始蛋糕炸弹层（可选；cake[y][x]=N=该蛋糕剩余 N 血，0=无蛋糕）
var cake: Array = []          # 当前蛋糕层（蛋糕格 grid 复用 WALL=不可消不可动；相邻被清则-1并引爆一圈，归0大爆炸+移除）
var cake_destroyed: int = 0   # 累计炸毁(血量归0)的蛋糕数（OBJ_DESTROY_CAKE 目标）
var init_mystery: Array = []  # 初始神秘糖层（可选；mystery[y][x]=1=神秘糖格，0=无）
var mystery: Array = []       # 当前神秘糖层（神秘糖格 grid 是普通棋子=可消可换随重力下落；被消除时揭开为随机内容、mystery→0）
var mystery_revealed: int = 0 # 累计被揭开的神秘糖数（OBJ_REVEAL_MYSTERY 目标）
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
# 滚动关(挖矿)：消除时盘面只挖空(顶部不补，上面不掉落新棋子)；清到一页70%才从 feed 批量"拉新页"补满(补到一页为止)。
# feed[x]=列 x 的预设深层储备(约4页)。挖穿(清到70%且储备已空)= 通关。
var is_scrolling: bool = false
var feed: Array = []
var _dug_through: bool = false   # 滚动关：4页全挖穿标志
var last_cascade_cells: Array = []   # 最近一次交换的逐级联消除格(供视图逐级联动画)

func _init(w: int, h: int, species_set: Array, target: int, moves: int, seed_val: int, mask: Array = [], objs: Array = [], jelly_layer: Array = [], coat_layer: Array = [], choco_layer: Array = [], ingredient_layer: Array = [], exits: Array = [], bomb_layer: Array = [], cannon_layer: Array = [], popcorn_layer: Array = [], cake_layer: Array = [], mystery_layer: Array = []) -> void:
	width = w
	height = h
	species = species_set
	target_score = target
	move_limit = moves
	init_cannon = cannon_layer
	init_cake = cake_layer
	# 炮口格 / 蛋糕格均复用 WALL（不可消不可动）：把它们的位置并入墙掩码，make_board 在这些格放 WALL。
	# 这是"最小改动面"的关键——find_matches/apply_gravity/is_legal_swap 见 WALL 即生效，无需感知 cannon/cake。
	wall_mask = _merge_walls_into_mask(mask, cannon_layer, cake_layer)
	objectives = objs
	init_jelly = jelly_layer
	init_coat = coat_layer
	init_choco = choco_layer
	init_ing = ingredient_layer
	init_bomb = bomb_layer
	# 爆米花格 grid 是普通棋子(占位、非墙)：不并入 wall_mask，只作并行层叠加，由 make_board 正常铺棋子。
	init_popcorn = popcorn_layer
	# 神秘糖格 grid 是普通棋子(可消、非墙)：同爆米花，不并入 wall_mask，只作并行层叠加，由 make_board 正常铺棋子。
	init_mystery = mystery_layer
	# 出口列：未指定则默认整最底行皆出口（最小可扩展：传 exits 限定某几列为出口）。
	exit_cols = exits.duplicate() if not exits.is_empty() else _all_bottom_cols()
	rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	start()

# 默认出口：grid 最底行的全部列（0..width-1）。
func _all_bottom_cols() -> Array:
	var cols := []
	for x in width:
		cols.append(x)
	return cols

# 把炮位(cannon>0)与蛋糕位(cake>0)并入墙掩码：返回新掩码，炮口/蛋糕/原墙格皆为 true（make_board 据此放 WALL）。
# 两层皆空 → 原样返回 mask（无糖果炮/蛋糕关零开销）。
func _merge_walls_into_mask(mask: Array, cannon_layer: Array, cake_layer: Array) -> Array:
	if cannon_layer.is_empty() and cake_layer.is_empty():
		return mask
	var has_cannon := not cannon_layer.is_empty()
	var has_cake := not cake_layer.is_empty()
	var out := []
	for y in height:
		var row := []
		for x in width:
			var is_wall: bool = (not mask.is_empty()) and mask[y][x]
			var is_cannon: bool = has_cannon and cannon_layer[y][x] > 0
			var is_cake: bool = has_cake and cake_layer[y][x] > 0
			row.append(is_wall or is_cannon or is_cake)
		out.append(row)
	return out

func start() -> void:
	grid = ME.make_board(width, height, species, rng, wall_mask)
	fx = _blank_fx()
	collected = {}
	jelly = init_jelly.duplicate(true)
	jelly_cleared = 0
	coat = init_coat.duplicate(true)
	ME.apply_blocker_occupancy(grid, fx, coat)
	blocker_cleared = 0
	choco = init_choco.duplicate(true)
	choco_cleared = 0
	ing = init_ing.duplicate(true)
	ingredient_collected = 0
	bomb = init_bomb.duplicate(true)
	bomb_defused = 0
	bomb_exploded = false
	cannon = init_cannon.duplicate(true)
	cannon_spawned = 0
	popcorn = init_popcorn.duplicate(true)
	popcorn_hit = 0
	cake = init_cake.duplicate(true)
	cake_destroyed = 0
	mystery = init_mystery.duplicate(true)
	mystery_revealed = 0
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

# 七层结果累加：把 resolve / account_clears 返回的各计数加进对应 board 成员计数器。
# PROGRESS_KEYS 里每个名字同时是【结果字典键】与【board 成员属性名】（一一对应），用 get/set 驱动。
# acc(account_clears) 不含 ingredient_collected 键 → .get(k, 0) 退化为 +0，与原逐字代码完全一致（纯重构）。
const PROGRESS_KEYS := [
	"jelly_cleared", "blocker_cleared", "choco_cleared", "ingredient_collected",
	"bomb_defused", "popcorn_hit", "cake_destroyed", "mystery_revealed",
]
func _accumulate_progress(r: Dictionary) -> void:
	for k in PROGRESS_KEYS:
		set(k, get(k) + r.get(k, 0))

# 9 个可选障碍/目标层（与 grid/fx 一起构成盘面状态；grid/fx 恒非空、单独显式处理）。
# 三处共用：_snapshot 各 duplicate(true)、_restore 各 duplicate(true) 回写、skill_gravity_flip 各 reverse()。
# 名字一一对应成员变量；改/加层只需动这张表，杜绝"加层漏改某一处"。
const LAYER_NAMES := ["coat", "jelly", "choco", "ing", "bomb", "cannon", "popcorn", "cake", "mystery"]
# 快照/恢复要存的整型计数器（= 累加七层 + cannon_spawned；cannon_spawned 非累加块成员，单列于此）。
const SNAPSHOT_COUNTERS := [
	"jelly_cleared", "blocker_cleared", "choco_cleared", "ingredient_collected",
	"bomb_defused", "cannon_spawned", "popcorn_hit", "cake_destroyed", "mystery_revealed",
]

func _blank_fx() -> Array:
	var f := []
	for y in height:
		var row := []
		for x in width:
			row.append(ME.SP_NONE)
		f.append(row)
	return f

# 把本局全部障碍/目标层打包成 match_engine 约定的 Layers Dictionary（fx 不入此包，作独立参数另传）。
# match_engine 各函数用 layers.get("xxx", []) 自取所需层；这里一次性装齐 9 层，所有 resolve/gravity/account 调用复用。
func _layers() -> Dictionary:
	return {
		"jelly": jelly, "coat": coat, "choco": choco, "ing": ing,
		"bomb": bomb, "cannon": cannon, "popcorn": popcorn, "cake": cake, "mystery": mystery,
		"exit_cols": exit_cols,
	}

func is_won() -> bool:
	if borrow_debt > 0:
		return false  # 借贷铁律：欠债未还 → 不算过关（即使分数/目标已达成）
	if bomb_exploded:
		return false  # 炸弹引爆铁律：任一炸弹倒计时归零 → 本局判负，永不算赢（核心张力）
	if is_scrolling:
		return _dug_through  # 滚动关：挖穿(清到一页70%且储备已空)= 过关
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
		elif o["type"] == "CLEAR_CHOCO":
			if choco_cleared < o["target"]:
				return false
		elif o["type"] == "COLLECT_INGREDIENT":
			if ingredient_collected < o["target"]:
				return false
		elif o["type"] == "DEFUSE_BOMB":
			if bomb_defused < o["target"]:
				return false  # 拆够 N 个炸弹即达成（且全程无炸弹引爆，由上面 bomb_exploded 铁律保证）
		elif o["type"] == "POP_POPCORN":
			if popcorn_hit < o["target"]:
				return false  # 用特效砸够 N 次爆米花即达成（每次命中-1 计一次，含归0变彩球那次）
		elif o["type"] == "DESTROY_CAKE":
			if cake_destroyed < o["target"]:
				return false  # 炸毁够 N 个蛋糕(血量归0)即达成
		elif o["type"] == "REVEAL_MYSTERY":
			if mystery_revealed < o["target"]:
				return false  # 揭开够 N 个神秘糖即达成（每个神秘糖被消除时揭开计一次）
	return true

func _feed_empty() -> bool:
	for col in feed:
		if not col.is_empty():
			return false
	return true

func is_lost() -> bool:
	# 炸弹引爆 → 立即判负（不论步数；is_won 已被 bomb_exploded 铁律置假，这里显式让对局即刻失败）。
	if bomb_exploded:
		return true
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
	if not ME.is_legal_swap(grid, a, b, span, _layers()):
		return {"ok": false, "reason": "illegal"}   # ing/popcorn 格不可换（爆米花未变彩球前 fx=SP_NONE，落到此处被拒）
	if longswap_armed:
		longswap_armed = false   # 隔位对换消耗
	_push_history()   # 时间回退#2：记录走子前局面
	ME._swap_cells(grid, a, b)
	ME._swap_cells(fx, a, b)   # 特效随棋子一起交换
	last_cascade_cells = []   # 捕获本次交换的逐级联消除格
	var spawn_preference := ME.swap_special_spawn_preference(grid, fx, _layers(), b, a)
	var res: Dictionary = ME.resolve(grid, species, rng, fx, feed, not is_scrolling, last_cascade_cells, _layers(), spawn_preference, ME.SP_NONE, true)
	_gain(res["score"])
	_accumulate(res.get("by_species", {}))
	_accumulate_progress(res)   # 本步 resolve 的七层计数(果冻/涂层/巧克力/原料/炸弹/爆米花/蛋糕/神秘糖)累加进 board 计数器
	_settle_consumed_move(res.get("choco_cleared", 0), res["cascades"])
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
	# 直清的格计入目标（COLLECT/果冻/涂层/巧克力/炸弹）；锁住/巧克力/原料等受保护格只破层/揭开，不被清。须在清空 grid 前结算。
	var acc := ME.account_clears(grid, eff, fx, rng, species, _layers())
	_accumulate(acc["by_species"])
	var step_choco: int = acc.get("choco_cleared", 0)   # 本步啃食量(供 _spread_choco_if_untouched 判蔓延)，acc+res 两段累计
	_accumulate_progress(acc)   # 彩球直清的七层计数累加；原料只锁定不清，ingredient_collected 仍由重力出口收集产生
	var locked_set := {}
	for p in acc["locked"]:
		locked_set[p] = true
	var to_clear := []
	for p in eff:
		if not locked_set.has(p):
			to_clear.append(p)   # 受保护格不清（只破层/啃食/揭开）；彩球护盾时 cb 已排除
	var gained := ME.score_for_clear(to_clear.size(), 1)
	_gain(gained)
	ME._apply_clears(grid, fx, to_clear, [])   # 无 spawn，纯清除
	ME.apply_gravity(grid, fx, false, _layers())   # coat/choco 感知：障碍固定；原料/炸弹随重力落
	_refill_unless_scroll()
	var res: Dictionary = ME.resolve(grid, species, rng, fx, feed, not is_scrolling, null, _layers())   # 结算余下级联
	_gain(res["score"])
	_accumulate(res.get("by_species", {}))
	step_choco += res.get("choco_cleared", 0)   # 余下级联的啃食并入本步累计(供蔓延判定)
	_accumulate_progress(res)   # 余下级联的七层计数累加进 board 计数器
	_settle_consumed_move(step_choco, res["cascades"])
	return {"ok": true, "gained": gained + res["score"], "cascades": res["cascades"], "colorbomb": true}

# 两个特效融合引爆：按交换后方向几何清除 + 链式展开被卷入的特效，锁住格只破锁不清。
func _activate_fusion(a: Vector2i, b: Vector2i) -> Dictionary:
	var ka: int = fx[a.y][a.x]
	var kb: int = fx[b.y][b.x]
	var seeds := ME.special_fusion_cells(grid, a, b, ka, kb)
	_push_history()
	var fusion_fx: Array = fx.duplicate(true)
	fusion_fx[a.y][a.x] = ME.SP_NONE
	fusion_fx[b.y][b.x] = ME.SP_NONE
	var to_set := ME._expand_triggers(grid, fusion_fx, seeds)   # 链式展开被卷入的直线/爆炸；交换双方只按融合几何触发
	var cells: Array = to_set.keys()
	var acc := ME.account_clears(grid, cells, fx, rng, species, _layers())
	_accumulate(acc["by_species"])
	var step_choco: int = acc.get("choco_cleared", 0)   # 本步啃食量(供 _spread_choco_if_untouched 判蔓延)，acc+res 两段累计
	_accumulate_progress(acc)   # 融合直清的七层计数累加；原料只锁定不清，ingredient_collected 仍由重力出口收集产生
	var locked := {}
	for p in acc["locked"]:
		locked[p] = true
	var to_clear := []
	for p in cells:
		if not locked.has(p):
			to_clear.append(p)
	for bp in acc.get("cake_blast", []):
		to_clear.append(bp)   # 蛋糕引爆波及的普通格一并清除
	var gained := ME.score_for_clear(to_clear.size(), 1)
	_gain(gained)
	ME._apply_clears(grid, fx, to_clear, [])
	ME.apply_gravity(grid, fx, false, _layers())
	_refill_unless_scroll()
	var res: Dictionary = ME.resolve(grid, species, rng, fx, feed, not is_scrolling, null, _layers())
	_gain(res["score"])
	_accumulate(res.get("by_species", {}))
	step_choco += res.get("choco_cleared", 0)   # 余下级联的啃食并入本步累计(供蔓延判定)
	_accumulate_progress(res)   # 余下级联的七层计数累加进 board 计数器
	_settle_consumed_move(step_choco, res["cascades"])
	return {"ok": true, "gained": gained + res["score"], "cascades": res["cascades"], "fusion": true}

func _settle_consumed_move(step_choco: int, cascades: int = 0) -> void:
	moves_left -= 1
	_tick_bombs_after_move()   # 有效交换/彩球/融合消耗一步 → 存活炸弹倒计时 -1；归零未消则引爆判负
	_spread_choco_if_untouched(step_choco)   # 巧克力：整步零啃食 → 蔓延一格
	_spawn_from_cannons_after_move()   # 糖果炮：每有效步从炮口下方产棋子(普通糖/原料)，持续供给
	_on_move_resolved(cascades)   # 被动技能 #10/#11
	_settle_deadlock()

# 巧克力蔓延钩子：玩家整步若零啃食(step_eaten==0)，巧克力向随机相邻格增殖一格。
# 用 board 注入的 rng → 确定性可复现。须在 try_swap/彩球/融合 的一步完整结算后调一次。
func _spread_choco_if_untouched(step_eaten: int) -> void:
	if choco.is_empty():
		return
	if step_eaten > 0:
		return   # 这步啃到了巧克力 → 不蔓延
	ME.spread_chocolate(choco, grid, rng)

# 炸弹倒计时钩子：每次【消耗步数的有效交换/彩球/融合】完整结算后调一次（须在 resolve 拆弹之后）。
# 存活炸弹(bomb>0) 全部 -1；某格本步递减到 0 即引爆 → bomb_exploded=true → 对局立即失败。
# 一致语义：技能/免费动作（gravity_flip/clear_species/break 等，走 _settle_after_skill）不调此 → 不递减。
func _tick_bombs_after_move() -> void:
	if bomb.is_empty():
		return
	if ME.tick_bombs(bomb) > 0:
		bomb_exploded = true   # 这步有炸弹倒计时归零（且未被消除拆除）→ 引爆，本局判负

# 糖果炮产出钩子：每次【消耗步数的有效交换/彩球/融合】完整结算后调一次（须在 resolve 稳定之后）。
# 每个炮口格在其正下方空格产一个棋子(cannon=1 普通糖 / cannon=2 原料)，再结算产出物的下落+级联，
# 滚动关不补随机(do_refill=false)。须用 board 注入的 rng → 确定性可复现。
# 一致语义：技能/免费动作不调此（炮只随有效步供给，与炸弹递减同节奏）。
func _spawn_from_cannons_after_move() -> void:
	if cannon.is_empty():
		return
	var produced := ME.spawn_from_cannons(cannon, grid, species, rng, ing)
	if produced == 0:
		return
	cannon_spawned += produced
	# 产出物落进盘面 → 重力下沉 + 结算其引发的级联（含原料收集），与一次普通结算同口径推进目标。
	ME.apply_gravity(grid, fx, false, _layers())
	var res: Dictionary = ME.resolve(grid, species, rng, fx, feed, not is_scrolling, null, _layers())
	_gain(res.get("score", 0))
	_accumulate(res.get("by_species", {}))
	_accumulate_progress(res)   # 炮口产出引发级联的七层计数累加进 board 计数器

func _settle_deadlock() -> void:
	if is_scrolling:
		_scroll_advance()   # 每步统一收口：滚动关在此判"清到70%"→拉新页 / 挖穿
	if not is_over() and not ME.has_legal_move(grid, _layers()):
		ME.reshuffle(grid, rng, _layers())   # coat/choco/ing/popcorn 感知洗牌，避免洗完仍无真实合法步
		fx = _blank_fx()   # 洗牌后特效重置（极罕见边界）

# 滚动关消除时不补(resolve do_refill=false)；普通关维持原样随机补。
func _refill_unless_scroll() -> void:
	if not is_scrolling:
		ME.refill(grid, species, rng, fx, feed, _layers())

# 一页清到≥70% → 往下拉一截：批量从 feed 补满空格(补到一页为止)，再结算拉下来内容的级联(仍只挖空)。
# feed 已空又清到70% = 储备挖光 = 挖穿通关。每步收口(_settle_deadlock)调一次。
func _scroll_advance() -> void:
	if _dug_through or not _scroll_cleared_enough():
		return
	if _feed_empty():
		_dug_through = true   # 没有储备可拉 + 已清70% = 4页挖穿
		return
	ME.refill(grid, species, rng, fx, feed, _layers())   # 拉新页：批量补满空格(feed 不足的列留空)
	var res: Dictionary = ME.resolve(grid, species, rng, fx, feed, false, null, _layers())  # 拉下来只结算级联，仍不补
	_gain(res.get("score", 0))
	_accumulate(res.get("by_species", {}))
	_accumulate_progress(res)   # 拉新页引发级联的七层计数累加进 board 计数器

# 当前页是否已清到≥70%(空格占非墙格 ≥70%)。
func _scroll_cleared_enough() -> bool:
	var total := 0
	var empty := 0
	for row in grid:
		for v in row:
			if v == ME.WALL:
				continue
			total += 1
			if v == ME.EMPTY:
				empty += 1
	return total > 0 and empty * 10 >= 7 * total


# ───── 被动技能 #10/#11：走子结算后按连锁奖步/攒碎片 ─────
func _on_move_resolved(cascades: int) -> void:
	if skill == "chainbonus" and cascades >= chain_threshold:
		moves_left += 1
		bonus_moves += 1
	elif skill == "collector" and cascades >= 2:
		fragments += cascades

# ───── 局面快照（时间回退#2 / 存档快照#3 共用）─────
func _snapshot() -> Dictionary:
	# grid/fx 恒非空、单独深拷；9 个可选层与计数器各按表驱动；其余标量状态显式列。
	var s := {
		"grid": grid.duplicate(true), "fx": fx.duplicate(true),
		"score": score, "moves_left": moves_left,
		"collected": collected.duplicate(true),
		"bomb_exploded": bomb_exploded,
		"borrow_debt": borrow_debt, "rng_state": rng.state,
	}
	for name in LAYER_NAMES:
		s[name] = get(name).duplicate(true)
	for c in SNAPSHOT_COUNTERS:
		s[c] = get(c)
	return s

func _restore(s: Dictionary) -> void:
	# 与 _snapshot 对称：grid/fx 单独深拷回写；9 个可选层与计数器各按同一张表驱动；其余标量显式回写。
	grid = s["grid"].duplicate(true)
	fx = s["fx"].duplicate(true)
	for name in LAYER_NAMES:
		set(name, s[name].duplicate(true))
	for c in SNAPSHOT_COUNTERS:
		set(c, s[c])
	score = s["score"]
	moves_left = s["moves_left"]
	collected = s["collected"].duplicate(true)
	bomb_exploded = s["bomb_exploded"]
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
	# 9 个可选障碍/目标层随盘面行序倒置，保持与 grid 对齐（空层跳过）；
	# 随后 apply_gravity 用普通 down 重新沉底 → 原料/炸弹/爆米花/神秘糖落到新底行，语义一致。
	for name in LAYER_NAMES:
		var layer: Array = get(name)
		if not layer.is_empty():
			layer.reverse()
	ME.apply_gravity(grid, fx, false, _layers())
	_refill_unless_scroll()
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
	var acc := ME.account_clears(grid, cells, fx, rng, species, _layers())
	_accumulate(acc["by_species"])
	_accumulate_progress(acc)   # 同类消除直清的七层计数累加；原料只锁定不清，ingredient_collected 仍由重力出口收集产生
	var locked := {}
	for p in acc["locked"]:
		locked[p] = true
	var to_clear := []
	for p in cells:
		if not locked.has(p):
			to_clear.append(p)
	for bp in acc.get("cake_blast", []):
		to_clear.append(bp)   # 蛋糕引爆波及的普通格一并清除
	_gain(ME.score_for_clear(to_clear.size(), 1))
	ME._apply_clears(grid, fx, to_clear, [])
	ME.apply_gravity(grid, fx, false, _layers())
	_refill_unless_scroll()
	_settle_after_skill()
	active_used = true
	return true

# 破障(#9)：直接清掉至多 n 个锁住格（n 看等级）。
func skill_break(n: int = 0) -> bool:
	if skill != "breaker" or active_used or is_over():
		return false
	if n <= 0:
		n = skill_level   # 等级越高破越多（1级破1，高级破2-3）
	var broke := ME.break_blockers(coat, n, grid, fx)
	if broke <= 0:
		return false
	blocker_cleared += broke
	ME.apply_gravity(grid, fx, false, _layers())
	_refill_unless_scroll()
	_settle_after_skill()
	active_used = true
	return true

# 预知(#8)：返回最优的 k 步走法（不改盘面，供视图高亮）。
func skill_foresight(k: int = 0) -> Array:
	if skill != "foresight" or active_used or is_over():
		return []
	if k <= 0:
		k = maxi(1, skill_level)   # 等级越高亮越多步（1级亮1，高级3-5）
	active_used = true
	return ME.best_moves(grid, k, _layers(), objectives)

# 技能改动盘面后结算余下级联 + 死局兜底（不消耗步数，技能是免费动作 → 不触发巧克力蔓延、不递减炸弹倒计时）。
# 但技能消除波及的炸弹格仍算拆弹（透传 bomb 给 resolve，bomb_defused 累加）——拆弹与"是否消耗步数"无关。
func _settle_after_skill() -> void:
	var res: Dictionary = ME.resolve(grid, species, rng, fx, feed, not is_scrolling, null, _layers())
	_gain(res.get("score", 0))
	_accumulate(res.get("by_species", {}))
	_accumulate_progress(res)   # 技能改盘后余下级联的七层计数累加(免费动作不 tick 倒计时/不触发蔓延，但拆弹/命中/炸毁/揭开照算)
	_settle_deadlock()

# ───── 默认提示(#0) / 看广告续用 / 结算数据 ─────

# 默认精灵提示(#0)：返回最优 k 步（卡住引路；非战斗，无一局一次约束）。
func hint(k: int = 1) -> Array:
	return ME.best_moves(grid, k, _layers(), objectives)

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

# 通关奖励：剩余 N 步 → 随机 N 个普通棋子先变成 4 合 1 线特效，表现层随后统一触发。
func prepare_endgame_bonus_lines() -> Array:
	var count := maxi(moves_left, 0)
	if count <= 0:
		return []
	var candidates := []
	for y in height:
		for x in width:
			if _can_receive_endgame_bonus_line(y, x):
				candidates.append(Vector2i(x, y))
	var picked := []
	while picked.size() < count and not candidates.is_empty():
		var idx: int = rng.randi() % candidates.size()
		var pos: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		var kind := ME.SP_LINE_H if (rng.randi() % 2 == 0) else ME.SP_LINE_V
		fx[pos.y][pos.x] = kind
		picked.append({"pos": pos, "kind": kind})
	moves_left = 0
	return picked

func _can_receive_endgame_bonus_line(y: int, x: int) -> bool:
	if grid[y][x] < 0 or fx[y][x] != ME.SP_NONE:
		return false
	if (not coat.is_empty() and coat[y][x] > 0) or (not choco.is_empty() and choco[y][x] > 0):
		return false
	if (not ing.is_empty() and ing[y][x] > 0) or (not bomb.is_empty() and bomb[y][x] > 0):
		return false
	if (not popcorn.is_empty() and popcorn[y][x] > 0) or (not mystery.is_empty() and mystery[y][x] > 0):
		return false
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
		"is_scrolling": is_scrolling,   # 供个性化调度按类型(普通/挖矿)分别估技能
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
			if grid[y][x] >= 0 and fx[y][x] == ME.SP_NONE and (coat.is_empty() or coat[y][x] == 0) and (choco.is_empty() or choco[y][x] == 0):
				spots.append(Vector2i(x, y))
	if spots.is_empty():
		return
	var p: Vector2i = spots[rng.randi() % spots.size()]
	fx[p.y][p.x] = kind
