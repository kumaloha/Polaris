extends RefCounted
# meta ↔ 对局 的唯一桥（契约D）。
# 单向依赖：app → meta、app → match3；match3 禁 import meta，反向同禁。
# 本文件无 Node 依赖，纯逻辑可 headless 单测。

# 当前固定出战宠物注册表 key（未来可按 loadout 配）。
const DEFAULT_PETS := ["timerewind", "raccoon", "dragon", "ladybug"]
const PlaytestRecorder := preload("res://app/playtest_recorder.gd")

# ── 开局组装 ──────────────────────────────────────────────────────────────────

# 按契约D组装 SessionConfig，注入给 Level.tscn。
# meta_state : MetaState.gd 实例（RefCounted，不需 Node）
# level_index : 关卡库索引（int）
# 返回 SessionConfig 字典：
#   { "level_index": int, "loadout": Dictionary, "pets": Array[String] }
func build_config(meta_state: Object, level_index: int) -> Dictionary:
	return {
		"level_index": level_index,
		"loadout": meta_state.loadout(),
		"pets": DEFAULT_PETS.duplicate(),
	}

# ── 结算入账 ──────────────────────────────────────────────────────────────────

# 消费 SessionResult → 更新 meta_state 并持久化。
# result 字典须含 won/stars/score/is_scrolling/collected（契约D §5.2）。
# level_index : 对应关卡库索引，用于 record_clear。
# 返回入账摘要（金币/碎片/水晶增量——用于结算页显示）：
#   { "coins_delta": int, "fragments_delta": int, "crystals_delta": int }
func bank(meta_state: Object, result: Dictionary, level_index: int, level_record: Dictionary = {}) -> Dictionary:
	# 快照入账前数值
	var coins_before    := int(meta_state.coins)
	var fragments_before := int(meta_state.fragments)
	var crystals_before := int(meta_state.crystals)

	# 调用 meta 入账
	meta_state.bank_result(result)

	# 记录关卡星级
	var stars := int(result.get("stars", 0))
	meta_state.record_clear(level_index, stars)

	# 持久化
	meta_state.save()
	var playtest_event := {}
	if result.has("level_coordinate") or not level_record.is_empty():
		playtest_event = PlaytestRecorder.record(result, level_index, level_record)

	# 返回增量摘要
	return {
		"coins_delta":     int(meta_state.coins)     - coins_before,
		"fragments_delta": int(meta_state.fragments) - fragments_before,
		"crystals_delta":  int(meta_state.crystals)  - crystals_before,
		"playtest_event_id": str(playtest_event.get("event_id", "")),
	}

# ── 推关 ─────────────────────────────────────────────────────────────────────

# 薄透传至 meta_state.recommend_next，供 game_root Map 状态调用。
# library : 关卡库 Array（来自 levels.json）
# played  : 已玩关卡索引集 Dictionary（{ int: bool }）
# 返回推荐关卡库索引（int）
func recommend_next(meta_state: Object, library: Array, played: Dictionary = {}) -> int:
	return meta_state.recommend_next(library, played)
