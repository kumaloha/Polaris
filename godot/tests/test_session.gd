extends "res://tests/test_lib.gd"
# test_session.gd — session.gd 纯逻辑测试（不注册 runner）
# 验收：假 MetaState（真类 new，不 load）+ 假 result 字典
# 覆盖：build_config 字段完整性、bank 入账正确性（含 coin_mult 铭文加成）、依赖纪律

const MetaState := preload("res://meta/meta_state.gd")
const Enchants  := preload("res://meta/enchants.gd")
const Session   := preload("res://app/session.gd")
const PlaytestRecorder := preload("res://app/playtest_recorder.gd")
const LevelLibrary := preload("res://core/level_library.gd")

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
	assert_eq(pets.size(), 2, "默认只带两只龙宠物")
	assert_true("dragon_baby" in pets, "小龙在列表")
	assert_true("dragon_youth" in pets, "大龙在列表")
	assert_false("timerewind" in pets, "时兔不再进入默认底栏")
	assert_false("raccoon" in pets, "浣熊不再进入默认底栏")
	assert_false("ladybug" in pets, "瓢虫不再进入默认底栏")

func test_build_config_pets_is_copy() -> void:
	# pets 是 duplicate，改外部不影响 DEFAULT_PETS
	var ms := MetaState.new()
	var sess := Session.new()
	var cfg1 := sess.build_config(ms, 0)
	cfg1["pets"].append("extra")
	var cfg2 := sess.build_config(ms, 0)
	assert_eq(cfg2["pets"].size(), 2, "duplicate 隔离，外部 append 不污染")

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

func test_playtest_recorder_writes_jsonl_and_player_context() -> void:
	var old_log := PlaytestRecorder.LOG_PATH
	var old_context := PlaytestRecorder.CONTEXT_PATH
	PlaytestRecorder.LOG_PATH = "user://test_playtest_sessions.jsonl"
	PlaytestRecorder.CONTEXT_PATH = "user://test_player_context.json"
	PlaytestRecorder.clear_test_files()

	var event := PlaytestRecorder.record({
		"won": false,
		"lost": true,
		"stars": 0,
		"score": 120,
		"moves_left": 0,
		"move_limit": 22,
		"level_coordinate": 5,
		"assigned_instance_id": "level_005_assisted_c01",
		"objectives": [{"type": "CLEAR_JELLY", "target": 6}],
		"objective_progress": [{"type": "CLEAR_JELLY", "current": 3, "target": 6}],
	}, 4, {"level_id": "level_005_assisted_c01"})

	assert_true(FileAccess.file_exists(PlaytestRecorder.LOG_PATH), "playtest JSONL is written")
	assert_true(FileAccess.file_exists(PlaytestRecorder.CONTEXT_PATH), "generate-next PlayerContext snapshot is written")
	assert_eq(event.get("level_coordinate"), 5, "event keeps the playable coordinate")
	assert_eq(event.get("assigned_instance_id"), "level_005_assisted_c01", "event keeps assigned instance id")
	assert_eq(event.get("fail_reasons", {}).get("out_of_moves"), 1, "out-of-moves loss is machine readable")

	var f := FileAccess.open(PlaytestRecorder.CONTEXT_PATH, FileAccess.READ)
	var ctx = JSON.parse_string(f.get_as_text())
	f.close()
	assert_true(ctx is Dictionary, "context file is JSON object")
	assert_eq(ctx.get("played_levels", []).size(), 1, "context gets one played level record")
	var played: Dictionary = ctx["played_levels"][0]
	assert_eq(played.get("level_coordinate"), 5, "context record keeps coordinate")
	assert_eq(played.get("won"), false, "context record keeps win/loss")
	assert_eq(played.get("attempts"), 1, "each playtest event is one attempt")

	PlaytestRecorder.clear_test_files()
	PlaytestRecorder.LOG_PATH = old_log
	PlaytestRecorder.CONTEXT_PATH = old_context

func test_bank_records_playtest_event_for_generate_next_context() -> void:
	var old_log := PlaytestRecorder.LOG_PATH
	var old_context := PlaytestRecorder.CONTEXT_PATH
	PlaytestRecorder.LOG_PATH = "user://test_bank_playtest_sessions.jsonl"
	PlaytestRecorder.CONTEXT_PATH = "user://test_bank_player_context.json"
	PlaytestRecorder.clear_test_files()

	var ms := MetaState.new()
	var sess := Session.new()
	var summary := sess.bank(ms, {
		"won": true,
		"stars": 2,
		"score": 500,
		"fragments": 0,
		"is_scrolling": false,
		"moves_left": 4,
		"move_limit": 20,
		"level_coordinate": 9,
		"assigned_instance_id": "level_009_base_c00",
		"objectives": [{"type": "COLLECT_INGREDIENT", "target": 1}],
		"objective_progress": [{"type": "COLLECT_INGREDIENT", "current": 1, "target": 1}],
	}, 8, {"level_id": "level_009_base_c00"})

	assert_true(String(summary.get("playtest_event_id", "")).begins_with("playtest_"), "bank returns the recorded playtest event id")
	var f := FileAccess.open(PlaytestRecorder.CONTEXT_PATH, FileAccess.READ)
	var ctx = JSON.parse_string(f.get_as_text())
	f.close()
	assert_eq(ctx.get("played_levels", [])[0].get("level_coordinate"), 9, "bank writes the context coordinate for generate-next")
	assert_eq(ctx.get("played_levels", [])[0].get("moves_left"), 4, "bank writes remaining moves")

	PlaytestRecorder.clear_test_files()
	PlaytestRecorder.LOG_PATH = old_log
	PlaytestRecorder.CONTEXT_PATH = old_context

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

# ══════════════════════════════════════════════════════════════════════════════
# ── game_root 端到端状态机测试（不依赖 Level 信号，直接驱动状态机方法）────────
# ══════════════════════════════════════════════════════════════════════════════
#
# 策略：preload game_root.gd → new() → 手动初始化 _meta/_session/_library/_played_set
#        → 调 _build_ui()（建 Node 子树，headless 下无渲染但不崩）
#        → 通过 _enter_boot() / _on_session_ended() 直接驱动状态机
#        → 断言内部字段（_state / _meta / _last_summary / _last_stars）
# 不测 Control 像素/布局，只测逻辑正确性。

const GameRoot := preload("res://app/game_root.gd")

func _make_root_with_library(lib: Array) -> Node:
	# 构造 game_root 实例并手动初始化——跳过 _ready() 的磁盘 IO 和 _enter_boot()
	PlaytestRecorder.LOG_PATH = "user://test_game_root_playtest_sessions.jsonl"
	PlaytestRecorder.CONTEXT_PATH = "user://test_game_root_player_context.json"
	PlaytestRecorder.clear_test_files()
	var gr := GameRoot.new()
	gr._meta    = MetaState.new()
	gr._session = Session.new()
	gr._library = lib
	gr._played_set = {}
	gr._last_summary = {}
	gr._last_stars = 0
	# _build_ui 建 Node 子树：MapScroll/LevelRoot/ResultPanel
	gr._build_ui()
	return gr

# ── Boot → Map：状态枚举 + 列表生成 ─────────────────────────────────────────

func test_game_root_boot_enters_map_state() -> void:
	# _enter_boot 直通 _enter_map → 状态应为 MAP
	# 清空磁盘 level_stars 影响：_enter_boot 调 load_state，
	# 但状态枚举不受存档影响，只验证最终 _state == MAP
	var gr := _make_root_with_library([])
	gr._enter_boot()
	assert_eq(gr._state, GameRoot.State.MAP, "Boot 直通 MAP 状态")
	gr.free()

func test_game_root_ready_loads_generated_library_by_default() -> void:
	# 真实启动冒烟：_ready() 自己解析默认路径、读磁盘关卡包并进入地图。
	var gr := GameRoot.new()
	gr._ready()
	assert_eq(gr._levels_path, LevelLibrary.DEFAULT_LEVELS_PATH, "GameRoot 默认使用生成关卡包")
	assert_true(gr._library.size() > 0, "默认生成关卡包可被 GameRoot 读到")
	assert_eq(gr._state, GameRoot.State.MAP, "_ready 后进入地图状态")
	assert_true(gr._map_container.get_child_count() > 0, "地图由默认生成关卡包构建按钮")
	gr.free()

func test_game_root_map_builds_button_per_level() -> void:
	# library 含 3 条 → MapContainer 应有 3 个子节点
	var lib := [{"id": 0}, {"id": 1}, {"id": 2}]
	var gr := _make_root_with_library(lib)
	gr._enter_boot()
	# MapContainer 的子节点数 == library.size()
	assert_eq(gr._map_container.get_child_count(), 3, "3 关卡 → 3 个按钮")
	gr.free()

func test_game_root_map_shows_zero_stars_initially() -> void:
	# 未通关时，地图按钮文字含 ☆☆☆
	# 不走 _enter_boot（会 load_state 读磁盘存档），直接用新鲜 meta
	var lib := [{"id": 0}]
	var gr := _make_root_with_library(lib)
	# _meta 已是 new()，level_stars 为空，直接进 Map
	gr._enter_map()
	var btn: Button = gr._map_container.get_child(0) as Button
	assert_true(btn != null and "☆☆☆" in btn.text, "未通关显示 ☆☆☆，实际: " + (btn.text if btn != null else "null"))
	gr.free()

# ── Result 路径：bank 调用 + UI 数字 ─────────────────────────────────────────

func test_game_root_session_ended_updates_summary() -> void:
	# 模拟 session_ended：喂假 result，断言 _last_summary 被填充
	# _make_root_with_library 内已调 _build_ui()，无需重复
	var gr := _make_root_with_library([{"id": 0}])
	gr._enter_boot()
	gr._current_index = 0
	var fake_result := {"won": true, "stars": 2, "score": 500, "fragments": 10, "is_scrolling": false}
	gr._on_session_ended(fake_result)
	assert_eq(gr._state, GameRoot.State.RESULT, "session_ended 后进入 RESULT 状态")
	assert_eq(gr._last_stars, 2, "_last_stars 记录本局星级")
	assert_eq(gr._last_summary.get("fragments_delta"), 10, "摘要 fragments_delta 正确")
	assert_eq(gr._last_summary.get("coins_delta"), 10, "摘要 coins_delta 正确（500/50=10）")
	assert_eq(gr._last_summary.get("crystals_delta"), 1, "摘要 crystals_delta=1（过关）")
	gr.free()

func test_game_root_result_panel_shows_stars_label() -> void:
	# Result 面板应包含星级 Label
	var gr := _make_root_with_library([{"id": 0}])
	gr._enter_boot()
	gr._current_index = 0
	gr._last_stars = 3
	gr._last_summary = {"coins_delta": 5, "fragments_delta": 2, "crystals_delta": 1}
	gr._enter_result()
	# 在 ResultPanel 子树里找 name="StarsLabel" 的节点
	var stars_lbl: Node = _find_node_by_name(gr._result_panel, "StarsLabel")
	assert_true(stars_lbl != null, "Result 面板含 StarsLabel 节点")
	if stars_lbl != null and stars_lbl is Label:
		assert_eq((stars_lbl as Label).text, "★★★", "3 星显示 ★★★")
	gr.free()

func test_game_root_result_panel_shows_summary_label() -> void:
	# Result 面板 SummaryLabel 文字包含增量数字
	var gr := _make_root_with_library([{"id": 0}])
	gr._enter_boot()
	gr._current_index = 0
	gr._last_stars = 1
	gr._last_summary = {"coins_delta": 8, "fragments_delta": 3, "crystals_delta": 0}
	gr._enter_result()
	var summary_lbl: Node = _find_node_by_name(gr._result_panel, "SummaryLabel")
	assert_true(summary_lbl != null, "Result 面板含 SummaryLabel 节点")
	if summary_lbl != null and summary_lbl is Label:
		assert_true("8" in (summary_lbl as Label).text, "SummaryLabel 含 coins_delta=8")
		assert_true("3" in (summary_lbl as Label).text, "SummaryLabel 含 fragments_delta=3")
	gr.free()

# ── 回 Map：星级刷新 ──────────────────────────────────────────────────────────

func test_game_root_map_refreshes_stars_after_result() -> void:
	# session_ended → _meta.level_stars 应记录新星级（数据层断言，不依赖 UI 节点生命周期）
	var lib := [{"id": 0}, {"id": 1}]
	var gr := _make_root_with_library(lib)
	gr._enter_map()
	gr._current_index = 0
	# 模拟关 0 通关 2 星
	var fake_result := {"won": true, "stars": 2, "score": 0, "fragments": 0, "is_scrolling": false}
	gr._on_session_ended(fake_result)
	# 星级已记录在 meta（_session.bank 内部调 record_clear）
	assert_eq(int(gr._meta.level_stars.get("0", 0)), 2, "关 0 通关后 level_stars 记录 2 星")
	assert_eq(int(gr._meta.level_stars.get("1", 0)), 0, "关 1 未通关仍 0 星")
	# 回 Map 后 _stars_str 应正确（验证 _stars_str 方法本身）
	assert_eq(gr._stars_str(2), "★★☆", "_stars_str(2) 返回 ★★☆")
	assert_eq(gr._stars_str(0), "☆☆☆", "_stars_str(0) 返回 ☆☆☆")
	gr.free()

func test_game_root_played_set_updated_after_session_ended() -> void:
	# session_ended 后 _played_set 应包含当前关索引
	var gr := _make_root_with_library([{"id": 0}])
	gr._enter_boot()
	gr._current_index = 0
	var fake_result := {"won": false, "stars": 0, "score": 0, "fragments": 0, "is_scrolling": false}
	gr._on_session_ended(fake_result)
	assert_true(gr._played_set.has(0), "_played_set 包含已玩关 0")
	gr.free()

# ── 工具：递归按 name 找节点 ──────────────────────────────────────────────────

func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for ch in root.get_children():
		var found := _find_node_by_name(ch, target_name)
		if found != null:
			return found
	return null

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
