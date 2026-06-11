extends Node
# 壳层主场景状态机：Boot → Map → Level → Result → (回 Map)
# 运行：godot --path godot res://app/game_root.tscn
# main_scene 切换是 P9 最后一步，此处暂不改 project.godot。
#
# 依赖纪律：app → {meta, match3}；match3 禁 import meta，反向同禁。

const MetaState := preload("res://meta/meta_state.gd")
const Session   := preload("res://app/session.gd")

# 加载关卡配置（levels.json 在 godot/ 根目录下）
const LEVELS_PATH := "res://levels.json"

# ── 状态枚举 ─────────────────────────────────────────────────────────────────
enum State { BOOT, MAP, LEVEL, RESULT }

var _state: State = State.BOOT
var _meta: MetaState
var _session: Session
var _library: Array         # levels.json 全量
var _current_index: int = 0 # 当前进入关卡的库索引
var _last_summary: Dictionary = {}  # bank() 返回的入账摘要，供 Result 页显示
var _last_stars: int = 0            # 本局星级，供 Result 页显示
var _played_set: Dictionary = {}    # 已玩关卡索引集 { int: bool }，供 recommend_next

# ── 场景节点引用（build_ui 建立） ─────────────────────────────────────────────
var _map_container: Control    # Map 状态的垂直列表容器
var _level_root: Node          # Level.tscn 实例挂载点
var _result_panel: Control     # Result 结算面板

func _ready() -> void:
	_meta    = MetaState.new()
	_session = Session.new()
	_library = _load_library()
	_build_ui()
	_enter_boot()

# ── 关卡库加载 ────────────────────────────────────────────────────────────────
func _load_library() -> Array:
	if not FileAccess.file_exists(LEVELS_PATH):
		push_warning("game_root: levels.json not found at " + LEVELS_PATH)
		return []
	var f := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if f == null:
		push_warning("game_root: failed to open levels.json")
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("levels") and typeof(parsed["levels"]) == TYPE_ARRAY:
		return parsed["levels"]
	push_warning("game_root: levels.json has unexpected structure")
	return []

# ── UI 骨架构建 ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Map 容器（垂直滚动列表）
	var scroll := ScrollContainer.new()
	scroll.name = "MapScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_map_container = VBoxContainer.new()
	_map_container.name = "MapContainer"
	_map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_map_container)

	# Level 挂载点（透明容器）
	_level_root = Node.new()
	_level_root.name = "LevelRoot"
	add_child(_level_root)

	# Result 面板
	_result_panel = Panel.new()
	_result_panel.name = "ResultPanel"
	_result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_result_panel)
	_result_panel.visible = false

# ── Boot ──────────────────────────────────────────────────────────────────────
func _enter_boot() -> void:
	_state = State.BOOT
	_meta.load_state()
	# Boot 直通 Map
	_enter_map()

# ── Map ───────────────────────────────────────────────────────────────────────
func _enter_map() -> void:
	_state = State.MAP
	_result_panel.visible = false
	_clear_level()

	# 显示 MapScroll
	var scroll := get_node("MapScroll")
	scroll.visible = true

	_rebuild_map_list()

func _rebuild_map_list() -> void:
	# 清空旧按钮
	for ch in _map_container.get_children():
		ch.queue_free()

	if _library.is_empty():
		var lbl := Label.new()
		lbl.text = "（无关卡数据）"
		_map_container.add_child(lbl)
		return

	# 计算推荐关（有 library 时才调）
	var recommended_idx: int = _session.recommend_next(_meta, _library, _played_set)

	for i in _library.size():
		var stars: int = int(_meta.level_stars.get(str(i), 0))
		var is_recommended: bool = (i == recommended_idx)
		var btn := Button.new()
		var suffix := " [推荐]" if is_recommended else ""
		btn.text = "关 %d  %s%s" % [i + 1, _stars_str(stars), suffix]
		btn.name = "LevelBtn_%d" % i
		# 闭包捕获 i
		var idx := i
		btn.pressed.connect(func(): _on_map_level_pressed(idx))
		_map_container.add_child(btn)

func _stars_str(stars: int) -> String:
	match stars:
		1: return "★☆☆"
		2: return "★★☆"
		3: return "★★★"
		_: return "☆☆☆"

func _on_map_level_pressed(index: int) -> void:
	_current_index = index
	_enter_level(index)

# ── Level ─────────────────────────────────────────────────────────────────────
func _enter_level(index: int) -> void:
	_state = State.LEVEL

	# 隐藏地图
	get_node("MapScroll").visible = false

	# 卸载旧 Level 实例（若有）
	_clear_level()

	# 加载 Level.tscn
	var level_scene: PackedScene = load("res://Level.tscn")
	if level_scene == null:
		push_error("game_root: cannot load res://Level.tscn")
		_enter_map()
		return

	var level_inst := level_scene.instantiate()
	_level_root.add_child(level_inst)

	# 鸭子类型探测：注入 SessionConfig（接线点——level 侧 receive_session_config 由主线程后续加）
	var config := _session.build_config(_meta, index)
	if level_inst.has_method("receive_session_config"):
		level_inst.receive_session_config(config)

	# 鸭子类型探测：连接 session_ended 信号（接线点——level 侧信号由主线程后续加）
	if level_inst.has_signal("session_ended"):
		level_inst.session_ended.connect(_on_session_ended)

func _clear_level() -> void:
	for ch in _level_root.get_children():
		ch.queue_free()

# ── Result ────────────────────────────────────────────────────────────────────
func _on_session_ended(result: Dictionary) -> void:
	_last_summary = _session.bank(_meta, result, _current_index)
	_last_stars = int(result.get("stars", 0))
	_played_set[_current_index] = true
	_enter_result()

func _enter_result() -> void:
	_state = State.RESULT
	_clear_level()
	_result_panel.visible = true

	# 清空旧 Result 内容
	for ch in _result_panel.get_children():
		ch.queue_free()

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(vbox)

	# 星级
	var stars_lbl := Label.new()
	stars_lbl.name = "StarsLabel"
	stars_lbl.text = _stars_str(_last_stars)
	vbox.add_child(stars_lbl)

	# 入账摘要
	var summary_lbl := Label.new()
	summary_lbl.name = "SummaryLabel"
	summary_lbl.text = "金币 +%d　碎片 +%d　水晶 +%d" % [
		_last_summary.get("coins_delta", 0),
		_last_summary.get("fragments_delta", 0),
		_last_summary.get("crystals_delta", 0),
	]
	vbox.add_child(summary_lbl)

	# 下一关按钮
	var next_btn := Button.new()
	next_btn.text = "下一关"
	next_btn.pressed.connect(_on_result_next)
	vbox.add_child(next_btn)

	# 回地图按钮
	var map_btn := Button.new()
	map_btn.text = "回地图"
	map_btn.pressed.connect(_enter_map)
	vbox.add_child(map_btn)

func _on_result_next() -> void:
	var next := _current_index + 1
	if next >= _library.size():
		next = 0
	_current_index = next
	_result_panel.visible = false
	_enter_level(next)
