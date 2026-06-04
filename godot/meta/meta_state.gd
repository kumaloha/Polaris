extends RefCounted
# 玩家 Meta 进度状态：钱包 + 拥有角色(含等级) + 铭文页 + 装备，含持久化(user://save.json)。
# 这是 Meta 系统的纯逻辑/数据层；UI(app.gd)读写它，对局开始时用 loadout() 给 board 喂参。

const Gacha := preload("res://meta/gacha.gd")
const Enchants := preload("res://meta/enchants.gd")
const Scheduler := preload("res://meta/scheduler.gd")
const SAVE_PATH := "user://save.json"

var fragments: int = 0      # 铭文碎片
var crystals: int = 0       # 水晶（抽卡机会）
var coins: int = 0          # 金币
var owned: Dictionary = {}  # 角色 id -> 等级
var enchant_page: Array = []    # 9 格(String，空槽 "")
var equipped_skill: String = "" # 当前装备的角色 id
var history: Array = []          # 每局表现 [{won, stars}]，供个性化调度估技能

func _init() -> void:
	enchant_page.resize(Enchants.SLOTS)
	enchant_page.fill("")

# 一局结束入账（吃 board.result()）。碎片/金币/水晶为占位公式，数值待调。
func bank_result(r: Dictionary) -> void:
	fragments += int(r.get("fragments", 0))
	var coin_mult: float = Enchants.aggregate(enchant_page).get("coin_mult", 1.0)
	coins += int(int(r.get("score", 0)) / 50.0 * coin_mult)
	if r.get("won", false):
		crystals += 1   # 过关给一点抽卡机会
	history.append({
		"won": r.get("won", false),
		"stars": int(r.get("stars", 0)),
		"kind": ("scroll" if r.get("is_scrolling", false) else "normal"),   # 类型化历史→分类型估技能
	})

# 抽卡（消耗水晶）。返回 pull 结果，或 {"error":...}。
func do_gacha(rng: RandomNumberGenerator, cost: int = 1) -> Dictionary:
	if crystals < cost:
		return {"error": "not_enough_crystals"}
	crystals -= cost
	var first := owned.is_empty()
	var res := Gacha.pull(owned, rng, first)
	if res["dupe"]:
		fragments += 20         # 重复角色转碎片（占位）
	else:
		owned[res["id"]] = 1    # 新角色 1 级
	return res

# 当前装备角色 + 铭文 → 对局参数（给 board 喂值）。
func loadout() -> Dictionary:
	var agg := Enchants.aggregate(enchant_page)
	agg["skill"] = equipped_skill
	agg["skill_level"] = int(owned.get(equipped_skill, 1))
	return agg

# 个性化推关（09 §5.4 心流）：类型感知——挖矿/普通关各按各的水平推。played=已玩过的库索引集。
func recommend_next(library: Array, played: Dictionary = {}) -> int:
	return Scheduler.recommend_for(library, history, played)

# ── 持久化 ──
func save() -> void:
	var d := {
		"fragments": fragments, "crystals": crystals, "coins": coins,
		"owned": owned, "enchant_page": enchant_page, "equipped_skill": equipped_skill,
		"history": history,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return
	fragments = int(d.get("fragments", 0))
	crystals = int(d.get("crystals", 0))
	coins = int(d.get("coins", 0))
	owned = d.get("owned", {})
	equipped_skill = String(d.get("equipped_skill", ""))
	var page = d.get("enchant_page", [])
	enchant_page = page if typeof(page) == TYPE_ARRAY and page.size() == Enchants.SLOTS else _blank_page()
	var h = d.get("history", [])
	history = h if typeof(h) == TYPE_ARRAY else []   # 恢复历史→个性化调度跨会话累积(不重置)

func _blank_page() -> Array:
	var p := []
	p.resize(Enchants.SLOTS)
	p.fill("")
	return p
