shader_type canvas_item;
// Düşman vurulma parlaması: MultiMesh INSTANCE_CUSTOM.r (0..1) beyaza karışım.
// gl_compatibility'de çalıştığı U1-7 prototipiyle doğrulandı (docs/dev/perf.md "Render notları (U1-7)").

varying float v_flash;

void vertex() {
	v_flash = INSTANCE_CUSTOM.r;
}

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.96, 0.88), clamp(v_flash, 0.0, 1.0) * 0.85);
}
