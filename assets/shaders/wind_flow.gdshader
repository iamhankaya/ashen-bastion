shader_type canvas_item;
// Hortum/Tufan akış katmanı: `hortum_akis` döşenebilir dokusu gövdenin içinde silindir eşlemeyle DÖNER (yatay kayma, hafif
// yukarı bileşen) ve gövde dokusunun (TEXTURE) alfasıyla maskelenir. Açısal hız sabit olduğundan ekrandaki hız huni
// genişliğiyle orantılıdır (üst geniş kısım alttan hızlı döner). Bölge başına parametreler tepe renginde gelir:
//   r = yatay (dönüş) kayma fazı (0..1), g = döşeme sıklığı / 8, b = dikey kayma fazı (0..1), a = saydamlık.
// Fazları kod sim zamanından hesaplar (duraklatınca durur); doku 1 periyotla döşendiği için 0..1 sarma dikişsizdir.

uniform sampler2D flow : repeat_enable, filter_linear;
// Gövde dokusunda zemin noktası (tuval yüksekliği oranı) ve görünür yükseklik; huni genişliği tahmini için.
uniform float body_foot = 0.87;
uniform float body_span = 0.69;
// Harita uyumu (ZyfenFx.apply_grade).
uniform vec3 grade_mul = vec3(1.0);
uniform float grade_sat = 1.0;

varying vec4 prm;

void vertex() {
	prm = COLOR;
}

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	float tile = prm.g * 8.0;
	// Silindir eşleme: x -> açı; kenarlarda doku sıkışır (dönen gövde hissi).
	float cx = clamp((UV.x - 0.5) * 2.0 / 0.82, -1.0, 1.0);
	float theta = asin(cx) / 3.14159265;
	vec2 uv;
	uv.x = theta * tile * 1.6 + prm.r;
	uv.y = UV.y * tile * 2.0 - prm.b;
	vec4 f = texture(flow, uv);
	// Alt uca (huni ucu) doğru solar.
	float h = clamp((body_foot - UV.y) / body_span, 0.0, 1.0);
	float fade = smoothstep(0.0, 0.5, h);
	// Kenar şeritleri görünür kalsın, merkez saydamlaşsın.
	float edge = mix(0.55, 1.0, smoothstep(0.1, 0.9, abs(cx)));
	vec3 rgb = f.rgb * 1.15;
	rgb = mix(vec3(dot(rgb, vec3(0.299, 0.587, 0.114))), rgb, grade_sat) * grade_mul;
	COLOR = vec4(rgb, f.a * mask * prm.a * edge * (0.35 + 0.65 * fade));
}
