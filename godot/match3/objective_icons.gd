class_name ObjectiveIcons
extends RefCounted
## Shared generated objective/actor icons for mechanics that do not have final art yet.
## One source of truth keeps the board actor and HUD objective from drifting apart.

const DROP_RELIC_ASSET_KEY := "generated:drop_relic_lost_cub"

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

static var _drop_relic_cache: Dictionary = {}

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

static func _edge(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x)
