extends RefCounted
# 个性化难度调度（09 §5.4 / 00 §2 需求2 心流）：按玩家表现估技能 → 从关卡库推一关贴合水平的。
# 纯逻辑、运行时轻量（合 05：重算法离线，调度只是从库里挑）。MetaState 记录表现，调 recommend()。
# "算法藏在底层"：玩家只觉得"这游戏怎么这么懂我"，不暴露最优解/难度数字。

# 玩家技能评分(0..1，越高越强)：最近 N 局的过关率 + 星级滑动估计。
static func estimate_skill(history: Array, kind: String = "") -> float:
	var rows := history
	if kind != "":   # 按关卡类型("normal"/"scroll")过滤；该类型样本太少(<2)则退回全部历史
		rows = []
		for h in history:
			if String(h.get("kind", "")) == kind:
				rows.append(h)
		if rows.size() < 2:
			rows = history
	if rows.is_empty():
		return 0.4   # 新手默认偏低 → 先推容易的
	var n := mini(rows.size(), 10)   # 最近 10 局
	var sum := 0.0
	for i in range(rows.size() - n, rows.size()):
		var h: Dictionary = rows[i]
		if h.get("won", false):
			sum += 0.4 + 0.2 * float(int(h.get("stars", 1)) - 1)   # 1星0.4 / 2星0.6 / 3星0.8
		else:
			sum += 0.1
	return clampf(sum / n, 0.0, 1.0)

# 从关卡库推一关（心流）：玩家越强→推 skilled_pass 越低(越难)的关；优先没玩过的。
# 返回库索引(-1=空库)。library 每项需含 "skilled_pass"。
static func recommend(library: Array, skill: float, played: Dictionary = {}) -> int:
	if library.is_empty():
		return -1
	# 目标通过率：skill 0→0.9(易) … skill 1→0.2(难)。心流=能过但有挑战。
	var target_pass := lerpf(0.9, 0.2, clampf(skill, 0.0, 1.0))
	var best := _closest(library, target_pass, played)
	if best < 0:   # 没玩过的都没了 → 不排除已玩
		best = _closest(library, target_pass, {})
	return best

static func _closest(library: Array, target_pass: float, exclude: Dictionary) -> int:
	var best := -1
	var best_d := 1.0e9
	for i in library.size():
		if exclude.has(i):
			continue
		var p := float(library[i].get("skilled_pass", 0.5))
		var d := absf(p - target_pass)
		if d < best_d:
			best_d = d
			best = i
	return best

# 类型感知推关：挖矿(scroll)和普通关各按各的水平推——每关用"该类型的技能"算目标通过率。
# 擅长普通关≠擅长挖矿，故分别估技能(estimate_skill 按 kind 过滤)，避免拿普通关水平推挖矿关。
static func recommend_for(library: Array, history: Array, played: Dictionary = {}) -> int:
	if library.is_empty():
		return -1
	var skill_normal := estimate_skill(history, "normal")
	var skill_scroll := estimate_skill(history, "scroll")
	var best := _closest_typed(library, skill_normal, skill_scroll, played)
	if best < 0:   # 没玩过的都没了 → 不排除已玩
		best = _closest_typed(library, skill_normal, skill_scroll, {})
	return best

static func _closest_typed(library: Array, skill_normal: float, skill_scroll: float, exclude: Dictionary) -> int:
	var best := -1
	var best_d := 1.0e9
	for i in library.size():
		if exclude.has(i):
			continue
		var skill: float = skill_scroll if bool(library[i].get("is_scrolling", false)) else skill_normal
		var target := lerpf(0.9, 0.2, clampf(skill, 0.0, 1.0))
		var d := absf(float(library[i].get("skilled_pass", 0.5)) - target)
		if d < best_d:
			best_d = d
			best = i
	return best
