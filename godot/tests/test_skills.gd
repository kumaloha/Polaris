extends "res://tests/test_lib.gd"
# P4: 技能栏子控制器(match3/skills.gd)专属行为测试。契约 A 消费者 + 契约 C 协作(头像/相框)。
# 注意: 本文件【未注册】runner.gd(主线程统一注册); 经 godot -s 直接跑或后续接入。
# 测试守则: 行为断言优先, 不做源码 contains 断言。

const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const LevelSkills := preload("res://match3/skills.gd")

const DRAGON_BABY_IDLE := "res://assets/pets/dragon_baby/frames/dragon_00.png"
const DRAGON_YOUTH_IDLE := "res://assets/pets/dragon_youth/frames/frame_001.png"


func _prepare_level_scene() -> Node:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	level.background_layer = level.get_node("BackgroundLayer")
	level.board_layer = level.get_node("BoardLayer")
	level.gem_layer = level.get_node("GemLayer")
	level.character_layer = level.get_node("CharacterLayer")
	level.ui_layer = level.get_node("UILayer")
	level.skill_bar = level.get_node("SkillBar")
	level._levels = LevelLibrary.load_file(LevelLibrary.DEFAULT_LEVELS_PATH)
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


# build() 在 skill_bar 上只渲染两只龙：左小龙、右大龙镜像。
func test_build_renders_two_dragon_avatar_buttons() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	assert_eq(_count_texture_buttons(level.skill_bar), 2, "only two dragon avatar buttons are rendered on the skill bar")
	assert_eq(String(LevelSkills.SKILLS[0].get("av", "")), DRAGON_BABY_IDLE, "left slot idles on the baby dragon first frame")
	assert_eq(String(LevelSkills.SKILLS[1].get("av", "")), DRAGON_YOUTH_IDLE, "right slot idles on the youth dragon first frame")
	var right_btn: TextureButton = level.skills._skill_btns[1]
	assert_true(right_btn != null, "right dragon slot button exists")
	if right_btn != null:
		assert_true(right_btn.scale.x < 0.0, "right dragon avatar is mirrored horizontally")
	level.free()


# 契约 A: on_step 读 report.account.by_species 给对应色技能充能。
func test_on_step_charges_skill_from_by_species() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	level.skills.reset_charge()
	# 两只龙都绑定 red → species 0。
	level.skills.on_step({"account": {"by_species": {0: 5}}})
	assert_eq(level.skills._skill_charge[0], 5.0, "red clears charge the baby dragon slot via the StepReport account")
	assert_eq(level.skills._skill_charge[1], 5.0, "red clears charge the youth dragon slot via the StepReport account")
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
	level.skills.charge({0: 999})
	assert_eq(level.skills._skill_charge[0], 10.0, "baby dragon charge clamps at the full requirement and does not overflow")
	assert_eq(level.skills._skill_charge[1], 10.0, "youth dragon charge clamps at the full requirement and does not overflow")
	level.free()


# 按钮 pressed → skills 发 skill_pressed(idx) 信号(level 据此走 dispatch)。
func test_button_press_emits_skill_pressed_signal() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	var got := {"idx": -1}
	level.skills.skill_pressed.connect(func(i: int): got["idx"] = i)
	level.skills.call("_on_skill_button_pressed", 1)
	assert_eq(got["idx"], 1, "skills emits skill_pressed with the two-dragon slot index for level to dispatch")
	level.free()


# refresh_visual: 充满→按钮可点(不禁用); 满亮。
func test_refresh_visual_enables_button_when_charged() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	level.skills._skill_charge[1] = 10.0
	level.skills.refresh_visual()
	var btn: TextureButton = level.skills._skill_btns[1]
	assert_true(btn != null, "charge skill button exists")
	if btn != null:
		assert_false(btn.disabled, "a fully charged skill button is enabled")
		assert_eq(btn.modulate.a, 1.0, "a ready skill button is shown at full brightness")
	level.free()


# 两只龙都走充能门槛；未充能不可点，满充能可点。
func test_dragon_buttons_require_charge() -> void:
	var level := _prepare_level_scene()
	level.load_level(1)
	level.skills._skill_charge[0] = 0.0
	level.skills._skill_charge[1] = 0.0
	assert_false(level.skills.is_clickable(0), "baby dragon cannot cast before it is charged")
	assert_false(level.skills.is_clickable(1), "youth dragon cannot cast before it is charged")
	level.skills._skill_charge[0] = LevelSkills.SKILL_CHARGE_REQ
	level.skills._skill_charge[1] = LevelSkills.SKILL_CHARGE_REQ
	assert_true(level.skills.is_clickable(0), "baby dragon can cast once charged")
	assert_true(level.skills.is_clickable(1), "youth dragon can cast once charged")
	level.free()
