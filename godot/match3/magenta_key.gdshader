shader_type canvas_item;
// 品红(magenta)背景抠除：去掉接近品红的像素(软边羽化)。给 AI 生成的 boss/avatar 立绘(品红底)去背。
// 品红与紫火焰在 RGB 空间距离够远，tolerance 取中等即可保留主体、只吃背景。
uniform vec3 key_color = vec3(0.93, 0.06, 0.75);
uniform float tolerance : hint_range(0.0, 1.0) = 0.34;
uniform float softness : hint_range(0.0, 0.5) = 0.10;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float d = distance(tex.rgb, key_color);
	float keep = smoothstep(tolerance, tolerance + softness, d);
	COLOR = vec4(tex.rgb, tex.a * keep);
}
