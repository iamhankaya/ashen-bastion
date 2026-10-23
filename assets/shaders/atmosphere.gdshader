shader_type canvas_item;
// Ekran uzayı atmosfer katmanı: süzülen sis (değer gürültüsü), kenar kararması (vinyet), oyuncu çevresinde sıcak ışık.
// Dünya kaymasıyla sis akar (cam_pos). Oyuncu ekran merkezindedir.

uniform vec2 cam_pos = vec2(0.0);
uniform vec2 view_size = vec2(1080.0, 2400.0);
uniform float fog_amount : hint_range(0.0, 1.0) = 0.28;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.55;
uniform vec3 fog_color : source_color = vec3(0.30, 0.24, 0.36);
uniform vec3 light_color : source_color = vec3(1.0, 0.62, 0.30);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 px = UV * view_size;
	vec2 world = px + cam_pos - view_size * 0.5;
	float n = vnoise(world * 0.0016 + vec2(TIME * 0.015, TIME * 0.007));
	n = n * 0.65 + vnoise(world * 0.0042 - vec2(TIME * 0.02, 0.0)) * 0.35;
	float fog = smoothstep(0.35, 0.85, n) * fog_amount;
	vec2 c = (UV - vec2(0.5, 0.5)) * vec2(1.0, view_size.y / view_size.x);
	float d = length(c);
	float vig = smoothstep(0.35, 1.05, d) * vignette_amount;
	float glow = (1.0 - smoothstep(0.0, 0.34, d)) * 0.06;
	vec3 col = fog_color * fog + light_color * glow;
	float a = clamp(fog * 0.6 + vig + glow * 0.4, 0.0, 0.85);
	COLOR = vec4(mix(col, vec3(0.03, 0.02, 0.05), clamp(vig / max(a, 0.001), 0.0, 1.0)), a);
}
