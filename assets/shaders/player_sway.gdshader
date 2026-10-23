shader_type canvas_item;
// Gövde ikincil hareketi + rim konturu + hasar/ölüm tonları. Parametreler karakter verisinden (rig.sway):
//   etek (hem_from_y altı) yatay kayar (sway, amp px) ve yürürken adım fazıyla ±3 px ek salınır (walk_phase);
//   atkı bölgesi (scarf_rect) zamanla dalgalanır (scarf_amp: kod her kare yazar).
// Anlık tepkiler: hit (kemik-beyaz parlama), tint_amt/tint (bordo/altın ton), desat (ölümde solma).
// Kare modu (D4): cells > 1 ise doku yatay şerittir; frame_a/frame_b hücreleri frame_mix ile harmanlanır (yalnız duruş geçişi).
// Mesh, dokunun etrafında `pad` doku pikseli saydam boşluk taşır (rim için); UV dokuya göre 0..1'dir (kare modunda hücreye göre).
#include "res://assets/shaders/rim.gdshaderinc"

uniform sampler2D body_tex : source_color, filter_linear;
uniform float sway = 0.0;
uniform float amp = 6.0;
uniform float hem_from_y = 0.6;
uniform vec4 scarf_rect = vec4(0.1, 0.25, 0.45, 0.7);
uniform float scarf_amp = 5.0;
uniform float walk_phase = 0.0;
uniform float hit = 0.0;
uniform float tint_amt = 0.0;
uniform vec3 tint : source_color = vec3(0.878, 0.345, 0.31);
uniform float desat = 0.0;
uniform float frame_a = 0.0;
uniform float frame_b = 0.0;
uniform float frame_mix = 0.0;
uniform float cells = 1.0;
uniform vec2 pad_frac = vec2(0.0);  // dolgu / toplam doku boyutu (UV kayması için)
uniform vec3 rim_color : source_color = vec3(0.80, 0.72, 0.56);
uniform float rim_px = 3.0;

varying vec2 v_uv;
varying vec2 v_uv_b;

vec2 cell_uv(vec2 uv, float frame) {
	float c = max(cells, 1.0);
	return vec2((uv.x + frame) / c, uv.y);
}

void vertex() {
	// Sprite kutusuna göre normalize UV (dolgusuz): 0..1
	vec2 su = (UV - pad_frac) / max(vec2(1.0) - 2.0 * pad_frac, vec2(0.001));
	float k = clamp((su.y - hem_from_y) / max(1.0 - hem_from_y, 0.001), 0.0, 1.0);
	VERTEX.x += sway * amp * k * k;
	VERTEX.x += sin(walk_phase * 6.2831853 * 2.0) * 3.0 * k * k;
	vec2 inside = step(scarf_rect.xy, su) * step(su, scarf_rect.zw);
	float m = inside.x * inside.y;
	float depth = clamp((scarf_rect.z - su.x) / max(scarf_rect.z - scarf_rect.x, 0.001), 0.0, 1.0);
	VERTEX.x += m * depth * (sin(TIME * 7.0 + su.y * 9.0) * scarf_amp + sway * amp * 0.5);
	VERTEX.y += m * depth * cos(TIME * 5.0 + su.x * 6.0) * scarf_amp * 0.4;
	v_uv = cells > 1.5 ? cell_uv(UV, frame_a) : UV;
	v_uv_b = cells > 1.5 ? cell_uv(UV, frame_b) : UV;
}

void fragment() {
	vec4 t = texture(body_tex, v_uv);
	vec4 c = apply_rim(body_tex, v_uv, TEXTURE_PIXEL_SIZE, t, rim_color, rim_px);
	if (cells > 1.5 && frame_mix > 0.0) {
		vec4 tb = texture(body_tex, v_uv_b);
		vec4 cb = apply_rim(body_tex, v_uv_b, TEXTURE_PIXEL_SIZE, tb, rim_color, rim_px);
		c = mix(c, cb, frame_mix);
	}
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(luma), desat);
	c.rgb = mix(c.rgb, tint, tint_amt);
	c.rgb = mix(c.rgb, vec3(0.937, 0.906, 0.839), hit);
	COLOR = c;
}
