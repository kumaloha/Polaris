extends SceneTree
# 一次性生成 beam_comet_white.png(纯白流星拖尾, 行列横扫波素材)。
# 跑: godot --headless --path godot -s res://tools/gen_comet.gd
# save_png 是纯 CPU, headless 可用(无需 GPU)。

func _init() -> void:
	var W := 256
	var H := 64
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var cy := (H - 1) / 2.0
	var head := W - 1                       # 头(密亮)在右端, 向左拖尾稀疏淡出
	var sigma := H * 0.20
	for y in range(H):
		var yb: float = exp(-pow(y - cy, 2.0) / (2.0 * sigma * sigma))   # 中间厚两边薄
		for x in range(W):
			var tail: float = exp(-float(head - x) / 78.0)               # 沿长指数拖尾
			var hd: float = sqrt(pow(x - head, 2.0) + pow(y - cy, 2.0))
			var core: float = tail * yb + exp(-pow(hd / 20.0, 2.0))       # 头部聚焦亮核
			img.set_pixel(x, y, Color(1, 1, 1, minf(core, 1.0)))         # 纯白, modulate 染色
	var path := ProjectSettings.globalize_path("res://assets/fx/beam_comet_white.png")
	var err := img.save_png(path)
	print("save_png err=", err, " path=", path)
	quit()
