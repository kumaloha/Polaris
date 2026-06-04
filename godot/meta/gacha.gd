extends RefCounted
# 抽卡纯逻辑（02 §三）：抽卡机会靠"把关卡分玩得很高"解锁；首抽必出借贷；之后随机池。
# UI 调 pull()。能力靠抽卡，外观(皮肤)是另一条线——这里只发角色。

# 可抽角色池（11 可玩，不含默认门面 lucky）
const POOL := ["borrrower", "timerewind", "snapshot", "longswap", "gravityflip",
	"colorshield", "sametypeclear", "foresight", "breaker", "chainbonus", "collector"]

# 抽一次。is_first_pull → 必出借贷(雪中送炭由它兜底)；否则从池随机。rng 注入(可复现)。
# 返回 {id, dupe}（dupe=是否已拥有，UI 据此把重复转碎片）。
static func pull(owned: Dictionary, rng: RandomNumberGenerator, is_first_pull: bool) -> Dictionary:
	var id: String
	if is_first_pull:
		id = "borrrower"   # 首抽 100% 保底
	else:
		id = POOL[rng.randi() % POOL.size()]
	return {"id": id, "dupe": owned.has(id)}
