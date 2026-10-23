extends GutTest
## ResultScreen v1.1: skor dökümü, rekor durumları, düzen sınırları, güvenli alan, atlama kuralı.


func _stats(score: int = 246350, lord: int = 25000, evos: int = 2) -> Dictionary:
	var e: Array = []
	for i in evos:
		e.append(&"zincirleme_patlama")
	return {
		"time": 1200.0,
		"level": 17,
		"kills": 1482,
		"evolutions": e,
		"score": score,
		"best_mult": 5,
		"score_parts":
		{"kills": 61340, "streak": 48920, "evolution": evos * 2000, "survival": 6000, "lord": lord},
	}


func _combos(n: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for k in n:
		rows.append(
			{"id": &"zincirleme_patlama", "name": "Kıyamet Mermisi", "pair": "A + B", "icon": ""}
		)
	return rows


func _screen(
	won: bool, n_combos: int, rec: Dictionary = {}, stats: Dictionary = {}
) -> ResultScreen:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var r := ResultScreen.new()
	host.add_child(r)
	r.show_result(won, stats if not stats.is_empty() else _stats(), _combos(n_combos), "", rec)
	return r


func _all_blocks(r: ResultScreen) -> Array[Control]:
	return [
		r.title_label,
		r.sub_label,
		r.score_value,
		r.record_band,
		r.breakdown_panel,
		r.strip_panel,
		r.combo_panel,
		r.replay_button,
		r.menu_button
	]


func test_layout_zero_and_four_combos_fit_with_buttons_below_content() -> void:
	for n in [0, 4, 5]:
		var r := _screen(true, n)
		await get_tree().process_frame
		var bottom := r.menu_button.position.y + r.menu_button.size.y
		assert_lte(bottom, 2400.0 - 72.0, "%d kombo: düğme alt güvenli alanda (%.0f)" % [n, bottom])
		assert_gte(r.replay_button.position.y, 1500.0, "düğmeler y >= 1500")
		assert_gte(
			r.replay_button.position.y,
			r.combo_panel.position.y + r.combo_panel.size.y + 24.0 - 0.01,
			"düğmeler içerik_alt + 24'ün altında"
		)
		if n == 4:
			assert_lte(bottom, 2328.0)
		assert_almost_eq(r.content_bottom(), bottom, 0.01)


func test_fifth_combo_shows_plus_one() -> void:
	var r := _screen(true, 5)
	var last := r.combo_box.get_child(r.combo_box.get_child_count() - 1) as Label
	assert_eq(last.text, "+1")
	assert_eq(r.combo_box.get_child_count(), 5, "4 satır + '+1'")
	var r4 := _screen(true, 4)
	assert_eq(r4.combo_box.get_child_count(), 4)


func test_block_order_matches_design_y_values() -> void:
	var r := _screen(true, 2)
	assert_eq(r.score_caption.position.y, 404.0)
	assert_eq(r.record_band.position.y, 590.0)
	assert_eq(r.breakdown_panel.position.y, 760.0)
	assert_almost_eq(r.breakdown_panel.size.y, 5.0 * 84.0 + 24.0, 0.01)
	assert_eq(r.strip_panel.position.y, 1228.0)
	assert_eq(r.strip_panel.size.y, 170.0)
	assert_eq(r.combo_panel.position.y, 1422.0)


func test_safe_area_extra_keeps_blocks_inside() -> void:
	var r := _screen(false, 0)
	r.apply_safe_area(Vector4(0, 100, 0, 150))
	var limit := 2400.0 - 72.0 - 150.0
	var top_min := 96.0 + 100.0
	assert_gte(r.title_label.position.y, top_min)
	for c in _all_blocks(r):
		if c.visible:
			assert_lte(c.position.y + c.size.y, limit, "%s alt" % c.name)
	assert_lte(r.menu_button.position.y + r.menu_button.size.y, limit)
	r.apply_safe_area(Vector4.ZERO)
	assert_eq(r.title_label.position.y, 170.0)


func test_breakdown_values_and_lord_row_dim_when_lost() -> void:
	var r := _screen(false, 0, {}, _stats(120000, 0, 0))
	r.finish_count()
	var vals: Array[String] = []
	for row in r.breakdown_rows:
		vals.append((row.get_node("Value") as Label).text)
	assert_eq(vals, ["61.340", "+48.920", "+0", "+6.000", "—"])
	var lord := r.breakdown_rows[4]
	assert_almost_eq(lord.modulate.a, 0.35, 0.001)
	assert_eq((lord.get_node("Detail") as Label).text, "Lord'u yen")
	assert_almost_eq(r.breakdown_rows[2].modulate.a, 0.35, 0.001, "evrim yoksa %35")
	assert_eq((r.breakdown_rows[1].get_node("Detail") as Label).text, "en yüksek ×5")
	assert_eq((r.breakdown_rows[3].get_node("Detail") as Label).text, "20:00")
	assert_eq(r.score_value.text, "120.000")


func test_won_run_shows_lord_bonus_and_amber_score() -> void:
	var r := _screen(true, 2)
	r.finish_count()
	assert_eq((r.breakdown_rows[4].get_node("Value") as Label).text, "+25.000")
	assert_almost_eq(r.breakdown_rows[4].modulate.a, 1.0, 0.001)
	assert_eq((r.breakdown_rows[2].get_node("Detail") as Label).text, "2 evrim")
	assert_eq(r.score_value.text, "246.350")
	assert_eq(r.score_value.get_theme_color(&"font_color"), UiKit.AMBER)
	assert_eq(r.title_label.text, "KAZANDIN")


func test_lost_without_record_uses_bone_score() -> void:
	var r := _screen(false, 0)
	assert_eq(r.title_label.text, "OYUN BİTTİ")
	assert_eq(r.score_value.get_theme_color(&"font_color"), UiKit.KEMIK_100)


func test_record_rank_1_shows_band_and_previous_best() -> void:
	var rec := {
		"rank": 1, "is_record": true, "previous_best": 154200, "needed_for_top10": 0, "index": 0
	}
	var r := _screen(true, 0, rec)
	assert_eq(r.record_kind, &"record")
	assert_true(r.record_band.visible)
	assert_eq(r.record_label.text, "YENİ REKOR")
	assert_false(r.record_pill.visible)
	assert_eq(r.record_note.text, "Önceki en iyi: 154.200")
	var lost := _screen(false, 0, rec)
	assert_eq(lost.title_label.text, "OYUN BİTTİ", "ölünce de rekor olabilir")
	assert_eq(lost.score_value.get_theme_color(&"font_color"), UiKit.AMBER)


func test_first_game_record_has_no_previous_best_line() -> void:
	var rec := {"rank": 1, "is_record": true, "previous_best": 0, "needed_for_top10": 0, "index": 0}
	var r := _screen(false, 0, rec)
	assert_true(r.record_band.visible)
	assert_eq(r.record_note.text, "")


func test_record_rank_2_to_10_shows_pill() -> void:
	var rec := {
		"rank": 4, "is_record": false, "previous_best": 900, "needed_for_top10": 0, "index": 3
	}
	var r := _screen(false, 0, rec)
	assert_eq(r.record_kind, &"top10")
	assert_true(r.record_pill.visible)
	assert_eq(r.record_pill.text, "EN İYİ 10'A GİRDİN · 4. SIRA")
	assert_false(r.record_band.visible)


func test_record_outside_top10_shows_needed_line() -> void:
	var rec := {
		"rank": 0, "is_record": false, "previous_best": 900, "needed_for_top10": 62400, "index": -1
	}
	var r := _screen(false, 0, rec)
	assert_eq(r.record_kind, &"outside")
	assert_eq(r.record_note.text, "10. sıra için gereken: 62.400")
	assert_false(r.record_band.visible)
	assert_false(r.record_pill.visible)


func test_no_record_info_shows_nothing() -> void:
	var r := _screen(false, 0)
	assert_eq(r.record_kind, &"none")
	assert_false(r.record_band.visible)
	assert_false(r.record_pill.visible)
	assert_eq(r.record_note.text, "")


func test_timeline_drives_counts_and_stamp_once() -> void:
	var rec := {"rank": 1, "is_record": true, "previous_best": 5, "needed_for_top10": 0, "index": 0}
	var r := _screen(true, 0, rec)
	watch_signals(r)
	r._apply(0.0)
	assert_eq(r.score_value.text, "0")
	r._apply(0.45)
	var mid := int(r.score_value.text.replace(".", ""))
	assert_between(mid, 200000, 246349)
	r._apply(1.0)
	assert_eq(r.score_value.text, "246.350")
	assert_signal_not_emitted(r, "record_stamped")
	r._apply(1.3)
	r._apply(1.4)
	r._apply(1.6)
	assert_signal_emit_count(r, "record_stamped", 1)
	assert_eq(r.record_band.scale, Vector2.ONE)


func test_buttons_lock_until_1_3s_or_skip_rule() -> void:
	var r := _screen(true, 0)
	assert_false(r.buttons_enabled())
	assert_true(r.replay_button.disabled)
	r._t = 1.29
	assert_false(r.buttons_enabled())
	r._t = 1.31
	r._apply(r._t)
	assert_true(r.buttons_enabled())
	var r2 := _screen(true, 0)
	r2._t = 0.2
	r2.finish_count()
	r2._t = 0.79
	assert_false(r2.buttons_enabled())
	r2._t = 0.81
	assert_true(r2.buttons_enabled(), "atlama t=0,2 -> 0,8")
	assert_eq(r2.score_value.text, "246.350", "atlanınca değerler son halde")


func test_second_finish_does_not_extend_lock() -> void:
	var r := _screen(true, 0)
	r._t = 0.2
	r.finish_count()
	r._t = 1.0
	r.finish_count()
	assert_true(r.buttons_enabled(), "ilk atlama t'si korunur")


func test_four_combos_with_big_safe_area_shrink_rows_instead_of_overflowing() -> void:
	var r := _screen(true, 4)
	r.apply_safe_area(Vector4(0, 100, 0, 150))
	var limit := 2400.0 - 72.0 - 150.0
	assert_lte(r.menu_button.position.y + r.menu_button.size.y, limit)
	var last := r.combo_box.get_child(r.combo_box.get_child_count() - 1) as Label
	assert_true(last is Label and last.text.begins_with("+"), "taşan kombolar +N olur")
	r.apply_safe_area(Vector4.ZERO)
	assert_eq(r.combo_box.get_child_count(), 4, "güvenli alan kalkınca 4 satır geri gelir")


func test_hero_score_is_capped_at_display_cap() -> void:
	var st := _stats(1_500_000_000)
	var r := _screen(true, 0, {}, st)
	r.finish_count()
	assert_eq(r.score_value.text, "99.999.999")
