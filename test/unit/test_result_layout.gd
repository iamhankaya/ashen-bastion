extends GutTest
## #8: kombo paneli içeriğe göre boyutlanır; boşsa kısa satır; düğmeler panelin hemen altında; 5 kombo ekrana sığar.


func _screen(n: int) -> ResultScreen:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1080, 2400)
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var r := ResultScreen.new()
	host.add_child(r)
	var rows: Array[Dictionary] = []
	for k in n:
		rows.append(
			{"id": &"zincirleme_patlama", "name": "Kıyamet Mermisi", "pair": "A + B", "icon": ""}
		)
	r.show_result(true, {"time": 1290.0, "level": 31, "kills": 4210, "evolutions": []}, rows)
	return r


func _panel(r: ResultScreen) -> Control:
	return r.combo_box.get_parent().get_parent() as Control


func test_empty_panel_is_short_and_buttons_follow_it() -> void:
	var r := _screen(0)
	await get_tree().process_frame
	await get_tree().process_frame
	var p := _panel(r)
	assert_lt(p.size.y, 220.0, "boş durum: başlık + tek kısa satır")
	assert_eq((r.combo_box.get_child(0) as Label).text, ResultScreen.EMPTY_TEXT)
	var gap := r.replay_button.get_global_rect().position.y - (p.get_global_rect().end.y)
	assert_lt(gap, 80.0, "panel→düğme ölü boşluk yok (%.0f px)" % gap)


func test_panel_grows_with_combos_and_five_combos_fit_the_screen() -> void:
	var r0 := _screen(1)
	var r5 := _screen(5)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(_panel(r5).size.y, _panel(r0).size.y + 300.0, "içeriğe göre büyür")
	var bottom := r5.menu_button.get_global_rect().end.y
	assert_lte(
		bottom,
		2400.0 - UiKit.DEFAULT_BOTTOM,
		"5 kombo + düğmeler alt güvenli alana taşmaz (%.0f)" % bottom
	)
