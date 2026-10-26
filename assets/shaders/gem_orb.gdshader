shader_type canvas_item;
// v2.0.3 ruh küreleri: tek MultiMesh, 3 kutulu atlas. INSTANCE_CUSTOM = (tip, evre, boy_px, 0).
// Elit/ara boss küreleri hafifçe süzülür (yalnız görünüm; sim konumu değişmez); hareket_azalt'ta bob_scale = 0.
uniform float bob_scale = 1.0;
varying vec2 atlas_uv;

void vertex() {
	float tier = INSTANCE_CUSTOM.x;
	float boss = step(1.5, tier);
	float elit = step(0.5, tier) - boss;
	float amp_px = elit * 3.0 + boss * 4.0;
	float period_s = mix(1.8, 1.4, boss);
	VERTEX.y += sin((TIME / period_s + INSTANCE_CUSTOM.y) * 6.2831853) * amp_px * bob_scale / INSTANCE_CUSTOM.z;
	atlas_uv = vec2((UV.x + tier) / 3.0, UV.y);
}

void fragment() {
	COLOR = texture(TEXTURE, atlas_uv) * COLOR;
}
