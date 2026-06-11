extends "res://tests/test_lib.gd"
# P4: 技能栏子控制器(match3/skills.gd)专属行为测试。契约 A 消费者 + 契约 C 协作(头像/相框)。
# 注意: 本文件【未注册】runner.gd(主线程统一注册); 经 godot -s 直接跑或后续接入。
# 测试守则: 行为断言优先, 不做源码 contains 断言。

const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")

const RABBIT_AVATAR := "res://assets/pets/timerewind/rabbit_avatar.png"
const RABBIT_AVATAR_FRAME_NODE := "TimeRabbitAvatarFrame"
const RABBIT_AVATAR_FRAME_BG_NODE := "TimeRabbitAvatarFrameBg"


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


func _find_named_node(root: Node, node_name: String) -> Node:
	if String(root.name) == node_name:
		return root
	for child in root.get_children():
		var found := _find_named_node(child, node_name)
		if found != null:
			return found
	return null


func _count_texture_buttons(root: Node) -> int:
	var count := 0
	if root is TextureButton:
		count += 1
	for child in root.get_children():
		count += _count_texture_buttons(child)
	return count


# level 一造好(经 _init), skills 子控制器即存在并已注入 level。
func test_level_owns_a_skills_child_controller() -> void:
	var level := _prepare_level_scene()
	assert_true(level.skills != null, "level exposes a skills child controller")
	assert_true(level.skills is Node, "skills is a Node (lives in level subtree, 铁律2)")
	assert_eq(level.skills.get_parent(), level, "skills is parented under level so it dies with the level subtree")
	level.free()


# build() 在 skill_bar 上渲染 4 头像按钮 + 时兔相框(slot 0)。
func test_build_renders_four_avatar_buttons_and_time_rabbit_frame() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	assert_eq(_count_texture_buttons(level.skill_bar), 4, "four pet avatar buttons are rendered on the skill bar")
	assert_true(_find_named_node(level.skill_bar, RABBIT_AVATAR_FRAME_NODE) != null, "time rabbit avatar frame is rendered on the skill bar")
	# 时兔头像隐藏/恢复要用到的空框背景 frame_bg, 时兔施法控制器按名查它。
	assert_true(_find_named_node(level.skill_bar, RABBIT_AVATAR_FRAME_BG_NODE) != null, "time rabbit frame background is on the skill bar where the cast controller looks it up by name")
	level.free()


# 契约 A: on_step 读 report.account.by_species 给对应色技能充能。
func test_on_step_charges_skill_from_by_species() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	level.skills.reset_charge()
	# 时兔(slot 0) gem=purple → species 4。
	level.skills.on_step({"account": {"by_species": {4: 5}}})
	assert_eq(level.skills._skill_charge[0], 5.0, "purple clears charge the time rabbit slot via the StepReport account")
	level.free()


# 充能满需求是被减半的(快充): SKILL_CHARGE_REQ = 10。
func test_skill_charge_requirement_is_halved() -> void:
	var level := _prepare_level_scene()
	assert_eq(level.skills.get("SKILL_CHARGE_REQ"), 10.0, "pet skill progress fills twice as fast via a halved charge requirement")
	level.free()


# 充能封顶不溢出 SKILL_CHARGE_REQ。
func test_charge_clamps_to_requirement() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	level.skills.reset_charge()
	level.skills.charge({4: 999})
	assert_eq(level.skills._skill_charge[0], 10.0, "charge clamps at the full requirement and does not overflow")
	level.free()


# 按钮 pressed → skills 发 skill_pressed(idx) 信号(level 据此走 dispatch)。
func test_button_press_emits_skill_pressed_signal() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	var got := {"idx": -1}
	level.skills.skill_pressed.connect(func(i: int): got["idx"] = i)
	level.skills.call("_on_skill_button_pressed", 2)
	assert_eq(got["idx"], 2, "skills emits skill_pressed with the slot index for level to dispatch")
	level.free()


# 时兔头像施法显隐: casting=true 时清贴图(让活体兔子顶替), false 时复原。
func test_time_rabbit_avatar_casting_hides_and_restores_texture() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	var btn: TextureButton = level.skills._skill_btns[0]
	assert_true(btn != null, "time rabbit slot button exists")
	if btn == null:
		level.free()
		return
	assert_true(btn.texture_normal != null, "time rabbit button starts with its avatar texture")
	level.skills.set_time_rabbit_avatar_casting(true)
	assert_eq(btn.texture_normal, null, "casting hides the static avatar so the live rabbit takes over")
	level.skills.set_time_rabbit_avatar_casting(false)
	assert_true(btn.texture_normal != null, "finishing the cast restores the static avatar texture")
	level.free()


# refresh_visual: 充满→按钮可点(不禁用); 满亮。
func test_refresh_visual_enables_button_when_charged() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	# slot 2(龙宝宝, 充能型技能)充满 → 应可点、满亮。
	level.skills._skill_charge[2] = 10.0
	level.skills.refresh_visual()
	var btn: TextureButton = level.skills._skill_btns[2]
	assert_true(btn != null, "charge skill button exists")
	if btn != null:
		assert_false(btn.disabled, "a fully charged skill button is enabled")
		assert_eq(btn.modulate.a, 1.0, "a ready skill button is shown at full brightness")
	level.free()


# 时兔可点性: 有历史时 is_ready, 无历史但仍 is_clickable(可点给 peek 反馈)。
func test_time_rabbit_ready_follows_history_not_charge() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	level.skills._skill_charge[0] = 0.0
	assert_true(level.skills.is_clickable(0), "time rabbit stays clickable before history so taps can give feedback")
	assert_false(level.skills.is_ready(0), "time rabbit is not ready to actually rewind before there is history")
	level.board._push_history()
	assert_true(level.skills.is_ready(0), "time rabbit becomes ready once the board has rewind history, regardless of gem charge")
	level.free()
