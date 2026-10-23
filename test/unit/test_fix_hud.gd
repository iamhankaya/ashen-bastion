extends GutTest
## Ara denetim düzeltmeleri (HUD): V-03 Lord bandı güvenli alan, V-04 ekran dışı ok kenar payı, V-06 kazanç başlığı boşluğu.

const NOTCH := Vector4(48.0, 130.0, 48.0, 80.0)


func _hud(extra: Variant = null) -> Hud:
	var host := Control.new()
	host.size = Vector2(1080.0, 2400.0)
	add_child_autofree(host)
	var h := Hud.new()
	host.add_child(h)
	h.bind(SimKit.make(1))
	if extra != null:
		h.apply_safe_area(extra)
	return h


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


# --- V-03 --------------------------------------------------------------------------------------------------


func test_boss_band_clears_hud_with_notch() -> void:
	var h := _hud(NOTCH)
	await _frames(3)
	h.show_boss_band(&"kale_lordu")
	h.boss_row.visible = true
	h.score_block.chip.visible = true
	var band := h.boss_band.get_global_rect()
	var others := {
		"SERİ çipi": h.score_block.chip.get_global_rect(),
		"kazanç başlığı": h.score_block.gain_label.get_global_rect(),
		"boss satırı": h.boss_row.get_global_rect(),
		"rozet satırı": h.buff_row.get_global_rect(),
		"pasif yuva": (h.passive_slots[0] as Control).get_global_rect(),
	}
	for k in others:
		assert_false(
			band.intersects(others[k]), "%s bandın altında kalmaz (%s ↔ %s)" % [k, band, others[k]]
		)
	assert_gte(
		band.position.y,
		h.boss_row.get_global_rect().end.y - 0.5,
		"bant boss satırının hemen altında"
	)


func test_boss_band_unchanged_without_notch() -> void:
	var h := _hud()
	await _frames(3)
	assert_almost_eq(h.boss_band.offset_top, 520.0, 0.01)
	assert_almost_eq(h.boss_band.offset_bottom, 652.0, 0.01)
	h.apply_safe_area(NOTCH)
	assert_almost_eq(h.boss_band.offset_top, 650.0, 0.01, "üst payı kadar iner")
	h.apply_safe_area(Vector4.ZERO)
	assert_almost_eq(h.boss_band.offset_top, 520.0, 0.01, "pay kalkınca geri gelir")


# --- V-04 --------------------------------------------------------------------------------------------------

const VIEW := Vector2(1080.0, 2400.0)


## Hedef yönüne göre ok dairesinin (yarıçap SIZE/2) ekran kenarına uzaklığı (en küçük).
func _edge_gap(target: Vector2, safe: Rect2) -> float:
	var r := OffscreenArrow.place(target, Vector2.ZERO, VIEW, safe, OffscreenArrow.MARGIN)
	assert_true(r["visible"])
	var c: Vector2 = r["pos"]
	var rad := OffscreenArrow.SIZE * 0.5
	return minf(minf(c.x - rad, VIEW.x - c.x - rad), minf(c.y - rad, VIEW.y - c.y - rad))


func test_arrow_circle_keeps_36px_from_screen_edge_without_notch() -> void:
	var safe := Rect2(Vector2.ZERO, VIEW)
	for t in [
		Vector2(3000, 0),
		Vector2(-3000, 0),
		Vector2(0, 3000),
		Vector2(0, -3000),
		Vector2(2500, 2500),
		Vector2(-2500, -2500)
	]:
		assert_gte(_edge_gap(t, safe), 36.0, "kenara >= 36 px (%s)" % t)


func test_arrow_circle_keeps_36px_plus_inset_with_notch() -> void:
	var safe := Rect2(Vector2(48.0, 130.0), VIEW - Vector2(96.0, 210.0))
	var rad := OffscreenArrow.SIZE * 0.5
	# hedef yönü -> [kenar uzaklığı ölçüsü, beklenen en az (36 + pay)]
	var left := OffscreenArrow.place(
		Vector2(-3000, 0), Vector2.ZERO, VIEW, safe, OffscreenArrow.MARGIN
	)
	var right := OffscreenArrow.place(
		Vector2(3000, 0), Vector2.ZERO, VIEW, safe, OffscreenArrow.MARGIN
	)
	var up := OffscreenArrow.place(
		Vector2(0, -3000), Vector2.ZERO, VIEW, safe, OffscreenArrow.MARGIN
	)
	var down := OffscreenArrow.place(
		Vector2(0, 3000), Vector2.ZERO, VIEW, safe, OffscreenArrow.MARGIN
	)
	assert_gte((left["pos"] as Vector2).x - rad, 36.0 + 48.0 - 0.01, "sol")
	assert_gte(VIEW.x - (right["pos"] as Vector2).x - rad, 36.0 + 48.0 - 0.01, "sağ")
	assert_gte((up["pos"] as Vector2).y - rad, 36.0 + 130.0 - 0.01, "üst")
	assert_gte(VIEW.y - (down["pos"] as Vector2).y - rad, 36.0 + 80.0 - 0.01, "alt")


func test_arrow_margin_is_safe_edge_plus_radius() -> void:
	assert_almost_eq(OffscreenArrow.MARGIN, UiKit.SAFE_EDGE + OffscreenArrow.SIZE * 0.5, 0.01)


# --- V-06 --------------------------------------------------------------------------------------------------


func test_gain_title_keeps_12px_from_streak_chip() -> void:
	var sb := ScoreBlock.new()
	sb.size = Vector2(460.0, 152.0)
	add_child_autofree(sb)
	sb.bind(SimKit.make(1))
	for m in [2, 3, 5, 9, 12]:
		sb._on_streak_changed(m, 1.0)
		var gain_right := sb.gain_label.position.x + sb.gain_label.size.x
		assert_gte(sb.chip.position.x - gain_right, 12.0, "×%d: boşluk >= 12 px" % m)
		var pop_left := sb.chip.position.x + sb.chip.size.x * (1.0 - ScoreBlock.CHIP_POP_SCALE)
		assert_gte(pop_left - gain_right, 12.0, "×%d: çip pop tepesinde de >= 12 px" % m)
