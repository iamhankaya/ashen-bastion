shader_type canvas_item;
// Gövde ikincil hareketi: etek (hem_from_y altı) yatay kayar. Parametreler karakter verisinden (rig.sway).
// sway: -1..1 (gecikmeli hareket yönünün tersi), amp: px.

uniform float sway = 0.0;
uniform float amp = 6.0;
uniform float hem_from_y = 0.6;

void vertex() {
	float k = clamp((UV.y - hem_from_y) / max(1.0 - hem_from_y, 0.001), 0.0, 1.0);
	VERTEX.x += sway * amp * k * k;
}
