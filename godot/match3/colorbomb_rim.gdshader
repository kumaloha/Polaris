shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(1.0, 0.90, 0.54, 0.92);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.80, 0.30, 0.72);
uniform float rim_radius : hint_range(0.20, 0.60) = 0.455;
uniform float rim_width : hint_range(0.005, 0.09) = 0.018;
uniform float flow_speed : hint_range(-2.0, 2.0) = 0.34;
uniform float spark_width : hint_range(0.01, 0.30) = 0.052;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float ring_outer = smoothstep(rim_radius + rim_width, rim_radius, dist);
	float ring_inner = smoothstep(rim_radius - rim_width, rim_radius, dist);
	float ring = ring_outer * ring_inner;

	float angle01 = fract((atan(centered.y, centered.x) + 3.14159265359) / 6.28318530718);
	float spark_angle = fract(TIME * flow_speed);
	float spark_delta = abs(fract(angle01 - spark_angle + 0.5) - 0.5);
	float spark = smoothstep(spark_width, 0.0, spark_delta);
	float trail = smoothstep(spark_width * 2.4, 0.0, spark_delta) * 0.22;
	float strand = ring * (spark + trail);

	vec3 ring_rgb = mix(secondary_color.rgb, rim_color.rgb, spark);
	ring_rgb += vec3(1.0, 0.92, 0.68) * spark * 0.55;
	float alpha = strand * (0.42 + spark * 0.58);
	COLOR = vec4(min(ring_rgb, vec3(1.0)), min(alpha, 1.0) * rim_color.a);
}
