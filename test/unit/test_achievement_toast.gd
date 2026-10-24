extends GutTest
## AchievementToast (B3): IGNORE, geometri, kuyruk durumu -> konum/alfa, ad kırpması, kademe.

var _data: GameData


func before_each() -> void:
	_data = GameData.load_default()


func _toast() -> AchievementToast:
	var t := AchievementToast.new()
	add_child_autofree(t)
	return t


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func test_every_node_ignores_mouse_and_takes_no_focus() -> void:
	var t := _toast()
	t.show_def(_data.get_achievement(&"ilk_kan"))
	for n in _all(t, []):
		if n is Control:
			assert_eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(n.name))
	assert_eq(t.focus_mode, Control.FOCUS_NONE)


func test_rect_contract_and_in_tree_geometry() -> void:
	assert_eq(AchievementToast.rect(0.0), Rect2(150, 820, 780, 120))
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var t := AchievementToast.new()
	host.add_child(t)
	var q := ToastQueue.new()
	q.push(&"ilk_kan")
	q.tick(0.3)  # HOLD: kayma 0, alfa 1
	t.show_def(_data.get_achievement(&"ilk_kan"))
	t.apply_state(q)
	assert_true(t.visible)
	assert_eq(t.get_rect(), Rect2(150, 820, 780, 120))


func test_state_maps_slide_and_alpha() -> void:
	var t := _toast()
	var q := ToastQueue.new()
	t.apply_state(q)
	assert_false(t.visible, "boşta görünmez")
	q.push(&"ilk_kan")
	t.show_def(_data.get_achievement(&"ilk_kan"))
	t.apply_state(q)
	assert_true(t.visible)
	assert_almost_eq(t.modulate.a, 0.0, 1e-6)
	assert_almost_eq(t.offset_top, 820.0 - 24.0, 1e-4, "girişte 24 px yukarıdan")
	q.tick(0.22 + 0.01)
	t.apply_state(q)
	assert_almost_eq(t.modulate.a, 1.0, 1e-6)
	assert_almost_eq(t.offset_top, 820.0, 1e-4)
	q.tick(2.1)  # OUT
	q.tick(0.09)
	t.apply_state(q)
	assert_between(t.modulate.a, 0.01, 0.99)
	q.tick(0.2)
	t.apply_state(q)
	assert_false(t.visible)


func test_name_is_turkish_upper_and_fits_for_22_letters() -> void:
	var t := _toast()
	var def := AchievementDef.new()
	def.display_name = "İlk kan ışığı"
	def.tier = &"kolay"
	def.stat = &"total_kills"
	t.show_def(def)
	assert_eq(t.name_label.text, "İLK KAN IŞIĞI")
	var longest := ""
	for d in _data.achievements:
		if d.display_name.length() > longest.length():
			longest = d.display_name
	assert_lte(longest.length(), 22)
	def.display_name = longest
	t.show_def(def)
	var w := (
		UiKit
		. font(&"display")
		. get_string_size(t.name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38)
		. x
	)
	assert_lt(w, t.name_label.size.x, "en uzun gerçek ad tek satıra sığar")


func test_tier_marks_and_edge() -> void:
	var t := _toast()
	var expect := {&"kolay": 1, &"orta": 2, &"zor": 3, &"cok_zor": 4}
	for tier in expect:
		var def := AchievementDef.new()
		def.display_name = "X"
		def.tier = tier
		t.show_def(def)
		assert_eq(t.tier_marks.count, expect[tier], str(tier))


func test_show_null_def_hides() -> void:
	var t := _toast()
	t.show_def(null)
	assert_false(t.visible)


func test_tag_text_and_min_font_size() -> void:
	var t := _toast()
	t.show_def(_data.get_achievement(&"ilk_kan"))
	assert_eq(t.tag_label.text, "BAŞARIM AÇILDI")
	assert_gte(t.tag_label.get_theme_font_size(&"font_size"), 26)
	assert_gte(t.name_label.get_theme_font_size(&"font_size"), 26)


func test_does_not_intersect_hud_regions_for_three_safe_tops() -> void:
	# Tasarım §5.2: skor sütunu, elit satırı, Lord bandı (+pay), yuva satırı, tambur/rozet satırı ile kesişmez.
	var regions := [
		Rect2(584, 284, 460, 152),
		Rect2(0, 506, 1080, 98),
		Rect2(0, 520, 1080, 132),
		Rect2(36, 270, 522, 70),
		Rect2(0, 2160, 1080, 168),
	]
	for top in [0.0, 60.0, 100.0]:
		var r := AchievementToast.rect(top)
		for reg: Rect2 in regions:
			var band := reg
			if reg.position.y == 520.0:
				band.position.y += top  # Lord bandı güvenli üst payla iner
			if reg.position.y == 506.0:
				band.position.y += top
			assert_false(r.intersects(band), "safe_top=%s bölge=%s" % [top, reg])
