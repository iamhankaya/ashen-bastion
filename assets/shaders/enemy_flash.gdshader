shader_type canvas_item;
// Düşman MultiMesh'i: tek atlas dokusu, örnek başına INSTANCE_CUSTOM:
//   r = vurulma parlaması (0..1), g = atlas hücre indeksi, b = kontur kalınlığı (doku pikseli),
//   a = elit işareti (0/1; elitte kontur rengi ve gövde tonu örnek rengidir).
// Örnek rengin alfası (COLOR.a) alfa çarpanıdır: hayalet türü 0,9–1,0 (v1.1).
// gl_compatibility'de çalıştığı U1-7 prototipiyle doğrulandı (docs/dev/perf.md "Render notları (U1-7)").
#include "res://assets/shaders/rim.gdshaderinc"

// Atlas dokusu betikten de verilir (TEXTURE yerleşiği işlev bağımsız değişkeni olamaz).
uniform sampler2D atlas_tex : source_color, filter_linear;
uniform vec4 cell_rect[16];  // hücre başına atlas UV dikdörtgeni (u0, v0, du, dv)
uniform vec3 rim_color : source_color = vec3(0.74, 0.64, 0.47);

varying float v_flash;
varying float v_rim_px;
varying float v_elite;
varying vec3 v_tint;
varying float v_alpha;

void vertex() {
	v_flash = INSTANCE_CUSTOM.r;
	v_rim_px = INSTANCE_CUSTOM.b;
	v_elite = INSTANCE_CUSTOM.a;
	v_tint = COLOR.rgb;
	v_alpha = COLOR.a;
	int cell = int(floor(INSTANCE_CUSTOM.g + 0.5));
	vec4 r = cell_rect[cell];
	UV = r.xy + UV * r.zw;
}

void fragment() {
	vec4 t = texture(atlas_tex, UV);
	t.a = smoothstep(0.05, 0.75, t.a);  // yarı saydam tüy/kumaş pikselleri daha dolgun
	vec3 body = t.rgb * mix(vec3(1.0), v_tint * 1.35, v_elite * 0.6);
	vec4 c = vec4(body, t.a);
	vec3 rim = mix(rim_color, clamp(v_tint * 1.25, 0.0, 1.0), v_elite);
	// Kontur hücre içinde kalır (hücre kenarına yayılmaz): hücre sınırına yakın örnekler komşu hücreyi okuyabilir,
	// atlasta hücreler yeterli saydam boşlukla ayrılmıştır.
	c = apply_rim(atlas_tex, UV, TEXTURE_PIXEL_SIZE, c, rim, v_rim_px);
	c.rgb = mix(c.rgb, vec3(1.0, 0.96, 0.88), clamp(v_flash, 0.0, 1.0) * 0.55);
	COLOR = vec4(c.rgb, c.a * v_alpha);
}
