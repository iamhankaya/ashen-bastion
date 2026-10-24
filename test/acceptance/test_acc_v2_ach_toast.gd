extends GutTest
## Kabul (v2.0 B4): ToastQueue zamanlaması (sanal tick, duvar saati yok), AchievementToast geometrisi/fare süzgeci.
## Geometri sabitleri: test/helpers/expected_layout_v2.gd (kaynak: docs/design/v2.0/DESIGN.md §5.2, plan B4).
## ToastQueue ve AchievementToast.rect sözleşmede GERÇEK olduğundan o testler dilimsizdir; ekran düğümü testleri B ister.

const EPS := 1.0e-6
const TOTAL := ToastQueue.IN_SEC + ToastQueue.HOLD_SEC + ToastQueue.OUT_SEC


func _gate() -> bool:
	return V2Slice.require(self, "B")


func _run(q: ToastQueue, secs: float, dt: float = 1.0 / 60.0) -> void:
	var left := secs
	while left > 0.0:
		var d := minf(dt, left)
		q.tick(d)
		left -= d


func test_b4_queue_constants() -> void:
	assert_eq(ToastQueue.MAX_QUEUE, 3)
	assert_almost_eq(ToastQueue.IN_SEC, 0.22, EPS)
	assert_almost_eq(ToastQueue.HOLD_SEC, 2.1, EPS)
	assert_almost_eq(ToastQueue.OUT_SEC, 0.18, EPS)
	assert_almost_eq(ToastQueue.GAP_SEC, 0.15, EPS)
	assert_almost_eq(TOTAL, 2.5, EPS, "toplam görünür süre 2,5 sn")


func test_b4_single_toast_visible_for_exactly_2_5_seconds() -> void:
	var q := ToastQueue.new()
	assert_true(q.push(&"ilk_kan"))
	assert_eq(q.current(), &"ilk_kan")
	_run(q, TOTAL - 0.01)
	assert_eq(q.current(), &"ilk_kan", "2,49 sn: hâlâ görünür")
	_run(q, 0.02)
	assert_eq(q.current(), &"", "2,5 sn sonrası görünmez")


func test_b4_at_most_one_visible_and_150ms_gap_between_toasts() -> void:
	var q := ToastQueue.new()
	q.push(&"a")
	q.push(&"b")
	_run(q, TOTAL + 0.01)
	assert_eq(q.current(), &"", "arada 150 ms boşluk: ikinci henüz yok")
	assert_eq(q.phase(), ToastQueue.Phase.GAP)
	_run(q, ToastQueue.GAP_SEC)
	assert_eq(q.current(), &"b", "boşluktan sonra ikinci")
	# Hiçbir anda iki kimlik birden görünmez (current tek değerdir); sıra a -> b.
	_run(q, TOTAL + ToastQueue.GAP_SEC + 0.05)
	assert_eq(q.phase(), ToastQueue.Phase.IDLE)


func test_b4_waiting_capped_at_three_and_overflow_counted() -> void:
	var q := ToastQueue.new()
	assert_true(q.push(&"g"), "görünür")
	assert_true(q.push(&"b1"))
	assert_true(q.push(&"b2"))
	assert_true(q.push(&"b3"))
	assert_false(q.push(&"x1"), "bekleyen 3'te: reddedilir")
	assert_false(q.push(&"x2"))
	assert_eq(q.overflow, 2)
	assert_eq(q.waiting_count(), 3)


func test_b4_queue_plays_in_order_and_goes_idle() -> void:
	var q := ToastQueue.new()
	for id in [&"g", &"b1", &"b2", &"b3"]:
		q.push(id)
	var seen: Array[StringName] = []
	for i in 4000:
		q.tick(1.0 / 60.0)
		var c := q.current()
		if c != &"" and (seen.is_empty() or seen[-1] != c):
			seen.append(c)
	assert_eq(seen, [&"g", &"b1", &"b2", &"b3"])
	assert_eq(q.phase(), ToastQueue.Phase.IDLE)


func test_b4_tick_zero_and_negative_freeze_queue() -> void:
	var q := ToastQueue.new()
	q.push(&"a")
	q.tick(0.1)
	var ph := q.phase()
	var oa := q.offset_alpha()
	for i in 600:
		q.tick(0.0)  # duraklama: view_dt = 0
	q.tick(-1.0)
	assert_eq(q.phase(), ph)
	assert_eq(q.offset_alpha(), oa)
	assert_eq(q.current(), &"a")


func test_b4_offset_alpha_in_hold_out_curve() -> void:
	var q := ToastQueue.new()
	assert_eq(q.offset_alpha(), Vector2.ZERO, "boşta görünmez")
	q.push(&"a")
	var start := q.offset_alpha()
	assert_almost_eq(start.x, 24.0, 0.01, "başlangıç kayması 24 px")
	assert_almost_eq(start.y, 0.0, 0.01, "başlangıç alfa 0")
	_run(q, ToastQueue.IN_SEC + 0.5)
	assert_eq(q.phase(), ToastQueue.Phase.HOLD)
	assert_eq(q.offset_alpha(), Vector2(0.0, 1.0))
	_run(q, ToastQueue.HOLD_SEC - 0.5 + ToastQueue.OUT_SEC * 0.5)
	assert_eq(q.phase(), ToastQueue.Phase.OUT)
	var mid := q.offset_alpha()
	assert_between(mid.y, 0.3, 0.7, "çıkışta alfa düşer")


func test_b4_clear_resets_everything() -> void:
	var q := ToastQueue.new()
	for i in 6:
		q.push(StringName("t%d" % i))
	q.clear()
	assert_eq(q.current(), &"")
	assert_eq(q.phase(), ToastQueue.Phase.IDLE)
	assert_eq(q.overflow, 0)
	assert_eq(q.waiting_count(), 0)


func test_b4_toast_rect_matches_design_and_follows_safe_top() -> void:
	assert_eq(AchievementToast.rect(0.0), ExpectedLayoutV2.TOAST)
	var r := AchievementToast.rect(100.0)
	assert_eq(r, Rect2(150.0, 920.0, 780.0, 120.0))
	assert_eq(r.size, ExpectedLayoutV2.TOAST.size)


func test_b4_toast_rect_avoids_hud_regions_for_three_safe_paddings() -> void:
	for safe in [
		ExpectedLayoutV2.SAFE_NONE, ExpectedLayoutV2.SAFE_WIDE, ExpectedLayoutV2.SAFE_NOTCH
	]:
		var top: float = (safe as Vector4).y
		var toast := AchievementToast.rect(top)
		for zone in ExpectedLayoutV2.TOAST_AVOID:
			var rect: Rect2 = zone[1]
			if zone[0] == "lord_bandi":
				rect = Rect2(rect.position, Vector2(rect.size.x, 782.0 - rect.position.y))  # çentik payıyla <= 782
			assert_false(
				toast.intersects(rect), "bildirim %s ile kesişmez (üst pay %s)" % [zone[0], top]
			)
		assert_lte(toast.end.y, ExpectedLayoutV2.REF.y, "ekran içinde")


func test_b4_toast_node_ignores_mouse_including_children() -> void:
	if _gate():
		return
	var t := AchievementToast.new()
	add_child_autofree(t)
	var d := GameData.load_default()
	t.show_def(d.get_achievement(&"ilk_kan"))
	assert_eq(t.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var n := _check_ignore(t)
	assert_gt(n, 0, "alt düğüm var (kutu içeriği)")


func _check_ignore(node: Node) -> int:
	var count := 0
	for c in node.get_children():
		if c is Control:
			assert_eq(
				(c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s IGNORE" % c.name
			)
			count += 1
		count += _check_ignore(c)
	return count


func test_b4_toast_shows_name_of_definition() -> void:
	if _gate():
		return
	var t := AchievementToast.new()
	add_child_autofree(t)
	var d := GameData.load_default()
	t.show_def(d.get_achievement(&"bes_dakika"))
	assert_true(
		AchKit.any_text_contains(t, UiKit.upper_tr("Beş Dakika")), "başarım adı bildirimde görünür"
	)


func test_b4_toast_apply_state_changes_position_or_alpha() -> void:
	if _gate():
		return
	var t := AchievementToast.new()
	add_child_autofree(t)
	t.show_def(GameData.load_default().get_achievement(&"ilk_kan"))
	var q := ToastQueue.new()
	q.push(&"ilk_kan")
	t.apply_state(q)
	var pos0 := t.position
	var a0 := t.modulate.a
	_run(q, ToastQueue.IN_SEC + 0.3)
	t.apply_state(q)
	assert_true(
		t.position != pos0 or not is_equal_approx(t.modulate.a, a0), "kayma ya da alfa uygulanır"
	)
