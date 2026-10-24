shader_type canvas_item;
// Kilitli başarım ikonu: boyalı ikonu gri tonlar ve karartır (renk çarpanı yerine).
uniform float desaturate : hint_range(0.0, 1.0) = 1.0;
uniform float darken : hint_range(0.0, 1.0) = 0.7;
uniform float alpha_mul : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c.rgb, vec3(l), desaturate) * darken;
	COLOR = vec4(g, c.a * alpha_mul) * COLOR;
}
