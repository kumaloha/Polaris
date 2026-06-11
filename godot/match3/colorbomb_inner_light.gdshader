shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 light_color_0 : source_color = vec4(1.0, 0.10, 0.08, 0.48);
uniform vec4 light_color_1 : source_color = vec4(0.16, 0.92, 0.22, 0.46);
uniform vec4 light_color_2 : source_color = vec4(0.56, 0.20, 1.0, 0.48);
uniform vec4 light_color_3 : source_color = vec4(1.0, 0.24, 0.76, 0.46);
uniform vec4 light_color_4 : source_color = vec4(1.0, 0.88, 0.14, 0.42);
uniform vec4 light_color_5 : source_color = vec4(0.12, 0.54, 1.0, 0.48);
uniform float inner_radius : hint_range(0.12, 0.48) = 0.36;
uniform float cycle_seconds : hint_range(0.12, 2.0) = 0.56;

vec4 light_at(float index) {
	if (index < 0.5) {
		return light_color_0;
	}
	if (index < 1.5) {
		return light_color_1;
	}
	if (index < 2.5) {
		return light_color_2;
	}
	if (index < 3.5) {
		return light_color_3;
	}
	if (index < 4.5) {
		return light_color_4;
	}
	return light_color_5;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	centered.y *= 1.08;
	float dist = length(centered);
	float inner_mask = smoothstep(inner_radius, inner_radius * 0.26, dist);

	float phase = mod(TIME / max(cycle_seconds, 0.01), 6.0);
	float color_index = min(floor(phase), 5.0);
	float next_index = mod(color_index + 1.0, 6.0);
	float blend_t = smoothstep(0.18, 0.82, fract(phase));
	vec4 active = mix(light_at(color_index), light_at(next_index), blend_t);

	float diagonal = smoothstep(0.20, 0.0, abs(centered.x * 0.72 + centered.y * 0.42));
	float lens = smoothstep(0.24, 0.0, distance(UV, vec2(0.43, 0.43)));
	float pulse = 0.88 + 0.12 * sin(TIME * 6.28318530718 / max(cycle_seconds, 0.01));
	float alpha = (inner_mask * 0.92 + diagonal * inner_mask * 0.20 + lens * 0.14) * active.a * pulse * tex.a;

	COLOR = vec4(active.rgb, clamp(alpha, 0.0, 0.72));
}
