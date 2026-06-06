shader_type canvas_item;
render_mode blend_add;  // 加性混合: 金光叠加发亮, 不挡背景(等效 CanvasItemMaterial 的 Add)

uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.35, 1.0); // 金色
uniform float speed = 0.25;        // 流动速度, 越小越缓(连贯纯横移)
uniform float intensity = 0.35;    // 整体强度(透明度上限), 低调
uniform float band_scale = 2.5;    // 光带数量/疏密

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	// 纯横向平移: 所有项都是 phase 的函数, t 增大→整条光带连贯匀速横移(无逆向干涉/闪烁)
	// 竖向轻微弯曲(静态, 仅依赖 uv.y)增加自然感, 不破坏连贯
	float phase = uv.x * band_scale + t + 0.12 * sin(uv.y * 3.14159);
	float wave = sin(phase * 3.14159) + 0.5 * sin(phase * 1.7 * 3.14159 + 1.3);
	wave = wave / 1.5 * 0.5 + 0.5; // 归一到 0..1
	// 垂直方向柔和衰减(中间亮, 上下淡)
	float vfade = smoothstep(0.0, 0.4, uv.y) * smoothstep(1.0, 0.6, uv.y);
	float a = wave * vfade * intensity;
	COLOR = vec4(glow_color.rgb, glow_color.a * a);
}
