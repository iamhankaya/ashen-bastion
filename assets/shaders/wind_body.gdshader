shader_type canvas_item;
// Hortum/Tufan gövdesi: merkez saydam, kenar şeritleri görünür kalır (arkadaki düşman/küre okunur). Tepe rengi: rgb = harita
// uyumu çarpanı (ZyfenFx.grade), a = bölge saydamlığı. Huni genişliği tahmini akış gölgelendiricisiyle aynıdır.

uniform float body_foot = 0.87;
uniform float body_span = 0.69;
uniform float center_alpha = 0.45;
uniform float grade_sat = 1.0;

varying vec4 inst;

void vertex() {
	inst = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float h = clamp((body_foot - UV.y) / body_span, 0.0, 1.0);
	float half_w = 0.41 * (0.18 + 0.82 * h);
	float c = clamp(abs(UV.x - 0.5) / max(half_w, 0.02), 0.0, 1.0);
	float edge = mix(center_alpha, 1.0, smoothstep(0.15, 0.85, c));
	vec3 rgb = mix(vec3(dot(tex.rgb, vec3(0.299, 0.587, 0.114))), tex.rgb, grade_sat);
	COLOR = vec4(rgb * inst.rgb, tex.a * inst.a * edge);
}
