extends GutTest
## Kabul: evrim koşulları, evrim kartı ve yuva değişimi. Koşul: aktif max_level (5) VE eşleşen pasif seviye >= 1.
## Mantık (kart/yuva) slice 1'de test/fixtures/data_valid ile (zincirleme_patlama); davranışlar slice 2'de gerçek veriyle.


func _fx(seed_value: int) -> GameSim:
	return SimKit.make(seed_value, {"data_kind": "fixture"})


func _active_ids(sim: GameSim) -> Array:
	var out: Array = []
	for s in sim.loadout.actives():
		out.append(s.id)
	return out


func test_condition_requires_max_level_active_and_matching_passive() -> void:
	var sim := _fx(71)
	sim.debug_grant(&"seken_mermi", 4)
	sim.debug_grant(&"barut_kesesi", 1)
	assert_eq(sim.loadout.evolution_ready(), &"", "aktif sv4: hazır değil")
	var sim2 := _fx(72)
	sim2.debug_grant(&"seken_mermi", 5)
	assert_eq(sim2.loadout.evolution_ready(), &"", "pasif yok: hazır değil")
	var sim3 := _fx(73)
	sim3.debug_grant(&"seken_mermi", 5)
	sim3.debug_grant(&"hizli_doldurma", 5)
	assert_eq(sim3.loadout.evolution_ready(), &"", "yanlış pasif: hazır değil")
	var sim4 := _fx(74)
	sim4.debug_grant(&"seken_mermi", 5)
	sim4.debug_grant(&"barut_kesesi", 1)
	assert_eq(sim4.loadout.evolution_ready(), &"zincirleme_patlama", "sv5 + pasif sv1 yeter")


func test_ready_evolution_appears_as_last_card_exactly_once() -> void:
	var sim := _fx(75)
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"barut_kesesi", 1)
	assert_true(SimKit.level_up_with(sim, 12))
	var cards := sim.pending_choices()
	assert_eq(cards.size(), 3)
	var evo_idx := -1
	var evo_count := 0
	for i in cards.size():
		if cards[i].kind == Choice.KIND_EVOLUTION:
			evo_idx = i
			evo_count += 1
	assert_eq(evo_count, 1, "tam bir evrim kartı")
	assert_eq(evo_idx, cards.size() - 1, "evrim kartı en altta")
	if evo_idx >= 0:
		assert_eq(cards[evo_idx].skill_id, &"zincirleme_patlama")
		assert_eq(cards[evo_idx].from_level, 0)
		assert_eq(cards[evo_idx].to_level, 1)
	var seen := {}
	for c in cards:
		assert_false(seen.has(c.skill_id), "tekrarsız")
		seen[c.skill_id] = true


func test_choosing_the_evolution_replaces_the_raw_active_in_place() -> void:
	var sim := _fx(76)
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"barut_kesesi", 1)
	var slot_before := _active_ids(sim).find(&"seken_mermi")
	var slots_before := sim.loadout.actives().size()
	var fired: Array = []
	sim.bus.evolution_gained.connect(func(id: StringName) -> void: fired.append(id))
	assert_true(SimKit.level_up_with(sim, 12))
	var idx := SimKit.card_index(sim, &"zincirleme_patlama")
	assert_gte(idx, 0, "evrim kartı var")
	assert_true(sim.choose(idx))
	assert_eq(sim.loadout.level_of(&"zincirleme_patlama"), 1)
	assert_eq(sim.loadout.level_of(&"seken_mermi"), 0, "ham aktif yuvadan çıkar")
	assert_eq(sim.loadout.level_of(&"barut_kesesi"), 1, "pasif kalır")
	assert_eq(sim.loadout.actives().size(), slots_before, "yuva sayısı değişmez")
	assert_eq(_active_ids(sim).find(&"zincirleme_patlama"), slot_before, "yuvada yerinde değişir")
	assert_eq(
		sim.evolved_log,
		[&"zincirleme_patlama"] as Array[StringName],
		"sonuç ekranı için evrim kaydı"
	)
	assert_eq(SimKit.last_event(sim, SimEvents.EVOLUTION).get("evo_id", &""), &"zincirleme_patlama")
	assert_eq(fired, [&"zincirleme_patlama"])
	assert_eq(sim.loadout.evolution_ready(), &"", "evrim alındıktan sonra tekrar hazır olmaz")


func test_evolution_is_offered_every_level_until_taken() -> void:
	var sim := _fx(77)
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"barut_kesesi", 1)
	for round_i in 3:
		assert_true(SimKit.level_up_with(sim, XpCurve.need(sim.level)))
		var idx := SimKit.card_index(sim, &"zincirleme_patlama")
		assert_gte(idx, 0, "tur %d: evrim hâlâ önerilmeli" % round_i)
		var other := 0 if idx != 0 else 1
		assert_true(sim.choose(other))
	assert_eq(sim.loadout.level_of(&"seken_mermi"), 5, "evrim seçilmedi: ham aktif yerinde")


func test_after_taking_it_no_more_evolution_cards() -> void:
	var sim := _fx(78)
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"barut_kesesi", 1)
	assert_true(SimKit.level_up_with(sim, 12))
	assert_true(sim.choose(SimKit.card_index(sim, &"zincirleme_patlama")))
	for round_i in 3:
		assert_true(SimKit.level_up_with(sim, XpCurve.need(sim.level)))
		for c in sim.pending_choices():
			assert_ne(c.kind, Choice.KIND_EVOLUTION)
		assert_true(sim.choose(0))


func test_real_data_evolution_pairs_in_slice2() -> void:
	if Slice.current() < 2:
		pending("4 evrim slice 2 içeriği")
		return
	for evo in ExpectedTables.EVOLUTIONS:
		var pair: Array = ExpectedTables.EVOLUTION_REQUIRES[evo]
		var sim := SimKit.make(79)
		sim.debug_grant(pair[0], 4)
		sim.debug_grant(pair[1], 1)
		assert_eq(sim.loadout.evolution_ready(), &"", "%s: aktif sv4 yetmez" % evo)
		var sim2 := SimKit.make(80)
		sim2.debug_grant(pair[0], 5)
		sim2.debug_grant(pair[1], 1)
		assert_eq(sim2.loadout.evolution_ready(), evo, "%s: sv5 + pasif sv1" % evo)


func test_two_ready_evolutions_show_only_one_card_then_the_other_next_level() -> void:
	if Slice.current() < 2:
		pending("slice 2 içeriği")
		return
	var sim := SimKit.make(81)
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"barut_kesesi", 1)
	sim.debug_grant(&"son_mermi_patlar", 5)
	sim.debug_grant(&"hizli_doldurma", 1)
	assert_true(SimKit.level_up_with(sim, 12))
	var evo_cards: Array = []
	for c in sim.pending_choices():
		if c.kind == Choice.KIND_EVOLUTION:
			evo_cards.append(c.skill_id)
	assert_eq(evo_cards.size(), 1, "iki evrim hazırsa yalnız biri gösterilir")
	assert_true(sim.choose(SimKit.card_index(sim, evo_cards[0])))
	assert_true(SimKit.level_up_with(sim, XpCurve.need(sim.level)))
	var second: Array = []
	for c in sim.pending_choices():
		if c.kind == Choice.KIND_EVOLUTION:
			second.append(c.skill_id)
	assert_eq(second.size(), 1, "diğer evrim sonraki seviyede")
	assert_ne(second[0] if second.size() > 0 else &"", evo_cards[0])


func test_kiyamet_mermisi_refunds_once_per_reload_cycle() -> void:
	if Slice.current() < 2:
		pending("kiyamet_mermisi slice 2 içeriği")
		return
	var sim := SimKit.make(82)
	SimKit.godmode(sim)
	assert_ne(SimKit.add_enemy(sim, &"elit_piyade", Vector2(400, 0)), -1)
	sim.debug_grant(&"kiyamet_mermisi")
	sim.debug_grant(&"hizli_doldurma", 1)
	SimKit.run(sim, 250)
	var refunds := SimKit.events(sim, SimEvents.REFUND)
	var starts := SimKit.events(sim, SimEvents.RELOAD_START)
	var ends := SimKit.events(sim, SimEvents.RELOAD_END)
	assert_gte(refunds.size(), 1, "son kurşunda 2 mermi geri yazılır")
	assert_gte(starts.size(), 1)
	if refunds.is_empty() or starts.is_empty():
		return
	assert_eq(int(refunds[0]["n"]), 2)
	# Döngü başına bir geri yazma: her doldurma aralığında en çok bir refund.
	var boundaries: Array = [0]
	for e in ends:
		boundaries.append(int(e["step"]))
	boundaries.append(1 << 30)
	for i in boundaries.size() - 1:
		var n := 0
		for r in refunds:
			if int(r["step"]) > int(boundaries[i]) and int(r["step"]) <= int(boundaries[i + 1]):
				n += 1
		assert_lte(n, 1, "döngü %d: en çok bir geri yazma" % i)
	# İlk döngüde 6 + 2 = 8 kurşun çıkar, doldurma ikinci 'son kurşun'dan sonra başlar.
	var s0 := int(starts[0]["step"])
	var shots := 0
	for s in SimKit.events(sim, SimEvents.SHOT):
		if int(s["step"]) <= s0:
			shots += 1
	assert_eq(shots, 8, "ilk döngüde 8 kurşun (6 + 2 geri yazılan)")
	var ex := SimKit.events(sim, SimEvents.EXPLOSION)
	assert_gt(ex.size(), 0)
	if not ex.is_empty():
		assert_almost_eq(float(ex[0]["dmg"]), 400.0, 0.5, "devasa patlama 400")
		assert_almost_eq(float(ex[0]["radius"]), 260.0, 0.5, "yarıçap 260")


func test_zincirleme_patlama_explodes_on_bounces() -> void:
	if Slice.current() < 2:
		pending("zincirleme_patlama slice 2 içeriği")
		return
	var sim := SimKit.make(83)
	for p in [Vector2(450, 0), Vector2(470, 60), Vector2(500, -50), Vector2(430, 110)]:
		SimKit.add_enemy(sim, &"sovalye_hayaleti", p)
	sim.debug_grant(&"zincirleme_patlama")
	SimKit.run(sim, 100)
	var hits := 0
	for e in SimKit.events(sim, SimEvents.EXPLOSION):
		if is_equal_approx(float(e["dmg"]), 40.0) and is_equal_approx(float(e["radius"]), 90.0):
			hits += 1
	assert_gt(hits, 0, "sekmede patlama: hasar 40, yarıçap 90")


func test_mermi_firtinasi_fires_double_cap_salvo_and_rings_during_reload() -> void:
	if Slice.current() < 2:
		pending("mermi_firtinasi slice 2 içeriği")
		return
	var sim := SimKit.make(84)
	SimKit.add_enemy(sim, &"elit_piyade", Vector2(400, 0))
	SimKit.godmode(sim)
	sim.debug_grant(&"mermi_firtinasi")
	SimKit.run(sim, 130)
	var starts := SimKit.events(sim, SimEvents.RELOAD_START)
	if starts.is_empty():
		fail_test("doldurma başlamadı")
		return
	var s0 := int(starts[0]["step"])
	var in_reload := 0
	var salvo := 0
	for s in SimKit.events(sim, SimEvents.SHOT):
		var st := int(s["step"])
		if st >= s0 and st <= s0 + 62:
			in_reload += 1
			if st <= s0 + 2 and is_equal_approx(float(s["dmg"]), 20.0):
				salvo += 1
	assert_gte(salvo, 2 * sim.magazine.cap, "doldurma başında 2 x cap salvo (hasar 20)")
	assert_gte(
		in_reload, 2 * sim.magazine.cap + 6 * 3, "doldurma boyunca 0,15 sn'de bir 6'lı halka"
	)


func test_gurleyen_yelpaze_volley_of_13() -> void:
	if Slice.current() < 2:
		pending("gurleyen_yelpaze slice 2 içeriği")
		return
	var sim := SimKit.make(85)
	SimKit.add_enemy(sim, &"elit_piyade", Vector2(300, 0))
	SimKit.godmode(sim)
	sim.debug_grant(&"gurleyen_yelpaze")
	SimKit.run(sim, 110)
	var n := 0
	for s in SimKit.events(sim, SimEvents.SHOT):
		if is_equal_approx(float(s["dmg"]), 20.0):
			n += 1
	assert_eq(n, 13, "soğuma 2,0 sn: ilk 110 adımda tek salvo = 13 saçma (hasar 20)")
