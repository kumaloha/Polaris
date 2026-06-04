extends RefCounted
# 纯逻辑消除引擎（无渲染依赖）——日后 C++ 求解器逐行镜像它。
# grid 约定：grid[y][x] = species(int >= 0) 或 EMPTY。坐标用 Vector2i(x, y)。

const EMPTY := -1
const WALL := -2  # 战场切割/异形棋盘：不可消、不可动、不补充；分隔区域

# 特效类型（fx 层；SP_NONE = 普通棋子）
const SP_NONE := 0
const SP_LINE_H := 1     # 直线：清整行（横向 4 连生成）
const SP_LINE_V := 2     # 直线：清整列（纵向 4 连生成）
const SP_BOMB := 3       # 爆炸：清 3x3（T/L 形生成）
const SP_COLORBOMB := 4  # 彩球：清某 species 全部（5 连生成）

# 找出所有应被消除的格子（横/竖 >=3 同 species），返回去重的 Array[Vector2i]。
static func find_matches(grid: Array, coat: Array = []) -> Array:
	var h := grid.size()
	if h == 0:
		return []
	var w: int = grid[0].size()
	var has_coat := not coat.is_empty()
	var matched := {}  # Vector2i -> true（当作 set 去重）
	# 横向扫描（EMPTY/WALL/锁住格(coat>0) 都不参与，也不能让串连过去）
	for y in h:
		var x := 0
		while x < w:
			if grid[y][x] == EMPTY or grid[y][x] == WALL or (has_coat and coat[y][x] > 0):
				x += 1
				continue
			var e := x
			while e + 1 < w and grid[y][e + 1] == grid[y][x] and not (has_coat and coat[y][e + 1] > 0):
				e += 1
			if e - x + 1 >= 3:
				for k in range(x, e + 1):
					matched[Vector2i(k, y)] = true
			x = e + 1
	# 纵向扫描
	for x in w:
		var y := 0
		while y < h:
			if grid[y][x] == EMPTY or grid[y][x] == WALL or (has_coat and coat[y][x] > 0):
				y += 1
				continue
			var e := y
			while e + 1 < h and grid[e + 1][x] == grid[y][x] and not (has_coat and coat[e + 1][x] > 0):
				e += 1
			if e - y + 1 >= 3:
				for k in range(y, e + 1):
					matched[Vector2i(x, k)] = true
			y = e + 1
	return matched.keys()


# 重力：每列非空格子落到列底，空格升到顶（原地修改 grid）。up=true 则反向上浮（重力翻转技能 #5）。
# fx 可选：传入则特效层与棋子层同步下落（保持对齐）。
static func apply_gravity(grid: Array, fx: Array = [], coat: Array = [], up: bool = false) -> void:
	var h := grid.size()
	if h == 0:
		return
	var w: int = grid[0].size()
	var has_fx := not fx.is_empty()
	var has_coat := not coat.is_empty()
	for x in w:
		# 墙 与 锁住格(coat>0) 把列切成独立段、原地固定，各段内分别下落
		var seg_start := 0
		for y in range(h + 1):
			if y == h or grid[y][x] == WALL or (has_coat and coat[y][x] > 0):
				var stack := []     # 段内非空 species（段内无墙）
				var fx_stack := []
				for k in range(seg_start, y):
					if grid[k][x] != EMPTY:
						stack.append(grid[k][x])
						if has_fx:
							fx_stack.append(fx[k][x])
				var empties := (y - seg_start) - stack.size()
				for k in range(seg_start, y):
					var idx := k - seg_start
					# 下落(down)：空格在段顶、棋子沉底；上浮(up)：棋子在段顶、空格沉底
					var is_empty_slot := (idx < empties) if not up else (idx >= stack.size())
					if is_empty_slot:
						grid[k][x] = EMPTY
						if has_fx:
							fx[k][x] = SP_NONE
					else:
						var si := (idx - empties) if not up else idx
						grid[k][x] = stack[si]
						if has_fx:
							fx[k][x] = fx_stack[si]
				seg_start = y + 1


# 随机补充：把所有 EMPTY 填成 species_set 里的随机 species（用注入的 rng → 可复现）。
# fx 可选：传入则新补的棋子特效置 SP_NONE（新棋子无特效）。
static func refill(grid: Array, species_set: Array, rng: RandomNumberGenerator, fx: Array = [], feed: Array = []) -> void:
	var n := species_set.size()
	var has_fx := not fx.is_empty()
	var has_feed := not feed.is_empty()
	# 滚动关：补充【只】按列从预设 feed 队列出(长盘内容自然下流)；feed[x] 空 = 该列挖穿 → 留空，不补随机(上面不掉落新棋子)。
	# 行序自上而下遍历 → feed 前端先填进最上方的空格，长盘从顶部下流。
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] == EMPTY:
				if has_feed:
					if x < feed.size() and not feed[x].is_empty():
						grid[y][x] = feed[x].pop_front()
					# feed[x] 空 → 留空，不补
				else:
					grid[y][x] = species_set[rng.randi() % n]
				if has_fx:
					fx[y][x] = SP_NONE


const BASE_TILE_SCORE := 10

# 一次消除的得分：消除格子数 × 基础分 × 连锁档（连锁越深越值钱 → high ceiling）。
static func score_for_clear(count: int, cascade_level: int) -> int:
	return count * BASE_TILE_SCORE * cascade_level


# 集成：消除 → 计分 → 下落 → 随机补充，循环直到盘面稳定（无消除）。
# 返回 {score, cascades, cleared}。原地修改 grid，结束时盘面保证无可消除。
# fx 可选：传入则启用多连特效（生成/触发/级联）；不传则 v1 纯消除行为。
static func resolve(grid: Array, species_set: Array, rng: RandomNumberGenerator, fx: Array = [], jelly: Array = [], coat: Array = [], feed: Array = [], do_refill: bool = true, cascades_out = null) -> Dictionary:
	# do_refill=false：消除时不补充（滚动关纯挖空；补充改由 board 在清到一页70%时批量"拉新页"）。
	# cascades_out!=null(Array)：按层记录每级联消除的格(供视图逐级联动画)；不传则零开销。
	if fx.is_empty():
		return _resolve_plain(grid, species_set, rng, jelly, coat, feed, do_refill, cascades_out)
	return _resolve_fx(grid, species_set, rng, fx, jelly, coat, feed, do_refill, cascades_out)


static func _resolve_plain(grid: Array, species_set: Array, rng: RandomNumberGenerator, jelly: Array = [], coat: Array = [], feed: Array = [], do_refill: bool = true, cascades_out = null) -> Dictionary:
	var total_score := 0
	var cascades := 0
	var cleared_total := 0
	var by_species := {}  # species -> 消除数
	var jelly_cleared := 0
	var blocker_cleared := 0
	var has_jelly := not jelly.is_empty()
	var has_coat := not coat.is_empty()
	while true:
		var matched: Array = find_matches(grid, coat)
		if matched.is_empty():
			break
		cascades += 1
		if cascades_out != null:
			cascades_out.append(matched.duplicate())
		if has_coat:
			var matched_set := {}
			for p in matched:
				matched_set[p] = true
			for cy in grid.size():
				for cx in grid[cy].size():
					if coat[cy][cx] <= 0:
						continue
					if matched_set.has(Vector2i(cx, cy)) or matched_set.has(Vector2i(cx - 1, cy)) or matched_set.has(Vector2i(cx + 1, cy)) or matched_set.has(Vector2i(cx, cy - 1)) or matched_set.has(Vector2i(cx, cy + 1)):
						coat[cy][cx] -= 1
						blocker_cleared += 1
		for pos in matched:
			var sp_p: int = grid[pos.y][pos.x]
			if sp_p >= 0:
				by_species[sp_p] = by_species.get(sp_p, 0) + 1
			if has_jelly and jelly[pos.y][pos.x] > 0:
				jelly[pos.y][pos.x] -= 1
				jelly_cleared += 1
			grid[pos.y][pos.x] = EMPTY
		cleared_total += matched.size()
		total_score += score_for_clear(matched.size(), cascades)
		apply_gravity(grid, [], coat)
		if do_refill:
			refill(grid, species_set, rng, [], feed)
	return {"score": total_score, "cascades": cascades, "cleared": cleared_total, "by_species": by_species, "jelly_cleared": jelly_cleared, "blocker_cleared": blocker_cleared}


# 彩球被交换引爆：清掉 partner 的整种颜色（+彩球+partner），双彩球则清全盘。
# 返回要清的格（含被卷入的直线/爆炸特效的触发链；不再触发其他彩球）。纯函数。
static func colorbomb_clear_set(grid: Array, fx: Array, cb_pos: Vector2i, partner_pos: Vector2i) -> Array:
	var seeds := []
	if fx[partner_pos.y][partner_pos.x] == SP_COLORBOMB:
		# 双彩球 → 清全盘非空（排除墙：墙不可消）
		for y in grid.size():
			for x in grid[y].size():
				if grid[y][x] != EMPTY and grid[y][x] != WALL:
					seeds.append(Vector2i(x, y))
	else:
		var target: int = grid[partner_pos.y][partner_pos.x]
		seeds = special_effect_cells(grid, cb_pos, SP_COLORBOMB, target)
		seeds.append(cb_pos)
		seeds.append(partner_pos)
	# 触发链：被卷入的直线/爆炸继续触发；但不再触发其他彩球（避免自激/递归）
	var to_clear := {}
	var queue := []
	for c in seeds:
		if not to_clear.has(c):
			to_clear[c] = true
			if fx[c.y][c.x] != SP_NONE and fx[c.y][c.x] != SP_COLORBOMB:
				queue.append(c)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for e in special_effect_cells(grid, c, fx[c.y][c.x], grid[c.y][c.x]):
			if not to_clear.has(e):
				to_clear[e] = true
				if fx[e.y][e.x] != SP_NONE and fx[e.y][e.x] != SP_COLORBOMB:
					queue.append(e)
	return to_clear.keys()


static func _resolve_fx(grid: Array, species_set: Array, rng: RandomNumberGenerator, fx: Array, jelly: Array = [], coat: Array = [], feed: Array = [], do_refill: bool = true, cascades_out = null) -> Dictionary:
	var total_score := 0
	var cascades := 0
	var cleared_total := 0
	var by_species := {}
	var jelly_cleared := 0
	var blocker_cleared := 0
	var has_jelly := not jelly.is_empty()
	var has_coat := not coat.is_empty()
	while true:
		var c := collect_clears(grid, fx, coat)
		var raw: Array = c["to_clear"]
		if raw.is_empty():
			break
		cascades += 1
		if cascades_out != null:
			cascades_out.append(raw.duplicate())
		# 锁住格(coat>0)不被清除：记下"开始时就锁住"的格，本回合只破锁、不清（下次才消）
		var cleared_set := {}
		var locked_start := {}
		for p in raw:
			cleared_set[p] = true
			if has_coat and coat[p.y][p.x] > 0:
				locked_start[p] = true
		# 破锁：被清除格的内/相邻的锁住格 -1（锁住格本身不被清）
		if has_coat:
			for cy in grid.size():
				for cx in grid[cy].size():
					if coat[cy][cx] <= 0:
						continue
					if cleared_set.has(Vector2i(cx, cy)) or cleared_set.has(Vector2i(cx - 1, cy)) or cleared_set.has(Vector2i(cx + 1, cy)) or cleared_set.has(Vector2i(cx, cy - 1)) or cleared_set.has(Vector2i(cx, cy + 1)):
						coat[cy][cx] -= 1
						blocker_cleared += 1
		# 真正清除的 = raw 里"开始时未锁"的格
		var to_clear := []
		for p in raw:
			if not locked_start.has(p):
				to_clear.append(p)
		cleared_total += to_clear.size()
		total_score += score_for_clear(to_clear.size(), cascades)
		var spawn_set := {}
		for s in c["spawns"]:
			spawn_set[s["pos"]] = true
		for pos in to_clear:
			if not spawn_set.has(pos):
				var sp_p: int = grid[pos.y][pos.x]
				if sp_p >= 0:
					by_species[sp_p] = by_species.get(sp_p, 0) + 1
			if has_jelly and jelly[pos.y][pos.x] > 0:
				jelly[pos.y][pos.x] -= 1
				jelly_cleared += 1
		_apply_clears(grid, fx, to_clear, c["spawns"])
		apply_gravity(grid, fx, coat)
		if do_refill:
			refill(grid, species_set, rng, fx, feed)
	return {"score": total_score, "cascades": cascades, "cleared": cleared_total, "by_species": by_species, "jelly_cleared": jelly_cleared, "blocker_cleared": blocker_cleared}


# 交换是否合法：相邻 + 交换后能形成消除（v1 无特效）。不修改 grid。
static func is_legal_swap(grid: Array, a: Vector2i, b: Vector2i, coat: Array = [], span: int = 1) -> bool:
	# 正交、同行或列、间距=span（span=1 相邻；span=2 隔一格=隔位对换技能 #4，仅 Godot 玩家侧）
	var in_range: bool = (a.y == b.y and abs(a.x - b.x) == span) or (a.x == b.x and abs(a.y - b.y) == span)
	if not in_range:
		return false
	var va = grid[a.y][a.x]
	var vb = grid[b.y][b.x]
	if va == WALL or vb == WALL or va == EMPTY or vb == EMPTY:
		return false  # 墙/空格不可参与交换（墙不可动）
	if not coat.is_empty() and (coat[a.y][a.x] > 0 or coat[b.y][b.x] > 0):
		return false  # 冻住的格不可换
	_swap_cells(grid, a, b)
	var found := not find_matches(grid, coat).is_empty()
	_swap_cells(grid, a, b)  # 还原
	return found

# 交换两格内容（原地）。GDScript 无元组交换，用临时变量。
static func _swap_cells(grid: Array, a: Vector2i, b: Vector2i) -> void:
	var t = grid[a.y][a.x]
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = t


# 是否存在任一合法交换（无 → 死局，需洗牌）。
static func has_legal_move(grid: Array, coat: Array = []) -> bool:
	var h := grid.size()
	if h == 0:
		return false
	var w: int = grid[0].size()
	for y in h:
		for x in w:
			if x + 1 < w and is_legal_swap(grid, Vector2i(x, y), Vector2i(x + 1, y), coat):
				return true
			if y + 1 < h and is_legal_swap(grid, Vector2i(x, y), Vector2i(x, y + 1), coat):
				return true
	return false


# 构造初始盘：逐格随机但避免凑成 3 连（开局无现成消除），并保证至少有一个合法移动。
static func make_board(w: int, h: int, species: Array, rng: RandomNumberGenerator, wall_mask: Array = []) -> Array:
	var has_mask := not wall_mask.is_empty()
	var grid := []
	for _attempt in 50:
		grid = []
		for y in h:
			var row := []
			for x in w:
				if has_mask and wall_mask[y][x]:
					row.append(WALL)
					continue
				var choices: Array = species.duplicate()
				# 避免横向三连：左边两格已同色，则排除该色
				if x >= 2 and row[x - 1] == row[x - 2]:
					choices.erase(row[x - 1])
				# 避免纵向三连：上面两格已同色，则排除该色
				if y >= 2 and grid[y - 1][x] == grid[y - 2][x]:
					choices.erase(grid[y - 2][x])
				if choices.is_empty():
					choices = species.duplicate()
				row.append(choices[rng.randi() % choices.size()])
			grid.append(row)
		if has_legal_move(grid):
			return grid
	return grid  # 兜底（极罕见：50 次都无合法移动）


# 死局/有现成消除时洗牌：重排现有棋子（多重集不变），直到无现成消除且有合法移动。
static func reshuffle(grid: Array, rng: RandomNumberGenerator, coat: Array = []) -> void:
	var h := grid.size()
	if h == 0:
		return
	var w: int = grid[0].size()
	# 只重排可动棋子；墙(WALL)/空格(EMPTY)固定不参与洗牌——否则异形棋盘会被打乱、墙乱飞。
	var positions := []
	var tiles := []
	for y in h:
		for x in w:
			var v: int = grid[y][x]
			if v == WALL or v == EMPTY:
				continue
			positions.append(Vector2i(x, y))
			tiles.append(v)
	var safe_tiles := []   # 记一个"至少无现成消除"的排列作兜底（避免开局即级联）
	for _attempt in 100:
		_shuffle(tiles, rng)
		for i in positions.size():
			var p: Vector2i = positions[i]
			grid[p.y][p.x] = tiles[i]
		# 验收须 coat 感知：忽略冰锁会"看似有步、真实玩家无步"。
		var no_match := find_matches(grid, coat).is_empty()
		if no_match and has_legal_move(grid, coat):
			return   # 理想：无现成消除 + 有合法步
		if no_match and safe_tiles.is_empty():
			safe_tiles = tiles.duplicate()
	# 没凑出理想排列：退而求其次用"至少无现成消除"的（可能无合法步=真死局，罕见）
	if not safe_tiles.is_empty():
		for i in positions.size():
			var p: Vector2i = positions[i]
			grid[p.y][p.x] = safe_tiles[i]
	# 否则保留最后一次（极端病态，几乎不可达）

# Fisher-Yates 洗牌（用注入的 rng → 可复现；Array.shuffle 用全局 RNG 不可 seed）。
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


# 分类消除：识别每个 >=3 直线串，决定生成什么特效。
# 返回 {clear: Array[Vector2i] 要清空的格, spawns: Array[{pos, kind}] 要生成的特效格}。
# 规则（v1.1 直线串）：>=5 连→彩球；==4 连→直线(横H/竖V)；==3 连→普通清除。
# （T/L 形爆炸在后续步骤补。spawns 的 pos 不进 clear——它变成特效而非清空。）
static func classify_matches(grid: Array, coat: Array = []) -> Dictionary:
	var h := grid.size()
	if h == 0:
		return {"clear": [], "spawns": []}
	var w: int = grid[0].size()
	var has_coat := not coat.is_empty()

	# 收集所有 >=3 的横/纵直线串：{cells, len, mid}
	var h_runs := []
	for y in h:
		var x := 0
		while x < w:
			if grid[y][x] == EMPTY or grid[y][x] == WALL or (has_coat and coat[y][x] > 0):
				x += 1
				continue
			var e := x
			while e + 1 < w and grid[y][e + 1] == grid[y][x] and not (has_coat and coat[y][e + 1] > 0):
				e += 1
			if e - x + 1 >= 3:
				var cells := []
				for k in range(x, e + 1):
					cells.append(Vector2i(k, y))
				h_runs.append({"cells": cells, "len": e - x + 1, "mid": Vector2i((x + e) / 2, y)})
			x = e + 1
	var v_runs := []
	for x in w:
		var y := 0
		while y < h:
			if grid[y][x] == EMPTY or grid[y][x] == WALL or (has_coat and coat[y][x] > 0):
				y += 1
				continue
			var e := y
			while e + 1 < h and grid[e + 1][x] == grid[y][x] and not (has_coat and coat[e + 1][x] > 0):
				e += 1
			if e - y + 1 >= 3:
				var cells := []
				for k in range(y, e + 1):
					cells.append(Vector2i(x, k))
				v_runs.append({"cells": cells, "len": e - y + 1, "mid": Vector2i(x, (y + e) / 2)})
			y = e + 1

	# matched 全集 + H/V 归属
	var in_h := {}
	var in_v := {}
	var matched := {}
	for r in h_runs:
		for c in r["cells"]:
			in_h[c] = true
			matched[c] = true
	for r in v_runs:
		for c in r["cells"]:
			in_v[c] = true
			matched[c] = true

	# 生成特效，优先级：彩球(5连) > 爆炸(交点) > 直线(4连)
	var spawns := []
	var spawn_at := {}     # pos -> true（一个格只生成一个特效）

	for r in (h_runs + v_runs):
		if r["len"] >= 5 and not spawn_at.has(r["mid"]):
			spawns.append({"pos": r["mid"], "kind": SP_COLORBOMB})
			spawn_at[r["mid"]] = true

	for c in matched.keys():
		if in_h.has(c) and in_v.has(c) and not spawn_at.has(c):
			spawns.append({"pos": c, "kind": SP_BOMB})  # T/L/+ 交点
			spawn_at[c] = true

	# 垂直约定(对齐 Candy Crush)：横向4连→竖直特效(清列)、纵向4连→横向特效(清行)。
	for r in h_runs:
		if r["len"] == 4 and not _run_intersects(r["cells"], in_v) and not spawn_at.has(r["mid"]):
			spawns.append({"pos": r["mid"], "kind": SP_LINE_V})
			spawn_at[r["mid"]] = true
	for r in v_runs:
		if r["len"] == 4 and not _run_intersects(r["cells"], in_h) and not spawn_at.has(r["mid"]):
			spawns.append({"pos": r["mid"], "kind": SP_LINE_H})
			spawn_at[r["mid"]] = true

	var clear_list := []
	for pos in matched.keys():
		if not spawn_at.has(pos):
			clear_list.append(pos)
	return {"clear": clear_list, "spawns": spawns}

static func _run_intersects(cells: Array, other_membership: Dictionary) -> bool:
	for c in cells:
		if other_membership.has(c):
			return true
	return false


# 一个特效被触发时清除哪些格（不含触发链，链由 resolve 处理）。
# COLORBOMB 需 target species（被它换中的那种颜色）。
static func special_effect_cells(grid: Array, pos: Vector2i, kind: int, target: int = -1) -> Array:
	var h := grid.size()
	var w: int = grid[0].size()
	var out := []
	match kind:
		SP_LINE_H:
			for x in w:
				if grid[pos.y][x] != WALL and grid[pos.y][x] != EMPTY:
					out.append(Vector2i(x, pos.y))
		SP_LINE_V:
			for y in h:
				if grid[y][pos.x] != WALL and grid[y][pos.x] != EMPTY:
					out.append(Vector2i(pos.x, y))
		SP_BOMB:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := pos.x + dx
					var ny := pos.y + dy
					if nx >= 0 and nx < w and ny >= 0 and ny < h and grid[ny][nx] != WALL and grid[ny][nx] != EMPTY:
						out.append(Vector2i(nx, ny))
		SP_COLORBOMB:
			for y in h:
				for x in w:
					if grid[y][x] == target:
						out.append(Vector2i(x, y))
	return out


# 汇总一次消除要清的全部格：>=3 匹配 + 命中的特效触发链（特效连特效）。
# 返回 {to_clear: Array[Vector2i], spawns: Array[{pos,kind}]}（spawns 来自匹配形状）。
# 纯函数，不修改 grid/fx。
static func collect_clears(grid: Array, fx: Array, coat: Array = []) -> Dictionary:
	var to_clear := _expand_triggers(grid, fx, find_matches(grid, coat))
	var cls := classify_matches(grid, coat)
	return {"to_clear": to_clear.keys(), "spawns": cls["spawns"]}

# 从 seed 格出发，沿特效触发链 BFS 展开，返回所有应清的格（Dictionary 当 set）。
static func _expand_triggers(grid: Array, fx: Array, seeds: Array) -> Dictionary:
	var to_clear := {}
	var queue := []
	for c in seeds:
		if not to_clear.has(c):
			to_clear[c] = true
			if fx[c.y][c.x] != SP_NONE:
				queue.append(c)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for e in special_effect_cells(grid, c, fx[c.y][c.x], grid[c.y][c.x]):
			if not to_clear.has(e):
				to_clear[e] = true
				if fx[e.y][e.x] != SP_NONE:
					queue.append(e)
	return to_clear


# 执行清除：spawn 格落特效（保留 species），其余格清空（grid=EMPTY, fx=NONE）。原地修改。
static func _apply_clears(grid: Array, fx: Array, to_clear: Array, spawns: Array) -> void:
	var spawn_map := {}
	for s in spawns:
		spawn_map[s["pos"]] = s["kind"]
	for pos in to_clear:
		if grid[pos.y][pos.x] == WALL:
			continue  # 兜底：墙绝不被清、不落特效（异形棋盘契约：不可消、不可动）
		if spawn_map.has(pos):
			fx[pos.y][pos.x] = spawn_map[pos]  # 落特效，保留 species
		else:
			grid[pos.y][pos.x] = EMPTY
			fx[pos.y][pos.x] = SP_NONE


# 把"一组被直接清掉的格"计入目标账：by_species(收集) / 果冻 / 涂层。原地递减 jelly/coat，不改 grid。
# 用于彩球直清等不经 resolve 匹配循环的清除路径，使其与普通消除同样推进目标。
# 涂层语义与 resolve 一致：清除格内或正交相邻的涂层 -1 层。须在清空 grid 前调用（读 species）。
static func account_clears(grid: Array, cells: Array, jelly: Array = [], coat: Array = []) -> Dictionary:
	var by_species := {}
	var jelly_cleared := 0
	var blocker_cleared := 0
	var has_jelly := not jelly.is_empty()
	var has_coat := not coat.is_empty()
	var locked := {}  # 开始时锁住的格：只破锁，不被清/不计入收集·果冻
	if has_coat:
		for p in cells:
			if coat[p.y][p.x] > 0:
				locked[p] = true
		var cleared_set := {}
		for p in cells:
			cleared_set[p] = true
		for cy in grid.size():
			for cx in grid[cy].size():
				if coat[cy][cx] <= 0:
					continue
				if cleared_set.has(Vector2i(cx, cy)) or cleared_set.has(Vector2i(cx - 1, cy)) or cleared_set.has(Vector2i(cx + 1, cy)) or cleared_set.has(Vector2i(cx, cy - 1)) or cleared_set.has(Vector2i(cx, cy + 1)):
					coat[cy][cx] -= 1
					blocker_cleared += 1
	for pos in cells:
		if locked.has(pos):
			continue  # 锁住格不被清除，不计入收集/果冻（仅上面破锁）
		var sp_p: int = grid[pos.y][pos.x]
		if sp_p >= 0:
			by_species[sp_p] = by_species.get(sp_p, 0) + 1
		if has_jelly and jelly[pos.y][pos.x] > 0:
			jelly[pos.y][pos.x] -= 1
			jelly_cleared += 1
	return {"by_species": by_species, "jelly_cleared": jelly_cleared, "blocker_cleared": blocker_cleared, "locked": locked.keys()}


# ───────────── Meta 技能原语（玩家侧能力的引擎钩子，见 10 §7；不进 C++ 基准）─────────────

# 同类消除(#7)：返回某 species 的全部格（清除/计目标交给 board 的 account_clears）。
static func cells_of_species(grid: Array, sp: int) -> Array:
	var out := []
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] == sp:
				out.append(Vector2i(x, y))
	return out

# 破障(#9)：清掉至多 n 个锁住格（coat 归 0），返回实际破掉的格数。原地改 coat。
static func break_blockers(coat: Array, n: int) -> int:
	var broken := 0
	for y in coat.size():
		for x in coat[y].size():
			if broken >= n:
				return broken
			if coat[y][x] > 0:
				coat[y][x] = 0
				broken += 1
	return broken

# 枚举全部合法交换（预知/默认提示用）。返回 [[a:Vector2i, b:Vector2i], ...]，coat 感知。
static func legal_moves(grid: Array, coat: Array = []) -> Array:
	var h := grid.size()
	if h == 0:
		return []
	var w: int = grid[0].size()
	var out := []
	for y in h:
		for x in w:
			if x + 1 < w and is_legal_swap(grid, Vector2i(x, y), Vector2i(x + 1, y), coat):
				out.append([Vector2i(x, y), Vector2i(x + 1, y)])
			if y + 1 < h and is_legal_swap(grid, Vector2i(x, y), Vector2i(x, y + 1), coat):
				out.append([Vector2i(x, y), Vector2i(x, y + 1)])
	return out

# 特效主动融合：两个特效相邻交换时的合并清除几何（排除墙）。pos=融合点。
# 直线×直线 → 十字(整行+整列)；爆炸×爆炸 → 5x5；直线×爆炸 → 粗十字(3行+3列)。
static func special_fusion_cells(grid: Array, pos: Vector2i, ka: int, kb: int) -> Array:
	var h := grid.size()
	var w: int = grid[0].size()
	var cset := {}
	var a_line := ka == SP_LINE_H or ka == SP_LINE_V
	var b_line := kb == SP_LINE_H or kb == SP_LINE_V
	var a_bomb := ka == SP_BOMB
	var b_bomb := kb == SP_BOMB
	if a_line and b_line:
		for x in w:
			cset[Vector2i(x, pos.y)] = true
		for y in h:
			cset[Vector2i(pos.x, y)] = true
	elif a_bomb and b_bomb:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var nx := pos.x + dx
				var ny := pos.y + dy
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					cset[Vector2i(nx, ny)] = true
	else:  # 直线 + 爆炸 → 粗十字(3 行 + 3 列)
		for dy in range(-1, 2):
			var ry := pos.y + dy
			if ry >= 0 and ry < h:
				for x in w:
					cset[Vector2i(x, ry)] = true
		for dx in range(-1, 2):
			var rx := pos.x + dx
			if rx >= 0 and rx < w:
				for y in h:
					cset[Vector2i(rx, y)] = true
	var out := []
	for c in cset:
		if grid[c.y][c.x] != WALL:
			out.append(c)
	return out


# 预知(#8)：运行时轻量 1-ply 求解器——按"即时消除格数 + 目标推进"给合法交换打分，返回最优 k 步。
# 目标感知：objectives 里 COLLECT 的目标色被消到则加权（呼应 C++ move_value）。不跑随机补充（确定性提示，不剧透掉落）。
static func best_moves(grid: Array, k: int, coat: Array = [], objectives: Array = []) -> Array:
	var moves := legal_moves(grid, coat)
	var scored := []
	for mv in moves:
		_swap_cells(grid, mv[0], mv[1])
		var m: Array = find_matches(grid, coat)
		var val := m.size()
		if not objectives.is_empty():
			for o in objectives:
				if o.get("type", "") == "COLLECT":
					var sp: int = o.get("species", -1)
					for p in m:
						if grid[p.y][p.x] == sp:
							val += 100
		_swap_cells(grid, mv[0], mv[1])  # 还原
		scored.append({"mv": mv, "val": val})
	scored.sort_custom(func(a, b): return a["val"] > b["val"])
	var out := []
	for i in range(min(k, scored.size())):
		out.append(scored[i]["mv"])
	return out
