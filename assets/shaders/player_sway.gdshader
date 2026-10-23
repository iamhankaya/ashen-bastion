shader_type canvas_item;
// Gövde ikincil hareketi + rim konturu. Parametreler karakter verisinden (rig.sway):
//   etek (hem_from_y altı) yatay kayar (sway, amp px); atkı bölgesi (scarf_rect) zamanla dalgalanır.
// Mesh, dokunun etrafında `pad` doku pikseli saydam boşluk taşır (rim için); UV dokuya göre 0..1'dir.
#include "res://assets/shaders/rim.gdshaderinc"

uniform sampler2D body_tex : source_color, filter_linear;
uniform float sway = 0.0;
uniform float amp = 6.0;
uniform float hem_from_y = 0.6;
uniform vec4 scarf_rect = vec4(0.1, 0.25, 0.45, 0.7);
uniform float scarf_amp = 5.0;
uniform vec2 pad_frac = vec2(0.0);  // dolgu / toplam doku boyutu (UV kayması için)
uniform vec3 rim_color : source_color = vec3(0.86, 0.80, 0.66);
uniform float rim_px = 3.0;

varying vec2 v_uv;

void vertex() {
	// Sprite kutusuna göre normalize UV (dolgusuz): 0..1
	vec2 su = (UV - pad_frac) / max(vec2(1.0) - 2.0 * pad_frac, vec2(0.001));
	float k = clamp((su.y - hem_from_y) / max(1.0 - hem_from_y, 0.001), 0.0, 1.0);
	VERTEX.x += sway * amp * k * k;
	vec2 inside = step(scarf_rect.xy, su) * step(su, scarf_rect.zw);
	float m = inside.x * inside.y;
	float depth = clamp((scarf_rect.z - su.x) / max(scarf_rect.z - scarf_rect.x, 0.001), 0.0, 1.0);
	VERTEX.x += m * depth * (sin(TIME * 7.0 + su.y * 9.0) * scarf_amp + sway * amp * 0.5);
	VERTEX.y += m * depth * cos(TIME * 5.0 + su.x * 6.0) * scarf_amp * 0.4;
	v_uv = UV;
}

void fragment() {
	vec4 t = texture(body_tex, v_uv);
	COLOR = apply_rim(body_tex, v_uv, TEXTURE_PIXEL_SIZE, t, rim_color, rim_px);
}
