extends RefCounted
# 铭文系统纯逻辑（量变·9 格碎片制，见 02 §2）。UI 只调 aggregate() 拿对局参数。
# 铁律：只量变（调数值），不质变（给新能力/改规则=技能）。

# 5 种铭文 id（不分线，从这 5 种填 9 格）
const MOVES := "moves"        # +步数
const SCORE := "score"        # +积分%
const COINS := "coins"        # +金币%
const SKILL := "skill_uses"   # +强化技能次数
const OPENING := "opening"    # +开局奖励
const TYPES := [MOVES, SCORE, COINS, SKILL, OPENING]
const SLOTS := 9

# 数值（占位，待策划调）
const SCORE_PCT := 0.05
const COIN_PCT := 0.05

# 把一页 9 格(Array[String]，空槽用 "")聚合成对局参数。
static func aggregate(page: Array) -> Dictionary:
	var c := {}
	for t in TYPES:
		c[t] = 0
	for slot in page:
		if c.has(slot):
			c[slot] += 1
	return {
		"extra_moves": mini(int(c[MOVES] / 3), 2),       # 3格+1步, 6格+2步(封顶, >6 无效)
		"score_mult": 1.0 + c[SCORE] * SCORE_PCT,        # 线性无封顶
		"coin_mult": 1.0 + c[COINS] * COIN_PCT,
		"extra_skill_uses": int(c[SKILL] / 6),           # 6格 = 技能多用 1 次（占 2/3 格）
		"opening_special": _opening_fx(c[OPENING]),      # 3格直线 / 6格彩球
	}

# 开局奖励 → fx 种类(0=无)。3格=4消直线(SP_LINE_H=1)；6格=升级成5消彩球(SP_COLORBOMB=4)。
static func _opening_fx(n: int) -> int:
	if n >= 6:
		return 4
	elif n >= 3:
		return 1
	return 0
