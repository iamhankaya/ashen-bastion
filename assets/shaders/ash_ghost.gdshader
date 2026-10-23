shader_type canvas_item;
// Ölüm "hayaleti": canlı düşmanın son görüntüsü kül olarak dağılır (E6). Enemy atlas dokusu ve cell_rect enemy_flash ile aynıdır.
// INSTANCE_CUSTOM: r = yaş 0..1, g = atlas hücre indeksi, b = kontur kalınlığı (doku pikseli), a = tohum (0..1; < 0 = LOD düz solma).
// Örnek rengi COLOR: rgb = tür tonu, a = çözülme başlangıcı (yaşın hangi kesrinde kül başlar).
// Kül: gürültü eşiği (doku değil, UV karması) yaşla yükselir; eşiğe yakın 0,06'lık kenar amber #E8A24A, gövde kül #3A322E'ye döner.
#include "res://assets/shaders/rim.gdshaderinc"

uniform sampler2D atlas_tex : source_color, filter_linear;
uniform vec4 cell_rect[16];
uniform vec3 rim_color : source_color = vec3(0.74, 0.64, 0.47);
uniform vec3 ash_color : source_color = vec3(0.227, 0.196, 0.18);
uniform vec3 edge_color : source_color = vec3(0.91, 0.635, 0.29);
uniform float grid = 22.0;

varying float v_age;
varying float v_seed;
varying float v_start;
varying float v_rim_px;
varying vec3 v_tint;
varying vec2 v_local;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	v_age = INSTANCE_CUSTOM.r;
	v_rim_px = INSTANCE_CUSTOM.b;
	v_seed = INSTANCE_CUSTOM.a;
	v_start = COLOR.a;
	v_tint = COLOR.rgb;
	v_local = UV;
	int cell = int(floor(INSTANCE_CUSTOM.g + 0.5));
	vec4 r = cell_rect[cell];
	UV = r.xy + UV * r.zw;
}

void fragment() {
	vec4 t = texture(atlas_tex, UV);
	t.a = smoothstep(0.05, 0.75, t.a);
	vec4 c = apply_rim(atlas_tex, UV, TEXTURE_PIXEL_SIZE, vec4(t.rgb * v_tint, t.a), rim_color, v_rim_px);
	float age = clamp(v_age, 0.0, 1.0);
	if (v_seed < 0.0) {
		// LOD: 150 ms düz solma
		COLOR = vec4(c.rgb, c.a * (1.0 - age));
	} else {
		float front = clamp((age - v_start) / max(1.0 - v_start, 0.01), 0.0, 1.0);
		float n = hash21(floor(v_local * grid) + v_seed * 17.0);
		float d = n - front * 1.12 + 0.06;
		float edge = 1.0 - smoothstep(0.0, 0.06, d);
		vec3 rgb = mix(c.rgb, ash_color, smoothstep(0.0, 0.7, front));
		rgb = mix(rgb, edge_color, edge * step(0.001, front) * 0.9);
		COLOR = vec4(rgb, c.a * step(0.0, d));
	}
}
