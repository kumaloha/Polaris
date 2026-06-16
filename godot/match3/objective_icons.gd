class_name ObjectiveIcons
extends RefCounted
## Shared generated objective/actor icons for mechanics that do not have final art yet.
## One source of truth keeps the board actor and HUD objective from drifting apart.

const DROP_RELIC_ASSET_KEY := "generated:drop_relic_lost_cub"
const GENERATED_ASSET_KEYS := {
	"target_mark": "generated:target_mark_mechanism",
	"crystal_shell": "generated:crystal_shell_mechanism",
	"drop_exit": "generated:drop_exit_nest_mechanism",
	"nest": "generated:drop_exit_nest_mechanism",
	"line_h_gem": "generated:line_h_gem_mechanism",
	"line_v_gem": "generated:line_v_gem_mechanism",
	"burst_gem": "generated:burst_gem_mechanism",
	"color_bomb_gem": "generated:color_bomb_gem_mechanism",
	"drop_relic": DROP_RELIC_ASSET_KEY,
}

const RING_OUTER := Color(0.98, 0.74, 0.22, 1.0)
const RING_INNER := Color(0.12, 0.56, 0.86, 1.0)
const RING_SHADOW := Color(0.05, 0.14, 0.28, 0.70)
const CUB_FUR := Color(0.94, 0.68, 0.34, 1.0)
const CUB_FUR_DARK := Color(0.62, 0.34, 0.15, 1.0)
const CUB_FACE := Color(1.0, 0.83, 0.52, 1.0)
const CUB_EYE := Color(0.05, 0.06, 0.08, 1.0)
const CUB_BLUSH := Color(1.0, 0.45, 0.42, 0.72)
const NEST := Color(0.28, 0.62, 0.24, 1.0)
const NEST_DARK := Color(0.11, 0.32, 0.13, 1.0)
const ARROW := Color(1.0, 1.0, 0.86, 1.0)
const SPARK := Color(1.0, 1.0, 1.0, 0.88)
const TARGET_BLUE := Color(0.18, 0.76, 1.0, 0.82)
const TARGET_CORE := Color(1.0, 0.98, 0.72, 0.96)
const CRYSTAL := Color(0.55, 0.92, 1.0, 0.78)
const CRYSTAL_DARK := Color(0.18, 0.38, 0.72, 0.74)
const SPECIAL_RED := Color(1.0, 0.26, 0.28, 1.0)
const SPECIAL_GOLD := Color(1.0, 0.82, 0.22, 1.0)
const SPECIAL_PURPLE := Color(0.65, 0.28, 1.0, 1.0)
const SPECIAL_CYAN := Color(0.24, 0.86, 1.0, 1.0)

static var _drop_relic_cache: Dictionary = {}
static var _mechanism_cache: Dictionary = {}

static func asset_key_for_mechanism(mechanic_id: String) -> String:
	var id := _normalize_mechanism_id(mechanic_id)
	return String(GENERATED_ASSET_KEYS.get(id, "generated:%s_mechanism" % id))

static func texture_for_mechanism(mechanic_id: String, size: int = 96) -> Texture2D:
	var id := _normalize_mechanism_id(mechanic_id)
	if id == "drop_relic":
		return drop_relic_texture(size)
	var px: int = clampi(size, 32, 256)
	var key := "%s:%d" % [id, px]
	if _mechanism_cache.has(key):
		return _mechanism_cache[key]
	var img: Image = Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_mechanism(img, id, px)
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_mechanism_cache[key] = tex
	return tex

static func _normalize_mechanism_id(mechanic_id: String) -> String:
	var id := mechanic_id.strip_edges().to_lower()
	match id:
		"drop_exit", "nest":
			return id
		"jelly", "clear_jelly":
			return "target_mark"
		"coat", "blocker", "clear_blocker":
			return "crystal_shell"
		"ingredient", "collect_ingredient":
			return "drop_relic"
		_:
			return id

static func drop_relic_texture(size: int = 96) -> Texture2D:
	var px: int = clampi(size, 32, 256)
	if _drop_relic_cache.has(px):
		return _drop_relic_cache[px]
	var img: Image = Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_drop_relic(img, px)
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_drop_relic_cache[px] = tex
	return tex

static func _draw_drop_relic(img: Image, size: int) -> void:
	var cx := size * 0.5
	var cy := size * 0.5
	# Magical objective badge / readable silhouette.
	_fill_circle(img, cx, cy + size * 0.035, size * 0.46, RING_SHADOW)
	_fill_circle(img, cx, cy, size * 0.45, RING_OUTER)
	_fill_circle(img, cx, cy, size * 0.38, RING_INNER)
	_fill_circle(img, cx - size * 0.14, cy - size * 0.13, size * 0.055, SPARK)
	_fill_circle(img, cx + size * 0.18, cy - size * 0.20, size * 0.035, SPARK)
	# Lost cub: ears + head, clearly not a normal gem.
	_fill_triangle(img, Vector2(cx - size * 0.24, cy - size * 0.10), Vector2(cx - size * 0.10, cy - size * 0.34), Vector2(cx - size * 0.03, cy - size * 0.08), CUB_FUR_DARK)
	_fill_triangle(img, Vector2(cx + size * 0.24, cy - size * 0.10), Vector2(cx + size * 0.10, cy - size * 0.34), Vector2(cx + size * 0.03, cy - size * 0.08), CUB_FUR_DARK)
	_fill_circle(img, cx, cy - size * 0.05, size * 0.235, CUB_FUR)
	_fill_circle(img, cx, cy + size * 0.005, size * 0.145, CUB_FACE)
	_fill_circle(img, cx - size * 0.075, cy - size * 0.055, size * 0.020, CUB_EYE)
	_fill_circle(img, cx + size * 0.075, cy - size * 0.055, size * 0.020, CUB_EYE)
	_fill_circle(img, cx, cy + size * 0.010, size * 0.020, CUB_FUR_DARK)
	_fill_circle(img, cx - size * 0.105, cy + size * 0.025, size * 0.030, CUB_BLUSH)
	_fill_circle(img, cx + size * 0.105, cy + size * 0.025, size * 0.030, CUB_BLUSH)
	# Down/home affordance: clear below the cub so it falls into the nest/exit.
	_fill_rect(img, Rect2(cx - size * 0.035, cy + size * 0.145, size * 0.07, size * 0.125), ARROW)
	_fill_triangle(img, Vector2(cx - size * 0.105, cy + size * 0.245), Vector2(cx + size * 0.105, cy + size * 0.245), Vector2(cx, cy + size * 0.355), ARROW)
	_fill_ellipse(img, cx, cy + size * 0.34, size * 0.21, size * 0.07, NEST_DARK)
	_fill_ellipse(img, cx, cy + size * 0.315, size * 0.18, size * 0.050, NEST)

static func _draw_mechanism(img: Image, id: String, size: int) -> void:
	match id:
		"target_mark":
			_draw_target_mark(img, size)
		"crystal_shell":
			_draw_crystal_shell(img, size)
		"drop_exit", "nest":
			_draw_drop_exit(img, size)
		"line_h_gem":
			_draw_special_gem(img, size, Vector2.RIGHT)
		"line_v_gem":
			_draw_special_gem(img, size, Vector2.DOWN)
		"burst_gem":
			_draw_burst_gem(img, size)
		"color_bomb_gem":
			_draw_color_bomb_gem(img, size)
		_:
			_draw_target_mark(img, size)

static func _draw_target_mark(img: Image, size: int) -> void:
	var c := Vector2(size * 0.5, size * 0.5)
	_fill_circle(img, c.x, c.y + size * 0.035, size * 0.40, Color(0.02, 0.08, 0.18, 0.34))
	for radius in [0.39, 0.29, 0.18]:
		_fill_circle(img, c.x, c.y, size * float(radius), TARGET_BLUE)
		_fill_circle(img, c.x, c.y, size * (float(radius) - 0.035), Color(0, 0, 0, 0))
	_fill_circle(img, c.x, c.y, size * 0.082, TARGET_CORE)
	_fill_rect(img, Rect2(c.x - size * 0.035, c.y - size * 0.44, size * 0.07, size * 0.18), TARGET_CORE)
	_fill_rect(img, Rect2(c.x - size * 0.035, c.y + size * 0.26, size * 0.07, size * 0.18), TARGET_CORE)
	_fill_rect(img, Rect2(c.x - size * 0.44, c.y - size * 0.035, size * 0.18, size * 0.07), TARGET_CORE)
	_fill_rect(img, Rect2(c.x + size * 0.26, c.y - size * 0.035, size * 0.18, size * 0.07), TARGET_CORE)

static func _draw_crystal_shell(img: Image, size: int) -> void:
	var c := Vector2(size * 0.5, size * 0.5)
	_fill_circle(img, c.x, c.y + size * 0.035, size * 0.40, Color(0.02, 0.06, 0.16, 0.36))
	var pts := [
		Vector2(c.x, c.y - size * 0.43),
		Vector2(c.x + size * 0.36, c.y - size * 0.12),
		Vector2(c.x + size * 0.28, c.y + size * 0.34),
		Vector2(c.x - size * 0.28, c.y + size * 0.34),
		Vector2(c.x - size * 0.36, c.y - size * 0.12),
	]
	_fill_poly(img, pts, CRYSTAL_DARK)
	_fill_poly(img, [
		Vector2(c.x, c.y - size * 0.36),
		Vector2(c.x + size * 0.27, c.y - size * 0.09),
		Vector2(c.x + size * 0.20, c.y + size * 0.25),
		Vector2(c.x - size * 0.20, c.y + size * 0.25),
		Vector2(c.x - size * 0.27, c.y - size * 0.09),
	], CRYSTAL)
	_fill_triangle(img, Vector2(c.x, c.y - size * 0.34), Vector2(c.x + size * 0.10, c.y + size * 0.24), Vector2(c.x - size * 0.04, c.y + size * 0.24), Color(1.0, 1.0, 1.0, 0.28))
	_fill_rect(img, Rect2(c.x - size * 0.30, c.y - size * 0.03, size * 0.60, size * 0.055), Color(1.0, 1.0, 1.0, 0.24))

static func _draw_drop_exit(img: Image, size: int) -> void:
	var c := Vector2(size * 0.5, size * 0.5)
	_fill_ellipse(img, c.x, c.y + size * 0.25, size * 0.34, size * 0.14, NEST_DARK)
	_fill_ellipse(img, c.x, c.y + size * 0.20, size * 0.30, size * 0.10, NEST)
	_fill_rect(img, Rect2(c.x - size * 0.045, c.y - size * 0.35, size * 0.09, size * 0.34), ARROW)
	_fill_triangle(img, Vector2(c.x - size * 0.18, c.y - size * 0.04), Vector2(c.x + size * 0.18, c.y - size * 0.04), Vector2(c.x, c.y + size * 0.16), ARROW)
	_fill_circle(img, c.x - size * 0.18, c.y + size * 0.21, size * 0.035, SPARK)
	_fill_circle(img, c.x + size * 0.18, c.y + size * 0.21, size * 0.035, SPARK)

static func _draw_special_gem(img: Image, size: int, dir: Vector2) -> void:
	var c := Vector2(size * 0.5, size * 0.5)
	_fill_diamond(img, c, size * 0.34, SPECIAL_CYAN)
	_fill_diamond(img, c, size * 0.25, Color(0.18, 0.36, 0.96, 1.0))
	if absf(dir.x) > absf(dir.y):
		_fill_rect(img, Rect2(c.x - size * 0.40, c.y - size * 0.045, size * 0.80, size * 0.09), SPECIAL_GOLD)
		_fill_triangle(img, Vector2(c.x + size * 0.42, c.y), Vector2(c.x + size * 0.26, c.y - size * 0.11), Vector2(c.x + size * 0.26, c.y + size * 0.11), SPECIAL_GOLD)
		_fill_triangle(img, Vector2(c.x - size * 0.42, c.y), Vector2(c.x - size * 0.26, c.y - size * 0.11), Vector2(c.x - size * 0.26, c.y + size * 0.11), SPECIAL_GOLD)
	else:
		_fill_rect(img, Rect2(c.x - size * 0.045, c.y - size * 0.40, size * 0.09, size * 0.80), SPECIAL_GOLD)
		_fill_triangle(img, Vector2(c.x, c.y - size * 0.42), Vector2(c.x - size * 0.11, c.y - size * 0.26), Vector2(c.x + size * 0.11, c.y - size * 0.26), SPECIAL_GOLD)
		_fill_triangle(img, Vector2(c.x, c.y + size * 0.42), Vector2(c.x - size * 0.11, c.y + size * 0.26), Vector2(c.x + size * 0.11, c.y + size * 0.26), SPECIAL_GOLD)

static func _draw_burst_gem(img: Image, size: int) -> void:
	var c := Vector2(size * 0.5, size * 0.5)
	_fill_diamond(img, c, size * 0.32, SPECIAL_RED)
	_fill_circle(img, c.x, c.y, size * 0.17, SPECIAL_GOLD)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var p := c + Vector2.RIGHT.rotated(a) * size * 0.39
		_fill_triangle(img, c + Vector2.RIGHT.rotated(a - 0.20) * size * 0.19, c + Vector2.RIGHT.rotated(a + 0.20) * size * 0.19, p, ARROW)

static func _draw_color_bomb_gem(img: Image, size: int) -> void:
	var c := Vector2(size * 0.5, size * 0.5)
	_fill_circle(img, c.x, c.y, size * 0.35, Color(0.08, 0.06, 0.16, 1.0))
	var colors: Array[Color] = [SPECIAL_RED, SPECIAL_GOLD, SPECIAL_CYAN, NEST, SPECIAL_PURPLE, Color(1.0, 0.36, 0.72, 1.0)]
	for i in range(6):
		var a := TAU * float(i) / 6.0
		var col: Color = colors[i]
		_fill_circle(img, c.x + cos(a) * size * 0.17, c.y + sin(a) * size * 0.17, size * 0.105, col)
	_fill_circle(img, c.x, c.y, size * 0.09, SPARK)

static func _fill_circle(img: Image, cx: float, cy: float, radius: float, color: Color) -> void:
	var min_x: int = maxi(0, int(floor(cx - radius)))
	var max_x: int = mini(img.get_width() - 1, int(ceil(cx + radius)))
	var min_y: int = maxi(0, int(floor(cy - radius)))
	var max_y: int = mini(img.get_height() - 1, int(ceil(cy + radius)))
	var rr := radius * radius
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy <= rr:
				img.set_pixel(x, y, color)

static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	var min_x: int = maxi(0, int(floor(cx - rx)))
	var max_x: int = mini(img.get_width() - 1, int(ceil(cx + rx)))
	var min_y: int = maxi(0, int(floor(cy - ry)))
	var max_y: int = mini(img.get_height() - 1, int(ceil(cy + ry)))
	if rx <= 0.0 or ry <= 0.0:
		return
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)

static func _fill_rect(img: Image, rect: Rect2, color: Color) -> void:
	var min_x: int = maxi(0, int(floor(rect.position.x)))
	var max_x: int = mini(img.get_width() - 1, int(ceil(rect.position.x + rect.size.x)))
	var min_y: int = maxi(0, int(floor(rect.position.y)))
	var max_y: int = mini(img.get_height() - 1, int(ceil(rect.position.y + rect.size.y)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			img.set_pixel(x, y, color)

static func _fill_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x: int = maxi(0, int(floor(minf(a.x, minf(b.x, c.x)))))
	var max_x: int = mini(img.get_width() - 1, int(ceil(maxf(a.x, maxf(b.x, c.x)))))
	var min_y: int = maxi(0, int(floor(minf(a.y, minf(b.y, c.y)))))
	var max_y: int = mini(img.get_height() - 1, int(ceil(maxf(a.y, maxf(b.y, c.y)))))
	var area := _edge(a, b, c)
	if absf(area) <= 0.001:
		return
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(float(x), float(y))
			var w0 := _edge(b, c, p)
			var w1 := _edge(c, a, p)
			var w2 := _edge(a, b, p)
			if (w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0) or (w0 <= 0.0 and w1 <= 0.0 and w2 <= 0.0):
				img.set_pixel(x, y, color)

static func _fill_diamond(img: Image, center: Vector2, radius: float, color: Color) -> void:
	_fill_poly(img, [
		Vector2(center.x, center.y - radius),
		Vector2(center.x + radius, center.y),
		Vector2(center.x, center.y + radius),
		Vector2(center.x - radius, center.y),
	], color)

static func _fill_poly(img: Image, points: Array, color: Color) -> void:
	if points.size() < 3:
		return
	for i in range(1, points.size() - 1):
		_fill_triangle(img, points[0], points[i], points[i + 1], color)

static func _edge(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x)
