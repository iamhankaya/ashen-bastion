extends GutTest
## V2Maint (M sahipli): güvenli alan dağıtımı (M8a/N7: HUD + seviye atlama + duraklatma), debug dokunma alanları (M6/S-04).

const NOTCH := Vector4(48.0, 130.0, 48.0, 80.0)
const PLAYING := PauseLogic.Screen.PLAYING


func _controller() -> GameController:
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	return c


func _buttons(root: Node, out: Array[Control]) -> void:
	for ch in root.get_children():
		if ch is Button and (ch as Button).is_visible_in_tree():
			out.append(ch)
		_buttons(ch, out)


# --- apply_safe_areas dağıtımı -------------------------------------------------------------------------------


class Spy:
	extends Control
	var got: Array = []

	func apply_safe_area(extra: Variant = null) -> void:
		got.append(extra)


func test_apply_safe_areas_reaches_hud_level_up_and_pause() -> void:
	var m := V2Maint.new()
	var hud := Spy.new()
	var lv := Spy.new()
	var ps := Spy.new()
	for n in [hud, lv, ps]:
		add_child_autofree(n)
	m.build_world({"hud": hud, "level_up": lv, "pause_screen": ps})
	m.apply_safe_areas(NOTCH)
	assert_eq(hud.got, [NOTCH])
	assert_eq(lv.got, [NOTCH])
	assert_eq(ps.got, [NOTCH])
	m.apply_safe_areas()
	assert_eq(hud.got.size(), 2)
	assert_null(hud.got[1], "null: her ekran pencereden kendisi okur")


func test_apply_safe_areas_skips_screens_without_the_method_and_freed_refs() -> void:
	var m := V2Maint.new()
	var plain := Control.new()  # apply_safe_area yok (K1 gelmeden seviye atlama gibi)
	var gone := Spy.new()
	add_child_autofree(plain)
	m.build_world({"level_up": plain, "pause_screen": gone})
	gone.free()
	m.apply_safe_areas(NOTCH)  # çökmez
	m.release()
	m.apply_safe_areas(NOTCH)
	pass_test("serbest/eksik ekran atlandı")


func test_controller_size_change_reapplies_hud_and_pause_safe_area() -> void:
	var c := _controller()
	await get_tree().process_frame
	c.hud.apply_safe_area(Vector4.ZERO)
	c.pause_screen.apply_safe_area(Vector4.ZERO)
	assert_almost_eq(c.hud.safe.offset_top, 0.0, 0.01)
	# Pencere boyutu değişimi bağlantısı: aynı yol _apply_safe_areas (masaüstünde pay 0; yenilemenin çalıştığını
	# HUD'un önceden bozulan payının sıfıra dönmesiyle görürüz).
	c.hud.apply_safe_area(NOTCH)
	assert_almost_eq(c.hud.safe.offset_top, 130.0, 0.01)
	c._apply_safe_areas()
	assert_almost_eq(c.hud.safe.offset_top, UiKit.current_safe_extra(Vector2(1080, 2400)).y, 0.01)


# --- PauseScreen.apply_safe_area (N7) ------------------------------------------------------------------------


func _pause_screen() -> PauseScreen:
	var holder := Control.new()
	holder.size = Vector2(1080, 2400)
	add_child_autofree(holder)
	var p := PauseScreen.new()
	holder.add_child(p)
	return p


func test_pause_screen_column_moves_with_the_safe_area() -> void:
	var p := _pause_screen()
	p.apply_safe_area(Vector4.ZERO)
	var top0 := p.column.offset_top
	var left0 := p.column.offset_left
	assert_almost_eq(top0, PauseScreen.COL_TOP, 0.01, "pay 0: v1.1 düzeni")
	p.apply_safe_area(NOTCH)
	assert_almost_eq(p.column.offset_top, top0 + 130.0, 0.01, "üst pay kadar iner")
	assert_almost_eq(p.column.offset_left, left0, 0.01, "yan paylar eşit: kayma yok")
	p.apply_safe_area(Vector4(100.0, 0.0, 20.0, 0.0))
	assert_almost_eq(
		p.column.offset_left, left0 + 40.0, 0.01, "yan pay farkının yarısı kadar kayar"
	)
	p.apply_safe_area(Vector4.ZERO)
	assert_almost_eq(p.column.offset_top, top0, 0.01, "pay kalkınca geri gelir")


func test_pause_screen_buttons_stay_inside_the_safe_rect() -> void:
	var p := _pause_screen()
	await get_tree().process_frame
	for extra: Vector4 in [Vector4.ZERO, NOTCH, Vector4(0, 200, 0, 150)]:
		p.apply_safe_area(extra)
		await get_tree().process_frame
		var bottom := p.column.get_global_rect().end.y
		assert_lte(
			bottom,
			2400.0 - UiKit.DEFAULT_BOTTOM - extra.w + 0.5,
			"sütun alt güvenli kenarı aşmaz %s" % extra
		)
		assert_gte(p.menu_button.get_global_rect().position.y, extra.y, "üst pay altında")


# --- debug etiketleri (M6/S-04) ------------------------------------------------------------------------------


func _taps(c: GameController) -> Array[Label]:
	var out: Array[Label] = []
	for t in get_tree().get_nodes_in_group(DebugLabels.TAP_GROUP):
		if c.ui.is_ancestor_of(t):
			out.append(t)
	return out


func test_debug_label_rects_sit_on_the_top_edge_and_ignore_touch() -> void:
	assert_true(OS.is_debug_build())
	var c := _controller()
	c.start_run()
	c._update_views(0.016)
	for label: Label in [c._render_label, c._escape_label]:
		var r := label.get_global_rect()
		assert_gte(r.position.y, 6.0, "y >= 6")
		assert_lte(r.end.y, 40.0, "y <= 40")
		assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "etiket dokunmayı yutmaz")
		assert_gte(r.position.x, UiKit.SAFE_EDGE - 0.01)
		assert_lte(r.end.x, 1080.0 - UiKit.SAFE_EDGE + 0.01)
	var taps := _taps(c)
	assert_eq(taps.size(), 2, "iki dokunma alanı")
	for t in taps:
		var r := t.get_global_rect()
		assert_gte(r.position.y, 6.0)
		assert_lte(r.end.y, 40.0)
		assert_lte(r.end.x, 1080.0 - UiKit.SAFE_EDGE + 0.01)


func test_tap_areas_are_active_only_while_playing() -> void:
	var c := _controller()
	c.start_run()
	c._update_views(0.016)
	c._update_views(0.016)  # dokunma alanı yazısı etiketten bir kare gecikmeli
	for t in _taps(c):
		assert_true(t.visible, "oyunda dokunulur")
		assert_eq(t.mouse_filter, Control.MOUSE_FILTER_STOP)
		assert_true(t.text.begins_with("dokun: "), t.text)
	c.pause_game()
	c._update_views(0.016)
	assert_true(c._render_label.visible, "duraklatmada etiket görünür")
	for t in _taps(c):
		assert_false(t.visible, "duraklatmada dokunulmaz")
	c._set_screen(PauseLogic.Screen.RESULT)
	for t in _taps(c):
		assert_false(t.visible, "sonuçta dokunulmaz")
	c.go_menu()
	for t in _taps(c):
		assert_false(t.visible)


func test_tap_text_follows_the_flag_state() -> void:
	assert_eq(
		DebugLabels.tap_text("düşman 1/1  taş 0/0\nkesme düzeltmesi: AÇIK (dokun)"), "dokun: AÇIK"
	)
	assert_eq(
		DebugLabels.tap_text("kaçışta 0  girilen 0\nçıkmaz kaçışı: KAPALI (dokun)"), "dokun: KAPALI"
	)
	assert_eq(DebugLabels.tap_text("tek satır"), "dokun", "ikinci satır yoksa yalnız 'dokun'")


func test_tapping_the_area_toggles_the_flag_and_the_label_does_not() -> void:
	var c := _controller()
	c.start_run()
	c._update_views(0.016)
	var was := c._escape_enabled
	var tap: Label = null
	for t in _taps(c):
		if t.get_meta(&"source") == c._escape_label:
			tap = t
	assert_not_null(tap)
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	tap.gui_input.emit(ev)
	assert_ne(c._escape_enabled, was, "dokunma alanı bayrağı çevirir")
	c.toggle_escape_fix()
	assert_eq(c._escape_enabled, was)


func test_debug_widgets_never_intersect_buttons_or_the_offscreen_arrow() -> void:
	var c := _controller()
	c.start_run()
	c._update_views(0.016)
	await get_tree().process_frame
	var screens := {
		"oyun": PauseLogic.Screen.PLAYING,
		"duraklatma": PauseLogic.Screen.PAUSED,
		"sonuç": PauseLogic.Screen.RESULT,
	}
	for label: String in screens:
		c._set_screen(screens[label])
		c.v2.update_views(0.0)
		await get_tree().process_frame
		var widgets: Array[Control] = [c._render_label, c._escape_label]
		widgets.append_array(_taps(c))
		var btns: Array[Control] = []
		_buttons(c.ui, btns)
		for w in widgets:
			if not w.visible:
				continue
			for b in btns:
				assert_false(
					w.get_global_rect().intersects(b.get_global_rect()),
					"%s: %s, %s düğmesiyle kesişmez" % [label, w.name, b.name]
				)
	# Ekran dışı ok: dairenin üst kenarı güvenli üst kenardan >= 62 px, üçgen ucu dahil >= 50 px -> y 40'tan aşağıda.
	var top_clear := OffscreenArrow.CIRCLE_EDGE - OffscreenArrow.TIP
	assert_gt(top_clear, 40.0, "ok glifi etiket bandının (y<=40) altında kalır")


func test_sd06_debug_strip_drops_by_safe_top_extra() -> void:
	var c := _controller()
	c.start_run()
	c._update_views(0.016)
	DebugLabels.apply_safe_area(c.ui, Vector4(0, 60, 0, 0))
	assert_almost_eq(c._render_label.position.y, DebugLabels.Y + 60.0, 0.01)
	for t in _taps(c):
		assert_almost_eq(t.position.y, DebugLabels.Y + 60.0, 0.01)
	assert_almost_eq(c._bounce_label.position.y, DebugLabels.Y + 60.0, 0.01)
	DebugLabels.apply_safe_area(c.ui, Vector4.ZERO)
	assert_almost_eq(c._render_label.position.y, DebugLabels.Y, 0.01, "çentiksizde eski yer")
