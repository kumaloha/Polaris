extends "res://tests/test_lib.gd"

const ClearVisuals := preload("res://match3/clear_visuals.gd")
const Board := preload("res://core/board.gd")
const LevelLibrary := preload("res://core/level_library.gd")
const LevelMotion := preload("res://match3/level_motion.gd")
const ME := preload("res://core/match_engine.gd")
const TimeRabbitCast := preload("res://match3/pets/time_rabbit.gd")

# P3(契约 C, docs/11 §4): 时兔施法已抽成 match3/pets/time_rabbit.gd 的 TimeRabbitCast(PetCast 子类)。
# 这些测试断言搬到 TimeRabbitCast 实例上(几何/帧序列/锁协议语义全保留, 仅换调用对象)。
const RABBIT_SRC := "res://match3/pets/time_rabbit.gd"
const LEVEL_SRC := "res://match3/level.gd"


func _none_fx(w: int, h: int) -> Array:
	var fx := []
	for y in h:
		var row := []
		for x in w:
			row.append(ME.SP_NONE)
		fx.append(row)
	return fx


func _prepare_level_scene_with_real_levels() -> Node:
	var scene: PackedScene = load("res://Level.tscn")
	var level := scene.instantiate()
	# @onready 节点引用仅在入树时解析; 测试里手工接(与 test_ui_assets._prepare_level_scene 同口径),
	# 这样不入树也能跑 load_level/_render_skillbar(它们要 skill_bar 等层)。
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


# 造一个挂在 level 之上的时兔施法控制器(注入 level 上下文), 用真实关布局。
func _make_rabbit_cast(cast_effect: bool = true) -> TimeRabbitCast:
	var cast := TimeRabbitCast.new()
	cast.setup({
		"skill_bar": null,
		"board": Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 25, 7),
		"cell_size": 77.0,
		"board_origin": Vector2(20.0, 400.0),
		"cast_effect": cast_effect,
		"load_texture": Callable(self, "_load_texture_for_cast"),
		"set_avatar_casting": Callable(),
		"refresh_skill_ui": Callable(),
	})
	return cast


func _load_texture_for_cast(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func test_time_rabbit_cast_animation_has_readable_timing() -> void:
	var cast := _make_rabbit_cast()
	assert_eq(cast.get("TIME_SCALE"), 2.75, "time rabbit animation follows the slower full skill animatic timing")
	assert_eq(cast.get("CAST_HOLD"), 0.82, "time rabbit cast frame is held through the readable hourglass beat")
	cast.free()
	var src := FileAccess.get_file_as_string(RABBIT_SRC)
	var start: int = src.find("func _build_cast_tween")
	assert_true(start >= 0, "time rabbit tween builder exists")
	if start < 0:
		return
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	# K8 施法定格保持一拍后再提交回退(用 .find 校验顺序, 隐含三者都存在)
	var k8_idx: int = body.find("K8")
	var hold_idx: int = body.find("t.tween_interval(CAST_HOLD)", k8_idx)
	var commit_idx: int = body.find("_commit", k8_idx)
	assert_true(k8_idx >= 0 and hold_idx > k8_idx and commit_idx > hold_idx, "K8 cast frame holds briefly before committing the board rewind")
	var first_k1_idx: int = body.find("_queue_frame(t, rig, rabbit, K1")
	var first_k1_end: int = body.find("\n", first_k1_idx)
	var first_k1_line := body.substr(first_k1_idx, first_k1_end - first_k1_idx) if first_k1_idx >= 0 and first_k1_end > first_k1_idx else ""
	# 钉源码理由: 时兔逐帧锚点对齐是已逐帧手调拍板的视觉决策(docs/11) —— 首帧 peek 眼睛对齐头像(first_peek), K2~K4 帧底贴头像框下唇(emerge_bottom); tween 编排无法 headless 量化故锁文本
	assert_true(body.contains("var emerge_bottom := _avatar_frame_bottom_anchor()"), "later emerge frames share the avatar frame lower lip as their bottom anchor")
	assert_true(body.contains("var first_peek := _first_peek_anchor()"), "first peek frame has its own eye-aligned avatar anchor")
	assert_true(first_k1_line.contains("first_peek"), "second GIF frame keeps the rabbit eyes level with the avatar instead of dropping to the lower lip")
	for path_name in ["K2", "K25", "K3", "K4"]:
		var line_idx: int = body.find("_queue_frame(t, rig, rabbit, %s" % path_name)
		var line_end: int = body.find("\n", line_idx)
		var line := body.substr(line_idx, line_end - line_idx) if line_idx >= 0 and line_end > line_idx else ""
		assert_true(line.contains("emerge_bottom"), "%s keeps its image bottom on the avatar frame lower lip" % path_name)
	# 钉源码理由: 施法定格后回程帧不得二次缩小(K55/K5 不再叠加 leap_w*0.92/0.86 的缩放), 也不得在首帧前下沉头像(home+12) —— 都是已修过的尺度/锚点回归
	assert_false(body.contains("K55, leap_w * 0.92"), "return frame after K8 must not shrink smaller than the cast/readable rabbit scale")
	assert_false(body.contains("K5, leap_w * 0.86"), "return leap frame must not add a second scale drop after the cast beat")
	assert_false(body.contains("home + Vector2(0.0, 12.0)"), "time rabbit should not sink the avatar actor before the first peek frame")


func test_time_rewind_cast_locks_board_and_level_switch_cancels() -> void:
	# B1 回归(2026-06-11 bugfix)→ P3 重写为契约 C 锁协议: 施法即锁盘、换关取消在途施法。
	# 锁的读写只在 level.gd(cast_started→上锁, cast_finished→解锁); 取消经实例 cancel()。
	var level := _prepare_level_scene_with_real_levels()
	level.load_level(1)
	# 施法即锁盘: cast_started 回调上 _busy + _time_rewind_cast_pending(头像演出整段锁)。
	level.set("_busy", false)
	level.set("_time_rewind_cast_pending", false)
	level.call("_on_pet_cast_started")
	assert_true(bool(level.get("_busy")), "starting the rewind cast locks the board for the whole sequence")
	assert_true(bool(level.get("_time_rewind_cast_pending")), "starting the rewind cast marks a cast in progress")
	# cast_finished 回调释放锁(演出全部结束含归位/取消)。
	level.call("_on_pet_cast_finished", null)
	assert_eq(bool(level.get("_busy")), false, "finishing the cast releases the board lock")
	assert_eq(bool(level.get("_time_rewind_cast_pending")), false, "finishing the cast clears the cast-in-progress flag")
	# 端到端: 经 _cast_pet 实例化施法控制器并取消, 验证 _cancel_active_cast 复位标记 + 幂等。
	var did: bool = level.call("_cast_pet", 0, false)
	assert_true(did, "casting the time rewind pet starts the controller")
	level.call("_cancel_active_cast")
	assert_eq(level.get("_active_cast"), null, "cancelling drops the active cast reference")
	level.call("_cancel_active_cast")   # 幂等: 无在途施法重复调用不崩
	assert_eq(bool(level.get("_time_rewind_cast_pending")), false, "cancel hook resets the casting flag even with no cast alive")
	level.free()

	# 锁协议在 level 接线点(信号回调)与 load_level/_unhandled_input 上, 锁住关键语句。
	var src := FileAccess.get_file_as_string(LEVEL_SRC)
	var started_start: int = src.find("func _on_pet_cast_started")
	var started_body: String = src.substr(started_start, src.find("\nfunc ", started_start + 10) - started_start)
	# 钉源码理由: 宠物施法一开始就必须 _busy=true 锁住整段, 否则玩家能在回退动画中继续操作导致状态错乱
	assert_true(started_body.contains("_busy = true"), "starting the pet cast locks the board for the whole sequence")
	var load_start: int = src.find("func load_level")
	var load_body: String = src.substr(load_start, src.find("\nfunc ", load_start + 10) - load_start)
	# 钉源码理由: 换关必须 _cancel_active_cast() 取消在途施法, 否则旧关的兔子动画会泄漏到新关
	assert_true(load_body.contains("_cancel_active_cast()"), "switching levels cancels any in-flight pet cast")
	var input_start: int = src.find("func _unhandled_input")
	var input_body: String = src.substr(input_start, src.find("\nfunc ", input_start + 10) - input_start)
	assert_true(input_body.find("_time_rewind_cast_pending") < input_body.find("KEY_RIGHT"), "keyboard level-switch is gated behind the cast/busy/settled checks")


func test_time_rabbit_jump_has_inbetween_frames() -> void:
	var cast := _make_rabbit_cast()
	assert_true(cast.has_method("_jump_points"), "time rabbit jump exposes inbetween arc points")
	assert_true(cast.has_method("_jump_durations"), "time rabbit jump exposes per-inbetween timing")
	assert_true(cast.has_method("_avatar_frame_bottom_anchor"), "time rabbit exposes the avatar frame bottom anchor")
	assert_true(cast.has_method("_first_peek_anchor"), "time rabbit exposes the eye-aligned first peek anchor")
	var home := Vector2(140.0, 1320.0)
	var cast_pt := Vector2(360.0, 1040.0)
	var points: Array = cast.call("_jump_points", home, cast_pt)
	var durations: Array = cast.call("_jump_durations")
	assert_true(points.size() >= 10, "rabbit jump is split into enough visible inbetween positions instead of two large sampled leaps")
	assert_eq(points.size(), durations.size(), "each rabbit jump inbetween point has its own timing")
	var raw_total := 0.0
	for d in durations:
		raw_total += float(d)
	assert_true(raw_total >= 0.70, "rabbit jump gives the eye enough time to read the added inbetweens")
	var bottom_anchor: Vector2 = cast.call("_avatar_frame_bottom_anchor")
	var visible_frame_bottom: float = Vector2(cast.call("_home_anchor")).y + 132.0 * 0.5
	assert_true(absf(bottom_anchor.y - visible_frame_bottom) <= 1.0, "avatar frame bottom anchor uses the visible slot lip, not the oversized frame texture bounds")
	var first_peek: Vector2 = cast.call("_first_peek_anchor")
	var live_home: Vector2 = cast.call("_home_anchor")
	assert_true(absf(first_peek.y - (live_home.y - 24.0)) <= 1.0, "first peek anchor keeps the K1 eyes aligned with the static avatar")
	assert_true(first_peek.y < bottom_anchor.y - 72.0, "first peek starts well above the lower lip so the second frame does not look too low")
	assert_true(points[0].y > home.y, "first jump inbetween starts near the lower avatar-frame lip instead of popping above it")
	assert_true(points[points.size() - 1].distance_to(cast_pt) <= 0.5, "last jump inbetween lands at the documented cast anchor")
	var reaches_apex := false
	var moved_toward_book := false
	var previous: Vector2 = points[0]
	for p in points:
		var point := p as Vector2
		assert_true(point.x >= home.x - 0.5 and point.x <= cast_pt.x + 0.5, "rabbit jump stays between the avatar slot and the book-center cast point")
		assert_true(previous.distance_to(point) <= 105.0, "adjacent rabbit jump frames stay close enough to avoid a dropped-frame leap")
		if point.y < minf(home.y, cast_pt.y):
			reaches_apex = true
		if point.x > home.x + 24.0:
			moved_toward_book = true
		previous = point
	assert_true(reaches_apex, "middle jump inbetweens reach a visible arc apex before landing")
	assert_true(moved_toward_book, "rabbit visibly jumps out toward the book center instead of staying on the avatar column")
	cast.free()
	# 上面已用行为断言充分校验跳跃弧点/锚点几何; 以下锁住 tween 编排里"用多步跳跃助手、回程 K1 复用眼对齐锚、不再一长跳到位"的逐帧契约
	var src := FileAccess.get_file_as_string(RABBIT_SRC)
	var start: int = src.find("func _build_cast_tween")
	var end: int = src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body: String = src.substr(start, end - start)
	# 钉源码理由: 主时间线必须用多步 _queue_jump(而非一长跳), 回程 K1 复用 first_peek 眼对齐锚; 这是逐帧手调的跳跃演出, tween 无法 headless 量化故锁文本
	assert_true(body.contains("_queue_jump("), "main rabbit cast timeline uses the multi-step jump helper")
	assert_true(body.contains("_queue_frame(t, rig, rabbit, K1, HOME_W, first_peek"), "return-to-pocket K1 reuses the same eye-aligned anchor before switching back to avatar art")
	assert_false(body.contains("K5, LEAP_W, cast + Vector2(-44.0, 38.0)"), "rabbit no longer jumps from crouch to cast in one long tween")


func test_time_rabbit_cast_anchor_is_below_magic_book() -> void:
	var cast := TimeRabbitCast.new()
	assert_true(cast.has_method("_cast_anchor"), "time rabbit cast anchor exists")
	assert_true(cast.has_method("_home_anchor"), "time rabbit home anchor exists")
	assert_true(cast.has_method("_cast_width"), "time rabbit cast width adapts to each board gap")
	assert_true(cast.has_method("_hourglass_float_anchor"), "time rabbit hourglass has a board-centered float anchor")
	assert_true(cast.has_method("_current_board_rect"), "cast exposes board rect for cast placement")
	assert_true(cast.has_method("_book_frame_rect"), "cast exposes book rect for cast placement")
	var board := Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 25, 7)
	cast.setup(_layout_ctx(board))
	var home: Vector2 = cast.call("_home_anchor")
	var cast_pt: Vector2 = cast.call("_cast_anchor")
	var cast_width: float = cast.call("_cast_width")
	var board_rect: Rect2 = cast.call("_current_board_rect")
	var book_rect: Rect2 = cast.call("_book_frame_rect")
	assert_true(absf(cast_pt.x - book_rect.get_center().x) <= 0.5, "rabbit casts below the center of the magic book")
	assert_true(absf(cast_pt.x - home.x) > 80.0, "rabbit leaves the avatar column after jumping out")
	assert_true(cast_pt.y < home.y, "rabbit cast point floats above the avatar slot")
	assert_true(cast_pt.y >= book_rect.end.y + 28.0, "rabbit cast point stays below the magic book")
	assert_true(cast_pt.y <= home.y - 84.0, "rabbit cast bottom stays above the avatar row instead of covering pet slots")
	assert_false(board_rect.has_point(cast_pt), "rabbit cast anchor must not overlap the playable board")
	var hourglass_anchor: Vector2 = cast.call("_hourglass_float_anchor", cast_pt)
	assert_true(absf(hourglass_anchor.x - board_rect.get_center().x) <= 0.5, "hourglass floats to the board center, not over the pet slot")
	assert_true(hourglass_anchor.y < board_rect.get_center().y, "hourglass floats in the upper half of the board airspace")
	var k8_width: float = cast.call("_frame_width", "res://assets/pets/timerewind/rabbit_k8_cast.png", cast_width)
	var cast_top := cast_pt.y - 8.0 - k8_width * (1191.0 / 908.0)
	assert_true(cast_top >= board_rect.end.y, "rabbit K8 visible body stays below the playable board, not just its anchor")
	# 高盘(8×10): 缩 cast sprite 而非挪进盘内
	var board2 := Board.new(8, 10, [0, 1, 2, 3, 4], 999999, 25, 8)
	cast.setup(_layout_ctx(board2))
	home = cast.call("_home_anchor")
	cast_pt = cast.call("_cast_anchor")
	cast_width = cast.call("_cast_width")
	board_rect = cast.call("_current_board_rect")
	book_rect = cast.call("_book_frame_rect")
	k8_width = cast.call("_frame_width", "res://assets/pets/timerewind/rabbit_k8_cast.png", cast_width)
	cast_top = cast_pt.y - 8.0 - k8_width * (1191.0 / 908.0)
	assert_true(cast_width < 220.0, "tall boards shrink the cast sprite instead of moving it into the board")
	assert_true(absf(cast_pt.x - book_rect.get_center().x) <= 0.5, "tall board rabbit cast still lands under the book center")
	assert_true(cast_pt.y <= home.y - 84.0, "tall board rabbit cast still stays above the avatar row")
	assert_true(cast_top >= board_rect.end.y, "tall board rabbit K8 visible body stays below the playable board")
	cast.free()


func test_time_rabbit_cast_uses_full_brief_frames_and_feedback() -> void:
	var cast := TimeRabbitCast.new()
	cast.setup(_layout_ctx(Board.new(8, 8, [0, 1, 2, 3, 4], 999999, 25, 7)))
	# K2.5/K5.5 中间帧常量、按瞳距缩放的 EYE_DISTANCE 表: 实例上读到真实值即证明
	assert_true(cast.get("K25") != null, "rabbit climb uses the K2.5 push-up inbetween")
	assert_true(cast.get("K55") != null, "rabbit return uses the K5.5 falling inbetween")
	assert_true(cast.get("FRAME_EYE_DISTANCE") != null, "rabbit open-eye frames are scaled from measured pupil distance instead of crop width")
	# 倒流施法特效的反向沙粒/时钟投影/收尾信号在 async 特效里, 锁住已拍板的反馈契约
	var src := FileAccess.get_file_as_string(RABBIT_SRC)
	# 钉源码理由: 倒流施法必须含反向沙粒(TimeRewindSand)+时钟投影(TimeRewindClockHand)子特效, 并在收尾时发 cast_finished 信号(解锁后续) —— 都是已拍板的施法反馈, async 特效无法 headless 校验
	assert_true(src.contains("TimeRewindSand"), "time rewind cast effect includes reverse sand particles")
	assert_true(src.contains("TimeRewindClockHand"), "time rewind cast effect includes a clock projection beat")
	assert_true(src.contains("emit_signal(\"cast_finished\")"), "rabbit cast emits the finished signal when the actor is collected")

	assert_true(cast.has_method("_frame_width"), "time rabbit exposes corrected frame width helper")
	var home_w := 138.0
	var peek_w := 172.0
	var k1: float = cast.call("_frame_width", "res://assets/pets/timerewind/rabbit_k1_peektop.png", home_w)
	var k2: float = cast.call("_frame_width", "res://assets/pets/timerewind/rabbit_k2_peek.png", peek_w)
	var k25: float = cast.call("_frame_width", "res://assets/pets/timerewind/rabbit_k25_pushup.png", peek_w)
	var k3: float = cast.call("_frame_width", "res://assets/pets/timerewind/rabbit_k3_climb.png", peek_w)
	var k4: float = cast.call("_frame_width", "res://assets/pets/timerewind/rabbit_k4_crouch.png", peek_w)
	assert_true(k2 < peek_w, "wide peek face is slightly reduced before the climb")
	assert_true(k25 < k2 and k3 < k2 and k4 < k2, "vertical climb frames are reduced so the head does not jump larger than surrounding frames")
	assert_true(k4 <= k25, "crouch frame is not larger than the preceding push-up frame")
	assert_true(cast.has_method("_leap_width"), "time rabbit leap width is corrected independently from cramped cast width")
	var leap_w: float = cast.call("_leap_width", 96.0)
	assert_true(leap_w >= k4, "first leap frame does not shrink smaller than the preceding crouch frame")
	var avatar_eye_distance := 242.5
	var target_eye := avatar_eye_distance * (132.0 / 1254.0)
	var spacious_cast_w := 126.0
	var leap_w_for_eye: float = cast.call("_leap_width", spacious_cast_w)
	var open_eye_frames := [
		{ "path": "res://assets/pets/timerewind/rabbit_k1_peektop.png", "width": home_w, "eye": 288.6, "tex_w": 963.0 },
		{ "path": "res://assets/pets/timerewind/rabbit_k2_peek.png", "width": peek_w, "eye": 203.4, "tex_w": 1254.0 },
		{ "path": "res://assets/pets/timerewind/rabbit_k25_pushup.png", "width": peek_w, "eye": 172.5, "tex_w": 762.0 },
		{ "path": "res://assets/pets/timerewind/rabbit_k3_climb.png", "width": peek_w, "eye": 182.4, "tex_w": 794.0 },
		{ "path": "res://assets/pets/timerewind/rabbit_k4_crouch.png", "width": peek_w, "eye": 157.7, "tex_w": 687.0 },
		{ "path": "res://assets/pets/timerewind/rabbit_k5_leap.png", "width": leap_w_for_eye, "eye": 176.1, "tex_w": 1123.0 },
		{ "path": "res://assets/pets/timerewind/rabbit_k55_fall.png", "width": leap_w_for_eye * 0.92, "eye": 149.3, "tex_w": 836.0 },
		{ "path": "res://assets/pets/timerewind/rabbit_k6_idle.png", "width": spacious_cast_w, "eye": 147.9, "tex_w": 668.0 },
		{ "path": "res://assets/pets/timerewind/rabbit_k8_cast.png", "width": spacious_cast_w, "eye": 195.2, "tex_w": 908.0 },
	]
	for item in open_eye_frames:
		var path := String(item["path"])
		var display_w: float = cast.call("_frame_width", path, float(item["width"]))
		var display_eye: float = float(item["eye"]) * display_w / float(item["tex_w"])
		assert_true(absf(display_eye - target_eye) <= 1.25, "%s keeps pupil distance consistent with the avatar frame" % path)
	cast.free()


func test_time_rewind_board_effect_keeps_board_center_anchor() -> void:
	var cast := TimeRabbitCast.new()
	assert_true(cast.has_method("_effect_anchor"), "time rewind effect has a board-centered anchor separate from the rabbit")
	# 直接调真函数: 倒流特效锚点应是棋盘矩形中心, 且明显不同于兔子 home 锚点(兔子在棋盘下方)
	var board := Board.new(8, 8, [0, 1, 2, 3, 4, 5], 0, 25, 1)
	cast.setup(_layout_ctx(board))
	var anchor: Vector2 = cast.call("_effect_anchor")
	var board_center: Vector2 = cast.call("_current_board_rect").get_center()
	assert_true(anchor.distance_to(board_center) <= 1.0, "rewind board flash/rings center on the book/board rect, not the rabbit's feet")
	var rabbit_home: Vector2 = cast.call("_home_anchor")
	assert_true(anchor.distance_to(rabbit_home) > 1.0, "rewind effect anchor is distinct from the rabbit home anchor")
	cast.free()
	# spawner 把 effect.position 设为该锚点的接线在 async 特效内, 锁住关键调用
	var src := FileAccess.get_file_as_string(RABBIT_SRC)
	var start: int = src.find("func _spawn_cast_effect")
	var end: int = src.find("\nfunc ", start + 1)
	if start < 0 or end <= start:
		return
	var body: String = src.substr(start, end - start)
	# 钉源码理由: 倒流闪光/光环必须用 _effect_anchor() 定位(棋盘中心), 决不能挂在兔子脚下, 这是已修过的居中回归
	assert_true(body.contains("effect.position = _effect_anchor()"), "board flash and rings stay centered on the book/board, not on the rabbit's feet")


# 真实关布局上下文(8×N): 用 LevelLayout 算 cell_size/board_origin, 与 level._compute_layout 同口径。
func _layout_ctx(board) -> Dictionary:
	var LevelLayout := load("res://match3/level_layout.gd")
	var layout: Dictionary = LevelLayout.compute_layout(board.width, board.height)
	return {
		"skill_bar": null,
		"board": board,
		"cell_size": float(layout["cell_size"]),
		"board_origin": layout["board_origin"],
		"cast_effect": true,
		"load_texture": Callable(self, "_load_texture_for_cast"),
		"set_avatar_casting": Callable(),
		"refresh_skill_ui": Callable(),
	}
