shader_type canvas_item;
// 近白背景抠除：把接近白色的像素变透明(软边)。给无 alpha 的角色立绘(白底)当临时抠图，
// 让萌宠浮在占星背景上。阈值偏高→只吃掉纯白背景，保留金/红/彩等主体色。
uniform float threshold : hint_range(0.0, 1.0) = 0.82;
uniform float softness : hint_range(0.001, 0.4) = 0.10;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = min(c.r, min(c.g, c.b));   // 越接近白，三通道最小值越高
	float keyed = smoothstep(threshold, threshold + softness, m);
	COLOR = vec4(c.rgb, c.a * (1.0 - keyed));
}
