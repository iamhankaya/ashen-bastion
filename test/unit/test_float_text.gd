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


# --- V-02: aynı anda toplanan eklentilerin metinleri üst üste binmez ---------------------------------------


func _min_gap_over_time(f: FloatText) -> float:
	var worst := 1.0e9
	for _k in 44:
		var ys: Array[float] = []
		for i in FloatText.POOL:
			if f.progress_of(i) < 1.0:
				ys.append(f.draw_y(i))
		ys.sort()
		for j in range(1, ys.size()):
			worst = minf(worst, ys[j] - ys[j - 1])
		f.refresh(0.016)
	return worst


func test_three_pickups_in_one_frame_keep_44px_apart() -> void:
	var f := FloatText.new()
	add_child_autofree(f)
	for t in ["Sınırsız şarjör", "Hasar arttı", "Atış hızı arttı"]:
		f.show_text(t, Vector2(540.0, 900.0))
	assert_eq(f.active_count(), 3)
	assert_gte(_min_gap_over_time(f), 44.0, "hiçbir iki satır örtüşmez")


func test_pickups_300ms_apart_do_not_overlap_either() -> void:
	var f := FloatText.new()
	add_child_autofree(f)
	f.show_text("Hasar arttı", Vector2(540.0, 900.0))
	for _k in 18:
		f.refresh(0.016)
	f.show_text("Atış hızı arttı", Vector2(540.0, 900.0))
	for _k in 18:
		f.refresh(0.016)
	f.show_text("Sınırsız şarjör", Vector2(540.0, 900.0))
	assert_gte(_min_gap_over_time(f), 44.0)


func test_a_lone_pickup_keeps_its_position() -> void:
	var f := FloatText.new()
	add_child_autofree(f)
	f.show_text("+25 Can", Vector2(540.0, 900.0))
	assert_almost_eq(f.draw_y(0), 900.0, 0.01, "yalnız başlık kaymaz")
	f.refresh(0.016)
	f.show_text("Hasar arttı", Vector2(540.0, 2000.0))
	assert_almost_eq(f.draw_y(1), 2000.0, 0.01, "uzaktaki başlık kaymaz")


func test_fourth_text_is_not_pushed_by_the_slot_it_overwrites() -> void:
	var f := FloatText.new()
	add_child_autofree(f)
	for k in 3:
		f.show_text("T%d" % k, Vector2(540.0, 900.0))
	f.show_text("T3", Vector2(540.0, 900.0))
	assert_lte(
		f._pos[0].y, 900.0 + 2.0 * FloatText.ROW, "en eski yuvayı ezen başlık gereksiz itilmez"
	)
