extends GutTest
## U3 rüzgar görünümü: WindRenderer ekran içi çizim sınırı, Girdap halkası, FxRenderer bağlantısı (dalga halkası).


func _fx_with_sim(sim: GameSim) -> FxRenderer:
	var cam := CameraRig.new()
	add_child_autofree(cam)
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	fx.bind(sim, cam)
	return fx


func test_fx_renderer_owns_a_wind_renderer_child_with_the_zone_blend_of_zyfen_fx() -> void:
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	assert_not_null(fx.wind_renderer)
	assert_eq(fx.wind_renderer.get_parent(), fx)
	assert_eq(fx.wind_renderer.use_parent_material, ZyfenFx.ZONES_ADDITIVE)


func test_draws_at_most_max_drawn_zones_even_with_a_full_pool() -> void:
	var sim := WindKit.make()
	for k in ZonePool.CAP:
		WindSystem.spawn_zone(
			sim,
			ZonePool.KIND_TWISTER,
			Vector2(50 * (k % 8), 50 * (k / 8)),
			{"radius": 100.0, "life": 9.0}
		)
	assert_eq(sim.zones.count, ZonePool.CAP)
	var fx := _fx_with_sim(sim)
	fx.update_fx(0.016)
	await wait_process_frames(2)
	assert_gt(fx.wind_renderer.drawn_count, 0, "çizim yapıldı")
	assert_lte(fx.wind_renderer.drawn_count, WindRenderer.MAX_DRAWN)


func test_zones_outside_the_view_are_not_drawn() -> void:
	var sim := WindKit.make()
	WindSystem.spawn_zone(
		sim, ZonePool.KIND_GIANT, Vector2(90000, 90000), {"radius": 190.0, "life": 9.0}
	)
	WindSystem.spawn_zone(sim, ZonePool.KIND_POCKET, Vector2(40, 40), {"radius": 70.0, "life": 9.0})
	var fx := _fx_with_sim(sim)
	fx.update_fx(0.016)
	await wait_process_frames(2)
	assert_eq(fx.wind_renderer.drawn_count, 1)


func test_unbinding_clears_the_drawing() -> void:
	var sim := WindKit.make()
	WindSystem.spawn_zone(
		sim, ZonePool.KIND_TWISTER, Vector2(10, 10), {"radius": 100.0, "life": 9.0}
	)
	var fx := _fx_with_sim(sim)
	fx.update_fx(0.016)
	await wait_process_frames(2)
	assert_eq(fx.wind_renderer.drawn_count, 1)
	fx.bind(null)
	fx.update_fx(0.016)
	await wait_process_frames(2)
	assert_eq(fx.wind_renderer.drawn_count, 0)


func test_wind_wave_signal_adds_a_ring_and_big_waves_shake_the_camera() -> void:
	var sim := WindKit.make()
	var fx := _fx_with_sim(sim)
	assert_eq(fx.ring_count(), 0)
	sim.fx.wind_wave.emit(Vector2(5, 5), 200.0, false)
	assert_eq(fx.ring_count(), 1)
	sim.fx.wind_wave.emit(Vector2(5, 5), 900.0, true)
	assert_eq(fx.ring_count(), 2)
	fx.bind(null)
	sim.fx.wind_wave.emit(Vector2(5, 5), 200.0, false)
	assert_eq(fx.ring_count(), 0, "bağ kopunca halka yok (bind sıfırlar, sinyal bağlı değil)")


func test_wind_renderer_reads_only_never_changes_sim_state() -> void:
	var sim := WindKit.make(&"girdap", 3)
	WindSystem.spawn_zone(
		sim, ZonePool.KIND_TWISTER, Vector2(100, 0), {"radius": 100.0, "life": 9.0, "dmg": 3.0}
	)
	var fx := _fx_with_sim(sim)
	var h := sim.state_hash()
	for _k in 5:
		fx.update_fx(0.016)
		await wait_process_frames(1)
	assert_eq(sim.state_hash(), h)


func test_armless_shot_adds_palm_ring_but_gunslinger_shot_does_not() -> void:
	var zy := WindKit.make()
	var fx := _fx_with_sim(zy)
	zy.bus.shot_fired.emit(0, Vector2(10, 10), Vector2.RIGHT)
	assert_eq(fx.ring_count(), 1, "kolsuz atış avuç halkası")
	zy.fx.wind_cast.emit(Vector2(5, 5))
	assert_eq(fx.ring_count(), 2)
	var gs := GameSim.new(1, &"gunslinger")
	var fx2 := _fx_with_sim(gs)
	gs.bus.shot_fired.emit(0, Vector2(10, 10), Vector2.RIGHT)
	assert_eq(fx2.ring_count(), 0)


func test_draw_calls_stay_under_the_budget_even_with_a_crowd_of_zones() -> void:
	var sim := WindKit.make()
	for k in ZonePool.CAP:
		var kind := ZonePool.KIND_GIANT if k % 3 == 0 else ZonePool.KIND_TWISTER
		WindSystem.spawn_zone(
			sim, kind, Vector2(50 * (k % 8), 50 * (k / 8)), {"radius": 120.0, "life": 9.0}
		)
	var fx := _fx_with_sim(sim)
	for _k in 3:
		fx.update_fx(0.016)
		await wait_process_frames(1)
	var wr := fx.wind_renderer
	assert_eq(wr.drawn_count, WindRenderer.MAX_DRAWN)
	assert_gt(wr.draw_calls(), 0)
	assert_lte(wr.draw_calls(), WindRenderer.MAX_DRAW_CALLS, "kalabalıkta taş/şimşek düşer")


func test_few_zones_get_full_layers_and_a_crowd_gets_fewer_stones() -> void:
	var sim := WindKit.make()
	WindSystem.spawn_zone(sim, ZonePool.KIND_GIANT, Vector2(10, 10), {"radius": 190.0, "life": 9.0})
	var fx := _fx_with_sim(sim)
	for _k in 40:
		sim.step(Vector2.ZERO)
		fx.update_fx(0.016)
	await wait_process_frames(2)
	var wr := fx.wind_renderer
	assert_gt(wr.calls[WindRenderer.PASS_FLOW], 0, "akış katmanı çizildi")
	var solo := wr.draw_calls()
	assert_gt(solo, 6, "taban + gövde + akış + taşlar")
	for k in 12:
		WindSystem.spawn_zone(
			sim, ZonePool.KIND_GIANT, Vector2(60 * k, 80), {"radius": 190.0, "life": 9.0}
		)
	fx.update_fx(0.016)
	await wait_process_frames(2)
	assert_lt(
		float(wr.draw_calls()) / float(sim.zones.count), float(solo), "bölge başına çizim düşer"
	)


func test_pocket_bursts_at_the_end_and_zone_state_is_never_written() -> void:
	var sim := WindKit.make()
	WindSystem.spawn_zone(sim, ZonePool.KIND_POCKET, Vector2(10, 10), {"radius": 80.0, "life": 0.2})
	var fx := _fx_with_sim(sim)
	var h := sim.state_hash()
	fx.update_fx(0.016)
	await wait_process_frames(2)
	assert_eq(fx.wind_renderer.calls[WindRenderer.PASS_BACK], 2, "küre + patlama (2 doku)")
	assert_eq(sim.state_hash(), h)


func test_body_and_flow_draw_behind_enemies_and_only_front_layer_is_in_front() -> void:
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	var w := fx.wind_renderer
	# Etkin z = FxRenderer 5 + bağıl; düşman/küre katmanları z 0.
	assert_lt(fx.z_index + w.z_index, 0, "gövde/akış/taban düşmanların arkasında")
	assert_gt(fx.z_index + w.z_index + w.get_node("Front").z_index, 0, "taş ve şimşek önde")


func test_overlapping_twisters_are_drawn_progressively_paler() -> void:
	var sim := WindKit.make()
	for k in 3:
		WindSystem.spawn_zone(
			sim, ZonePool.KIND_TWISTER, Vector2(10 + k, 10), {"radius": 100.0, "life": 9.0}
		)
	var fx := _fx_with_sim(sim)
	fx.update_fx(0.016)
	await wait_process_frames(2)
	var w := fx.wind_renderer
	assert_gt(w._fade[0], w._fade[1], "ikinci hortum birincisinden soluk")
	assert_gt(w._fade[1], w._fade[2], "üçüncü daha soluk")
	assert_gte(w._fade[2], WindRenderer.OVERLAP_MIN * WindRenderer.CROWD_MIN)


func test_body_draw_size_is_capped_by_screen_height_without_touching_sim_radius() -> void:
	var sim := WindKit.make()
	WindSystem.spawn_zone(sim, ZonePool.KIND_GIANT, Vector2(10, 10), {"radius": 900.0, "life": 9.0})
	var fx := _fx_with_sim(sim)
	var w := fx.wind_renderer
	var tex := ZyfenFx.texture(ZyfenFx.TUFAN_GOVDE)
	var wb := 900.0 * WindRenderer.GIANT_BODY
	var hb := wb * float(tex.get_height()) / float(tex.get_width())
	var cap := w._size_cap(hb)
	var view_h := fx._camera.view_size().y
	assert_lt(cap, 1.0)
	assert_lte(hb * cap * WindRenderer.BODY_SPAN, view_h * WindRenderer.MAX_BODY_SCREEN + 0.01)
	assert_eq(sim.zones.radius[0], 900.0, "sim yarıçapı değişmez")


func test_zyfen_map_grade_darkens_and_warms_whites() -> void:
	var g := ZyfenFx.grade(Color(1, 1, 1, 0.5))
	assert_lt(g.r, 1.0)
	assert_gt(g.r, g.b, "beyaz sıcak kül tonuna kayar")
	assert_eq(g.a, 0.5, "alfa korunur")
