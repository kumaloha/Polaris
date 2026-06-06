shader_type canvas_item;
// 米色框做旧: 斑驳污渍 + 边缘磨损 + 泛黄, 全程序化无需额外贴图。强度均可调。

uniform float edge_darken : hint_range(0.0, 1.0) = 0.5;   // 边缘磨损变暗
uniform float edge_lighten : hint_range(0.0, 2.0) = 0.0;  // 边缘提亮(抵消贴图烤进去的暗边/阴影)
uniform float mottle : hint_range(0.0, 1.0) = 0.30;       // 斑驳污渍强度
uniform float sepia : hint_range(0.0, 1.0) = 0.25;        // 泛黄做旧
uniform float noise_scale : hint_range(1.0, 20.0) = 7.0;  // 斑驳颗粒密度

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	// 1. 斑驳: fbm 噪声压暗局部, 形成水渍/霉斑
	float n = fbm(UV * noise_scale);
	col.rgb *= mix(1.0, 0.78, mottle * smoothstep(0.35, 0.75, n));
	// 2. 边缘处理(矩形 vignette)
	vec2 d = abs(UV - vec2(0.5)) * 2.0;
	float edge = max(d.x, d.y);
	// 2a. 提亮边缘: 抵消贴图自带的暗边(阴影感)
	col.rgb *= mix(1.0, 1.0 + edge_lighten, smoothstep(0.45, 1.0, edge));
	// 2b. 边缘磨损(默认 0)
	col.rgb *= mix(1.0, 1.0 - edge_darken, smoothstep(0.55, 1.0, edge));
	// 3. 泛黄做旧: 轻微 sepia
	float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sep = vec3(g) * vec3(1.08, 0.94, 0.74);
	col.rgb = mix(col.rgb, sep, sepia);
	COLOR = col;
}
