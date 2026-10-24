extends GutTest
## ArtLoader: dolgulu doku ve (D4) hücre hücre dolgulu şerit.

const PATH := "user://test_art_loader_strip.png"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	ArtLoader._cache.clear()


func _write_strip(cells: int, w: int, h: int) -> void:
	var img := Image.create(w * cells, h, false, Image.FORMAT_RGBA8)
	for c in cells:
		img.fill_rect(Rect2i(c * w, 0, w, h), Color(0.2 + 0.1 * c, 0.5, 0.4, 1.0))  # hücre kenarına dek opak
	img.save_png(PATH)


func test_padded_cells_pads_every_cell_separately() -> void:
	_write_strip(3, 10, 20)
	var tex := ArtLoader.padded_cells(PATH, 3, 4)
	assert_not_null(tex)
	assert_eq(tex.get_size(), Vector2(3 * (10 + 8), 20 + 8))
	var img := tex.get_image()
	for c in 3:
		var x0 := c * 18
		assert_eq(img.get_pixel(x0, 10).a, 0.0, "hücre %d sol dolgu saydam" % c)
		assert_eq(img.get_pixel(x0 + 17, 10).a, 0.0, "hücre %d sağ dolgu saydam" % c)
		assert_eq(img.get_pixel(x0 + 4, 4).a, 1.0, "içerik hücrenin dolgu içinde başlar")
		assert_almost_eq(img.get_pixel(x0 + 9, 14).r, 0.2 + 0.1 * c, 0.01)


func test_padded_cells_is_cached_and_null_for_missing_or_uneven_strips() -> void:
	_write_strip(3, 10, 20)
	assert_same(ArtLoader.padded_cells(PATH, 3, 4), ArtLoader.padded_cells(PATH, 3, 4))
	assert_null(ArtLoader.padded_cells("user://yok.png", 3, 4))
	assert_null(ArtLoader.padded_cells("placeholder:x", 3, 4))
	assert_null(ArtLoader.padded_cells(PATH, 4, 4), "30 px 4 hücreye bölünmez")
	assert_null(ArtLoader.padded_cells(PATH, 0, 4))
