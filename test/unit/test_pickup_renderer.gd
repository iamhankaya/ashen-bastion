extends GutTest
## PickupRenderer: saf yardımcılar (ölçek, yanıp sönme, önizleme, fitil dolgusu) ve bağlama/çizim duman testi.


func test_spawn_scale_curve_overshoots_then_settles() -> void:
	assert_eq(PickupRenderer.spawn_scale(0), 0.0)
	assert_gt(PickupRenderer.spawn_scale(8), 1.0)
	assert_almost_eq(PickupRenderer.spawn_scale(15), 1.03, 0.1)
	assert_eq(PickupRenderer.spawn_scale(16), 1.0)
	assert_eq(PickupRenderer.spawn_scale(900), 1.0)
	var peak := 0.0
	for a in 16:
		peak = maxf(peak, PickupRenderer.spawn_scale(a))
	assert_almost_eq(peak, 1.15, 0.03)


func test_blink_only_in_last_five_seconds_with_final_fade() -> void:
	assert_eq(PickupRenderer.blink_alpha(301, 300, 0.1), 1.0)
	var lo := 1.0
	var hi := 0.0
	for k in 100:
		var a := PickupRenderer.blink_alpha(250, 300, float(k) / 100.0)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	assert_almost_eq(lo, 0.45, 0.02)
	assert_almost_eq(hi, 1.0, 0.02)
	assert_lt(
		PickupRenderer.blink_alpha(3, 300, 0.0), PickupRenderer.blink_alpha(250, 300, 0.0) + 0.001
	)
	assert_eq(PickupRenderer.blink_alpha(0, 300, 0.0), 0.0)


func test_preview_alpha_fades_with_player_distance() -> void:
	assert_almost_eq(PickupRenderer.preview_alpha(100.0), 0.35, 0.0001)
	assert_almost_eq(PickupRenderer.preview_alpha(500.0), 0.35, 0.0001)
	assert_eq(PickupRenderer.preview_alpha(540.0), 0.0)
	assert_between(PickupRenderer.preview_alpha(520.0), 0.01, 0.34)


func test_fuse_fill_alpha_linear_and_dash_count_46() -> void:
	assert_almost_eq(PickupRenderer.fuse_fill_alpha(48, 48), 0.08, 0.0001)
	assert_almost_eq(PickupRenderer.fuse_fill_alpha(0, 48), 0.28, 0.0001)
	assert_almost_eq(PickupRenderer.fuse_fill_alpha(24, 48), 0.18, 0.0001)
	assert_eq(PickupRenderer.dash_count(320.0), 46)


func test_rarity_colors_differ_and_bob_is_bounded() -> void:
	var cols := [
		PickupRenderer.rarity_color(&"common"),
		PickupRenderer.rarity_color(&"uncommon"),
		PickupRenderer.rarity_color(&"rare")
	]
	assert_ne(cols[0], cols[1])
	assert_ne(cols[1], cols[2])
	assert_eq(cols[2], UiKit.AMBER)
	for k in 50:
		assert_lte(absf(PickupRenderer.bob_offset(float(k) * 0.13, k)), 6.0001)


func test_icons_load_for_every_kind_and_draw_counts_stay_within_twelve() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "pickups": false})
	var r := PickupRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	assert_eq(r._icons.size(), sim.data.pickup_ids.size())
	for t in r._icons:
		assert_not_null(t, "ikon yüklenir")
	for k in 8:
		sim.debug_spawn_pickup(
			sim.data.pickup_ids[k % 6], sim.player_pos + Vector2(200 + k * 10, 0)
		)
	for k in 4:
		sim.bombs.plant(sim.player_pos + Vector2(0, 100 * k), 48, 320.0, 4)
	r.refresh(0.016)
	await get_tree().process_frame
	assert_lte(r.last_draw_items, PickupRenderer.MAX_ITEMS)
	assert_eq(r.last_draw_items, 12)


func test_bomb_ring_hidden_when_run_is_won_or_lost() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "pickups": false})
	var r := PickupRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	sim.bombs.plant(sim.player_pos, 48, 320.0, 4)
	r.refresh(0.016)
	await get_tree().process_frame
	assert_eq(r.last_draw_items, 1)
	sim.hp = 0.0
	SimKit.run(sim, 3)
	assert_eq(sim.state, GameSim.State.LOST)
	r.refresh(0.016)
	await get_tree().process_frame
	assert_eq(r.last_draw_items, 0, "LOST: halka çizilmez")


func test_collect_event_queues_fx_ring_buffer() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "pickups": false})
	var r := PickupRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	sim.debug_spawn_pickup(&"kizil_iksir", sim.player_pos)
	sim.debug_collect_pickups()
	r.refresh(0.016)
	await get_tree().process_frame
	assert_gt(r.last_fx_items, 0)
	for k in 30:
		r._on_collected(&"cekim_tasi", Vector2.ZERO)
	assert_eq(r._fx_kind.size(), PickupRenderer.MAX_FX, "halka tampon taşmaz")
	r.bind(null)
	r.refresh(0.016)
