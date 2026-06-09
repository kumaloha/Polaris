shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.5) = 0.86;

void fragment() {
	vec4 col = COLOR;
	vec3 gray = vec3(dot(col.rgb, vec3(0.299, 0.587, 0.114)));
	col.rgb = mix(gray, col.rgb, saturation);
	COLOR = col;
}
