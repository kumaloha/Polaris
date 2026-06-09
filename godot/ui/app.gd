extends Control

const CharacterData := preload("res://ui/character_data.gd")
const GameScript := preload("res://view/game.gd")
const CelestialBg := preload("res://ui/celestial_bg.gd")
const BeeRig := preload("res://ui/bee_rig.gd")
const MetaState := preload("res://meta/meta_state.gd")
const Enchants := preload("res://meta/enchants.gd")
const LevelLibrary := preload("res://core/level_library.gd")

# 占星风配色
const C_GOLD := Color("e9c97c")
const C_INK := Color("f3ecff")
const C_INK_DIM := Color("b9c4e6")

# 5 种铭文的展示(名/色/一句话效果)
const ENCHANT_INFO := {
	"moves": {"name": "步数", "color": "6db6ff", "eff": "每3格+1步(6格封顶+2)"},
	"score": {"name": "积分", "color": "f6ad36", "eff": "每格分数+5%"},
	"coins": {"name": "金币", "color": "ff9f43", "eff": "每格金币+5%"},
	"skill_uses": {"name": "技能", "color": "9d6cf0", "eff": "每6格技能多用1次"},
	"opening": {"name": "开局", "color": "ff6fb6", "eff": "3格开局直线/6格彩球"},
}
const ENCHANT_CYCLE := ["", "moves", "score", "coins", "skill_uses", "opening"]

const VIEW_W := 720.0
const VIEW_H := 1520.0

var characters: Array = []
var selected_idx := 0
var body: Control
var _wkmat: ShaderMaterial
var meta: MetaState              # Meta 进度(钱包/角色/铭文/历史)，持久化 user://save.json
var _played: Dictionary = {}     # 本会话已玩过的库索引(调度优先没玩过的)
var _cur_level := -1             # 当前对局的库索引(结束后入账)
var _home_level := -1            # 首页左右箭头选中的关(替代关卡地图页)
var _rng: RandomNumberGenerator  # 抽卡随机源
var _lib: Array = []             # 关卡库(res://levels.json)，供地图显示关数/难度


# 抠白材质(无 alpha 的白底立绘 → 透明)；全 UI 共用一份。
func _white_key_material() -> ShaderMaterial:
	if _wkmat == null:
		_wkmat = ShaderMaterial.new()
		_wkmat.shader = load("res://ui/white_key.gdshader")
	return _wkmat


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 容器不吃鼠标，让点击穿透到对局棋盘(_unhandled_input)；子按钮各自仍可点
	_fit_window_to_screen()
	characters = CharacterData.load_characters()
	if characters.is_empty():
		push_warning("No character assets found at %s" % CharacterData.MANIFEST_PATH)
	meta = MetaState.new()
	meta.load_state()
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_lib = LevelLibrary.load_file("res://levels.json")
	_sync_selected_to_equipped()
	var launch_level_idx := _launch_level_index_from_args(OS.get_cmdline_user_args(), _lib.size())
	if launch_level_idx >= 0:
		_home_level = launch_level_idx
		_show_game(launch_level_idx)
	else:
		_show_home()


func _launch_level_index_from_args(args: Array, level_count: int) -> int:
	for i in range(args.size()):
		var arg := String(args[i])
		var raw := ""
		if arg == "--level":
			if i + 1 >= args.size():
				return -1
			raw = String(args[i + 1])
		elif arg.begins_with("--level="):
			raw = arg.substr("--level=".length())
		if raw.is_empty():
			continue
		if not raw.is_valid_int():
			return -1
		var level_number := raw.to_int()
		var idx := level_number - 1
		if idx < 0:
			return -1
		if level_count > 0 and idx >= level_count:
			return -1
		return idx
	return -1


# 窗口高度贴合本机屏幕(可用区)，宽度按画布比例(9:19)推导。后续可按收集机型自适应。
func _fit_window_to_screen() -> void:
	var s := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(s)
	var h := int(usable.size.y) - 72   # 预留标题栏，避免底部被裁
	var w := int(round(float(h) * (VIEW_W / VIEW_H)))
	DisplayServer.window_set_size(Vector2i(w, h))
	DisplayServer.window_set_position(Vector2i(
		int(usable.position.x) + (int(usable.size.x) - w) / 2,
		int(usable.position.y) + 24))


# 把首页出战角色对齐到 Meta 已装备的(新玩家无装备→保持默认)
func _sync_selected_to_equipped() -> void:
	if meta == null or String(meta.equipped_skill).is_empty():
		return
	for i in characters.size():
		if String(characters[i].get("id", "")) == meta.equipped_skill:
			selected_idx = i
			return


func _clear() -> void:
	for child in get_children():
		child.queue_free()


# 高瘦画布(1520)：把本屏内容整体下移 dy 以纵向居中(跳过背景/左上返回键/底栏)。
# 各非首页屏按为 920 布的版式构建后，调用一次即可贴合高画布。
func _center_content(dy: float) -> void:
	for c in get_children():
		if not (c is Control) or c.get_script() == CelestialBg:
			continue
		var ctl := c as Control
		if ctl is Button and ctl.size.x < 80.0 and ctl.position.y < 80.0:
			continue   # 左上角圆形返回键，保持在顶
		if ctl.position.y >= VIEW_H - 100.0:
			continue   # 底部导航栏
		ctl.position.y += dy


func _show_home() -> void:
	_clear()
	_add_gradient_background(true)   # 带魔法阵的占星背景(阵心默认 y600，对到萌宠)
	var hero := _selected_character()

	# 顶部：玩家牌(左,带等级条) + 资源链(右) + 设置齿轮(右上角)
	_add_avatar_chip(hero, Vector2(18, 42))
	_add_res_chips()
	var gear := _round_button("⚙", Rect2(662, 96, 46, 46))
	gear.add_theme_font_size_override("font_size", 22)
	gear.pressed.connect(Callable(self, "_show_settings"))
	add_child(gear)

	# 侧边徽章(任务/召唤)
	_add_side_badge("任务", Color("ff7eb0"), Vector2(20, 178), "3", Callable(self, "_show_placeholder").bind("每日任务", "每日任务 + 签到 · 领碎片与水晶"))
	var summon := _add_side_badge("召唤", Color("b88cf5"), Vector2(632, 178), "!", Callable(self, "_show_gacha"))
	summon.tooltip_text = "召唤"

	var n := _lib.size() if _lib.size() > 0 else 12
	var maxlv := _current_level(n)           # 最远解锁关
	if _home_level < 0:
		_home_level = maxlv
	_home_level = clampi(_home_level, 0, n - 1)
	var locked := _home_level > maxlv        # 浏览到尚未解锁的关

	# 关卡牌(萌宠上方)
	var lvlpill := _dark_panel(Rect2(296, 348, 128, 40), 999, C_GOLD, 1)
	add_child(lvlpill)
	lvlpill.add_child(_inner_label("第 %d 关" % (_home_level + 1), Rect2(0, 0, 128, 40), 18, C_GOLD))

	# 英雄台：魔法阵(背景已画) + 萌宠立绘(画布中部)
	_add_character_art(hero, Rect2(170, 402, 380, 400), false)
	_add_hero_ribbon(hero, Vector2(360, 812))

	# 左右箭头选关(替代关卡地图页)
	var prev := _arrow_button("‹", 16.0, _home_level > 0)
	if not prev.disabled:
		prev.pressed.connect(Callable(self, "_home_pick").bind(-1))
	add_child(prev)
	var nextb := _arrow_button("›", 640.0, _home_level < n - 1)
	if not nextb.disabled:
		nextb.pressed.connect(Callable(self, "_home_pick").bind(1))
	add_child(nextb)

	# 关卡目标预览(对齐 homepage.html 的 collect-items 面板)
	_add_home_objective(_home_level, Rect2(130, 918, 460, 168))

	# START：金色发光主按钮 → 直接打选中的关(未解锁则禁用)
	var start := _gold_button(
		"开 始" if not locked else "未 解 锁",
		("第 %d 关 · 进入" % (_home_level + 1)) if not locked else "通关前面的关来解锁",
		Rect2(228, 1168, 264, 96))
	if not locked:
		start.pressed.connect(Callable(self, "_show_game").bind(_home_level))
	else:
		start.disabled = true
	add_child(start)

	# 底部导航(首页高亮"角色"，对齐 homepage.html 的 Characters tab)
	_add_bottom_nav("character")


# 首页左右箭头切换选中关(clamp 在 _show_home 内)
func _home_pick(delta: int) -> void:
	_home_level += delta
	_show_home()


# 选关箭头按钮：浅蓝填充 + 粗金边 + 大箭头，醒目可见。
func _arrow_button(text: String, x: float, enabled: bool) -> Button:
	var b := Button.new()
	b.position = Vector2(x, 540)
	b.size = Vector2(64, 116)
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 48)
	b.add_theme_color_override("font_color", C_GOLD)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.18))
	b.add_theme_stylebox_override("normal", _style(Color(0.20, 0.30, 0.56, 0.90), 26, C_GOLD, 3))
	b.add_theme_stylebox_override("hover", _style(Color(0.28, 0.40, 0.68, 0.95), 26, Color("fff1c4"), 3))
	b.add_theme_stylebox_override("pressed", _style(Color(0.14, 0.22, 0.44, 0.95), 26, C_GOLD, 3))
	b.add_theme_stylebox_override("disabled", _style(Color(0.12, 0.16, 0.30, 0.30), 26, Color(1, 1, 1, 0.12), 1))
	b.disabled = not enabled
	return b


# 首页关卡目标预览(对齐 homepage.html)：关号·难度 + 收集/奖励三格
func _add_home_objective(level_idx: int, rect: Rect2) -> void:
	var panel := _dark_panel(rect, 24, C_GOLD, 1)
	add_child(panel)
	var diff := "普通"
	if level_idx >= 0 and level_idx < _lib.size():
		diff = "挖矿关" if bool(_lib[level_idx].get("is_scrolling", false)) else String(_lib[level_idx].get("difficulty", "普通"))
	panel.add_child(_inner_label("第 %d 关 · %s" % [level_idx + 1, diff], Rect2(0, 16, rect.size.x, 26), 18, C_GOLD))
	panel.add_child(_inner_label("收集星辉 · 点亮魔法小径", Rect2(0, 46, rect.size.x, 22), 14, C_INK_DIM))
	var chips := [[Color("ff9ec7"), "碎片", "×8"], [Color("c79bff"), "水晶", "×1"], [C_GOLD, "星辉", "★3"]]
	var cw := 120.0
	var gap := (rect.size.x - 3.0 * cw) / 4.0
	for i in 3:
		var ci: Array = chips[i]
		var chip := Panel.new()
		chip.position = Vector2(gap + i * (cw + gap), 86)
		chip.size = Vector2(cw, 62)
		chip.add_theme_stylebox_override("panel", _style(Color(0.06, 0.10, 0.22, 0.6), 16, Color(1, 1, 1, 0.12), 1))
		panel.add_child(chip)
		var dot := Panel.new()
		dot.position = Vector2(12, 18)
		dot.size = Vector2(26, 26)
		dot.add_theme_stylebox_override("panel", _style(ci[0], 999, Color(1, 1, 1, 0.5), 1))
		chip.add_child(dot)
		chip.add_child(_inner_label(String(ci[1]), Rect2(44, 8, cw - 48, 20), 13, C_INK_DIM, HORIZONTAL_ALIGNMENT_LEFT))
		chip.add_child(_inner_label(String(ci[2]), Rect2(44, 28, cw - 48, 26), 17, C_INK, HORIZONTAL_ALIGNMENT_LEFT))


func _show_character() -> void:
	_clear()
	_add_gradient_background()

	var back := _round_button("‹", Rect2(28, 48, 54, 54))
	back.pressed.connect(Callable(self, "_show_home"))
	add_child(back)

	var title := _label("角色", Rect2(105, 52, 260, 46), 34, C_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	title.add_theme_font_size_override("font_size", 34)
	add_child(title)

	var shards := _glass_panel(Rect2(500, 52, 170, 42), Color(1, 1, 1, 0.72))
	add_child(shards)
	shards.add_child(_inner_label("碎片 24", Rect2(0, 0, 170, 42), 18, Color("7a3fe0")))

	var hero := _selected_character()
	_add_character_art(hero, Rect2(125, 105, 470, 420), false)
	_add_character_plate(hero, Vector2(86, 500), Vector2(548, 92))

	var skill := _glass_panel(Rect2(44, 620, 632, 112), Color(1, 1, 1, 0.80))
	add_child(skill)
	var skill_name := _skill_name(hero)
	skill.add_child(_inner_label(skill_name, Rect2(24, 14, 340, 28), 24, Color("2c2350"), HORIZONTAL_ALIGNMENT_LEFT))
	skill.add_child(_inner_label(_skill_desc(hero), Rect2(24, 48, 580, 48), 17, Color("4a3d7a"), HORIZONTAL_ALIGNMENT_LEFT))

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 10)
	strip.custom_minimum_size = Vector2(max(644, characters.size() * 108), 112)
	var strip_scroll := ScrollContainer.new()
	strip_scroll.position = Vector2(38, 760)
	strip_scroll.size = Vector2(644, 112)
	strip_scroll.clip_contents = true
	add_child(strip_scroll)
	strip_scroll.add_child(strip)
	for i in characters.size():
		strip.add_child(_character_thumb(i))

	var equip_text := "门面角色" if not bool(hero.get("playable", true)) else "设为出战"
	var equip := _button(equip_text, Rect2(54, 862, 300, 50), Color("9d6cf0"), Color("7a3fe0"))
	equip.disabled = not bool(hero.get("playable", true))
	if not equip.disabled:
		equip.pressed.connect(Callable(self, "_equip_current"))
	add_child(equip)
	var runes := _button("配铭文", Rect2(366, 862, 300, 50), Color("ffd874"), Color("f6ad36"))
	runes.add_theme_color_override("font_color", Color("4a2f00"))
	runes.pressed.connect(Callable(self, "_show_enchants"))
	add_child(runes)
	_center_content(280)


func _show_game(level_idx: int = -1) -> void:
	_clear()
	var game := Node2D.new()
	game.name = "Game"
	game.set_script(GameScript)
	add_child(game)   # _ready 同步：建 HUD/tiles、读关卡库、_new_game(默认关)
	game.game_over.connect(Callable(self, "_on_game_over"))   # 对局结束→结算屏
	# 选关：地图指定(level_idx>=0) 优先；否则心流调度推荐。再喂 loadout(技能+铭文)重开。
	_cur_level = -1
	if meta != null:
		var lib: Array = game.algo_levels
		var idx := level_idx if level_idx >= 0 else meta.recommend_next(lib, _played)
		if idx >= 0 and idx < lib.size():
			game.demo_idx = idx
			_cur_level = idx
		game.loadout = meta.loadout()
		game.equipped_skill = String(meta.equipped_skill)
		game._new_game()
	else:
		game.set_skill(String(_selected_character().get("id", "")))

	var back := _round_button("‹", Rect2(18, 18, 48, 48))
	back.z_index = 50
	back.pressed.connect(Callable(self, "_exit_game"))
	add_child(back)


# 中途返回(未结束=放弃本局，不入账)。结束的入账走 _on_game_over。
func _exit_game() -> void:
	_show_home()


# 对局结束(game_over 信号)：结果入账 Meta + 存档 + 记入已玩，弹结算屏。
func _on_game_over(result: Dictionary) -> void:
	if meta != null:
		meta.bank_result(result)
		if _cur_level >= 0:
			_played[_cur_level] = true
			if bool(result.get("won", false)):
				meta.record_clear(_cur_level, int(result.get("stars", 0)))   # 关卡进度
		meta.save()
		if bool(result.get("won", false)):
			_home_level = -1   # 过关→下次回首页重置到最新解锁关(自动指向下一关)
	_show_result(result)


# 结算屏(占星风)：星级 + 最终得分 + 奖励(碎片/水晶) + 下一关/再玩/回首页。
func _show_result(result: Dictionary) -> void:
	_clear()
	_add_gradient_background(true)
	var won: bool = bool(result.get("won", false))
	var stars: int = int(result.get("stars", 0))
	var score: int = int(result.get("score", 0))
	var frags: int = int(result.get("fragments", 0))
	var crystals_gained: int = 1 if won else 0   # 与 MetaState.bank_result 一致：过关 +1 水晶

	# 标题
	var en := _label("LEVEL CLEAR" if won else "LEVEL FAILED", Rect2(0, 96, VIEW_W, 28), 16, C_GOLD)
	add_child(en)
	var zh := _label("过 关 !" if won else "未 通 关", Rect2(0, 126, VIEW_W, 64), 46, C_INK)
	add_child(zh)

	# 星级(三颗，亮=已得)
	var star_y := 214
	for i in 3:
		var on: bool = i < stars
		var big: bool = i == 1
		var sz := 76 if big else 58
		var sx := VIEW_W * 0.5 + (i - 1) * 86 - sz * 0.5
		var sy := star_y + (0 if big else 12)
		var st := _label("★", Rect2(sx, sy, sz, sz), sz, C_GOLD if on else Color(1, 1, 1, 0.16))
		add_child(st)

	# 最终得分
	add_child(_label("最终得分", Rect2(0, 322, VIEW_W, 24), 16, C_INK_DIM))
	var sc := _label(_fmt(score), Rect2(0, 346, VIEW_W, 64), 52, C_GOLD)
	add_child(sc)

	# 奖励面板
	var panel := _dark_panel(Rect2(150, 440, 420, 120), 24, C_GOLD, 1)
	add_child(panel)
	panel.add_child(_inner_label("本关奖励", Rect2(0, 12, 420, 24), 16, C_GOLD))
	if won:
		_reward_chip(panel, Color("ff9ec7"), "碎片", frags, Rect2(40, 48, 160, 56))
		_reward_chip(panel, Color("c79bff"), "水晶", crystals_gained, Rect2(220, 48, 160, 56))
	else:
		panel.add_child(_inner_label("差一点点，再来一次～", Rect2(0, 56, 420, 28), 18, C_INK_DIM))

	# 按钮
	var primary_text := "下一关 ▸" if won else "再玩一次"
	var primary := _gold_button(primary_text, "体力 1", Rect2(228, 626, 264, 84))
	if won:
		primary.pressed.connect(Callable(self, "_show_home"))                      # 过关→回首页(箭头已指向下一关)
	else:
		primary.pressed.connect(Callable(self, "_show_game").bind(_cur_level))     # 失败→重开本关
	add_child(primary)
	var homebtn := _round_button("‹", Rect2(18, 18, 48, 48))
	homebtn.z_index = 50
	homebtn.pressed.connect(Callable(self, "_show_home"))
	add_child(homebtn)
	var home_wide := _button("回首页", Rect2(270, 728, 180, 52), Color("9d6cf0"), Color("7a3fe0"))
	home_wide.pressed.connect(Callable(self, "_show_home"))
	add_child(home_wide)
	_center_content(320)


func _reward_chip(parent: Control, icon_color: Color, label: String, n: int, rect: Rect2) -> void:
	var chip := Panel.new()
	chip.position = rect.position
	chip.size = rect.size
	chip.add_theme_stylebox_override("panel", _style(Color(0.06, 0.10, 0.22, 0.6), 16, Color(1, 1, 1, 0.12), 1))
	parent.add_child(chip)
	var dot := Panel.new()
	dot.position = Vector2(12, (rect.size.y - 26) * 0.5)
	dot.size = Vector2(26, 26)
	dot.add_theme_stylebox_override("panel", _style(icon_color, 999, Color(1, 1, 1, 0.5), 1))
	chip.add_child(dot)
	chip.add_child(_inner_label(label, Rect2(46, 8, rect.size.x - 50, 22), 14, C_INK_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	chip.add_child(_inner_label("×%d" % n, Rect2(46, 28, rect.size.x - 50, 24), 20, C_INK, HORIZONTAL_ALIGNMENT_LEFT))


func _selected_character() -> Dictionary:
	if characters.is_empty():
		return {
			"id": "missing",
			"name": "Missing",
			"subtitle": "No assets loaded",
			"accent": "#8b54e8",
			"portrait": "",
			"card": "",
		}
	return characters[clamp(selected_idx, 0, characters.size() - 1)]


func _add_gradient_background(show_circle := false) -> void:
	var bg := CelestialBg.new()
	bg.show_circle = show_circle
	add_child(bg)


# 占星玻璃面板(深蓝底+金边)
func _dark_panel(rect: Rect2, radius: int, border: Color, bw: int) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _style(Color(0.09, 0.14, 0.30, 0.80), radius, border, bw))
	return p


func _add_avatar_chip(hero: Dictionary, pos: Vector2) -> void:
	var chip := _dark_panel(Rect2(pos, Vector2(224, 62)), 999, C_GOLD, 1)
	add_child(chip)
	var av := TextureRect.new()
	av.position = Vector2(6, 6)
	av.size = Vector2(50, 50)
	av.texture = _load_texture(String(hero.get("portrait", "")))
	av.material = _white_key_material()
	av.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(av)
	chip.add_child(_inner_label("星语者", Rect2(66, 8, 150, 22), 16, C_INK, HORIZONTAL_ALIGNMENT_LEFT))
	chip.add_child(_inner_label("Lv. 27", Rect2(150, 8, 66, 22), 13, C_GOLD, HORIZONTAL_ALIGNMENT_RIGHT))
	var track := Panel.new()   # 等级进度条
	track.position = Vector2(66, 38)
	track.size = Vector2(150, 9)
	track.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.14), 999, Color(1, 1, 1, 0.0), 0))
	chip.add_child(track)
	var fill := Panel.new()
	fill.position = Vector2(0, 0)
	fill.size = Vector2(150 * 0.62, 9)
	fill.add_theme_stylebox_override("panel", _style(C_GOLD, 999, Color(1, 1, 1, 0.0), 0))
	track.add_child(fill)


func _add_res_chips() -> void:
	var coins: int = meta.coins if meta != null else 0
	var crystals: int = meta.crystals if meta != null else 0
	var frags: int = meta.fragments if meta != null else 0
	_res_chip(C_GOLD, _fmt(coins), Rect2(444, 40, 92, 34))           # 金币
	_res_chip(Color("c79bff"), str(crystals), Rect2(542, 40, 68, 34))  # 水晶
	_res_chip(Color("ff9ec7"), str(frags), Rect2(616, 40, 80, 34))     # 碎片


func _fmt(n: int) -> String:
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


func _res_chip(icon_color: Color, value: String, rect: Rect2) -> void:
	var chip := _dark_panel(rect, 999, Color(1, 1, 1, 0.20), 1)
	add_child(chip)
	var dot := Panel.new()
	dot.position = Vector2(5, (rect.size.y - 22) * 0.5)
	dot.size = Vector2(22, 22)
	dot.add_theme_stylebox_override("panel", _style(icon_color, 999, Color(1, 1, 1, 0.55), 1))
	chip.add_child(dot)
	chip.add_child(_inner_label(value, Rect2(31, 0, rect.size.x - 36, rect.size.y), 15, C_INK, HORIZONTAL_ALIGNMENT_LEFT))


func _add_side_badge(label: String, color: Color, pos: Vector2, badge: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.position = pos
	btn.size = Vector2(68, 68)
	btn.flat = true
	btn.add_theme_stylebox_override("normal", _style(color.darkened(0.12), 22, C_GOLD, 2))
	btn.add_theme_stylebox_override("hover", _style(color, 22, C_GOLD, 2))
	btn.add_theme_stylebox_override("pressed", _style(color.darkened(0.22), 22, C_GOLD, 2))
	if cb.is_valid():
		btn.pressed.connect(cb)
	add_child(btn)
	btn.add_child(_inner_label(label, Rect2(0, 20, 68, 28), 17, Color.WHITE))
	if badge != "":
		var b := Panel.new()
		b.position = Vector2(48, -6)
		b.size = Vector2(26, 26)
		b.add_theme_stylebox_override("panel", _style(Color("ff5577"), 999, Color.WHITE, 2))
		btn.add_child(b)
		b.add_child(_inner_label(badge, Rect2(0, 0, 26, 26), 14, Color.WHITE))
	return btn


func _add_hero_ribbon(hero: Dictionary, center: Vector2) -> void:
	var w := 210.0
	var ribbon := Panel.new()
	ribbon.position = Vector2(center.x - w * 0.5, center.y)
	ribbon.size = Vector2(w, 46)
	ribbon.add_theme_stylebox_override("panel", _style(Color(0.12, 0.10, 0.24, 0.86), 999, C_GOLD, 2))
	add_child(ribbon)
	var dot := Panel.new()
	dot.position = Vector2(18, 17)
	dot.size = Vector2(12, 12)
	dot.add_theme_stylebox_override("panel", _style(Color("7dffb0"), 999, Color.WHITE, 1))
	ribbon.add_child(dot)
	ribbon.add_child(_inner_label(String(hero.get("name", "角色")), Rect2(0, 0, w, 46), 22, C_GOLD))


func _gold_button(text: String, sub: String, rect: Rect2) -> Button:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.text = ""
	btn.add_theme_stylebox_override("normal", _gold_style(0.0))
	btn.add_theme_stylebox_override("hover", _gold_style(0.08))
	btn.add_theme_stylebox_override("pressed", _gold_style(-0.08))
	btn.add_child(_inner_label(text, Rect2(0, 14, rect.size.x, 42), 33, Color("4a2f00")))
	btn.add_child(_inner_label(sub, Rect2(0, 56, rect.size.x, 24), 14, Color("70491a")))
	return btn


func _gold_style(shift: float) -> StyleBoxFlat:
	var base := Color("f1c965")
	var s := _style(base.lightened(shift) if shift >= 0.0 else base.darkened(-shift), 999, Color("fff1c4"), 3)
	s.shadow_color = Color(0.96, 0.78, 0.32, 0.55)
	s.shadow_size = 22
	s.shadow_offset = Vector2(0, 6)
	return s


func _add_bottom_nav(active: String) -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, VIEW_H - 100)
	bar.size = Vector2(VIEW_W, 100)
	bar.add_theme_stylebox_override("panel", _style(Color(0.07, 0.11, 0.24, 0.94), 30, Color(1, 1, 1, 0.10), 1))
	add_child(bar)
	# 图标+下方标签(对齐 homepage.html 的 tab 样式)；高亮态加金色圆底。
	var items := [
		["角色", "character", "✦", Callable(self, "_show_character")],
		["铭文", "enchant", "◆", Callable(self, "_show_enchants")],
		["成就", "achievement", "★", Callable(self, "_show_placeholder").bind("成就", "解锁里程碑 · 凭实力达成,不卖数值")],
		["商店", "shop", "❖", Callable(self, "_show_placeholder").bind("商店", "皮肤 + 水晶 · 纯外观,绝不卖加步数等强度道具")],
	]
	var n := items.size()
	var slot := VIEW_W / float(n)
	for i in n:
		var it: Array = items[i]
		var is_active: bool = String(it[1]) == active
		var btn := Button.new()
		btn.position = Vector2(slot * i, VIEW_H - 100)
		btn.size = Vector2(slot, 100)
		btn.flat = true
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.05), 18, Color(1, 1, 1, 0), 0))
		btn.add_theme_stylebox_override("pressed", _style(Color(1, 1, 1, 0.10), 18, Color(1, 1, 1, 0), 0))
		var cb: Callable = it[3]
		if cb.is_valid():
			btn.pressed.connect(cb)
		add_child(btn)
		if is_active:   # 高亮态：图标金色圆底
			var halo := Panel.new()
			halo.position = Vector2(slot * 0.5 - 27, 12)
			halo.size = Vector2(54, 54)
			halo.add_theme_stylebox_override("panel", _style(Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.18), 999, C_GOLD, 2))
			halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(halo)
		var icol: Color = C_GOLD if is_active else Color(0.74, 0.80, 0.96, 0.9)
		btn.add_child(_inner_label(String(it[2]), Rect2(0, 14, slot, 50), 28, icol))
		btn.add_child(_inner_label(String(it[0]), Rect2(0, 66, slot, 26), 15, C_GOLD if is_active else C_INK_DIM))


func _add_character_art(character: Dictionary, rect: Rect2, use_card: bool) -> void:
	if not use_card and BeeRig.supports(character):
		var rig := BeeRig.new()
		rig.position = rect.position
		rig.setup(character, rect.size)
		add_child(rig)
		return
	var tex_path := String(character.get("card" if use_card else "portrait", ""))
	var art := TextureRect.new()
	art.position = rect.position
	art.size = rect.size
	art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = _load_texture(tex_path)
	art.material = _white_key_material()   # 抠白底
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)


func _add_character_plate(character: Dictionary, pos: Vector2, size: Vector2) -> void:
	var accent := Color(String(character.get("accent", "#8b54e8")))
	var plate := _glass_panel(Rect2(pos, size), Color(1, 1, 1, 0.84))
	add_child(plate)
	var name := String(character.get("name", "Character"))
	var subtitle := String(character.get("subtitle", ""))
	var title := _inner_label(name, Rect2(0, 6, size.x, 38), 26, accent)
	plate.add_child(title)
	plate.add_child(_inner_label(subtitle, Rect2(0, 46, size.x, 30), 15, Color("6f63a0")))


func _character_thumb(index: int) -> Button:
	var character: Dictionary = characters[index]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(98, 108)
	btn.text = ""
	btn.flat = true
	btn.pressed.connect(Callable(self, "_select_character").bind(index))
	btn.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.62), 22, Color("ffffff"), 1))
	btn.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.80), 22, Color("ffffff"), 1))
	btn.add_theme_stylebox_override("pressed", _style(Color("e7defe"), 22, Color("ffffff"), 1))
	if index == selected_idx:
		btn.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.95), 22, Color(String(character.get("accent", "#8b54e8"))), 3))

	var art := TextureRect.new()
	art.position = Vector2(8, 5)
	art.size = Vector2(82, 70)
	art.texture = _load_texture(String(character.get("portrait", "")))
	art.material = _white_key_material()
	art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(art)

	var name := Label.new()
	name.position = Vector2(4, 77)
	name.size = Vector2(90, 24)
	name.text = String(character.get("name", ""))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 11)
	name.add_theme_color_override("font_color", Color("2c2350"))
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name)
	return btn


func _select_character(index: int) -> void:
	selected_idx = index
	_show_character()


# 设为出战：写入 Meta 装备 + 存档，回首页(首页/对局都会用这个角色技能)
func _equip_current() -> void:
	var hero := _selected_character()
	if meta != null and bool(hero.get("playable", true)):
		meta.equipped_skill = String(hero.get("id", ""))
		meta.save()
	_show_home()


func _char_by_id(id: String) -> Dictionary:
	for c in characters:
		if String(c.get("id", "")) == id:
			return c
	return {}


# 召唤屏(占星祭坛)：首抽保底借贷横幅 + 单抽(水晶1)/十连(水晶10)。
func _show_gacha() -> void:
	_clear()
	_add_gradient_background(true)
	var back := _round_button("‹", Rect2(18, 18, 48, 48))
	back.z_index = 50
	back.pressed.connect(Callable(self, "_show_home"))
	add_child(back)
	add_child(_label("魔导师召唤", Rect2(0, 32, VIEW_W, 40), 26, C_GOLD))
	var cz: int = meta.crystals if meta != null else 0
	_res_chip(Color("c79bff"), "水晶 %d" % cz, Rect2(470, 40, 226, 36))
	# 祭坛中央：一只萌宠浮于阵心
	_add_character_art(_selected_character(), Rect2(206, 252, 308, 318), false)
	# 首抽保底横幅(仅当还没角色时)
	if meta != null and meta.owned.is_empty():
		var banner := _dark_panel(Rect2(168, 214, 384, 42), 999, C_GOLD, 2)
		add_child(banner)
		banner.add_child(_inner_label("首次召唤必得「借贷」", Rect2(0, 0, 384, 42), 17, C_GOLD))
	# 召唤按钮
	var single := _gold_button("单次召唤", "水晶 1", Rect2(96, 690, 240, 84))
	single.pressed.connect(Callable(self, "_do_pull").bind(1))
	add_child(single)
	var ten := _gold_button("十连召唤", "水晶 10", Rect2(384, 690, 240, 84))
	ten.pressed.connect(Callable(self, "_do_pull").bind(10))
	add_child(ten)
	add_child(_label("高分对局可获得魔法水晶 · 重复转碎片", Rect2(0, 788, VIEW_W, 24), 14, C_INK_DIM))
	_center_content(320)


func _do_pull(n: int) -> void:
	if meta == null or meta.crystals < n:
		return   # 水晶不足：按钮无效(简版)
	var results := []
	for i in n:
		var r := meta.do_gacha(_rng, 1)
		if r.has("error"):
			break
		results.append(r)
	meta.save()
	if not results.is_empty():
		_show_gacha_reveal(results)


# 召唤结果：单抽=大卡，多抽=5列网格。NEW=新精灵；重复→转 +20 碎片。
func _show_gacha_reveal(results: Array) -> void:
	_clear()
	_add_gradient_background(true)
	add_child(_label("获得精灵!" if results.size() == 1 else "召唤结果", Rect2(0, 66, VIEW_W, 40), 26, C_GOLD))
	if results.size() == 1:
		var r: Dictionary = results[0]
		var c := _char_by_id(String(r.get("id", "")))
		_add_character_art(c, Rect2(196, 168, 328, 330), false)
		var plate := _dark_panel(Rect2(170, 504, 380, 112), 22, C_GOLD, 2)
		add_child(plate)
		plate.add_child(_inner_label(String(c.get("name", "?")), Rect2(0, 12, 380, 30), 24, C_GOLD))
		plate.add_child(_inner_label(_skill_name(c), Rect2(0, 46, 380, 24), 16, C_INK))
		plate.add_child(_inner_label("重复 · 转 +20 碎片" if bool(r.get("dupe", false)) else "全新精灵!", Rect2(0, 76, 380, 24), 14, C_INK_DIM))
	else:
		var cols := 5
		var cw := 124.0
		var ch := 148.0
		var gx := (VIEW_W - cols * cw) / (cols + 1)
		for i in results.size():
			var r: Dictionary = results[i]
			var c := _char_by_id(String(r.get("id", "")))
			var col := i % cols
			var row := i / cols
			var card := _dark_panel(Rect2(gx + col * (cw + gx), 168.0 + row * (ch + 16), cw, ch), 16, C_GOLD if not bool(r.get("dupe", false)) else Color(1, 1, 1, 0.22), 2)
			add_child(card)
			var art := TextureRect.new()
			art.position = Vector2(8, 6)
			art.size = Vector2(cw - 16, 102)
			art.texture = _load_texture(String(c.get("portrait", "")))
			art.material = _white_key_material()
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(art)
			card.add_child(_inner_label(String(c.get("name", "?")), Rect2(0, 110, cw, 20), 13, C_GOLD))
			card.add_child(_inner_label("重复" if bool(r.get("dupe", false)) else "NEW", Rect2(0, 128, cw, 16), 11, C_INK_DIM))
	var ok := _gold_button("确定", "", Rect2(228, 704, 264, 78))
	ok.pressed.connect(Callable(self, "_show_gacha"))
	add_child(ok)
	_center_content(320)


# 铭文屏：9 格碎片编辑器(全局页)。点格子循环切 5 种;实时显示聚合加成。
func _show_enchants() -> void:
	_clear()
	_add_gradient_background(false)
	var back := _round_button("‹", Rect2(18, 18, 48, 48))
	back.z_index = 50
	back.pressed.connect(Callable(self, "_show_character"))
	add_child(back)
	add_child(_label("铭文 · 9 格碎片", Rect2(0, 30, VIEW_W, 40), 26, C_GOLD))
	var fz: int = meta.fragments if meta != null else 0
	_res_chip(Color("ff9ec7"), "碎片 %d" % fz, Rect2(486, 40, 210, 36))
	add_child(_label("9 格自由分配 · 堆够格数才出效果 · 装了这个就装不了那个", Rect2(0, 84, VIEW_W, 22), 14, C_INK_DIM))

	var page := _enchant_page()
	var cell := 188.0
	var ch := 130.0
	var gap := 16.0
	var gx := (VIEW_W - 3.0 * cell - 2.0 * gap) / 2.0
	for i in 9:
		var col := i % 3
		var row := i / 3
		_enchant_slot(i, String(page[i]), Rect2(gx + col * (cell + gap), 148.0 + row * (ch + gap), cell, ch))

	var agg := Enchants.aggregate(page)
	var op := int(agg.get("opening_special", 0))
	var op_txt := "彩球" if op == 4 else ("直线" if op == 1 else "无")
	var summary := "步数+%d    分×%.2f    币×%.2f    技能+%d次    开局:%s" % [
		int(agg.get("extra_moves", 0)), float(agg.get("score_mult", 1.0)), float(agg.get("coin_mult", 1.0)),
		int(agg.get("extra_skill_uses", 0)), op_txt]
	var ap := _dark_panel(Rect2(60, 588, 600, 70), 18, C_GOLD, 1)
	add_child(ap)
	ap.add_child(_inner_label("当前加成", Rect2(0, 8, 600, 22), 14, C_GOLD))
	ap.add_child(_inner_label(summary, Rect2(0, 34, 600, 26), 16, C_INK))

	var clear := _button("清空", Rect2(270, 674, 180, 52), Color("9d6cf0"), Color("7a3fe0"))
	clear.pressed.connect(Callable(self, "_clear_enchants"))
	add_child(clear)
	add_child(_label("点格子循环切换 5 种铭文", Rect2(0, 738, VIEW_W, 22), 13, C_INK_DIM))
	_center_content(300)


func _enchant_page() -> Array:
	if meta == null:
		return ["", "", "", "", "", "", "", "", ""]
	while meta.enchant_page.size() < 9:
		meta.enchant_page.append("")
	return meta.enchant_page


func _enchant_slot(idx: int, type: String, rect: Rect2) -> void:
	var has: bool = ENCHANT_INFO.has(type)
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.flat = true
	var fill: Color = Color(ENCHANT_INFO[type]["color"]) if has else Color(0.10, 0.15, 0.30, 0.6)
	var border: Color = C_GOLD if has else Color(1, 1, 1, 0.18)
	btn.add_theme_stylebox_override("normal", _style(fill, 18, border, 2))
	btn.add_theme_stylebox_override("hover", _style(fill.lightened(0.10), 18, C_GOLD, 2))
	btn.add_theme_stylebox_override("pressed", _style(fill.darkened(0.10), 18, C_GOLD, 2))
	btn.pressed.connect(Callable(self, "_cycle_enchant").bind(idx))
	add_child(btn)
	if has:
		btn.add_child(_inner_label(String(ENCHANT_INFO[type]["name"]), Rect2(0, 26, rect.size.x, 32), 25, Color("2a1c00")))
		btn.add_child(_inner_label(String(ENCHANT_INFO[type]["eff"]), Rect2(8, 78, rect.size.x - 16, 36), 12, Color(0.22, 0.16, 0.0, 0.85)))
	else:
		btn.add_child(_inner_label("+", Rect2(0, 36, rect.size.x, 44), 40, Color(1, 1, 1, 0.30)))


func _cycle_enchant(idx: int) -> void:
	if meta == null:
		return
	var page := _enchant_page()
	var cur := ENCHANT_CYCLE.find(String(page[idx]))
	page[idx] = ENCHANT_CYCLE[(maxi(cur, 0) + 1) % ENCHANT_CYCLE.size()]
	meta.save()
	_show_enchants()


func _clear_enchants() -> void:
	if meta == null:
		return
	meta.enchant_page = ["", "", "", "", "", "", "", "", ""]
	meta.save()
	_show_enchants()


func _current_level(n: int) -> int:
	if meta == null:
		return 0
	for i in n:
		if not meta.level_stars.has(str(i)):
			return i
	return n - 1   # 全过了 → 停在最后一关


# 占位屏(即将开放)：商店/排行/任务用，含底部导航可继续切换。
func _show_placeholder(title: String, subtitle: String) -> void:
	_clear()
	_add_gradient_background(true)
	var back := _round_button("‹", Rect2(18, 18, 48, 48))
	back.z_index = 50
	back.pressed.connect(Callable(self, "_show_home"))
	add_child(back)
	add_child(_label(title, Rect2(0, 32, VIEW_W, 40), 26, C_GOLD))
	add_child(_label("✦", Rect2(0, 366, VIEW_W, 70), 60, C_GOLD))
	add_child(_label("即将开放", Rect2(0, 448, VIEW_W, 40), 28, C_INK))
	add_child(_label(subtitle, Rect2(50, 498, VIEW_W - 100, 48), 16, C_INK_DIM))
	var key := "shop" if title.begins_with("商店") else ("achievement" if title.begins_with("成就") else "")
	_center_content(360)
	_add_bottom_nav(key)


# 设置屏：音乐/音效偏好(持久化) + 语言(暂中文) + 版本 + 清除存档。
func _show_settings() -> void:
	_clear()
	_add_gradient_background(false)
	var back := _round_button("‹", Rect2(18, 18, 48, 48))
	back.z_index = 50
	back.pressed.connect(Callable(self, "_show_home"))
	add_child(back)
	add_child(_label("设置", Rect2(0, 32, VIEW_W, 40), 26, C_GOLD))
	_setting_row("音乐", "music", 168.0)
	_setting_row("音效", "sfx", 248.0)
	var lang := _dark_panel(Rect2(80, 328, 560, 64), 16, Color(1, 1, 1, 0.12), 1)
	add_child(lang)
	lang.add_child(_inner_label("语言", Rect2(22, 0, 200, 64), 19, C_INK, HORIZONTAL_ALIGNMENT_LEFT))
	lang.add_child(_inner_label("中文(英文待接入)", Rect2(0, 0, 538, 64), 16, C_INK_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	add_child(_label("魔法消除 · 开发版 v0.1", Rect2(0, 432, VIEW_W, 26), 15, C_INK_DIM))
	var wipe := _button("清除存档", Rect2(210, 512, 300, 56), Color("ff8a8a"), Color("e0556b"))
	wipe.pressed.connect(Callable(self, "_confirm_wipe"))
	add_child(wipe)
	_center_content(300)
	_add_bottom_nav("settings")


func _setting_row(label: String, key: String, y: float) -> void:
	var row := _dark_panel(Rect2(80, y, 560, 64), 16, Color(1, 1, 1, 0.12), 1)
	add_child(row)
	row.add_child(_inner_label(label, Rect2(22, 0, 200, 64), 19, C_INK, HORIZONTAL_ALIGNMENT_LEFT))
	var on: bool = bool(meta.settings.get(key, true)) if meta != null else true
	var tog := Button.new()
	tog.position = Vector2(456, 14)
	tog.size = Vector2(84, 36)
	tog.text = "开" if on else "关"
	tog.add_theme_font_size_override("font_size", 16)
	tog.add_theme_color_override("font_color", Color("2a1c00") if on else C_INK_DIM)
	tog.add_theme_stylebox_override("normal", _style(C_GOLD if on else Color(1, 1, 1, 0.12), 999, C_GOLD if on else Color(1, 1, 1, 0.25), 2))
	tog.pressed.connect(Callable(self, "_toggle_setting").bind(key))
	row.add_child(tog)


func _toggle_setting(key: String) -> void:
	if meta == null:
		return
	meta.settings[key] = not bool(meta.settings.get(key, true))
	meta.save()
	_show_settings()


func _confirm_wipe() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	add_child(dim)
	var panel := _dark_panel(Rect2(150, 358, 420, 200), 22, C_GOLD, 2)
	add_child(panel)
	panel.add_child(_inner_label("确认清除全部存档?", Rect2(0, 26, 420, 30), 20, C_INK))
	panel.add_child(_inner_label("角色 / 铭文 / 进度将重置,不可恢复", Rect2(0, 62, 420, 24), 14, C_INK_DIM))
	var yes := _button("确认清除", Rect2(40, 122, 150, 52), Color("ff8a8a"), Color("e0556b"))
	yes.pressed.connect(Callable(self, "_wipe_save"))
	panel.add_child(yes)
	var no := _button("取消", Rect2(230, 122, 150, 52), Color("9d6cf0"), Color("7a3fe0"))
	no.pressed.connect(Callable(self, "_show_settings"))
	panel.add_child(no)


func _wipe_save() -> void:
	var p := ProjectSettings.globalize_path("user://save.json")
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	meta = MetaState.new()
	_played = {}
	_sync_selected_to_equipped()
	_show_home()


func _skill_name(character: Dictionary) -> String:
	if character.has("skill_name"):
		return String(character["skill_name"])
	match String(character.get("id", "")):
		"borrrower":
			return "借贷"
		"breaker":
			return "破障"
		"chainbonus":
			return "连消奖步"
		"collector":
			return "连击收集"
		"colorshield":
			return "彩球护盾"
		"foresight":
			return "预知"
		"gravityflip":
			return "重力翻转"
		"longswap":
			return "隔位对换"
		"lucky":
			return "基础提示"
		"sametypeclear":
			return "同类清除"
		"snapshot":
			return "盘面快照"
		"timerewind":
			return "时间回溯"
	return "角色技能"


func _skill_desc(character: Dictionary) -> String:
	if character.has("skill_desc"):
		return String(character["skill_desc"])
	match String(character.get("id", "")):
		"borrrower":
			return "借一个特效，本关内必须还；不还不算过关。"
		"breaker":
			return "直接清除场上障碍(冰/锁等)。"
		"chainbonus":
			return "打连锁时奖励步数，递进式；始终靠打连锁技巧才给。"
		"collector":
			return "打连击时额外收集铭文碎片。"
		"colorshield":
			return "这局保彩球一次，被碰只掉护盾，彩球保留。"
		"foresight":
			return "高亮接下来最优的几步走法，不剧透掉落。"
		"gravityflip":
			return "临时翻转重力方向，改写下落和补充路线。"
		"longswap":
			return "能换相邻2步(隔一个)。"
		"lucky":
			return "无战斗技能；对局中给基础提示。"
		"sametypeclear":
			return "选一种棋子，消除全场所有该种类。"
		"snapshot":
			return "存一个局面，可一键跳回。"
		"timerewind":
			return "回退最近 5 步。"
	return "未来接入 Meta 后在对局前注入。"


func _button(text: String, rect: Rect2, top: Color, bottom: Color) -> Button:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.text = text
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color("6f63a0"))
	btn.add_theme_stylebox_override("normal", _button_style(top, bottom, 999))
	btn.add_theme_stylebox_override("hover", _button_style(top.lightened(0.08), bottom.lightened(0.08), 999))
	btn.add_theme_stylebox_override("pressed", _button_style(top.darkened(0.08), bottom.darkened(0.08), 999))
	btn.add_theme_stylebox_override("disabled", _style(Color(1, 1, 1, 0.58), 999, Color(1, 1, 1, 0.72), 1))
	return btn


func _round_button(text: String, rect: Rect2) -> Button:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.text = text
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_color_override("font_color", C_GOLD)
	btn.add_theme_stylebox_override("normal", _style(Color(0.09, 0.14, 0.30, 0.85), 999, C_GOLD, 2))
	btn.add_theme_stylebox_override("hover", _style(Color(0.14, 0.20, 0.40, 0.90), 999, C_GOLD, 2))
	btn.add_theme_stylebox_override("pressed", _style(Color(0.06, 0.10, 0.22, 0.90), 999, C_GOLD, 2))
	return btn


func _label(text: String, rect: Rect2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _inner_label(text: String, rect: Rect2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return _label(text, rect, font_size, color, align)


func _glass_panel(rect: Rect2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(color, 26, Color(1, 1, 1, 0.78), 1))
	return panel


func _style(fill: Color, radius: int, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.shadow_color = Color(0.30, 0.20, 0.55, 0.16)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 8)
	return style


func _button_style(top: Color, bottom: Color, radius: int) -> StyleBoxFlat:
	var style := _style(bottom, radius, Color(1, 1, 1, 0.65), 2)
	style.bg_color = bottom
	return style


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded
	path = CharacterData.resolve_file_path(path)
	if path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)   # Image.load 需文件系统路径
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("Unable to load character texture: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
