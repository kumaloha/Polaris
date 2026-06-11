extends "res://tests/test_lib.gd"
# test_session.gd — session.gd 纯逻辑测试（不注册 runner）
# 验收：假 MetaState（真类 new，不 load）+ 假 result 字典
# 覆盖：build_config 字段完整性、bank 入账正确性（含 coin_mult 铭文加成）、依赖纪律

const MetaState := preload("res://meta/meta_state.gd")
const Enchants  := preload("res://meta/enchants.gd")
const Session   := preload("res://app/session.gd")

# ── build_config 字段完整性 ───────────────────────────────────────────────────

func test_build_config_fields() -> void:
	var ms := MetaState.new()
	ms.equipped_skill = "timerewind"
	ms.owned["timerewind"] = 2
	var sess := Session.new()
	var cfg := sess.build_config(ms, 5)

	assert_eq(cfg.get("level_index"), 5, "level_index 透传")
	assert_true(cfg.has("loadout"), "config 含 loadout")
	assert_true(cfg.has("pets"), "config 含 pets")
	assert_eq(cfg["loadout"].get("skill"), "timerewind", "loadout.skill 透传")
	assert_eq(cfg["loadout"].get("skill_level"), 2, "loadout.skill_level 透传")

func test_build_config_pets_list() -> void:
	var ms := MetaState.new()
	var sess := Session.new()
	var cfg := sess.build_config(ms, 0)
	var pets: Array = cfg.get("pets", [])
	assert_eq(pets.size(), 4, "默认4只宠物")
	assert_true("timerewind" in pets, "时兔在列表")
	assert_true("raccoon"    in pets, "浣熊在列表")
	assert_true("dragon"     in pets, "龙在列表")
	assert_true("ladybug"    in pets, "瓢虫在列表")

func test_build_config_pets_is_copy() -> void:
	# pets 是 duplicate，改外部不影响 DEFAULT_PETS
	var ms := MetaState.new()
	var sess := Session.new()
	var cfg1 := sess.build_config(ms, 0)
	cfg1["pets"].append("extra")
	var cfg2 := sess.build_config(ms, 0)
	assert_eq(cfg2["pets"].size(), 4, "duplicate 隔离，外部 append 不污染")

# ── bank 基础入账 ─────────────────────────────────────────────────────────────

func test_bank_coins_and_fragments() -> void:
	var ms := MetaState.new()
	var sess := Session.new()
	var result := {"won": true, "stars": 2, "score": 500, "fragments": 10, "is_scrolling": false}
	var summary := sess.bank(ms, result, 3)

	# fragments 直接加
	assert_eq(ms.fragments, 10, "fragments 入账")
	assert_eq(summary.get("fragments_delta"), 10, "摘要 fragments_delta 正确")
	# won → +1 水晶
	assert_eq(ms.crystals, 1, "过关 +1 水晶")
	assert_eq(summary.get("crystals_delta"), 1, "摘要 crystals_delta 正确")
	# coins = score/50 * coin_mult (默认1.0) = 500/50 = 10
	assert_eq(ms.coins, 10, "金币按 score/50 公式入账")
	assert_eq(summary.get("coins_delta"), 10, "摘要 coins_delta 正确")

func test_bank_failed_no_crystal() -> void:
	var ms := MetaState.new()
	var sess := Session.new()
	var result := {"won": false, "stars": 0, "score": 100, "fragments": 0, "is_scrolling": false}
	var summary := sess.bank(ms, result, 0)

	assert_eq(ms.crystals, 0, "未过关不得水晶")
	assert_eq(summary.get("crystals_delta"), 0, "摘要 crystals_delta=0")

# ── coin_mult 铭文加成路径 ────────────────────────────────────────────────────

func test_bank_coin_mult_enchant() -> void:
	var ms := MetaState.new()
	# 填满 9 格 coins 铭文以得到最大 coin_mult
	# enchants.gd: coin_mult = 1.0 + count * COIN_PCT，需查几个格子
	# 先用 3 格 coins 铭文测试加成路径（不关心具体值，只关心 > 无铭文时）
	for i in 3:
		ms.enchant_page[i] = "coins"
	var sess := Session.new()
	var result := {"won": false, "stars": 1, "score": 500, "fragments": 0, "is_scrolling": false}
	var summary := sess.bank(ms, result, 0)

	# coin_mult > 1.0 时，金币应 > score/50 = 10
	assert_true(ms.coins > 10, "coins 铭文使金币增加 (coin_mult > 1.0)")
	assert_eq(summary.get("coins_delta"), ms.coins, "摘要 coins_delta 与实际一致")

# ── record_clear / level_stars 变化 ──────────────────────────────────────────

func test_bank_records_stars() -> void:
	var ms := MetaState.new()
	var sess := Session.new()
	sess.bank(ms, {"won": true, "stars": 2, "score": 0, "fragments": 0, "is_scrolling": false}, 7)
	assert_eq(int(ms.level_stars.get("7", 0)), 2, "关 7 记录 2 星")

func test_bank_keeps_best_stars() -> void:
	var ms := MetaState.new()
	var sess := Session.new()
	sess.bank(ms, {"won": true, "stars": 3, "score": 0, "fragments": 0, "is_scrolling": false}, 2)
	sess.bank(ms, {"won": true, "stars": 1, "score": 0, "fragments": 0, "is_scrolling": false}, 2)
	assert_eq(int(ms.level_stars.get("2", 0)), 3, "record_clear 保留最高星级")

# ── history 记录 ──────────────────────────────────────────────────────────────

func test_bank_appends_history() -> void:
	var ms := MetaState.new()
	var sess := Session.new()
	sess.bank(ms, {"won": true,  "stars": 3, "score": 100, "fragments": 0, "is_scrolling": false}, 0)
	sess.bank(ms, {"won": false, "stars": 0, "score": 0,   "fragments": 0, "is_scrolling": true},  1)
	assert_eq(ms.history.size(), 2, "bank 两次 → history 两条")
	assert_eq(ms.history[0].get("won"),  true,     "history[0].won 正确")
	assert_eq(ms.history[1].get("stars"), 0,       "history[1].stars 正确")
	assert_eq(ms.history[1].get("kind"), "scroll", "is_scrolling → kind=scroll")

# ── 依赖纪律：match3/ 禁 import meta/，meta/ 禁 import match3/ ────────────────

func test_dependency_discipline_match3_no_meta() -> void:
	# 铁律3：遍历 match3/ 所有 .gd，确认无 "res://meta/" 引用
	var violations := _grep_dir("res://match3", "res://meta/")
	assert_true(
		violations.is_empty(),
		"match3/ 包含 meta/ 引用（违反单向依赖）: " + ", ".join(violations)
	)

func test_dependency_discipline_meta_no_match3() -> void:
	# 铁律3 反向：遍历 meta/ 所有 .gd，确认无 "res://match3/" 引用
	var violations := _grep_dir("res://meta", "res://match3/")
	assert_true(
		violations.is_empty(),
		"meta/ 包含 match3/ 引用（违反单向依赖）: " + ", ".join(violations)
	)

# ── 工具：递归搜索目录下 .gd 文件中的字符串 ──────────────────────────────────

func _grep_dir(dir_path: String, needle: String) -> Array:
	# 返回含有 needle 的文件路径列表
	var hits: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return hits
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full := dir_path + "/" + fname
			if dir.current_is_dir():
				hits.append_array(_grep_dir(full, needle))
			elif fname.ends_with(".gd"):
				if _file_contains(full, needle):
					hits.append(full)
		fname = dir.get_next()
	dir.list_dir_end()
	return hits

func _file_contains(path: String, needle: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var content := f.get_as_text()
	f.close()
	return needle in content
