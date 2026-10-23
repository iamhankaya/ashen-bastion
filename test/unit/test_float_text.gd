extends GutTest
## FloatText: havuz 3, 700 ms, 60 px yükselme, upper_tr.


func test_hidden_until_first_text_and_upper_cased() -> void:
	var f := FloatText.new()
	add_child_autofree(f)
	assert_false(f.visible)
	f.show_text("Hasar arttı", Vector2(100, 200))
	assert_true(f.visible)
	assert_eq(f._text[0], "HASAR ARTTI")
	f.show_text("Atış hızı arttı", Vector2.ZERO)
	assert_eq(f._text[1], "ATIŞ HIZI ARTTI", "i/ı doğru büyür")


func test_lasts_700ms_then_expires() -> void:
	var f := FloatText.new()
	add_child_autofree(f)
	f.show_text("+25 Can", Vector2.ZERO)
	assert_eq(f.active_count(), 1)
	for _k in 41:
		f.refresh(0.016)
	assert_eq(f.active_count(), 1, "656 ms: sürüyor")
	for _k in 5:
		f.refresh(0.016)
	assert_eq(f.active_count(), 0)


func test_pool_of_three_reuses_oldest_slot() -> void:
	var f := FloatText.new()
	add_child_autofree(f)
	for k in 4:
		f.show_text("T%d" % k, Vector2.ZERO)
	assert_eq(f.active_count(), 3)
	assert_eq(f._text[0], "T3", "dördüncü en eski yuvayı ezer")


func test_empty_text_is_ignored() -> void:
	var f := FloatText.new()
	add_child_autofree(f)
	f.show_text("", Vector2.ZERO)
	assert_false(f.visible)
