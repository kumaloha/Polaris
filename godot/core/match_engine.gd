extends RefCounted
# 纯逻辑消除引擎（无渲染依赖）——日后 C++ 求解器逐行镜像它。
# grid 约定：grid[y][x] = species(int >= 0) 或 EMPTY。坐标用 Vector2i(x, y)。
#
# 【层组织约定 — GDScript 与 C++ 的差异】
# 障碍/目标层在 GDScript 侧统一收进一个 Layers Dictionary 传递，键名固定：
#   "jelly" / "coat" / "choco" / "ing" / "bomb" / "popcorn" / "cake" / "mystery" / "exit_cols"。
#   函数内用 layers.get("coat", []) 取出，缺省 []（只装需要的层，其余省略）。
#   fx（特效层）保留为独立参数——它与 grid 同等核心、几乎所有函数直接用它，不并入 layers。
# C++ 基准侧仍用【参数列表】逐个传层（无 Dictionary）。两端【逻辑完全一致】，只是参数的组织方式不同：
#   GDScript=Layers Dictionary（防参数爆炸） / C++=显式参数列表（静态类型、零哈希开销）。
# 镜像时把这里的 layers.get("xxx", []) 一一对应到 C++ 的 xxx 形参即可。

const EMPTY := -1
const WALL := -2  # 战场切割/异形棋盘：不可消、不可动、不补充；分隔区域

# 特效类型（fx 层；SP_NONE = 普通棋子）
const SP_NONE := 0
const SP_LINE_H := 1     # 直线：清整行（横向 4 连生成）
const SP_LINE_V := 2     # 直线：清整列（纵向 4 连生成）
const SP_BOMB := 3       # 爆炸：清 3x3（T/L 形生成）
const SP_COLORBOMB := 4  # 彩球：清某 species 全部（5 连生成）

# 找出所有应被消除的格子（横/竖 >=3 同 species），返回去重的 Array[Vector2i]。
# choco 可选：巧克力格(choco>0)与锁住格(coat>0)同样不参与匹配、不能让串连过去。
# ing 可选：原料格(ing>0)同样不参与匹配、不能让串连过去（原料不可消，但会随重力下落）。
# popcorn 可选：爆米花格(popcorn>0)同样不参与普通匹配、不能让串连过去（爆米花只认特效命中，普通三消不碰它，像 ing 但随重力下落）。
static func find_matches(grid: Array, layers: Dictionary = {}) -> Array:
	var coat: Array = layers.get("coat", [])
	var choco: Array = layers.get("choco", [])
	var ing: Array = layers.get("ing", [])
	var popcorn: Array = layers.get("popcorn", [])
	var h := grid.size()
	if h == 0:
		return []
	var w: int = grid[0].size()
	var has_coat := not coat.is_empty()
	var has_choco := not choco.is_empty()
	var has_ing := not ing.is_empty()
	var has_pop := not popcorn.is_empty()
	var matched := {}  # Vector2i -> true（当作 set 去重）
	# 横向扫描（EMPTY/WALL/锁住格(coat>0)/巧克力格(choco>0)/原料格(ing>0)/爆米花格(popcorn>0) 都不参与，也不能让串连过去）
	for y in h:
		var x := 0
		while x < w:
			if grid[y][x] == EMPTY or grid[y][x] == WALL or (has_coat and coat[y][x] > 0) or (has_choco and choco[y][x] > 0) or (has_ing and ing[y][x] > 0) or (has_pop and popcorn[y][x] > 0):
				x += 1
				continue
			var e := x
			while e + 1 < w and grid[y][e + 1] == grid[y][x] and not (has_coat and coat[y][e + 1] > 0) and not (has_choco and choco[y][e + 1] > 0) and not (has_ing and ing[y][e + 1] > 0) and not (has_pop and popcorn[y][e + 1] > 0):
				e += 1
			if e - x + 1 >= 3:
				for k in range(x, e + 1):
					matched[Vector2i(k, y)] = true
			x = e + 1
	# 纵向扫描
	for x in w:
		var y := 0
		while y < h:
			if grid[y][x] == EMPTY or grid[y][x] == WALL or (has_coat and coat[y][x] > 0) or (has_choco and choco[y][x] > 0) or (has_ing and ing[y][x] > 0) or (has_pop and popcorn[y][x] > 0):
				y += 1
				continue
			var e := y
			while e + 1 < h and grid[e + 1][x] == grid[y][x] and not (has_coat and coat[e + 1][x] > 0) and not (has_choco and choco[e + 1][x] > 0) and not (has_ing and ing[e + 1][x] > 0) and not (has_pop and popcorn[e + 1][x] > 0):
				e += 1
			if e - y + 1 >= 3:
				for k in range(y, e + 1):
					matched[Vector2i(x, k)] = true
			y = e + 1
	return matched.keys()


# 重力：每列非空格子落到列底，空格升到顶（原地修改 grid）。up=true 则反向上浮（重力翻转技能 #5）。
# fx 可选：传入则特效层与棋子层同步下落（保持对齐）。
# choco 可选：巧克力格(choco>0)与锁住格(coat>0)一样原地固定、把列切段（巧克力不下落）。
# ing 可选：原料格(ing>0)与普通棋子一样【随重力下落】（不切段、不固定）——这是原料与 choco 的关键区别。
#   原料是可移动格，作为段内一个元素和 grid 一起沉底，ing 层与 grid 列同步重排（像 fx 那样跟随）。
# bomb 可选：炸弹倒计时标记。炸弹格的 grid 是【普通棋子】(可消可换)，bomb 只是叠加的倒计时——
#   故 bomb 既不切段也不阻断匹配/交换，仅作为标记【随 grid 同步搬运】（与 ing 同样跟随，但语义更纯：纯标记）。
# popcorn 可选：爆米花剩余命中数。爆米花格 grid 是普通 species(占位)、不可消，但【随重力下落】——
#   与 ing/bomb 同构：不切段、作为段内可动元素的标记随 grid 同序搬运。
# mystery 可选：神秘糖标记。神秘糖格 grid 是【普通 species】(可消可换)，mystery 只是叠加的"这格是神秘糖"标记——
#   故 mystery 既不切段也不阻断匹配/交换，仅作为标记【随 grid 同步搬运】（与 bomb 同构：纯标记跟随）。
#   神秘糖随重力下落时其 mystery 标记必须跟着移动，否则下落后标记与真身错位，故此处给 apply_gravity 加 mystery 参数。
static func apply_gravity(grid: Array, fx: Array = [], up: bool = false, layers: Dictionary = {}) -> void:
	var coat: Array = layers.get("coat", [])
	var choco: Array = layers.get("choco", [])
	var ing: Array = layers.get("ing", [])
	var bomb: Array = layers.get("bomb", [])
	var popcorn: Array = layers.get("popcorn", [])
	var mystery: Array = layers.get("mystery", [])
	var h := grid.size()
	if h == 0:
		return
	var w: int = grid[0].size()
	var has_fx := not fx.is_empty()
	var has_coat := not coat.is_empty()
	var has_choco := not choco.is_empty()
	var has_ing := not ing.is_empty()
	var has_bomb := not bomb.is_empty()
	var has_pop := not popcorn.is_empty()
	var has_mystery := not mystery.is_empty()
	for x in w:
		# 墙 与 锁住格(coat>0) 与 巧克力格(choco>0) 把列切成独立段、原地固定，各段内分别下落。
		# 原料(ing>0) 不切段——它是段内可移动元素，随段一起下落。炸弹(bomb>0)/爆米花(popcorn>0)同样不切段（皆段内可动格）。
		var seg_start := 0
		for y in range(h + 1):
			if y == h or grid[y][x] == WALL or (has_coat and coat[y][x] > 0) or (has_choco and choco[y][x] > 0):
				var stack := []     # 段内非空 species（段内无墙）
				var fx_stack := []
				var ing_stack := []   # 段内每个可动格的原料标记，随 stack 同序搬运（原料随棋子一起落）
				var bomb_stack := []  # 段内每个可动格的炸弹倒计时，随 stack 同序搬运（炸弹随棋子一起落）
				var pop_stack := []   # 段内每个可动格的爆米花命中数，随 stack 同序搬运（爆米花随棋子一起落）
				var mys_stack := []   # 段内每个可动格的神秘糖标记，随 stack 同序搬运（神秘糖随棋子一起落）
				for k in range(seg_start, y):
					if grid[k][x] != EMPTY:
						stack.append(grid[k][x])
						if has_fx:
							fx_stack.append(fx[k][x])
						if has_ing:
							ing_stack.append(ing[k][x])
						if has_bomb:
							bomb_stack.append(bomb[k][x])
						if has_pop:
							pop_stack.append(popcorn[k][x])
						if has_mystery:
							mys_stack.append(mystery[k][x])
				var empties := (y - seg_start) - stack.size()
				for k in range(seg_start, y):
					var idx := k - seg_start
					# 下落(down)：空格在段顶、棋子沉底；上浮(up)：棋子在段顶、空格沉底
					var is_empty_slot := (idx < empties) if not up else (idx >= stack.size())
					if is_empty_slot:
						grid[k][x] = EMPTY
						if has_fx:
							fx[k][x] = SP_NONE
						if has_ing:
							ing[k][x] = 0   # 空格无原料
						if has_bomb:
							bomb[k][x] = 0   # 空格无炸弹
						if has_pop:
							popcorn[k][x] = 0   # 空格无爆米花
						if has_mystery:
							mystery[k][x] = 0   # 空格无神秘糖
					else:
						var si := (idx - empties) if not up else idx
						grid[k][x] = stack[si]
						if has_fx:
							fx[k][x] = fx_stack[si]
						if has_ing:
							ing[k][x] = ing_stack[si]   # 原料标记随该格内容一起落
						if has_bomb:
							bomb[k][x] = bomb_stack[si]   # 炸弹倒计时随该格内容一起落
						if has_pop:
							popcorn[k][x] = pop_stack[si]   # 爆米花命中数随该格内容一起落
						if has_mystery:
							mystery[k][x] = mys_stack[si]   # 神秘糖标记随该格内容一起落
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
static func resolve(grid: Array, species_set: Array, rng: RandomNumberGenerator, fx: Array = [], feed: Array = [], do_refill: bool = true, cascades_out = null, layers: Dictionary = {}) -> Dictionary:
	# do_refill=false：消除时不补充（滚动关纯挖空；补充改由 board 在清到一页70%时批量"拉新页"）。
	# cascades_out!=null(Array)：按层记录每级联消除的格(供视图逐级联动画)；不传则零开销。
	# choco 可选：巧克力层。结果里附带 choco_cleared = 本步啃掉的巧克力格数（被相邻消除则 -1）。
	# ing/exit_cols 可选：原料层 + 出口列。结果里附带 ingredient_collected = 本步落到出口被收的原料格数。
	# bomb 可选：炸弹倒计时层。被消除的炸弹格 bomb→0（拆弹）。结果里附带 bomb_defused = 本步因消除而拆掉的炸弹数。
	# popcorn 可选：爆米花层。被【特效】清除波及的爆米花格 popcorn-1(不清)，归0变彩球(SP_COLORBOMB)；普通三消不碰它。
	#   结果里附带 popcorn_hit = 本步被特效命中递减的爆米花次数。仅特效路径(_resolve_fx)有意义；纯三消(_resolve_plain)不触发。
	# mystery 可选：神秘糖层。神秘糖格 grid 是普通棋子(可消可换)，被消除时【揭开】为随机内容(mystery→0)而非清空。
	#   结果里附带 mystery_revealed = 本步被揭开的神秘糖数。两条路径(纯三消/特效)都支持；揭开内容按 70/20/10 概率(rng 确定性)。
	if fx.is_empty():
		return _resolve_plain(grid, species_set, rng, feed, do_refill, cascades_out, layers)
	return _resolve_fx(grid, species_set, rng, fx, feed, do_refill, cascades_out, layers)


# 原料下沉收集循环：消除稳定后，原料可能仍悬在出口上方（或刚补充落下）。
# 先重力沉底，再"收出口→重力"循环直到无新原料被收（触底→被收→让位→继续沉）。返回累计收集数。
# 注：纯重力不触发消除循环，故消除稳定后必须单独跑这个把已落定原料送进出口（先 gravity 让原料触到出口行）。
# bomb 可选：原料下沉伴随的重力也需让炸弹标记跟随搬运（与棋子一起落），故透传 bomb。
# popcorn 可选：同理透传——原料下沉的重力也要让爆米花格随之沉底（避免原料关与爆米花共存时爆米花掉队）。
# mystery 可选：同理透传——原料下沉的重力也要让神秘糖标记随之沉底（避免原料关与神秘糖共存时标记掉队）。
static func _drain_ingredients(grid: Array, fx: Array, up: bool, layers: Dictionary = {}) -> int:
	var ing: Array = layers.get("ing", [])
	var exit_cols: Array = layers.get("exit_cols", [])
	if ing.is_empty() or exit_cols.is_empty():
		return 0
	var collected := 0
	apply_gravity(grid, fx, up, layers)   # 先沉底：把悬空原料送到它能到的最低处（含出口行）
	while true:
		var got := collect_ingredients_at_exit(grid, ing, exit_cols)
		if got == 0:
			break
		collected += got
		apply_gravity(grid, fx, up, layers)   # 收掉出口原料 → 让位 → 上方原料/棋子继续沉
	return collected


# 啃食巧克力：被清除格(cleared_set)内或正交相邻的巧克力格 -1（巧克力本身不被清）。
# 原地改 choco，返回啃掉的格数。镜像 coat 破锁逻辑。
static func _eat_chocolate(choco: Array, cleared_set: Dictionary) -> int:
	var eaten := 0
	for cy in choco.size():
		for cx in choco[cy].size():
			if choco[cy][cx] <= 0:
				continue
			if cleared_set.has(Vector2i(cx, cy)) or cleared_set.has(Vector2i(cx - 1, cy)) or cleared_set.has(Vector2i(cx + 1, cy)) or cleared_set.has(Vector2i(cx, cy - 1)) or cleared_set.has(Vector2i(cx, cy + 1)):
				choco[cy][cx] -= 1
				eaten += 1
	return eaten


# 特效命中爆米花：被特效清除波及(cleared_set 内本身，非相邻)的爆米花格 popcorn-1（爆米花本身不被清）。
# 归0时该格变成色彩炸弹：grid 保留 species、fx=SP_COLORBOMB、popcorn=0（玩家随后可用这枚彩球）。
# 与 _eat_chocolate 的关键区别：① 只认"格自身"在清除集内(巧克力认正交相邻)；② 归0产物是彩球而非空格。
# 原地改 popcorn/fx，返回本次被命中递减的爆米花次数（含归0那次）。
static func _hit_popcorn(grid: Array, fx: Array, popcorn: Array, cleared_set: Dictionary) -> int:
	var hits := 0
	for cy in popcorn.size():
		for cx in popcorn[cy].size():
			if popcorn[cy][cx] <= 0:
				continue
			if cleared_set.has(Vector2i(cx, cy)):
				popcorn[cy][cx] -= 1
				hits += 1
				if popcorn[cy][cx] == 0:
					fx[cy][cx] = SP_COLORBOMB   # 归0 → 变彩球（grid 保留 species 作为彩球底色）
	return hits


# ───────────── 蛋糕炸弹（Cake Bomb）：逐层炸开的大障碍（对标 Candy Crush 的 Cake Bomb）─────────────
# 蛋糕语义 —— 复用 WALL，故 find_matches/apply_gravity/is_legal_swap 等全不感知 cake：
#   蛋糕格的 grid 是【WALL(-2)】（不可消/不可动/不下落/切段），cake[y][x]=N 只是叠加的剩余血量(0=无蛋糕)。
#   ① 被攻击-1+引爆一圈：每轮消除结算里，若某蛋糕格【正交相邻】有格被清除(普通三消 or 特效波及)，
#      则该蛋糕 cake-1（本轮最多-1，与 coat 破锁同节奏），并引爆它周围一圈（清蛋糕为心的 3x3 内非 WALL 普通格）。
#   ② 归0大爆炸：cake 减到 0 → 蛋糕移除(grid WALL→EMPTY, cake=0)，触发大爆炸(清以蛋糕为心的 5x5 非 WALL 格)。
#   ③ 引爆/大爆炸波及的特效格继续连锁（由调用方把返回的清除集并入 to_clear，沿特效链展开）。
# 引爆几何确定性（纯几何，无 rng）：一圈=SP_BOMB(3x3)、大爆炸=5x5；其它蛋糕在 3x3/5x5 内【不】被波及直减
#   （蛋糕只靠"相邻被清"递减，避免一次级联多个蛋糕连环掉血——与 coat 破锁的"每轮最多破一层"一致）。

const CAKE_BLAST_RADIUS := 2   # 归0大爆炸半径：以蛋糕为心的 (2*r+1)x(2*r+1)=5x5

# 半径 r 的方形几何（以 center 为心），仅收非 WALL/非 EMPTY 的普通格（蛋糕引爆不波及别的墙/蛋糕，不清空格）。
static func _square_cells(grid: Array, center: Vector2i, r: int) -> Array:
	var h := grid.size()
	var w: int = grid[0].size()
	var out := []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var nx := center.x + dx
			var ny := center.y + dy
			if nx >= 0 and nx < w and ny >= 0 and ny < h and grid[ny][nx] != WALL and grid[ny][nx] != EMPTY:
				out.append(Vector2i(nx, ny))
	return out

# 蛋糕结算：本轮被清除集(cleared_set)正交相邻的蛋糕 cake-1（每轮最多-1），并按规则引爆。
#   血量>0 的蛋糕：引爆一圈(3x3)；血量减到 0 的蛋糕：移除(grid→EMPTY, cake=0) + 大爆炸(5x5)。
#   返回 {blast: Array[Vector2i] 本轮所有引爆/大爆炸要清的普通格(供调用方并入 to_clear 沿特效链展开),
#         destroyed: int 本轮炸毁(归0)的蛋糕数}。原地改 cake/grid（归0蛋糕的 WALL→EMPTY）。
# 镜像 coat 破锁的相邻判定（cleared_set 内/正交相邻），但蛋糕走自己的引爆几何。
static func _blast_cakes(grid: Array, cake: Array, cleared_set: Dictionary) -> Dictionary:
	var blast := {}      # Vector2i -> true（去重的引爆清除格）
	var destroyed := 0
	# 先收集本轮要 -1 的蛋糕（快照命中判定）：避免边减边引爆改 grid 影响后续相邻判定。
	var hit_cakes := []
	for cy in cake.size():
		for cx in cake[cy].size():
			if cake[cy][cx] <= 0:
				continue
			var here := Vector2i(cx, cy)
			# 正交相邻(或自身，虽蛋糕格是 WALL 不会进 cleared_set)被清 → 本蛋糕受击
			if cleared_set.has(here) or cleared_set.has(Vector2i(cx - 1, cy)) or cleared_set.has(Vector2i(cx + 1, cy)) or cleared_set.has(Vector2i(cx, cy - 1)) or cleared_set.has(Vector2i(cx, cy + 1)):
				hit_cakes.append(here)
	for c in hit_cakes:
		cake[c.y][c.x] -= 1   # 本轮 -1（最多一次）
		if cake[c.y][c.x] <= 0:
			# 归0：移除蛋糕(WALL→EMPTY) + 大爆炸 5x5
			cake[c.y][c.x] = 0
			grid[c.y][c.x] = EMPTY
			destroyed += 1
			for e in _square_cells(grid, c, CAKE_BLAST_RADIUS):
				blast[e] = true
		else:
			# 血量仍 >0：引爆一圈 3x3（复用 SP_BOMB 几何）
			for e in special_effect_cells(grid, c, SP_BOMB):
				blast[e] = true
	return {"blast": blast.keys(), "destroyed": destroyed}

# 数盘上还有血量的蛋糕格总数（供 board/测试断言；炸毁的格 cake=0 不计）。
static func count_cakes(cake: Array) -> int:
	var n := 0
	for row in cake:
		for v in row:
			if v > 0:
				n += 1
	return n


# ───────────── 神秘糖（Mystery Candy）：被消除时揭开随机内容（对标 Candy Crush 的 Mystery Candy）─────────────
# 神秘糖语义 —— 与 coat/choco/ing 本质不同：神秘糖格的 grid 是【普通 species】（可消、可换、随重力下落），
#   mystery[y][x]=1 只是叠加的"这格外观是神秘糖、被消时揭开"标记（0=无神秘糖）。
#   故 find_matches/classify_matches/is_legal_swap 都【完全不感知 mystery】（神秘糖当普通棋子参与匹配/交换）——
#   这是与 coat/choco/ing 的关键区别（它们不可消所以要改那些函数；神秘糖可消，故零侵入匹配/交换/分类）。
#   ① 正常参与三消：神秘糖格 grid 是随机普通色，正常凑串、正常被特效波及。
#   ② 被消除时揭开：当某神秘糖格出现在 to_clear（将被清除）时，【不清空】而是揭开为随机内容、mystery 清 0：
#        70% 随机普通 species / 20% 直线特效(SP_LINE_H 或 SP_LINE_V) / 10% 原料(ing=1)。
#      揭开后该格【不参与本轮后续清除】（它是刚揭开的新内容，下一轮才可能消）。
#   ③ 随重力下落：mystery 作为纯标记随 grid 同步搬运（apply_gravity 已透传 mystery，与 bomb 同构）。
# 概率分配用注入的 rng（确定性可复现）。揭开原语集中在 _reveal_mystery_at / _reveal_mysteries_in_clear，
#   两条 resolve 路径(_resolve_plain/_resolve_fx)及直清路径(_apply_clears)都调它 → 揭开逻辑只一处。

const MYSTERY_P_SPECIES := 70   # 概率(%)：揭开为随机普通 species
const MYSTERY_P_FX := 20        # 概率(%)：揭开为直线特效（SP_LINE_H/V，按掷骰行号定向）
# 余下 10%：揭开为原料(ing=1)。三档累计 100。

# 揭开单个神秘糖格 pos：按掷骰设 grid 新 species / fx / ing，并清 mystery 标记。原地改 grid/fx/ing/mystery。
# rng 注入 → 确定性。fx/ing 可选：不传则对应产物退化（无 fx 层时特效档落普通色；无 ing 层时原料档落普通色）。
static func _reveal_mystery_at(grid: Array, fx: Array, ing: Array, mystery: Array, pos: Vector2i, rng: RandomNumberGenerator, species_set: Array) -> void:
	var n := species_set.size()
	var roll := rng.randi() % 100   # [0,99]
	var new_sp: int = species_set[rng.randi() % n] if n > 0 else grid[pos.y][pos.x]
	if roll < MYSTERY_P_SPECIES:
		# 70%：随机普通糖（揭开成一颗新普通色）
		grid[pos.y][pos.x] = new_sp
		if not fx.is_empty():
			fx[pos.y][pos.x] = SP_NONE
		if not ing.is_empty():
			ing[pos.y][pos.x] = 0
	elif roll < MYSTERY_P_SPECIES + MYSTERY_P_FX:
		# 20%：直线特效（保留/重置底色 species + 落条纹）。行号定向：偶数行清行(LINE_H)、奇数行清列(LINE_V) → 确定且行列兼顾。
		grid[pos.y][pos.x] = new_sp   # 无 fx 层兜底：grid 已是普通色，特效档自然退化为普通糖
		if not fx.is_empty():
			fx[pos.y][pos.x] = SP_LINE_H if (pos.y % 2 == 0) else SP_LINE_V
		if not ing.is_empty():
			ing[pos.y][pos.x] = 0
	else:
		# 10%：原料（grid=随机色占位 + ing=1）；无 ing 层则退化为普通色。
		grid[pos.y][pos.x] = new_sp
		if not fx.is_empty():
			fx[pos.y][pos.x] = SP_NONE
		if not ing.is_empty():
			ing[pos.y][pos.x] = 1
	mystery[pos.y][pos.x] = 0   # 揭开完成 → 不再是神秘糖

# 揭开一组将被清除的格(to_clear)里的全部神秘糖格：逐格揭开，返回被揭开的格集合(Dictionary 当 set)+计数。
# 被揭开的格【不被清空】(它变成新内容)，故调用方据返回的 set 把这些格从实际清除集中剔除。
# 顺序固定(按 to_clear 原序) → 同 seed 确定性。原地改 grid/fx/ing/mystery。
static func _reveal_mysteries_in_clear(grid: Array, fx: Array, ing: Array, mystery: Array, to_clear: Array, rng: RandomNumberGenerator, species_set: Array) -> Dictionary:
	var revealed := {}   # Vector2i -> true（本轮揭开、不被清空的格）
	if mystery.is_empty():
		return {"revealed": revealed, "count": 0}
	var count := 0
	for pos in to_clear:
		if mystery[pos.y][pos.x] > 0:
			_reveal_mystery_at(grid, fx, ing, mystery, pos, rng, species_set)
			revealed[pos] = true
			count += 1
	return {"revealed": revealed, "count": count}

# 数盘上还剩的神秘糖格总数（供 board/测试断言；已揭开的格 mystery=0 不计）。
static func count_mystery(mystery: Array) -> int:
	var n := 0
	for row in mystery:
		for v in row:
			if v > 0:
				n += 1
	return n


static func _resolve_plain(grid: Array, species_set: Array, rng: RandomNumberGenerator, feed: Array = [], do_refill: bool = true, cascades_out = null, layers: Dictionary = {}) -> Dictionary:
	var jelly: Array = layers.get("jelly", [])
	var coat: Array = layers.get("coat", [])
	var choco: Array = layers.get("choco", [])
	var ing: Array = layers.get("ing", [])
	var exit_cols: Array = layers.get("exit_cols", [])
	var bomb: Array = layers.get("bomb", [])
	var popcorn: Array = layers.get("popcorn", [])
	var cake: Array = layers.get("cake", [])
	var mystery: Array = layers.get("mystery", [])
	var total_score := 0
	var cascades := 0
	var cleared_total := 0
	var by_species := {}  # species -> 消除数
	var jelly_cleared := 0
	var blocker_cleared := 0
	var choco_cleared := 0
	var ingredient_collected := 0
	var bomb_defused := 0
	var cake_destroyed := 0
	var mystery_revealed := 0
	var has_jelly := not jelly.is_empty()
	var has_coat := not coat.is_empty()
	var has_choco := not choco.is_empty()
	var has_ing := not ing.is_empty()
	var has_bomb := not bomb.is_empty()
	var has_cake := not cake.is_empty()
	var has_mystery := not mystery.is_empty()
	# 纯三消路径无特效 → 爆米花永不被命中（爆米花只认特效）；此处仅让它【跳过匹配 + 随重力下落】，故透传给 find_matches/apply_gravity。
	while true:
		var matched: Array = find_matches(grid, layers)
		if matched.is_empty():
			break
		cascades += 1
		if cascades_out != null:
			cascades_out.append(matched.duplicate())
		var matched_set := {}
		for p in matched:
			matched_set[p] = true
		if has_coat:
			for cy in grid.size():
				for cx in grid[cy].size():
					if coat[cy][cx] <= 0:
						continue
					if matched_set.has(Vector2i(cx, cy)) or matched_set.has(Vector2i(cx - 1, cy)) or matched_set.has(Vector2i(cx + 1, cy)) or matched_set.has(Vector2i(cx, cy - 1)) or matched_set.has(Vector2i(cx, cy + 1)):
						coat[cy][cx] -= 1
						blocker_cleared += 1
		if has_choco:
			choco_cleared += _eat_chocolate(choco, matched_set)  # 巧克力被相邻消除则 -1
		# 神秘糖：被消除的神秘糖格【不清空】，揭开为随机内容(mystery→0)。揭开的格本轮不计入清除/收集。
		var revealed: Dictionary = {}
		if has_mystery:
			var rv := _reveal_mysteries_in_clear(grid, [], ing, mystery, matched, rng, species_set)  # 纯三消无 fx 层 → 特效档退化为普通糖
			revealed = rv["revealed"]
			mystery_revealed += rv["count"]
		for pos in matched:
			if revealed.has(pos):
				continue   # 神秘糖揭开 → 该格变新内容，不清空、不计消除
			var sp_p: int = grid[pos.y][pos.x]
			if sp_p >= 0:
				by_species[sp_p] = by_species.get(sp_p, 0) + 1
			if has_jelly and jelly[pos.y][pos.x] > 0:
				jelly[pos.y][pos.x] -= 1
				jelly_cleared += 1
			if has_bomb and bomb[pos.y][pos.x] > 0:
				bomb[pos.y][pos.x] = 0   # 炸弹格被消除 → 拆弹（bomb 归 0，不再倒计时）
				bomb_defused += 1
			grid[pos.y][pos.x] = EMPTY
			cleared_total += 1   # 仅真正清空的格计入（揭开的神秘糖不计）
		total_score += score_for_clear(matched.size() - revealed.size(), cascades)
		# 蛋糕：本轮三消相邻的蛋糕 cake-1 + 引爆一圈/归0大爆炸（引爆波及的普通格本轮一并清掉，随后下落级联）。
		if has_cake:
			var cb := _blast_cakes(grid, cake, matched_set)
			cake_destroyed += cb["destroyed"]
			# 蛋糕引爆波及的神秘糖格同样揭开(不清空)；先揭开再清其余。
			var blast_revealed: Dictionary = {}
			if has_mystery:
				var rvb := _reveal_mysteries_in_clear(grid, [], ing, mystery, cb["blast"], rng, species_set)
				blast_revealed = rvb["revealed"]
				mystery_revealed += rvb["count"]
			for bp in cb["blast"]:
				if blast_revealed.has(bp):
					continue   # 神秘糖揭开 → 不清空
				var sp_b: int = grid[bp.y][bp.x]
				if sp_b >= 0:
					by_species[sp_b] = by_species.get(sp_b, 0) + 1
				if has_jelly and jelly[bp.y][bp.x] > 0:
					jelly[bp.y][bp.x] -= 1
					jelly_cleared += 1
				if has_bomb and bomb[bp.y][bp.x] > 0:
					bomb[bp.y][bp.x] = 0   # 蛋糕引爆波及炸弹格 → 拆弹
					bomb_defused += 1
				grid[bp.y][bp.x] = EMPTY
				cleared_total += 1
		apply_gravity(grid, [], false, layers)   # 原料/炸弹/爆米花/神秘糖随重力下落（随 grid 同步移动）
		if has_ing:
			ingredient_collected += collect_ingredients_at_exit(grid, ing, exit_cols)  # 落到出口的原料即收
		if do_refill:
			refill(grid, species_set, rng, [], feed)
	# 消除稳定后，把仍悬在出口上方、已落定的原料一路沉到出口收掉（纯重力不触发上面的 match 循环）。
	if has_ing:
		ingredient_collected += _drain_ingredients(grid, [], false, layers)
		if do_refill:
			refill(grid, species_set, rng, [], feed)
	return {"score": total_score, "cascades": cascades, "cleared": cleared_total, "by_species": by_species, "jelly_cleared": jelly_cleared, "blocker_cleared": blocker_cleared, "choco_cleared": choco_cleared, "ingredient_collected": ingredient_collected, "bomb_defused": bomb_defused, "popcorn_hit": 0, "cake_destroyed": cake_destroyed, "mystery_revealed": mystery_revealed}


# 彩球被交换引爆：清掉 partner 的整种颜色（+彩球+partner），双彩球则清全盘。
# 返回要清的格（含被卷入的直线/爆炸特效的触发链；不再触发其他彩球）。纯函数。
#
# CC 式组合精度（对标 Candy Crush）：
#   彩球 + 条纹(SP_LINE_H/V) → 全盘该色棋子【先全部变成条纹糖，再一起引爆】(每个清整行/列，满屏连锁)。
#   彩球 + 包装(SP_BOMB)     → 全盘该色【先变成包装糖再引爆】(每个 3x3 连锁)。
#   彩球 + 普通棋子          → 清掉该色(原行为，保留)。
#   双彩球                  → 清全盘非空(原行为，保留)。
# 实现：把"该色每格当 partner 特效引爆"用 override 表达——BFS 触发时该格按 override 的特效几何展开，
#   而非它自身 fx(多为 SP_NONE)。其余被卷入格仍按各自现有 fx 展开。彩球不触发彩球(避免自激/递归)。
#   override 行号决定条纹方向(偶数行→清行 LINE_H、奇数行→清列 LINE_V)，确定性且行列兼顾、清除量最大化。
static func colorbomb_clear_set(grid: Array, fx: Array, cb_pos: Vector2i, partner_pos: Vector2i) -> Array:
	var seeds := []
	var override := {}   # Vector2i -> 特效 kind：该格强制按此特效几何引爆（彩球把该色格"染"成 partner 特效）
	var partner_fx: int = fx[partner_pos.y][partner_pos.x]
	if partner_fx == SP_COLORBOMB:
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
		# partner 是条纹/包装：该色每格【染成对应特效】，引爆时按特效几何满屏连锁(CC 式)。
		# 彩球本体(cb_pos)与 partner 本体不染(它们只是被清掉/已是触发源)，避免改写已有特效。
		if partner_fx == SP_LINE_H or partner_fx == SP_LINE_V or partner_fx == SP_BOMB:
			for c in seeds:
				if c == cb_pos or c == partner_pos:
					continue
				if grid[c.y][c.x] != target:
					continue   # 只染该色格(special_effect_cells 已只返该色，这里再兜底)
				if fx[c.y][c.x] == SP_COLORBOMB:
					continue   # 该色格上若另有彩球，不染、不触发(彩球不触发彩球)
				if partner_fx == SP_BOMB:
					override[c] = SP_BOMB
				else:
					# 条纹：偶数行染清行(LINE_H)、奇数行染清列(LINE_V) → 行列兼顾、确定性、清除量最大化
					override[c] = SP_LINE_H if (c.y % 2 == 0) else SP_LINE_V
	# 触发链：被卷入的直线/爆炸继续触发；但不再触发其他彩球（避免自激/递归）。
	# override 优先：被染色的该色格按 override 特效几何展开；其余格按自身 fx 展开。
	var to_clear := {}
	var queue := []
	for c in seeds:
		if not to_clear.has(c):
			to_clear[c] = true
			var k: int = override.get(c, fx[c.y][c.x])
			if k != SP_NONE and k != SP_COLORBOMB:
				queue.append(c)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		var kind: int = override.get(c, fx[c.y][c.x])
		for e in special_effect_cells(grid, c, kind, grid[c.y][c.x]):
			if not to_clear.has(e):
				to_clear[e] = true
				var ke: int = override.get(e, fx[e.y][e.x])
				if ke != SP_NONE and ke != SP_COLORBOMB:
					queue.append(e)
	return to_clear.keys()


static func _resolve_fx(grid: Array, species_set: Array, rng: RandomNumberGenerator, fx: Array, feed: Array = [], do_refill: bool = true, cascades_out = null, layers: Dictionary = {}) -> Dictionary:
	var jelly: Array = layers.get("jelly", [])
	var coat: Array = layers.get("coat", [])
	var choco: Array = layers.get("choco", [])
	var ing: Array = layers.get("ing", [])
	var exit_cols: Array = layers.get("exit_cols", [])
	var bomb: Array = layers.get("bomb", [])
	var popcorn: Array = layers.get("popcorn", [])
	var cake: Array = layers.get("cake", [])
	var mystery: Array = layers.get("mystery", [])
	var total_score := 0
	var cascades := 0
	var cleared_total := 0
	var by_species := {}
	var jelly_cleared := 0
	var blocker_cleared := 0
	var choco_cleared := 0
	var ingredient_collected := 0
	var bomb_defused := 0
	var popcorn_hit := 0
	var cake_destroyed := 0
	var mystery_revealed := 0
	var has_jelly := not jelly.is_empty()
	var has_coat := not coat.is_empty()
	var has_choco := not choco.is_empty()
	var has_ing := not ing.is_empty()
	var has_bomb := not bomb.is_empty()
	var has_pop := not popcorn.is_empty()
	var has_cake := not cake.is_empty()
	var has_mystery := not mystery.is_empty()
	while true:
		var c := collect_clears(grid, fx, layers)
		var raw: Array = c["to_clear"]
		if raw.is_empty():
			break
		cascades += 1
		if cascades_out != null:
			cascades_out.append(raw.duplicate())
		# 锁住格(coat>0)/巧克力格(choco>0)/原料格(ing>0)/爆米花格(popcorn>0)不被清除：记下它们，本回合只破层/啃食/命中、不清。
		# 神秘糖格(mystery>0)也不被直清：它会在下方揭开为随机内容，故同样记入 locked_start 排除出实际清除集。
		var cleared_set := {}
		var locked_start := {}
		for p in raw:
			cleared_set[p] = true
			if has_coat and coat[p.y][p.x] > 0:
				locked_start[p] = true
			if has_choco and choco[p.y][p.x] > 0:
				locked_start[p] = true   # 巧克力格也不被特效直清（只能靠相邻啃食）
			if has_ing and ing[p.y][p.x] > 0:
				locked_start[p] = true   # 原料格不被特效直清（原料不可消，只随重力下落到出口）
			if has_pop and popcorn[p.y][p.x] > 0:
				locked_start[p] = true   # 爆米花格不被特效直清（特效命中只递减、归0变彩球，见下方 _hit_popcorn）
			if has_mystery and mystery[p.y][p.x] > 0:
				locked_start[p] = true   # 神秘糖格不被直清：下方揭开为随机内容（mystery→0），本轮不清空
		# 破锁：被清除格的内/相邻的锁住格 -1（锁住格本身不被清）
		if has_coat:
			for cy in grid.size():
				for cx in grid[cy].size():
					if coat[cy][cx] <= 0:
						continue
					if cleared_set.has(Vector2i(cx, cy)) or cleared_set.has(Vector2i(cx - 1, cy)) or cleared_set.has(Vector2i(cx + 1, cy)) or cleared_set.has(Vector2i(cx, cy - 1)) or cleared_set.has(Vector2i(cx, cy + 1)):
						coat[cy][cx] -= 1
						blocker_cleared += 1
		if has_choco:
			choco_cleared += _eat_chocolate(choco, cleared_set)  # 巧克力被相邻消除则 -1
		# 爆米花命中：被特效清除波及(格自身在清除集)的爆米花 -1，归0变彩球。须在 _apply_clears(不清这些格)前结算。
		if has_pop:
			popcorn_hit += _hit_popcorn(grid, fx, popcorn, cleared_set)
		# 神秘糖揭开：被特效清除波及(格自身在清除集)的神秘糖格揭开为随机内容(mystery→0)、不清空。须在 _apply_clears 前结算。
		# 揭开走带 fx 层版本 → 20% 档真正落条纹特效（与纯三消路径退化为普通糖不同）。
		if has_mystery:
			var rv := _reveal_mysteries_in_clear(grid, fx, ing, mystery, raw, rng, species_set)
			mystery_revealed += rv["count"]
		# 真正清除的 = raw 里"开始时未锁/非巧克力/非原料/非爆米花/非神秘糖"的格
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
				if has_bomb and bomb[pos.y][pos.x] > 0:
					bomb[pos.y][pos.x] = 0   # 炸弹格被特效清除 → 拆弹（spawn 格保留为特效棋子，炸弹随之不拆）
					bomb_defused += 1
			if has_jelly and jelly[pos.y][pos.x] > 0:
				jelly[pos.y][pos.x] -= 1
				jelly_cleared += 1
		# 蛋糕：本轮特效清除波及相邻的蛋糕 cake-1 + 引爆一圈/归0大爆炸。引爆波及的普通格沿特效链展开后并入 to_clear。
		# 须在 _apply_clears 前结算（蛋糕格 grid=WALL 不会进 to_clear；归0蛋糕已在 _blast_cakes 里 WALL→EMPTY）。
		if has_cake:
			var cb := _blast_cakes(grid, cake, cleared_set)
			cake_destroyed += cb["destroyed"]
			if not cb["blast"].is_empty():
				var blast_set: Dictionary = _expand_triggers(grid, fx, cb["blast"])  # 引爆卷入的条纹/爆炸继续连锁
				for bp in blast_set:
					if cleared_set.has(bp):
						continue   # 已在本轮清除集里，避免重复计账
					cleared_set[bp] = true
					# 蛋糕引爆同样尊重锁住/巧克力/原料/爆米花/神秘糖：这些格只破层/啃食/命中/揭开、不被引爆直清。
					if (has_coat and coat[bp.y][bp.x] > 0) or (has_choco and choco[bp.y][bp.x] > 0) or (has_ing and ing[bp.y][bp.x] > 0):
						continue
					if has_pop and popcorn[bp.y][bp.x] > 0:
						# 蛋糕引爆/大爆炸波及的爆米花格 → 当作特效命中：popcorn-1、归0变彩球(SP_COLORBOMB)、不清空。
						# 与上方原始匹配格的 _hit_popcorn 同口径（条纹/爆炸/彩球命中爆米花完全一致），漏此分支即"蛋糕打不动爆米花"。
						popcorn_hit += _hit_popcorn(grid, fx, popcorn, {bp: true})
						continue
					if has_mystery and mystery[bp.y][bp.x] > 0:
						# 蛋糕引爆波及的神秘糖格 → 揭开为随机内容(mystery→0)、不清空（与上面波及揭开同口径）。
						var rvb := _reveal_mysteries_in_clear(grid, fx, ing, mystery, [bp], rng, species_set)
						mystery_revealed += rvb["count"]
						continue
					var sp_b: int = grid[bp.y][bp.x]
					if sp_b >= 0:
						by_species[sp_b] = by_species.get(sp_b, 0) + 1
					if has_bomb and bomb[bp.y][bp.x] > 0:
						bomb[bp.y][bp.x] = 0   # 蛋糕引爆波及炸弹格 → 拆弹
						bomb_defused += 1
					if has_jelly and jelly[bp.y][bp.x] > 0:
						jelly[bp.y][bp.x] -= 1
						jelly_cleared += 1
					to_clear.append(bp)
					cleared_total += 1
		_apply_clears(grid, fx, to_clear, c["spawns"])
		apply_gravity(grid, fx, false, layers)   # 原料/炸弹/爆米花/神秘糖随重力下落（随 grid/fx 同步移动）
		if has_ing:
			ingredient_collected += collect_ingredients_at_exit(grid, ing, exit_cols)
		if do_refill:
			refill(grid, species_set, rng, fx, feed)
	# 消除稳定后，把仍悬在出口上方、已落定的原料一路沉到出口收掉。
	if has_ing:
		ingredient_collected += _drain_ingredients(grid, fx, false, layers)
		if do_refill:
			refill(grid, species_set, rng, fx, feed)
	return {"score": total_score, "cascades": cascades, "cleared": cleared_total, "by_species": by_species, "jelly_cleared": jelly_cleared, "blocker_cleared": blocker_cleared, "choco_cleared": choco_cleared, "ingredient_collected": ingredient_collected, "bomb_defused": bomb_defused, "popcorn_hit": popcorn_hit, "cake_destroyed": cake_destroyed, "mystery_revealed": mystery_revealed}


# 交换是否合法：相邻 + 交换后能形成消除（v1 无特效）。不修改 grid。
# choco 可选：巧克力格(choco>0)与锁住格一样不可参与交换。
# ing 可选：原料格(ing>0)与锁住格一样不可参与交换（原料只随重力下落，玩家不能直接操作它）。
static func is_legal_swap(grid: Array, a: Vector2i, b: Vector2i, span: int = 1, layers: Dictionary = {}) -> bool:
	var coat: Array = layers.get("coat", [])
	var choco: Array = layers.get("choco", [])
	var ing: Array = layers.get("ing", [])
	var popcorn: Array = layers.get("popcorn", [])
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
	if not choco.is_empty() and (choco[a.y][a.x] > 0 or choco[b.y][b.x] > 0):
		return false  # 巧克力格不可换
	if not ing.is_empty() and (ing[a.y][a.x] > 0 or ing[b.y][b.x] > 0):
		return false  # 原料格不可换
	if not popcorn.is_empty() and (popcorn[a.y][a.x] > 0 or popcorn[b.y][b.x] > 0):
		return false  # 爆米花格不可换（不可消不可换，只随重力下落）
	_swap_cells(grid, a, b)
	var found := not find_matches(grid, layers).is_empty()
	_swap_cells(grid, a, b)  # 还原
	return found

# 交换两格内容（原地）。GDScript 无元组交换，用临时变量。
static func _swap_cells(grid: Array, a: Vector2i, b: Vector2i) -> void:
	var t = grid[a.y][a.x]
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = t


# 是否存在任一合法交换（无 → 死局，需洗牌）。
# choco 可选：透传给 is_legal_swap，使巧克力格不被算作可动（避免"看似有步、真实无步"）。
# ing 可选：透传给 is_legal_swap，使原料格不被算作可动（同 choco 处理）。
# popcorn 可选：透传给 is_legal_swap，使爆米花格不被算作可动（同 ing 处理）。
static func has_legal_move(grid: Array, layers: Dictionary = {}) -> bool:
	var h := grid.size()
	if h == 0:
		return false
	var w: int = grid[0].size()
	for y in h:
		for x in w:
			if x + 1 < w and is_legal_swap(grid, Vector2i(x, y), Vector2i(x + 1, y), 1, layers):
				return true
			if y + 1 < h and is_legal_swap(grid, Vector2i(x, y), Vector2i(x, y + 1), 1, layers):
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
# choco 可选：巧克力格(choco>0)与墙一样固定不参与洗牌；验收也 choco 感知。
# ing 可选：原料格(ing>0)与墙一样固定不参与洗牌（原料位置由重力决定，不可被打乱）；验收也 ing 感知。
# popcorn 可选：爆米花格(popcorn>0)与墙一样固定不参与洗牌（位置由重力决定，species 是占位）；验收也 popcorn 感知。
static func reshuffle(grid: Array, rng: RandomNumberGenerator, layers: Dictionary = {}) -> void:
	var choco: Array = layers.get("choco", [])
	var ing: Array = layers.get("ing", [])
	var popcorn: Array = layers.get("popcorn", [])
	var h := grid.size()
	if h == 0:
		return
	var w: int = grid[0].size()
	var has_choco := not choco.is_empty()
	var has_ing := not ing.is_empty()
	var has_pop := not popcorn.is_empty()
	# 只重排可动棋子；墙(WALL)/空格(EMPTY)/巧克力格(choco>0)/原料格(ing>0)/爆米花格(popcorn>0)固定不参与洗牌。
	var positions := []
	var tiles := []
	for y in h:
		for x in w:
			var v: int = grid[y][x]
			if v == WALL or v == EMPTY or (has_choco and choco[y][x] > 0) or (has_ing and ing[y][x] > 0) or (has_pop and popcorn[y][x] > 0):
				continue
			positions.append(Vector2i(x, y))
			tiles.append(v)
	var safe_tiles := []   # 记一个"至少无现成消除"的排列作兜底（避免开局即级联）
	for _attempt in 100:
		_shuffle(tiles, rng)
		for i in positions.size():
			var p: Vector2i = positions[i]
			grid[p.y][p.x] = tiles[i]
		# 验收须 coat/choco/ing/popcorn 感知：忽略障碍会"看似有步、真实玩家无步"。
		var no_match := find_matches(grid, layers).is_empty()
		if no_match and has_legal_move(grid, layers):
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
static func classify_matches(grid: Array, layers: Dictionary = {}) -> Dictionary:
	var coat: Array = layers.get("coat", [])
	var choco: Array = layers.get("choco", [])
	var ing: Array = layers.get("ing", [])
	var popcorn: Array = layers.get("popcorn", [])
	var h := grid.size()
	if h == 0:
		return {"clear": [], "spawns": []}
	var w: int = grid[0].size()
	var has_coat := not coat.is_empty()
	var has_choco := not choco.is_empty()
	var has_ing := not ing.is_empty()
	var has_pop := not popcorn.is_empty()

	# 收集所有 >=3 的横/纵直线串：{cells, len, mid}（巧克力格 choco>0 / 原料格 ing>0 / 爆米花格 popcorn>0 与锁住格一样跳过、断串）
	var h_runs := []
	for y in h:
		var x := 0
		while x < w:
			if grid[y][x] == EMPTY or grid[y][x] == WALL or (has_coat and coat[y][x] > 0) or (has_choco and choco[y][x] > 0) or (has_ing and ing[y][x] > 0) or (has_pop and popcorn[y][x] > 0):
				x += 1
				continue
			var e := x
			while e + 1 < w and grid[y][e + 1] == grid[y][x] and not (has_coat and coat[y][e + 1] > 0) and not (has_choco and choco[y][e + 1] > 0) and not (has_ing and ing[y][e + 1] > 0) and not (has_pop and popcorn[y][e + 1] > 0):
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
			if grid[y][x] == EMPTY or grid[y][x] == WALL or (has_coat and coat[y][x] > 0) or (has_choco and choco[y][x] > 0) or (has_ing and ing[y][x] > 0) or (has_pop and popcorn[y][x] > 0):
				y += 1
				continue
			var e := y
			while e + 1 < h and grid[e + 1][x] == grid[y][x] and not (has_coat and coat[e + 1][x] > 0) and not (has_choco and choco[e + 1][x] > 0) and not (has_ing and ing[e + 1][x] > 0) and not (has_pop and popcorn[e + 1][x] > 0):
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
static func collect_clears(grid: Array, fx: Array, layers: Dictionary = {}) -> Dictionary:
	var to_clear := _expand_triggers(grid, fx, find_matches(grid, layers))
	var cls := classify_matches(grid, layers)
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
# popcorn 可选：彩球/融合等直清路径波及的爆米花格 -1(不清、记 locked)，归0变彩球(fx=SP_COLORBOMB)。
#   结果里附带 popcorn_hit；爆米花格须 fx 才能落彩球，故 fx 也作为可选参数透传（不传则只递减不变彩球——退化兜底）。
# mystery/rng/species_set/ing 可选：彩球/融合/同类消除等直清路径波及的神秘糖格【揭开】为随机内容(mystery→0、记 locked 不清空)。
#   结果里附带 mystery_revealed；揭开须 rng+species_set（确定性概率），fx/ing 用于落特效/原料档（缺则对应档退化为普通糖）。
static func account_clears(grid: Array, cells: Array, fx: Array = [], rng: RandomNumberGenerator = null, species_set: Array = [], layers: Dictionary = {}) -> Dictionary:
	var jelly: Array = layers.get("jelly", [])
	var coat: Array = layers.get("coat", [])
	var choco: Array = layers.get("choco", [])
	var bomb: Array = layers.get("bomb", [])
	var popcorn: Array = layers.get("popcorn", [])
	var cake: Array = layers.get("cake", [])
	var mystery: Array = layers.get("mystery", [])
	var ing: Array = layers.get("ing", [])
	var by_species := {}
	var jelly_cleared := 0
	var blocker_cleared := 0
	var choco_cleared := 0
	var bomb_defused := 0
	var popcorn_hit := 0
	var cake_destroyed := 0
	var mystery_revealed := 0
	var has_jelly := not jelly.is_empty()
	var has_coat := not coat.is_empty()
	var has_choco := not choco.is_empty()
	var has_bomb := not bomb.is_empty()
	var has_pop := not popcorn.is_empty()
	var has_cake := not cake.is_empty()
	var has_mystery := not mystery.is_empty() and rng != null
	var locked := {}  # 开始时锁住/巧克力/爆米花/神秘糖的格：只破层啃食/命中/揭开，不被清/不计入收集·果冻
	var cleared_set := {}
	for p in cells:
		cleared_set[p] = true
	if has_coat:
		for p in cells:
			if coat[p.y][p.x] > 0:
				locked[p] = true
		for cy in grid.size():
			for cx in grid[cy].size():
				if coat[cy][cx] <= 0:
					continue
				if cleared_set.has(Vector2i(cx, cy)) or cleared_set.has(Vector2i(cx - 1, cy)) or cleared_set.has(Vector2i(cx + 1, cy)) or cleared_set.has(Vector2i(cx, cy - 1)) or cleared_set.has(Vector2i(cx, cy + 1)):
					coat[cy][cx] -= 1
					blocker_cleared += 1
	if has_choco:
		for p in cells:
			if choco[p.y][p.x] > 0:
				locked[p] = true   # 巧克力格不被直清（直清路径同样只能相邻啃食）
		choco_cleared += _eat_chocolate(choco, cleared_set)
	if has_pop and not fx.is_empty():
		for p in cells:
			if popcorn[p.y][p.x] > 0:
				locked[p] = true   # 爆米花格不被直清（直清波及只递减、归0变彩球）
		# 命中递减：直清路径同样只认"格自身在清除集"（与特效 resolve 路径一致）。
		popcorn_hit += _hit_popcorn(grid, fx, popcorn, cleared_set)
	if has_mystery:
		# 直清波及的神秘糖格揭开为随机内容(mystery→0、记 locked 不清空)。揭开走 fx/ing 版本 → 20%/10% 档真正落特效/原料。
		for p in cells:
			if mystery[p.y][p.x] > 0:
				locked[p] = true   # 神秘糖格不被直清（直清波及只揭开）
		var rv := _reveal_mysteries_in_clear(grid, fx, ing, mystery, cells, rng, species_set)
		mystery_revealed += rv["count"]
	for pos in cells:
		if locked.has(pos):
			continue  # 锁住/巧克力/爆米花/神秘糖格不被清除，不计入收集/果冻（仅上面破层/啃食/命中/揭开）
		var sp_p: int = grid[pos.y][pos.x]
		if sp_p >= 0:
			by_species[sp_p] = by_species.get(sp_p, 0) + 1
		if has_jelly and jelly[pos.y][pos.x] > 0:
			jelly[pos.y][pos.x] -= 1
			jelly_cleared += 1
		if has_bomb and bomb[pos.y][pos.x] > 0:
			bomb[pos.y][pos.x] = 0   # 炸弹格被特效(彩球/融合/同类消除)波及清除 → 拆弹
			bomb_defused += 1
	# 蛋糕：直清(彩球/融合/同类消除)波及相邻的蛋糕 cake-1 + 引爆一圈/归0大爆炸。
	# 返回 cake_blast（引爆要清的普通格）供调用方并入 to_clear 一并清除（蛋糕格 grid=WALL 不会在 cells 里）。
	var cake_blast := []
	if has_cake:
		var cb := _blast_cakes(grid, cake, cleared_set)
		cake_destroyed += cb["destroyed"]
		for bp in cb["blast"]:
			if cleared_set.has(bp):
				continue   # 已在直清集里，避免重复计账
			cleared_set[bp] = true
			# 蛋糕引爆同样尊重锁住/巧克力/爆米花：这些格只破层/啃食/命中、不被引爆直清。
			if (has_coat and coat[bp.y][bp.x] > 0) or (has_choco and choco[bp.y][bp.x] > 0):
				continue
			if has_pop and popcorn[bp.y][bp.x] > 0:
				# 蛋糕引爆/大爆炸波及的爆米花格 → 当作特效命中：popcorn-1、归0变彩球(SP_COLORBOMB)、不清空。
				# 与上方直清波及格的 _hit_popcorn 同口径（彩球/融合命中爆米花一致），漏此分支即"蛋糕打不动爆米花"。
				if not fx.is_empty():
					popcorn_hit += _hit_popcorn(grid, fx, popcorn, {bp: true})
				continue   # 爆米花格永不被引爆直清（无 fx 层时退化为只 continue，不递减不变彩球）
			if has_mystery and mystery[bp.y][bp.x] > 0:
				# 蛋糕引爆波及的神秘糖格 → 揭开(mystery→0)、不并入 cake_blast（不清空）。
				var rvb := _reveal_mysteries_in_clear(grid, fx, ing, mystery, [bp], rng, species_set)
				mystery_revealed += rvb["count"]
				continue
			var sp_b: int = grid[bp.y][bp.x]
			if sp_b >= 0:
				by_species[sp_b] = by_species.get(sp_b, 0) + 1
			if has_jelly and jelly[bp.y][bp.x] > 0:
				jelly[bp.y][bp.x] -= 1
				jelly_cleared += 1
			if has_bomb and bomb[bp.y][bp.x] > 0:
				bomb[bp.y][bp.x] = 0   # 蛋糕引爆波及炸弹格 → 拆弹
				bomb_defused += 1
			cake_blast.append(bp)
	return {"by_species": by_species, "jelly_cleared": jelly_cleared, "blocker_cleared": blocker_cleared, "choco_cleared": choco_cleared, "bomb_defused": bomb_defused, "popcorn_hit": popcorn_hit, "cake_destroyed": cake_destroyed, "cake_blast": cake_blast, "locked": locked.keys(), "mystery_revealed": mystery_revealed}


# ───────────── Meta 技能原语（玩家侧能力的引擎钩子，见 10 §7；不进 C++ 基准）─────────────

# 同类消除(#7)：返回某 species 的全部格（清除/计目标交给 board 的 account_clears）。
static func cells_of_species(grid: Array, sp: int) -> Array:
	var out := []
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] == sp:
				out.append(Vector2i(x, y))
	return out

# ───────────── 巧克力蔓延（Chocolate）：对局压力源 ─────────────
# 巧克力语义：占格、不参与 match、不可交换、不下落（apply_gravity 固定切段）、相邻消除则啃掉一格。
# 蔓延：玩家整步若零啃食，则从现存巧克力格向随机正交相邻"可侵占格"增殖一格。
#
# spread_chocolate：从所有现存巧克力格中，找其随机正交相邻的"可侵占格"
#   （grid 是普通棋子 species>=0、非墙、非空，且 choco==0），随机选一个变成巧克力。
#   必须用注入的 rng（确定性可测）。无处可蔓延返回 false；蔓延一格返回 true。原地改 choco。
static func spread_chocolate(choco: Array, grid: Array, rng: RandomNumberGenerator) -> bool:
	var h := choco.size()
	if h == 0:
		return false
	var w: int = choco[0].size()
	# 收集所有"巧克力相邻的可侵占格"候选（去重）。顺序固定(行序→列序→四向) → 同 seed 可复现。
	var seen := {}
	var candidates := []
	const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		for x in w:
			if choco[y][x] <= 0:
				continue
			for d in DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or nx >= w or ny < 0 or ny >= h:
					continue
				if choco[ny][nx] > 0:
					continue  # 已是巧克力
				if grid[ny][nx] < 0:
					continue  # EMPTY(-1)/WALL(-2) 不可侵占（只侵占普通棋子 species>=0）
				var key := Vector2i(nx, ny)
				if seen.has(key):
					continue
				seen[key] = true
				candidates.append(key)
	if candidates.is_empty():
		return false
	var pick: Vector2i = candidates[rng.randi() % candidates.size()]
	choco[pick.y][pick.x] = 1
	return true

# 数巧克力格总数（供 board 判蔓延/胜负，及测试断言）。
static func count_chocolate(choco: Array) -> int:
	var n := 0
	for row in choco:
		for v in row:
			if v > 0:
				n += 1
	return n


# ───────────── 运原料（Ingredients）：从顶部下落、落到底部出口被收集 ─────────────
# 原料语义（与 C++ 镜像一一对应）：
#   占格、不参与 match（find_matches/classify 跳过）、不可交换（is_legal_swap 拦）、
#   【随重力下落】（apply_gravity 把它当可动格搬运，这是与 choco 最大不同）、
#   落到底部出口列后被收集移除（grid→EMPTY, ing→0, ingredient_collected++）。
# 出口：exit_cols 列在 grid 物理最底行(y=h-1) = 出口。原料沉到出口格即被收。
#   重力翻转(up)时盘面 reverse → 原料重新沉到当前底行，出口恒随盘面物理底部，语义保持一致。

# 收集出口处的原料：扫描 exit_cols，最底行(y=h-1)若是原料(ing>0)则收集——
#   grid 该格清空(EMPTY)、ing 归 0，返回本次收集的原料格数。原地改 grid/ing。
#   须在每轮重力结算后调用：原料一路下沉触底 → 被收 → 让出空格 → 上方原料继续沉 → 再收。
static func collect_ingredients_at_exit(grid: Array, ing: Array, exit_cols: Array) -> int:
	var h := grid.size()
	if h == 0 or ing.is_empty():
		return 0
	var w: int = grid[0].size()
	var by := h - 1   # 物理最底行 = 出口所在行
	var collected := 0
	for cx in exit_cols:
		if cx < 0 or cx >= w:
			continue
		if ing[by][cx] > 0:
			grid[by][cx] = EMPTY
			ing[by][cx] = 0
			collected += 1
	return collected

# 数原料格总数（供 board/测试断言盘上剩余原料）。
static func count_ingredients(ing: Array) -> int:
	var n := 0
	for row in ing:
		for v in row:
			if v > 0:
				n += 1
	return n


# ───────────── 倒计时炸弹（Bomb）：对局紧迫感来源（对标 Candy Crush 的 Bomb）─────────────
# 炸弹语义 —— 与 coat/choco/ing 本质不同，是它们里【唯一可被三消/特效直接消除】的层：
#   炸弹格的 grid 是【普通棋子 species】（可消、可换、随重力下落），bomb[y][x] 只是叠加的剩余步数倒计时。
#   故 find_matches/classify_matches/is_legal_swap 都【不感知 bomb】（炸弹格当普通棋子参与匹配/交换）。
#   ① 消除拆弹：炸弹格被三消/特效/彩球波及清除 → bomb→0（resolve/account_clears 在清格处同步清）。
#   ② 随重力下落：bomb 作为纯标记随 grid 同步搬运（apply_gravity 已透传 bomb），不切段、不阻断。
#   ③ 每步递减：玩家每次【有效】交换结算后，所有 bomb>0 的格 -1（tick_bombs，由 board 在消耗步数处调）。
#   ④ 归零判负：某 bomb 从 >0 递减到 0 且该步未被消除 → 炸弹引爆 → 对局立即失败（board 据 tick 返回置失败态）。

# 每步倒计时递减：所有 bomb>0 的格 -1。返回本次有几个炸弹【因递减而归零】（即引爆数）。
#   语义约定：只在【消耗步数的有效交换】后调用（技能/免费动作不递减——见 board 注）。原地改 bomb。
static func tick_bombs(bomb: Array) -> int:
	if bomb.is_empty():
		return 0
	var exploded := 0
	for y in bomb.size():
		for x in bomb[y].size():
			if bomb[y][x] > 0:
				bomb[y][x] -= 1
				if bomb[y][x] == 0:
					exploded += 1   # 这步递减到 0 = 引爆（该格本步未被消除拆弹才会走到这）
	return exploded

# 数盘上还在倒计时的炸弹格总数（供 board/测试断言；拆掉的格 bomb=0 不计）。
static func count_bombs(bomb: Array) -> int:
	var n := 0
	for row in bomb:
		for v in row:
			if v > 0:
				n += 1
	return n


# ───────────── 爆米花（Popcorn）：被特效砸 N 次变彩球的策略格（对标 CC 的 Popcorn）─────────────
# 爆米花语义 —— 与 coat/choco 不同：普通三消【完全不碰】它，只有【特效清除波及】才递减：
#   爆米花格 grid 是普通 species(占位)、fx=SP_NONE、popcorn[y][x]=N(剩余命中数)；
#   ① 不参与普通匹配：find_matches/classify_matches 跳过(像 ing/choco 断串)。
#   ② 不可交换：is_legal_swap 拦(像 ing)。
#   ③ 随重力下落：apply_gravity 把它当段内可动格搬运(像 ing/bomb，popcorn 标记跟随)。
#   ④ 被特效命中-1：条纹/爆炸/彩球的清除波及到爆米花格(格自身在清除集)时，不清、popcorn-1(_hit_popcorn)。
#      普通三消相邻【不影响】(这是与 coat 破锁的关键区别：coat 普通相邻就破，popcorn 只认特效)。
#   ⑤ 归0变彩球：popcorn 递减到 0 → grid 保留 species、fx=SP_COLORBOMB、popcorn=0，玩家随后可用这枚彩球。
# 命中/递减/变彩球的实现已内嵌在 _hit_popcorn + _resolve_fx/account_clears 的特效清除路径；这里只提供计数原语。

# 数盘上还剩命中数的爆米花格总数（供 board/测试断言；归0已变彩球的格 popcorn=0 不计）。
static func count_popcorn(popcorn: Array) -> int:
	var n := 0
	for row in popcorn:
		for v in row:
			if v > 0:
				n += 1
	return n


# ───────────── 糖果炮（Candy Cannon）：持续供给的生成器障碍（对标 CC 生成器）─────────────
# 炮口语义 —— 复用 WALL 机制，故 find_matches/apply_gravity/is_legal_swap 等全部无需改动：
#   炮口格的 grid 是【WALL(-2)】（不可消、不可动、不下落、apply_gravity 处切段），cannon[y][x] 只是叠加的
#   "这格是炮 + 产出类型"标记：cannon[y][x]=0 无炮；=1 产普通糖；=2 产原料。
#   每【有效】交换结算后，每个炮口格在其【正下方相邻格】(y+1) 产出一个棋子（须该格 EMPTY，否则本步不产、等位置空出）：
#     cannon=1 → 普通糖（随机 species，注入 rng 确定性），后续自然下落；
#     cannon=2 → 原料（grid=随机 species + ing[y+1]=1），与运料关协同（炮源源产原料、玩家运到出口）。
#   炮口格永在盘面顶部（或区域顶），产出物落在其下，故炮始终从上方补给盘面。

# 从所有炮口产出：每个 cannon>0 的格在其正下方相邻格(y+1)若 EMPTY 则产一个棋子。
#   cannon=1 → 普通糖（grid=随机 species）；cannon=2 → 原料（grid=随机 species 且 ing[y+1]=1）。
#   下方非空(或越界到底)则该炮本步不产。须用注入的 rng（确定性可复现）。
#   ing 可选：仅 cannon=2 需要——传入则在产出格打原料标记；不传则 cannon=2 退化为只产普通糖（无原料层兜底）。
#   返回本次产出的棋子总数。原地改 grid（与 ing，若传入）。
static func spawn_from_cannons(cannon: Array, grid: Array, species_set: Array, rng: RandomNumberGenerator, ing: Array = []) -> int:
	var h := cannon.size()
	if h == 0:
		return 0
	var w: int = cannon[0].size()
	var n := species_set.size()
	if n == 0:
		return 0
	var has_ing := not ing.is_empty()
	var produced := 0
	# 顺序固定(行序→列序) → 同 seed 可复现。
	for y in h:
		for x in w:
			if cannon[y][x] <= 0:
				continue
			var by := y + 1
			if by >= h:
				continue   # 炮口在最底行：下方无格可产
			if grid[by][x] != EMPTY:
				continue   # 下方非空 → 本步不产（等位置空出）
			grid[by][x] = species_set[rng.randi() % n]   # 产出一个随机 species 棋子
			if cannon[y][x] == 2 and has_ing:
				ing[by][x] = 1   # 产原料炮：在产出格打原料标记（随重力下落、可被运到出口）
			produced += 1
	return produced

# 数盘上的炮口格总数（供 board/测试断言；cannon[y][x]>0 即一门炮）。
static func count_cannons(cannon: Array) -> int:
	var n := 0
	for row in cannon:
		for v in row:
			if v > 0:
				n += 1
	return n


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
			if x + 1 < w and is_legal_swap(grid, Vector2i(x, y), Vector2i(x + 1, y), 1, {"coat": coat}):
				out.append([Vector2i(x, y), Vector2i(x + 1, y)])
			if y + 1 < h and is_legal_swap(grid, Vector2i(x, y), Vector2i(x, y + 1), 1, {"coat": coat}):
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
		var m: Array = find_matches(grid, {"coat": coat})
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
