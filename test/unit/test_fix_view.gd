extends GutTest
## Ara denetim düzeltmeleri (görünüm): V-07 yaygın eklenti parlaması, V-08 seviye halkası zamanlaması.

# --- V-07 --------------------------------------------------------------------------------------------------


func test_pickup_glow_is_additive_with_a_soft_falloff_not_a_flat_plate() -> void:
	var r := PickupRenderer.new()
	add_child_autofree(r)
	var glow := r.get_node("Glow") as CanvasItem
	assert_eq((glow.material as CanvasItemMaterial).blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)
	var img := PickupRenderer.glow_texture().get_image()
	var c := img.get_width() / 2
	assert_gte(img.get_pixel(c, c).a, 0.95, "merkez dolu")
	# yarıçapın %50, %80 ve %95'inde alfa tek düze azalır; kenarda ~0 (sert kenar yok)
	var prev := 1.0
	for f in [0.5, 0.8, 0.95]:
		var a := img.get_pixel(c + int(float(c) * f), c).a
		assert_lt(a, prev, "kenara doğru azalır (%.2f)" % f)
		prev = a
	assert_lt(prev, 0.05, "kenarda sönük")


# --- V-08 --------------------------------------------------------------------------------------------------


func _run(a: PlayerAnim, sec: float) -> void:
	for _i in roundi(sec * 60.0):
		a.update(1.0 / 60.0, Vector2.ZERO, false, -1.0)


func test_deferred_ring_waits_for_the_card_choice() -> void:
	var a := PlayerAnim.new()
	a.defer_ring = true
	a.on_level_up()
	_run(a, 0.3)
	assert_gt(a.halo, 0.0, "ön vurgu sürüyor")
	assert_eq(a.level_ring, -1.0, "kart seçilmeden halka yok")
	a.on_level_chosen()
	_run(a, 0.225)
	assert_gt(a.level_ring, 100.0, "seçimden sonra cubic-out")
	_run(a, 0.225)
	assert_almost_eq(a.level_ring, 180.0, 4.0, "450. ms'de 180 px")
	_run(a, 0.1)
	assert_eq(a.level_ring, -1.0, "bitince yok")


func test_deferred_ring_still_plays_when_the_halo_already_ended() -> void:
	var a := PlayerAnim.new()
	a.defer_ring = true
	a.on_level_up()
	_run(a, 2.0)  # uzun kart seçimi
	assert_eq(a.halo, 0.0)
	a.on_level_chosen()
	_run(a, 0.1)
	assert_gt(a.level_ring, 0.0)


func test_ring_starts_at_level_up_by_default() -> void:
	var a := PlayerAnim.new()
	a.on_level_up()
	_run(a, 0.1)
	assert_gt(a.level_ring, 0.0, "varsayılan davranış korunur")
	a.on_level_chosen()  # varsayılanda etkisiz


# --- V-09 --------------------------------------------------------------------------------------------------


func test_debug_labels_do_not_cover_the_badge_row_or_the_drum() -> void:
	assert_true(OS.is_debug_build(), "test koşusu debug derleme")
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.start_run()
	c._update_views(0.016)
	await get_tree().process_frame
	for extra: Vector4 in [Vector4.ZERO, Vector4(48.0, 130.0, 48.0, 80.0)]:
		c.hud.apply_safe_area(extra)
		await get_tree().process_frame
		var zone := {
			"rozet satırı": c.hud.buff_row.get_global_rect(),
			"tambur": c.hud.drum.get_global_rect(),
		}
		for label: Label in [c._render_label, c._escape_label]:
			assert_true(label.visible)
			var r: Rect2 = (label as Control).get_global_rect()
			for k: String in zone:
				assert_false(
					r.intersects(zone[k]), "%s etiketi %s bölgesini örtmez" % [label.name, k]
				)
			assert_gte(r.position.x, 0.0)
			assert_lte(r.end.x, 1080.0 - UiKit.SAFE_EDGE + 0.01, "sağ güvenli kenar")
			assert_lte(r.end.y, 2400.0 + 0.01)
