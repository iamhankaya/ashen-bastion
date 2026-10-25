shader_type canvas_item;
// Hortum/Tufan akış katmanı: `hortum_akis` döşenebilir dokusu gövdenin içinde yukarı kayar, gövde dokusunun (TEXTURE)
// alfasıyla maskelenir. Bölge başına parametreler tepe renginde gelir (tek çizim düğümünde bölgeler ayrı ayrı çizilir):
//   r = kayma fazı (0..1), g = döşeme sıklığı / 8, b = hız çarpanı / 2, a = saydamlık.
// `t` sim zamanıdır (kod her kare yazar; duraklatınca durur). Akış dokusu `repeat_enable` ile döşenir.

uniform sampler2D flow : repeat_enable, filter_linear;
uniform float t = 0.0;
uniform float base_speed = 0.55;

varying vec4 prm;

void vertex() {
	prm = COLOR;
}

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	float tile = prm.g * 8.0;
	vec2 uv = UV * vec2(tile, tile * 2.0);
	uv.y += (prm.r + t * base_speed * prm.b * 2.0);
	// Gövde boyunca hafif spiral: üst kısım yatayda kayar.
	uv.x += (1.0 - UV.y) * 0.35 + sin(t * 0.9 + prm.r * 6.283) * 0.05;
	vec4 f = texture(flow, uv);
	// Alt uca (huni ucu) doğru solar.
	float fade = smoothstep(0.1, 0.6, 1.0 - UV.y);
	COLOR = vec4(f.rgb * 1.15, f.a * mask * prm.a * (0.35 + 0.65 * fade));
}
