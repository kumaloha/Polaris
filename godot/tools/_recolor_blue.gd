extends SceneTree
# 把新 elim 素材里非蓝的有色像素(粉/黄/紫环、星星、爪印)统一染成蓝色相,
# 保留白光核(低饱和不动)与各像素明暗/alpha; 输出覆盖旧蓝色 elim 素材。
const BASE := "/Users/kuma/Projects/Polaris/"
const BLUE_HUE := 0.60   # 目标蓝色相(青蓝, 对齐宝石蓝)
const SAT_GATE := 0.12   # 饱和度>此值=有色像素→染蓝; 以下=白/灰核, 保留

func _recolor(src: String, dst: String) -> void:
	var img := Image.load_from_file(src)
	if img == null:
		print("LOAD FAIL ", src); return
	var w := img.get_width(); var h := img.get_height()
	var changed := 0
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if c.s > SAT_GATE:
				# 只改色相, 保留饱和度/明度/alpha → 粉黄紫全部变蓝, 蓝保持蓝
				img.set_pixel(x, y, Color.from_hsv(BLUE_HUE, c.s, c.v, c.a))
				changed += 1
	var err := img.save_png(dst)
	print("%s -> %s  改色像素=%d err=%d" % [src.get_file(), dst.get_file(), changed, err])

func _initialize() -> void:
	_recolor(BASE + "resources/fx_out/blue_charge_additive.png",    BASE + "godot/assets/fx/elim/gem_blue_charge_up_additive.png")
	_recolor(BASE + "resources/fx_out/blue_burst_additive.png",     BASE + "godot/assets/fx/elim/gem_blue_burst_additive.png")
	_recolor(BASE + "resources/fx_out/blue_dissipate_additive.png", BASE + "godot/assets/fx/elim/gem_blue_dissipate_additive.png")
	print("DONE")
	quit()
