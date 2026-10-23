// Siluet çevresine açık kontur (rim ışığı): zeminle >= 3:1 ayrışma (ara denetim #1/#5).
// `a` dokunun kendi alfası; komşu alfa 8 yönde `px` doku pikseli uzaktan örneklenir.
// Opak pikseller (a >= 0.95) örneklemeden çıkar (kalabalık sahnede ek maliyet yok).
vec4 apply_rim(sampler2D tex, vec2 uv, vec2 texel, vec4 base, vec3 rim_rgb, float px) {
	if (base.a >= 0.95 || px <= 0.0) {
		return base;
	}
	vec2 o = texel * px;
	float na = 0.0;
	na = max(na, texture(tex, uv + vec2(o.x, 0.0)).a);
	na = max(na, texture(tex, uv + vec2(-o.x, 0.0)).a);
	na = max(na, texture(tex, uv + vec2(0.0, o.y)).a);
	na = max(na, texture(tex, uv + vec2(0.0, -o.y)).a);
	na = max(na, texture(tex, uv + o * 0.7071).a);
	na = max(na, texture(tex, uv - o * 0.7071).a);
	na = max(na, texture(tex, uv + vec2(o.x, -o.y) * 0.7071).a);
	na = max(na, texture(tex, uv + vec2(-o.x, o.y) * 0.7071).a);
	// Yarı saydam iç pikseller (tüy, kumaş) boyanmaz: kontur yalnızca gerçekten boş pikselde.
	float outside = clamp(1.0 - base.a * 2.5, 0.0, 1.0);
	float ra = outside * (1.0 - base.a) * clamp(na * 1.5, 0.0, 1.0);
	float out_a = base.a + ra;
	if (out_a <= 0.0001) {
		return base;
	}
	return vec4((base.rgb * base.a + rim_rgb * ra) / out_a, out_a);
}
