class_name RaccoonMinerCast
extends "res://match3/pets/pet_cast.gd"
## 矿工浣熊「破障」施法控制器（契约 C, docs/11 §4.6）。
##
## 范式验证：≤200 行、零改动 pet_cast.gd 基类。
## 无手绘帧序列；用头像 rig + Fx.spawn_explosion 做克制演出（总长 ~2s）。
##
## 注入上下文（经 setup()，禁止反摸 level 内部）：
##   skill_bar       — 演出节点父层（CanvasLayer）
##   board           — core/board.gd 实例（只读，落地时调 skill_break()）
##   cell_size / board_origin — 当前关布局（算施法/特效锚点）
##   set_avatar_casting — Callable(bool)：切换底部头像按钮显隐

const LevelLayout := preload("res://match3/level_layout.gd")

# ── 资源 / 节点名 / z 序 ──
const CAST_NODE := "RaccoonMinerCast"
const AVATAR := "res://assets/avatars/av_raccoon_miner.png"
const CAST_Z := 240

# ── 布局常量（与时兔同口径）──
const DESIGN_W := LevelLayout.DESIGN_W
const SKILL_AV_Y := LevelLayout.SKILL_AV_Y
const SKILL_AV_W := LevelLayout.SKILL_AV_W
const SLOT_COUNT := 4   # 底栏 4 个宠物槽（浣熊占 slot 1）

# ── 演出时长（总长约 2s，比时兔 TIME_SCALE=2.75 的~2.6s 更短）──
const DUR_JUMP_OUT := 0.38     # 头像跳出头像位 → 棋盘中央
const DUR_CHARGE  := 0.22     # 停顿蓄力
const DUR_SWING   := 0.18     # 挥动/缩放强调
const DUR_HOLD    := 0.10     # 破障定格（_commit 在此）
const DUR_RETURN  := 0.44     # 跳回头像位
const SWING_SCALE := Vector2(1.28, 1.28)   # 挥动强调的放大系数

# ── 注入上下文 ──
var skill_bar: CanvasLayer = null
var board = null
var cell_size: float = 0.0
var board_origin: Vector2 = Vector2.ZERO
var _set_avatar_casting_cb: Callable = Callable()

## 注入 level 上下文。必须在 add_child + start_cast 之前调用。
func setup(ctx: Dictionary) -> void:
	skill_bar = ctx.get("skill_bar", null)
	board = ctx.get("board", null)
	cell_size = float(ctx.get("cell_size", 0.0))
	board_origin = ctx.get("board_origin", Vector2.ZERO)
	_set_avatar_casting_cb = ctx.get("set_avatar_casting", Callable())

# ───────── PetCast 钩子实现 ─────────

func _can_cast() -> bool:
	if board == null:
		return false
	board.skill = "breaker"
	# 无 coat 层（关本身没有障碍）→ 拒绝，不消耗
	if board.coat.is_empty():
		return false
	# 已用过（active_used）或局已结束 → skill_break 内部会返回 false，
	# 这里提前检查让 start_cast 优雅拒绝而不进入演出
	if board.active_used or board.is_over():
		return false
	return true

func _build_visuals() -> void:
	if skill_bar == null:
		return
	var old := skill_bar.get_node_or_null(CAST_NODE)
	if old != null:
		_detach_and_free_later(old)
	_set_avatar_casting(true)
	var rig := Node2D.new()
	rig.name = CAST_NODE
	rig.z_index = CAST_Z
	rig.position = _home_anchor()
	skill_bar.add_child(rig)
	var sprite := Sprite2D.new()
	sprite.name = "RaccoonSprite"
	var tex := _load_texture(AVATAR)
	if tex != null:
		sprite.texture = tex
		var sz := tex.get_size()
		var max_side := maxf(sz.x, sz.y)
		if max_side > 0.0:
			sprite.scale = Vector2.ONE * (SKILL_AV_W / max_side)
	rig.add_child(sprite)

func _run_cast(t: Tween) -> void:
	if skill_bar == null:
		return
	var rig := skill_bar.get_node_or_null(CAST_NODE) as Node2D
	if rig == null:
		return
	var home  := _home_anchor()
	var center := _board_center()
	# 1. 跳出：头像位 → 棋盘中央（抛物线感：先偏上再落中）
	t.tween_property(rig, "position", center + Vector2(0.0, -60.0), DUR_JUMP_OUT * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(rig, "position", center, DUR_JUMP_OUT * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 2. 蓄力停顿
	t.tween_interval(DUR_CHARGE)
	# 3. 挥动/缩放强调
	t.tween_property(rig, "scale", SWING_SCALE, DUR_SWING * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(rig, "scale", Vector2.ONE, DUR_SWING * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 4. 破障定格 → 效果落地
	t.tween_interval(DUR_HOLD)
	t.tween_callback(Callable(self, "_commit"))
	# 5. 跳回头像位
	t.tween_property(rig, "position", home + Vector2(0.0, -40.0), DUR_RETURN * 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(rig, "position", home, DUR_RETURN * 0.60).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(Callable(self, "_finish"))

func _apply_effect() -> bool:
	if board == null:
		return false
	var ok: bool = board.skill_break()
	if ok:
		_spawn_break_fx()
	return ok

func _restore_avatar() -> void:
	_set_avatar_casting(false)

func _dispose_visuals() -> void:
	if skill_bar == null:
		return
	var rig := skill_bar.get_node_or_null(CAST_NODE)
	if rig != null:
		if rig is CanvasItem:
			(rig as CanvasItem).visible = false
		_detach_and_free_later(rig)

# ───────── 破障特效 ─────────

func _spawn_break_fx() -> void:
	# 在棋盘中央附近触发爆炸特效，象征障碍被敲碎
	var center := _board_center_world()
	if not is_inside_tree():
		return
	# Fx 是 autoload，直接调用；power=1.4 略强于普通消除（1.2）
	if Engine.has_singleton("Fx"):
		Engine.get_singleton("Fx").spawn_explosion(center, Color(0.9, 0.7, 0.3, 1.0), 1.4)
	else:
		# Fx 不是 singleton 注册名，走 SceneTree 查 autoload
		var fx_node := get_tree().root.get_node_or_null("Fx") if is_inside_tree() else null
		if fx_node != null and fx_node.has_method("spawn_explosion"):
			fx_node.spawn_explosion(center, Color(0.9, 0.7, 0.3, 1.0), 1.4)

# ───────── 头像切换 / 节点回收 ─────────

func _set_avatar_casting(is_casting: bool) -> void:
	if not _set_avatar_casting_cb.is_null():
		_set_avatar_casting_cb.call(is_casting)

func _detach_and_free_later(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var was_inside := node.is_inside_tree()
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if was_inside:
		node.queue_free()
	else:
		node.free()

# ───────── 纹理工具 ─────────

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# ───────── 锚点几何 ─────────

func _home_anchor() -> Vector2:
	# slot 1（浣熊）的头像槽中心（与时兔 slot 0 对齐公式相同，偏移一个槽位）
	return Vector2(DESIGN_W * 1.5 / float(SLOT_COUNT), SKILL_AV_Y)

func _board_center() -> Vector2:
	# 棋盘中央在 skill_bar 设计坐标空间中的位置
	if board != null:
		var board_w := float(board.width) * cell_size
		var board_h := float(board.height) * cell_size
		return board_origin + Vector2(board_w * 0.5, board_h * 0.5)
	return Vector2(DESIGN_W * 0.5, 760.0)

func _board_center_world() -> Vector2:
	# 世界坐标（供 Fx autoload 使用——Fx 工作在 CanvasLayer 坐标空间，
	# skill_bar 是 CanvasLayer 所以设计坐标 = 世界坐标）
	return _board_center()
