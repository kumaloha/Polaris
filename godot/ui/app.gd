extends Control

const CharacterData := preload("res://ui/character_data.gd")
const GameScript := preload("res://view/game.gd")
const CelestialBg := preload("res://ui/celestial_bg.gd")
const MetaState := preload("res://meta/meta_state.gd")
const Enchants := preload("res://meta/enchants.gd")
const LevelLibrary := preload("res://core/level_library.gd")

# 占星风配色
const C_GOLD := Color("e9c97c")
const C_GOLD_DEEP := Color("c79a4a")
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
const VIEW_H := 920.0

var characters: Array = []
var selected_idx := 0
var body: Control
var _wkmat: ShaderMaterial
var meta: MetaState              # Meta 进度(钱包/角色/铭文/历史)，持久化 user://save.json
var _played: Dictionary = {}     # 本会话已玩过的库索引(调度优先没玩过的)
var _cur_level := -1             # 当前对局的库索引(结束后入账)
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
	characters = CharacterData.load_characters()
	if characters.is_empty():
		push_warning("No character assets found at %s" % CharacterData.MANIFEST_PATH)
	meta = MetaState.new()
	meta.load_state()
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_lib = LevelLibrary.load_file("res://levels.json")
	_sync_selected_to_equipped()
	_show_home()


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


func _show_home() -> void:
	_clear()
	_add_gradient_background(true)   # 带魔法阵的占星背景
	var hero := _selected_character()

	# 顶部：玩家牌(左) + 资源链(右)
	_add_avatar_chip(hero, Vector2(18, 34))
	_add_res_chips()

	# 侧边徽章(任务/召唤)
	_add_side_badge("任务", Color("ff7eb0"), Vector2(20, 150), "3", Callable())
	var summon := _add_side_badge("召唤", Color("b88cf5"), Vector2(632, 150), "!", Callable(self, "_show_gacha"))
	summon.tooltip_text = "召唤"

	# 关卡牌(萌宠上方)
	var lvlpill := _glass_panel(Rect2(296, 214, 128, 38), Color(0.10, 0.16, 0.32, 0.78))
	lvlpill.add_theme_stylebox_override("panel", _style(Color(0.10, 0.16, 0.32, 0.78), 999, C_GOLD, 1))
	add_child(lvlpill)
	lvlpill.add_child(_inner_label("第 12 关", Rect2(0, 0, 128, 38), 18, C_GOLD))

	# 英雄台：魔法阵(背景已画) + 萌宠立绘
	_add_character_art(hero, Rect2(196, 250, 328, 330), false)
	_add_hero_ribbon(hero, Vector2(360, 566))

	# START：金色发光主按钮
	var start := _gold_button("开 始", "进入魔法小径", Rect2(228, 686, 264, 88))
	start.pressed.connect(Callable(self, "_show_map"))
	add_child(start)

	# 底部导航
	_add_bottom_nav("home")


func _show_character() -> void:
	_clear()
	_add_gradient_background()

	var back := _round_button("‹", Rect2(28, 48, 54, 54))
	back.pressed.connect(Callable(self, "_show_home"))
	add_child(back)

	var title := _label("角色", Rect2(105, 52, 260, 46), 34, Color("2c2350"), HORIZONTAL_ALIGNMENT_LEFT)
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
				meta.record_clear(_cur_level, int(result.get("stars", 0)))   # 关卡地图进度
		meta.save()
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
		primary.pressed.connect(Callable(self, "_show_map"))                       # 过关→回地图挑下一关
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
	var chip := _dark_panel(Rect2(pos, Vector2(190, 54)), 999, C_GOLD, 1)
	add_child(chip)
	var av := TextureRect.new()
	av.position = Vector2(5, 5)
	av.size = Vector2(44, 44)
	av.texture = _load_texture(String(hero.get("portrait", "")))
	av.material = _white_key_material()
	av.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(av)
	chip.add_child(_inner_label("星语者", Rect2(58, 7, 126, 24), 17, C_INK, HORIZONTAL_ALIGNMENT_LEFT))
	chip.add_child(_inner_label("Lv. 27", Rect2(58, 29, 126, 20), 13, C_GOLD, HORIZONTAL_ALIGNMENT_LEFT))


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
	bar.position = Vector2(0, 832)
	bar.size = Vector2(VIEW_W, 88)
	bar.add_theme_stylebox_override("panel", _style(Color(0.07, 0.11, 0.24, 0.92), 30, C_GOLD, 1))
	add_child(bar)
	var items := [["角色", "character", Callable(self, "_show_character")], ["商店", "shop", Callable()], ["排行", "rank", Callable()], ["设置", "settings", Callable()]]
	var n := items.size()
	var slot := VIEW_W / float(n)
	for i in n:
		var it: Array = items[i]
		var is_active: bool = String(it[1]) == active
		var btn := Button.new()
		btn.position = Vector2(slot * i + slot * 0.5 - 36, 842)
		btn.size = Vector2(72, 72)
		btn.flat = true
		var border := C_GOLD if is_active else Color(1, 1, 1, 0.28)
		var fill := C_GOLD if is_active else Color(1, 1, 1, 0.08)
		btn.add_theme_stylebox_override("normal", _style(fill, 999, border, 2))
		btn.add_theme_stylebox_override("hover", _style(C_GOLD.darkened(0.12), 999, C_GOLD, 2))
		btn.add_theme_stylebox_override("pressed", _style(C_GOLD.darkened(0.22), 999, C_GOLD, 2))
		var cb: Callable = it[2]
		if cb.is_valid():
			btn.pressed.connect(cb)
		add_child(btn)
		btn.add_child(_inner_label(String(it[0]), Rect2(0, 0, 72, 72), 18, Color("2a1c00") if is_active else C_INK))


func _add_character_art(character: Dictionary, rect: Rect2, use_card: bool) -> void:
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


# 关卡地图(蜿蜒小径)：库内各关按序蜿蜒排布,已过(蓝+星)/当前(金,可玩)/未解锁(灰)。点已解锁→打那关。
func _show_map() -> void:
	_clear()
	_add_gradient_background(false)
	var n: int = _lib.size() if _lib.size() > 0 else 12
	var gap_y := 132.0
	var pad_top := 70.0
	var content_h := pad_top + n * gap_y + 90.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 96)
	scroll.size = Vector2(VIEW_W, VIEW_H - 96)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(VIEW_W, content_h)
	scroll.add_child(content)
	var cur := _current_level(n)
	var cur_y := 0.0
	for i in n:
		var x := VIEW_W * 0.5 + sin(i * 0.95) * 150.0
		var y := pad_top + (n - 1 - i) * gap_y   # 0 关在最下，越高越上
		if i == cur:
			cur_y = y
		_map_node(content, i, x, y, _level_state(i, cur))
	scroll.set_deferred("scroll_vertical", int(maxf(0.0, cur_y - 240.0)))   # 开屏滚到当前关
	# 顶栏
	var back := _round_button("‹", Rect2(18, 18, 48, 48))
	back.z_index = 50
	back.pressed.connect(Callable(self, "_show_home"))
	add_child(back)
	add_child(_label("星辉森林 · 魔法小径", Rect2(88, 36, 420, 40), 22, C_GOLD, HORIZONTAL_ALIGNMENT_LEFT))


func _current_level(n: int) -> int:
	if meta == null:
		return 0
	for i in n:
		if not meta.level_stars.has(str(i)):
			return i
	return n - 1   # 全过了 → 停在最后一关


func _level_state(i: int, cur: int) -> String:
	if meta != null and meta.level_stars.has(str(i)):
		return "cleared"
	if i <= cur:
		return "current"
	return "locked"


func _map_node(parent: Control, idx: int, x: float, y: float, state: String) -> void:
	var sz := 72.0
	var locked: bool = state == "locked"
	var cleared: bool = state == "cleared"
	var is_cur: bool = state == "current"
	# 深色底衬：让节点色块在中心辉光上也清晰
	var halo := Panel.new()
	halo.position = Vector2(x - sz * 0.5 - 6, y - sz * 0.5 - 6)
	halo.size = Vector2(sz + 12, sz + 12)
	halo.add_theme_stylebox_override("panel", _style(Color(0.04, 0.07, 0.16, 0.82), 999, C_GOLD if is_cur else Color(1, 1, 1, 0.0), 0))
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(halo)
	var btn := Button.new()
	btn.position = Vector2(x - sz * 0.5, y - sz * 0.5)
	btn.size = Vector2(sz, sz)
	var fill: Color = Color("a89fce") if locked else (Color("5fb0ff") if cleared else Color("ffce5e"))
	var border: Color = C_GOLD if is_cur else Color(1, 1, 1, 0.55)
	var bw: int = 4 if is_cur else 2
	btn.add_theme_stylebox_override("normal", _style(fill, 999, border, bw))
	if not locked:
		btn.add_theme_stylebox_override("hover", _style(fill.lightened(0.10), 999, C_GOLD, bw))
		btn.add_theme_stylebox_override("pressed", _style(fill.darkened(0.10), 999, C_GOLD, bw))
		btn.pressed.connect(Callable(self, "_show_game").bind(idx))
	parent.add_child(btn)
	btn.add_child(_inner_label(str(idx + 1), Rect2(0, 0, sz, sz), 24, Color(1, 1, 1, 0.5) if locked else Color("3a2600")))
	# 难度标(节点右侧)
	if idx < _lib.size():
		var diff := "挖矿" if bool(_lib[idx].get("is_scrolling", false)) else String(_lib[idx].get("difficulty", ""))
		parent.add_child(_label(diff, Rect2(x + sz * 0.5 + 4, y - 11, 84, 22), 12, C_INK_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	# 星级(已过，节点下方)
	if cleared:
		var s := int(meta.level_stars.get(str(idx), 0))
		parent.add_child(_label("★".repeat(s), Rect2(x - 42, y + sz * 0.5 - 2, 84, 18), 14, C_GOLD))


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
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("Unable to load character texture: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
