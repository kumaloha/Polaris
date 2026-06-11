class_name BombOverlay
extends OverlayBase
## 炸弹倒计时 Overlay（契约 B §3.5 最复杂形态）。
## 没有现成 bomb 素材, 程序绘制: 深色圆 + 数字 Label。
## TEXTURE_PATH 预留, 有素材时换图。
##
## bomb tick 不经 account（每步在 board._settle_consumed_move）→ refresh() 自查模式（§3.5）。
## 数值 ≤3 红闪 tween（绑自身节点）。
## on_step 末尾 board_view 额外调一次 refresh() 刷 Label。

# ── 素材占位 ──
const TEXTURE_PATH := ""   # 炸弹底图路径（空=程序绘制）

# ── 程序绘制颜色 ──
const COLOR_BODY    := Color(0.12, 0.10, 0.10, 0.90)   # 深灰近黑
const COLOR_FUSE    := Color(0.85, 0.65, 0.10, 1.0)    # 导线黄
const COLOR_NORMAL  := Color(1.0, 1.0, 1.0, 1.0)        # 正常白字
const COLOR_DANGER  := Color(1.0, 0.18, 0.18, 1.0)      # 危险红字

# ── 红闪阈值 / 时长 ──
const DANGER_THRESHOLD := 3
const FLASH_DURATION   := 0.20
const FADE_DURATION    := 0.22

var _sprite: Sprite2D
var _label: Label
var _flash_tween: Tween = null
var _last_value: int = 0

# ── static 元信息 ──

static func layer_key() -> String:
	return "bomb"

static func z_band() -> int:
	return Z_BOMB   # 6: 倒计时 Label

# ── 生命周期 ──

func setup(p_cell: Vector2i, p_board, p_cell_px: float) -> void:
	super(p_cell, p_board, p_cell_px)
	_build_visuals()
	_last_value = current_value()
	_update_display(_last_value)

func on_step(report: Dictionary) -> void:
	# bomb 被消除拆弹时 account.bomb_defused > 0
	var account: Dictionary = report.get("account", {})
	if account.get("bomb_defused", 0) > 0:
		var new_val := current_value()
		if new_val <= 0:
			on_cleared()
			return
	# 无论是否消除, 最后都 refresh 以获取 tick 后最新值
	refresh()

## board_view 在 play_step 末尾额外调用（§3.5 自查模式）。
## 不依赖 on_step 通知——自查 current_value, 刷 Label + 触发危险提示。
func refresh() -> void:
	var val := current_value()
	if val <= 0:
		return
	_update_display(val)
	if val < _last_value:
		_trigger_tick_animation(val)
	_last_value = val

func on_cleared() -> void:
	if not is_inside_tree():
		queue_free()
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.4, 1.4), 0.08)
	t.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	t.tween_callback(queue_free)

# ── 内部 ──

func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = _make_body_texture()
	add_child(_sprite)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var lsize := int(_cell_px * 0.55)
	if lsize < 18:
		lsize = 18
	_label.size = Vector2(lsize, lsize)
	_label.position = Vector2(-lsize * 0.5, -lsize * 0.5)
	# 字体大小用 add_theme_font_size_override
	var font_size := int(_cell_px * 0.38)
	if font_size < 12:
		font_size = 12
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", COLOR_NORMAL)
	_label.z_index = 1
	add_child(_label)

func _update_display(value: int) -> void:
	if _label == null:
		return
	_label.text = str(value)
	if value <= DANGER_THRESHOLD:
		_label.add_theme_color_override("font_color", COLOR_DANGER)
	else:
		_label.add_theme_color_override("font_color", COLOR_NORMAL)

func _trigger_tick_animation(value: int) -> void:
	if not is_inside_tree():
		return
	# 杀掉上一个还在播的闪烁 tween
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
		modulate = Color.WHITE
		scale = Vector2.ONE
	if value <= DANGER_THRESHOLD:
		# 危险红闪: 快速放大缩回 + 短暂变红
		_flash_tween = create_tween()
		_flash_tween.set_parallel(true)
		_flash_tween.tween_property(self, "scale", Vector2(1.18, 1.18), FLASH_DURATION * 0.4)
		_flash_tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3, 1.0), FLASH_DURATION * 0.4)
		_flash_tween.chain()
		_flash_tween.set_parallel(true)
		_flash_tween.tween_property(self, "scale", Vector2.ONE, FLASH_DURATION * 0.6)
		_flash_tween.tween_property(self, "modulate", Color.WHITE, FLASH_DURATION * 0.6)
	else:
		# 普通轻微抖动
		_flash_tween = create_tween()
		_flash_tween.tween_property(self, "scale", Vector2(1.08, 1.08), FLASH_DURATION * 0.35)
		_flash_tween.tween_property(self, "scale", Vector2.ONE, FLASH_DURATION * 0.65)

func _make_body_texture() -> ImageTexture:
	# 优先用声明的贴图路径
	if TEXTURE_PATH != "" and ResourceLoader.exists(TEXTURE_PATH):
		return load(TEXTURE_PATH)
	# 程序绘制: 深色圆 + 导线
	var size := int(_cell_px * 0.75)
	if size <= 0:
		size = 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := size * 0.5
	var cy := size * 0.5
	var radius := size * 0.42
	# 画圆体
	for y in size:
		for x in size:
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, COLOR_BODY)
	# 画导线（右上方短线）
	var fuse_len := int(size * 0.22)
	for i in fuse_len:
		var fx := int(cx + radius * 0.68 + i * 0.6)
		var fy := int(cy - radius * 0.55 - i * 0.7)
		fx = clamp(fx, 0, size - 1)
		fy = clamp(fy, 0, size - 1)
		img.set_pixel(fx, fy, COLOR_FUSE)
		if fy - 1 >= 0:
			img.set_pixel(fx, fy - 1, COLOR_FUSE)
	return ImageTexture.create_from_image(img)
