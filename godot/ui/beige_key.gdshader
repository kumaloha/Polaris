shader_type canvas_item;

uniform float tolerance : hint_range(0.0, 1.0) = 0.22;
uniform float softness : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 key = vec3(0.94, 0.84, 0.67);
	float d = distance(tex.rgb, key);
	float keep = smoothstep(tolerance, tolerance + softness, d);
	float pale = smoothstep(0.08, 0.22, max(max(tex.r, tex.g), tex.b) - min(min(tex.r, tex.g), tex.b));
	float dark_keep = smoothstep(0.62, 0.40, max(max(tex.r, tex.g), tex.b));
	COLOR = vec4(tex.rgb, tex.a * max(keep, max(pale, dark_keep)));
}
