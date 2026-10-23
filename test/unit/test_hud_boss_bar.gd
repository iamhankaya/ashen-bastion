extends GutTest
## N2: elit/Lord can satırı oyuncu canından ayrı, ad ≥26 px, Lord daha kalın ve ayrı renkte; çok elitte "+N".


func _hud(sim: GameSim) -> Hud:
	var h := Hud.new()
	add_child_autofree(h)
	h.bind(sim)
	return h


func _scan(h: Hud) -> void:
	for i in 6:
		h.refresh(0.016)


func test_row_is_hidden_without_elites_and_sits_on_its_own_row() -> void:
	var sim := SimKit.make(1)
	var h := _hud(sim)
	_scan(h)
	assert_false(h.boss_row.visible)
	assert_false(h.boss_bar.visible)
	var hp: Control = h.hp_bar
	var passive: Control = h.passive_slots[0]
	var band: Control = h.boss_band
	assert_gte(h.boss_row.offset_top, passive.offset_bottom, "pasif yuva satırının altında")
	assert_lte(h.boss_row.offset_bottom, band.offset_top + 0.5, "uyarı bandına taşmaz")
	assert_gte(h.boss_row.offset_top, hp.offset_bottom + 100.0, "oyuncu can çubuğundan ayrı satır")
	assert_eq(h.boss_row.anchor_left, 0.5, "ortada")
	assert_almost_eq(h.boss_row.offset_right - h.boss_row.offset_left, Hud.BOSS_W, 0.01)
	assert_gte(Hud.BOSS_W, 700.0)
	var half := Hud.BOSS_W * 0.5
	assert_gte(540.0 - half, UiKit.SIDE, "1080 referans genişlikte yan güvenli kenar ≥36 px")


func test_elite_row_shows_name_at_least_26px_and_bar() -> void:
	var sim := SimKit.make(1)
	var id := sim.debug_spawn(&"elit_piyade", Vector2(600, 0))
	assert_gte(id, 0)
	var h := _hud(sim)
	_scan(h)
	assert_true(h.boss_row.visible)
	assert_true(h.boss_bar.visible)
	assert_eq(h.boss_name.text, "ELİT PİYADE", "Cinzel: Türkçe büyük harf (i→İ)")
	assert_gte(h.boss_name.get_theme_font_size(&"font_size"), 26)
	assert_false(h.boss_is_lord)
	assert_eq(h.boss_extra, 0)
	assert_almost_eq(h.boss_bar.value, 1.0, 0.001)
	sim.enemies.hp[EnemyPool.index_of(id)] *= 0.25
	_scan(h)
	assert_almost_eq(h.boss_bar.value, 0.25, 0.01)


func test_several_elites_show_the_strongest_and_a_plus_n_suffix() -> void:
	var sim := SimKit.make(1)
	sim.debug_spawn(&"elit_karga", Vector2(800, 0))
	sim.debug_spawn(&"elit_piyade", Vector2(-800, 0))
	sim.debug_spawn(&"elit_sovalye", Vector2(0, 800))
	var best := 0.0
	var best_name := ""
	for i in EnemyPool.CAP:
		if sim.enemies.alive[i] == 1 and sim.enemies.max_hp[i] > best:
			best = sim.enemies.max_hp[i]
			best_name = sim.enemies.def_of(i).display_name
	var h := _hud(sim)
	_scan(h)
	assert_eq(h.boss_extra, 2)
	assert_eq(h.boss_name.text, UiKit.upper_tr(best_name) + "  +2")
	assert_eq(Hud.boss_title("Elit Karga", 0), "ELİT KARGA")
	assert_eq(Hud.boss_title("Elit Karga", 3), "ELİT KARGA  +3")


func test_lord_is_thicker_other_color_and_wins_over_elites() -> void:
	var sim := SimKit.make(1)
	sim.debug_spawn(&"elit_sovalye", Vector2(800, 0))
	var h := _hud(sim)
	_scan(h)
	var elite_h := h.boss_bar.offset_bottom - h.boss_bar.offset_top
	var elite_fill := (h.boss_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color
	var elite_size := h.boss_name.get_theme_font_size(&"font_size")
	sim.debug_spawn(&"kale_lordu", Vector2(-900, 0))
	_scan(h)
	assert_true(h.boss_is_lord, "Lord her zaman öncelikli (en yüksek can olmasa da)")
	assert_eq(h.boss_extra, 1)
	assert_eq(h.boss_name.text, "DÜŞMÜŞ KALE LORDU  +1")
	var lord_h := h.boss_bar.offset_bottom - h.boss_bar.offset_top
	var lord_fill := (h.boss_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color
	assert_gt(lord_h, elite_h, "Lord çubuğu daha kalın")
	assert_ne(lord_fill, elite_fill, "Lord çubuğu ayrı renk")
	assert_gt(h.boss_name.get_theme_font_size(&"font_size"), elite_size - 1)
	assert_lte(
		h.boss_row.offset_top + h.boss_bar.offset_bottom,
		520.0 + 0.5,
		"Lord çubuğu bandın üstünde biter"
	)
	# Lord ölünce elit çubuğuna döner
	for i in EnemyPool.CAP:
		if sim.enemies.alive[i] == 1 and sim.enemies.def_of(i).ai == &"lord":
			sim.enemies.kill(EnemyPool.make_id(sim.enemies.gen[i], i))
	_scan(h)
	assert_false(h.boss_is_lord)
	assert_almost_eq(h.boss_bar.offset_bottom - h.boss_bar.offset_top, elite_h, 0.01)
