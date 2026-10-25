shader_type canvas_item;
render_mode blend_add;
// Delen Rüzgar / Göğün Mızrağı gövdesi (MultiMesh): gövdedeki spiral şeritler akıyormuş gibi dokuyu mızrak ekseni
// boyunca dalgalandırır ve parlak bantları uca doğru kaydırır. `t` sim zamanıdır (kod her kare yazar; duraklatınca durur).
// Örnek rengi (renk çarpanı) COLOR'a vertex aşamasında alınır, doku dalgalı UV'den örneklenir.

uniform float t = 0.0;
uniform float amp = 0.06;
uniform float freq = 20.0;
uniform float speed = 15.0;
// Harita uyumu (ZyfenFx.apply_grade): doygunluk; renk çarpanı örnek renginde zaten uygulanır.
uniform float grade_sat = 1.0;

varying vec4 inst;

void vertex() {
	inst = COLOR;
}

void fragment() {
	float edge = smoothstep(0.05, 0.3, UV.x) * (1.0 - smoothstep(0.8, 0.95, UV.x));
	vec2 uv = UV;
	uv.y += sin(UV.x * freq - t * speed) * amp * edge;
	vec4 tex = texture(TEXTURE, uv);
	float band = 0.82 + 0.18 * sin(UV.x * freq * 1.4 - t * speed * 1.3);
	vec3 rgb = tex.rgb * band;
	rgb = mix(vec3(dot(rgb, vec3(0.299, 0.587, 0.114))), rgb, grade_sat);
	COLOR = vec4(rgb, tex.a) * inst;
}
