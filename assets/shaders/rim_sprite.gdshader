shader_type canvas_item;
// Düz sprite + rim konturu (kollar). Doku etrafında saydam dolgu taşır.
#include "res://assets/shaders/rim.gdshaderinc"

uniform sampler2D sprite_tex : source_color, filter_linear;
uniform vec3 rim_color : source_color = vec3(0.86, 0.80, 0.66);
uniform float rim_px = 3.0;
uniform vec4 tint = vec4(1.0);

void fragment() {
	vec4 t = texture(sprite_tex, UV);
	vec4 r = apply_rim(sprite_tex, UV, TEXTURE_PIXEL_SIZE, t, rim_color, rim_px);
	COLOR = vec4(r.rgb * tint.rgb, r.a);
}
