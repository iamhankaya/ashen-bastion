extends GutTest
## ScoreBlock: HUD skor sütunu (DESIGN §3.2): konumlar, ease, pop kuralları, SERİ çipi.

var _sim: GameSim


func _block() -> ScoreBlock:
	_sim = SimKit.make(1)
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var b := ScoreBlock.new()
	b.position = Vector2(1080 - 36 - 460, 284)
	b.size = Vector2(460, 152)
	host.add_child(b)
	b.bind(_sim)
	return b


func test_hidden_until_bound() -> void:
	var b := ScoreBlock.new()
	add_child_autofree(b)
	assert_false(b.visible)
	b.refresh(0.016)  # bağlanmamış: sessizce no-op
	b.bind(SimKit.make(1))
	assert_true(b.visible)


func test_static_rules() -> void:
	assert_true(ScoreBlock.should_pop(50, 0.3))
	assert_false(ScoreBlock.should_pop(49, 5.0), "kazanç < 50")
	assert_false(ScoreBlock.should_pop(50, 0.29), "son pop'tan < 300 ms")
	assert_false(ScoreBlock.is_big_gain(399))
	assert_true(ScoreBlock.is_big_gain(400))
	assert_eq(ScoreBlock.tier_of(1), 0)
	assert_eq(ScoreBlock.tier_of(2), 1)
	assert_eq(ScoreBlock.tier_of(3), 2)
	assert_eq(ScoreBlock.tier_of(4), 2)
	assert_eq(ScoreBlock.tier_of(5), 3)
	assert_eq(ScoreBlock.format_score(1234567), "1.234.567")
	assert_eq(ScoreBlock.format_score(999999999), "99.999.999", "tavan")
	assert_eq(ScoreBlock.format_score(-5), "0")


func test_layout_matches_design_offsets() -> void:
	var b := _block()
	await get_tree().process_frame
	assert_eq(b.label_skor.position.y, 0.0)
	assert_eq(b.value_label.position.y, 28.0)
	assert_eq(b.label_skor.text, "SKOR")
	assert_eq(b.label_skor.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	assert_eq(b.value_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	assert_eq(b.value_label.get_theme_font_size(&"font_size"), 60)
	assert_eq(b.chip.position.y, 104.0)
	assert_eq(b.chip.size.y, 48.0)
	assert_almost_eq(b.chip.position.x + b.chip.size.x, 460.0, 0.01, "çip sağa hizalı")
	assert_gte(b.chip.size.x, 160.0)
	assert_eq(b.gain_label.position.y, 110.0)
	assert_lt(
		b.gain_label.position.x + b.gain_label.size.x, b.chip.position.x, "başlık çipin solunda"
	)


func test_eased_reaches_target_within_180ms() -> void:
	var shown := 0.0
	for i in 11:
		shown = ScoreBlock.eased(shown, 5000, 1.0 / 60.0)
	assert_gt(shown, 5000.0 * 0.95, "11 kare (183 ms) sonra hedefe yakın")
	assert_eq(ScoreBlock.eased(0.0, 5000, 0.18), 5000.0)
	assert_eq(ScoreBlock.eased(123.0, 5000, 0.0), 123.0, "dt 0: değişmez")


func test_value_follows_score_and_lands_exactly_after_180ms() -> void:
	var b := _block()
	await get_tree().process_frame
	_sim.score.on_kill(&"elit_karga", 1)
	_sim.score.on_kill(&"elit_karga", 1)
	_sim.score.on_kill(&"elit_karga", 1)
	for i in 4:
		b.refresh(1.0 / 60.0)
	assert_ne(b.value_label.text, "4.500", "ilk kareler yaklaşır, atlamaz")
	for i in 8:
		b.refresh(1.0 / 60.0)
	assert_eq(b.value_label.text, "4.500")


func test_pop_only_when_gain_ge_50_and_300ms_apart() -> void:
	var b := _block()
	await get_tree().process_frame
	b.refresh(0.5)
	_sim.bus.score_changed.emit(10, 1, 10)
	b.refresh(0.04)
	assert_eq(b.value_label.scale, Vector2.ONE, "10 puan pop yapmaz")
	_sim.bus.score_changed.emit(60, 1, 50)
	b.refresh(0.08)
	assert_almost_eq(b.value_label.scale.x, 1.08, 0.01, "80 ms'de tepe 1,08")
	b.refresh(0.16)
	assert_almost_eq(b.value_label.scale.x, 1.0, 0.01, "toplam 240 ms'de 1'e döner")
	_sim.bus.score_changed.emit(120, 1, 60)  # son pop'tan 240 ms
	b.refresh(0.08)
	assert_eq(b.value_label.scale, Vector2.ONE, "300 ms dolmadan ikinci pop yok")
	b.refresh(0.2)
	_sim.bus.score_changed.emit(180, 1, 60)
	b.refresh(0.08)
	assert_gt(b.value_label.scale.x, 1.05)


func test_big_gain_pops_bigger_and_shows_fading_title() -> void:
	var b := _block()
	await get_tree().process_frame
	b.refresh(0.5)
	_sim.bus.score_changed.emit(1500, 1, 1500)
	b.refresh(0.08)
	assert_almost_eq(b.value_label.scale.x, 1.18, 0.01)
	assert_true(b.gain_label.visible)
	assert_eq(b.gain_label.text, "+1.500")
	assert_almost_eq(b.gain_label.modulate.a, 1.0 - 0.08 / 0.9, 0.02)
	b.refresh(0.9)
	assert_false(b.gain_label.visible, "900 ms'de solar")


func test_small_gain_has_no_title() -> void:
	var b := _block()
	await get_tree().process_frame
	_sim.bus.score_changed.emit(399, 1, 399)
	b.refresh(0.016)
	assert_false(b.gain_label.visible)


func test_chip_hidden_at_x1_visible_at_x2_with_bar_counting_down() -> void:
	var b := _block()
	await get_tree().process_frame
	b.refresh(0.016)
	assert_false(b.chip.visible)
	for i in 10:
		_sim.score.on_kill(&"curumus_piyade", _sim.step_count)
	b.refresh(0.016)
	assert_true(b.chip.visible)
	assert_eq(b.chip.mult, 2)
	assert_almost_eq(b.chip.fraction, 1.0, 0.001, "yeni öldürmede çubuk dolu")
	SimKit.run(_sim, 90)
	b.refresh(0.016)
	assert_almost_eq(b.chip.fraction, 0.5, 0.02, "90 adım sonra yarım")
	SimKit.run(_sim, 100)
	b.refresh(0.3)
	b.refresh(0.3)
	assert_false(b.chip.visible, "pencere dolunca kırılma animasyonundan sonra gizli")


func test_chip_break_animation_runs_220ms_then_hides() -> void:
	var b := _block()
	await get_tree().process_frame
	for i in 10:
		_sim.score.on_kill(&"curumus_piyade", _sim.step_count)
	b.refresh(0.5)
	_sim.score.break_streak(_sim.step_count)
	b.refresh(0.11)
	assert_true(b.chip.visible)
	assert_almost_eq(b.chip.scale.x, 0.9, 0.02, "110 ms: 1 -> 0,8 yarı yol")
	assert_lt(b.chip.alpha, 1.0)
	b.refresh(0.12)
	assert_false(b.chip.visible)


func test_chip_pop_on_tier_increase() -> void:
	var b := _block()
	await get_tree().process_frame
	for i in 10:
		_sim.score.on_kill(&"curumus_piyade", _sim.step_count)
	b.refresh(0.09)
	assert_almost_eq(b.chip.scale.x, 1.25, 0.02, "90 ms: tepe 1,25")
	b.refresh(0.2)
	assert_eq(b.chip.scale, Vector2.ONE)


func test_rebinding_to_a_new_sim_resets_display_and_disconnects_old() -> void:
	var b := _block()
	var old := _sim
	_sim.score.on_kill(&"elit_karga", 1)
	b.refresh(0.5)
	assert_eq(b.value_label.text, "1.500")
	var fresh := SimKit.make(2)
	b.bind(fresh)
	assert_eq(b.value_label.text, "0")
	assert_false(old.bus.score_changed.is_connected(b._on_score_changed))
	b.bind(null)
	b.refresh(0.1)
	assert_true(fresh.bus.score_changed.get_connections().is_empty())
