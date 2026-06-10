shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(1.0, 0.52, 0.02, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.00, 0.58, 1.0, 1.0);
uniform float rim_radius : hint_range(0.20, 0.60) = 0.425;
uniform float rim_width : hint_range(0.005, 0.09) = 0.064;
uniform float flow_speed : hint_range(-2.0, 2.0) = 0.34;
uniform float spark_width : hint_range(0.01, 0.30) = 0.090;

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
	float second_spark_delta = abs(fract(angle01 - spark_angle - 0.38 + 0.5) - 0.5);
	float second_spark = smoothstep(spark_width * 0.58, 0.0, second_spark_delta) * 0.62;
	float trail = smoothstep(spark_width * 2.6, 0.0, spark_delta) * 0.34;
	float soft_halo = smoothstep(rim_radius + rim_width * 2.1, rim_radius, dist) * smoothstep(rim_radius - rim_width * 2.4, rim_radius, dist);
	float ripple = 0.5 + 0.5 * sin(angle01 * 37.6991118431 - TIME * 3.4);

	vec3 ring_rgb = mix(secondary_color.rgb, rim_color.rgb, 0.56 + 0.26 * ripple);
	ring_rgb = mix(ring_rgb * 0.58, ring_rgb, ring);
	ring_rgb += vec3(1.0, 0.88, 0.50) * spark * 0.82;
	ring_rgb += vec3(0.25, 0.88, 1.0) * second_spark * 0.62;
	float alpha = soft_halo * 0.28 + ring * (0.78 + ripple * 0.14 + trail + spark * 0.90 + second_spark * 0.64);
	COLOR = vec4(min(ring_rgb, vec3(1.0)), min(alpha, 1.0) * rim_color.a);
}
