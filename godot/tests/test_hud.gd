extends "res://tests/test_lib.gd"
# P4: HUD 子控制器(match3/hud.gd)专属行为测试。契约 A 消费者 + 结算面板渲染。
# 注意: 本文件【未注册】runner.gd(主线程统一注册); 经 godot -s 直接跑或后续接入。
# 测试守则: 行为断言优先, 不做源码 contains 断言。

const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")

const JELLY_GOAL_ICON := "res://assets/obstacles/ob_bubble.png"


func _prepare_level_scene() -> Node:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.background_layer = level.get_node("BackgroundLayer")
	level.board_layer = level.get_node("BoardLayer")
	level.gem_layer = level.get_node("GemLayer")
	level.character_layer = level.get_node("CharacterLayer")
	level.ui_layer = level.get_node("UILayer")
	level.skill_bar = level.get_node("SkillBar")
	level._levels = LevelLibrary.load_file("res://levels.json")
	level._playable = []
	for i in range(level._levels.size()):
		var objs = level._levels[i].get("objectives", [])
		if objs is Array and not objs.is_empty():
			level._playable.append(i)
	return level


func _filled_layer(w: int, h: int, v: int) -> Array:
	var rows: Array = []
	for r in range(h):
		var row: Array = []
		for c in range(w):
			row.append(v)
		rows.append(row)
	return rows


func _count_label_text(root: Node, text: String) -> int:
	var count := 0
	if root is Label and (root as Label).text == text:
		count += 1
	for child in root.get_children():
		count += _count_label_text(child, text)
	return count


# level 一造好(经 _init), hud 子控制器即存在并已注入 level。
func test_level_owns_a_hud_child_controller() -> void:
	var level := _prepare_level_scene()
	assert_true(level.hud != null, "level exposes a hud child controller")
	assert_true(level.hud is Node, "hud is a Node (lives in level subtree, 铁律2)")
	assert_eq(level.hud.get_parent(), level, "hud is parented under level so it dies with the level subtree")
	level.free()


# render_chrome 把顶栏画进 level 当前的 ui_layer(子控制器读 live ui_layer, 不缓存)。
func test_render_chrome_draws_topbar_into_ui_layer() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "1"], level._levels.size())
	level.load_level(raw_idx)
	assert_true(level.ui_layer.get_child_count() > 0, "render_chrome populates the ui layer with topbar nodes")
	# 关卡号标签出现(第 N 关)。
	var id: int = int(level._cur_cfg.get("id", 1))
	assert_true(_count_label_text(level.ui_layer, "第 %d 关" % id) > 0, "topbar shows the level number label")
	level.free()


# 契约 A: on_step 读 report.account 增量刷新目标进度 Label(不重画整层), 消灭"每步全清重画"。
func test_on_step_incrementally_updates_objective_progress_label() -> void:
	var level := _prepare_level_scene()
	var objs := [{"type": "CLEAR_JELLY", "species": -1, "target": 65}]
	level.board = Board.new(8, 9, [0, 1, 2, 3, 4, 5], 0, 25, 1, [], objs, _filled_layer(8, 9, 1))
	level.hud.render_chrome({"id": 1})
	# 初始剩余 = 65(progress 0)。
	assert_true(_count_label_text(level.ui_layer, "65") > 0, "objective starts showing the full remaining count")
	# 模拟一步消除把 jelly_cleared 推到 5 → 剩余 60; 经 StepReport 分发。
	level.board.jelly_cleared = 5
	level.hud.on_step({"account": {"jelly_cleared": 5, "by_species": {}}})
	assert_true(_count_label_text(level.ui_layer, "60") > 0, "on_step updates the cached objective label to the new remaining count")
	assert_eq(_count_label_text(level.ui_layer, "65"), 0, "the stale remaining count is replaced in place, not stacked")
	level.free()


# refresh() 重画 ui_layer 并重建缓存 Label(步数随 board.moves_left)。
func test_refresh_redraws_moves_from_board() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "1"], level._levels.size())
	level.load_level(raw_idx)
	level.board.moves_left = 17
	level.hud.refresh()
	assert_true(_count_label_text(level.ui_layer, "17") > 0, "refresh shows the current remaining moves from the board")
	level.free()


# 步数 override(结算奖励演出期间 level 调): set→显示 0, clear→回到 board.moves_left。
func test_moves_display_override_round_trips() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "1"], level._levels.size())
	level.load_level(raw_idx)
	level.board.moves_left = 9
	level.hud.refresh()
	level.hud.set_moves_display_override(0)
	assert_eq(level.hud.display_moves_left(), 0, "override forces the displayed moves to zero during endgame bonus")
	assert_true(_count_label_text(level.ui_layer, "0") > 0, "the displayed moves label reflects the override immediately")
	level.hud.clear_moves_display_override()
	assert_eq(level.hud.display_moves_left(), 9, "clearing the override returns to the live board move count")
	level.free()


# show_result 渲染结算面板(标题+按钮); 按钮回调经 Callable 注入连回 level。
func test_show_result_renders_panel_and_button_invokes_callback() -> void:
	var level := _prepare_level_scene()
	var raw_idx: int = level.call("_launch_level_idx_from_args", ["--level", "1"], level._levels.size())
	level.load_level(raw_idx)
	var hit := {"win": null}
	var cb := func(win: bool): hit["win"] = win
	level.hud.show_result(true, cb)
	assert_true(_count_label_text(level.ui_layer, "通关!") > 0, "win result panel shows the win title")
	var btn := _find_button(level.ui_layer)
	assert_true(btn != null, "result panel has a clickable button")
	if btn != null:
		btn.pressed.emit()
		assert_eq(hit["win"], true, "pressing the result button invokes the injected callback with the win flag")
		assert_eq(_count_label_text(level.ui_layer, "通关!"), 0, "pressing the result button removes the HUD result overlay immediately")
		assert_true(_find_button(level.ui_layer) == null, "pressing the result button removes the overlay button so it cannot keep eating clicks")
	level.free()


func _find_button(root: Node) -> Button:
	if root is Button:
		return root as Button
	for child in root.get_children():
		var f := _find_button(child)
		if f != null:
			return f
	return null


# 目标视图: COLLECT 用该色宝石图标, 进度来自 board.collected; 封顶到 target。
func test_objectives_view_collect_reads_board_state() -> void:
	var level := _prepare_level_scene()
	var objs := [{"type": "CLEAR_JELLY", "species": -1, "target": 65}]
	level.board = Board.new(8, 9, [0, 1, 2, 3, 4, 5], 0, 25, 1, [], objs, _filled_layer(8, 9, 1))
	var view: Array = level.hud.call("_objectives_view")
	assert_eq(view.size(), 1, "one objective card")
	assert_eq(view[0].get("label", ""), "清果冻", "jelly objective is labeled by its clearing action")
	assert_eq(view[0].get("icon", ""), JELLY_GOAL_ICON, "jelly objective uses the readable jelly icon")
	assert_eq(view[0].get("progress", -1), 0, "jelly starts at zero progress")
	level.free()
