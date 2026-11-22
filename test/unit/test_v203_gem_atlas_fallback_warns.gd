extends GutTest
## F-ashen-bastion-087: küre dokusu yüklenemezse yer tutucuya UYARISIZ düşülmez; uyarı eksik dokunun yolunu söyler.
## Sağlam yolda uyarı yoktur ve atlas 3 kutuludur.


func test_missing_texture_falls_back_to_placeholder_with_a_warning() -> void:
	var paths := PackedStringArray(GemTiers.TEXTURES)
	paths[1] = "res://assets/yok/zz_olmayan_kure.png"
	var tex := GemRenderer.atlas_texture(paths)
	assert_not_null(tex, "yer tutucu döner")
	assert_push_warning("zz_olmayan_kure.png")


func test_complete_textures_build_the_atlas_without_warning() -> void:
	var tex := GemRenderer.atlas_texture()
	assert_eq(tex.get_width(), GemRenderer.TILE_PX * GemTiers.COUNT, "3 kutulu atlas")
	assert_push_warning_count(0)
