shader_type canvas_item;
// 方向性中性高光: 沿 light_axis 方向, 在 light_pos 处最亮, 边缘补 rim light。
// 横摇=光左右扫(axis=(1,0)), 纵点头=光上下扫(axis=(0,1))。光在哪侧 → 棋子朝哪侧转的方向感。
// 只在棋子本体(alpha>0)上提亮, 不压暗、不把固定暖色加进原色, 避免蓝色宝石偏紫。

uniform vec2 light_axis = vec2(1.0, 0.0);                  // 横=(1,0) 纵=(0,1)
uniform float light_pos : hint_range(0.0, 1.0) = 0.5;      // 沿轴高光中心(代码驱动左右/上下扫)
uniform float light_w : hint_range(0.05, 1.0) = 0.55;      // 高光半宽(越小越聚拢)
uniform float light_strength : hint_range(0.0, 2.0) = 0.0; // 提亮强度
uniform vec3 light_tint : source_color = vec3(1.0, 1.0, 1.0); // 中性白光目标色
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;    // 外缘白边/弧面边缘光
uniform float bulge_strength : hint_range(0.0, 1.0) = 0.0;  // 中央鼓面感, 让高光像贴在弧面上
uniform float specular_strength : hint_range(0.0, 1.0) = 0.0; // 白色镜面热点强度
uniform float base_saturation : hint_range(0.0, 1.5) = 1.0; // 与普通棋子统一的基础饱和度

void fragment() {
	vec4 col = COLOR;
	vec3 base_gray = vec3(dot(col.rgb, vec3(0.299, 0.587, 0.114)));
	col.rgb = mix(base_gray, col.rgb, base_saturation);
	vec2 axis = normalize(light_axis);
	vec2 cross_axis = vec2(-axis.y, axis.x);
	float proj = dot(UV, axis);
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered * 2.0);
	float dome = clamp(1.0 - radius, 0.0, 1.0);
	vec2 dome_xy = centered * mix(0.95, 1.48, bulge_strength);
	float dome_z = sqrt(max(0.001, 1.0 - clamp(dot(dome_xy, dome_xy), 0.0, 0.98)));
	vec3 dome_normal = normalize(vec3(dome_xy * (0.70 + bulge_strength * 0.55), dome_z));
	float f = clamp(1.0 - abs(proj - light_pos) / light_w, 0.0, 1.0);
	f = f * f;  // 二次衰减, 高光更聚拢
	float turn = clamp((light_pos - 0.5) * 2.5, -1.0, 1.0);
	vec2 moving_light_xy = axis * turn * 0.62 + cross_axis * -0.24 + vec2(-0.16, -0.30);
	vec3 light_dir = normalize(vec3(moving_light_xy, 0.92));
	float normal_light = clamp(dot(dome_normal, light_dir), 0.0, 1.0);
	float curved_light = f * mix(0.62 + dome * 0.38, normal_light, bulge_strength);
	float rim = smoothstep(0.56, 0.98, length(centered * 2.0));
	float specular_shape = pow(clamp(f, 0.0, 1.0), 2.5) * pow(clamp(normal_light, 0.0, 1.0), 5.0) * (0.45 + dome * 0.55);
	float light_mix = clamp(curved_light * light_strength * col.a, 0.0, 0.66);
	vec3 hue_safe_light = col.rgb + col.rgb * light_mix * 0.82;
	col.rgb = min(hue_safe_light, vec3(1.0));
	vec3 soft_specular_tint = mix(col.rgb, light_tint, 0.24);
	col.rgb += soft_specular_tint * specular_shape * specular_strength * col.a;
	col.rgb += soft_specular_tint * rim * rim_strength * (0.35 + 0.65 * abs(turn)) * col.a;
	col.rgb = min(col.rgb, vec3(1.0));
	COLOR = col;
}
