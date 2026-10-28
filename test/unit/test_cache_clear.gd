extends GutTest
## R2: UiKit/ArtLoader önbellekleri `clear_caches()` ile sıfırlanır (test sızıntı koruması bunu çağırır).


func test_ui_kit_clear_caches_empties_tex_cache() -> void:
	UiKit.font_semibold()  # önbelleği doldurur
	assert_false(UiKit._tex_cache.is_empty(), "ön koşul: önbellek dolu")
	UiKit.clear_caches()
	assert_true(UiKit._tex_cache.is_empty())


func test_art_loader_clear_caches_empties_cache() -> void:
	ArtLoader._cache["probe"] = null
	ArtLoader.clear_caches()
	assert_true(ArtLoader._cache.is_empty())
