extends GutTest
## Kabul: XP, seviye atlama ve beceri seçimi. Plan "Seviye atlama" + "Loadout.roll_choices" + XpCurve.


func test_xp_curve_fixed_points() -> void:
	for n in ExpectedTables.XP_NEED.keys():
		assert_eq(XpCurve.need(int(n)), int(ExpectedTables.XP_NEED[n]), "need(%d)" % n)
	assert_eq(XpCurve.cumulative(10), ExpectedTables.XP_CUMULATIVE_10, "cumulative(10)")
	assert_eq(XpCurve.cumulative(1), 0)
	assert_eq(XpCurve.cumulative(2), 12)


func test_xp_curve_is_strictly_increasing() -> void:
	var prev := 0
	for n in range(1, 60):
		var v := XpCurve.need(n)
		assert_gt(v, prev, "need(%d) artmalı" % n)
		prev = v


func test_below_threshold_stays_running_then_crossing_levels_up() -> void:
	var sim := SimKit.make(51)
	assert_eq(sim.xp_to_next, 12, "ilk eşik need(1) = 12")
	sim.debug_add_xp(11)
	SimKit.run(sim, 3)
	assert_eq(sim.state, GameSim.State.RUNNING)
	assert_eq(sim.level, 1)
	sim.debug_add_xp(1)
	assert_true(SimKit.run_to_level_up(sim, 3), "12 XP ile seviye atlanmalı")
	assert_eq(sim.level, 2, "level eşik aşıldığı adımda artar")
	assert_eq(sim.xp, 0, "xp -= xp_to_next")
	assert_eq(sim.xp_to_next, 16, "need(2)")
	assert_eq(sim.pending_levels, 1)


func test_level_up_offers_three_distinct_valid_cards() -> void:
	var sim := SimKit.make(52)
	assert_true(SimKit.level_up_with(sim, 12))
	var cards := sim.pending_choices()
	assert_eq(cards.size(), 3, "3 kart")
	var seen := {}
	for c in cards:
		assert_false(seen.has(c.skill_id), "aynı beceri iki kart olamaz: %s" % c.skill_id)
		seen[c.skill_id] = true
		assert_true(
			c.kind in [Choice.KIND_UPGRADE, Choice.KIND_NEW],
			"evrim/şifa dışı bir kart: %s" % c.kind
		)
		assert_ne(c.title, "", "kart başlığı")
		assert_ne(c.desc, "", "kart açıklaması")
		assert_ne(c.icon, "", "kart ikonu")
		if c.kind == Choice.KIND_NEW:
			assert_eq(c.from_level, 0)
			assert_eq(c.to_level, 1)
		else:
			assert_eq(c.to_level, c.from_level + 1)
			assert_eq(c.from_level, sim.loadout.level_of(c.skill_id))
	assert_eq(SimKit.count_events(sim, SimEvents.LEVEL_UP), 1)
	assert_eq(SimKit.last_event(sim, SimEvents.LEVEL_UP).get("level", -1), 2)
	var ev := SimKit.last_event(sim, SimEvents.CHOICES)
	assert_eq((ev.get("ids", []) as Array).size(), 3, "choices olayı 3 kimlik taşır")


func test_sim_is_frozen_while_choosing() -> void:
	var sim := SimKit.make(53)
	SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(40, 0))
	assert_true(SimKit.level_up_with(sim, 12))
	var t := sim.time
	var n := sim.step_count
	var hp := sim.hp
	sim.gems.drop(Vector2(10, 0), 5)
	var gem_hash := sim.state_hash()
	for i in 90:
		sim.step(Vector2.RIGHT)
	assert_eq(sim.state, GameSim.State.LEVEL_UP)
	assert_eq(sim.time, t, "LEVEL_UP'ta süre akmaz")
	assert_eq(sim.step_count, n)
	assert_eq(sim.hp, hp, "LEVEL_UP'ta hasar yok")
	assert_eq(sim.state_hash(), gem_hash, "LEVEL_UP'ta hiçbir şey değişmez")


func test_invalid_choose_changes_nothing() -> void:
	var sim := SimKit.make(54)
	assert_false(sim.choose(0), "RUNNING iken choose false")
	assert_true(SimKit.level_up_with(sim, 12))
	var h := sim.state_hash()
	assert_false(sim.choose(-1))
	assert_false(sim.choose(3))
	assert_false(sim.choose(99))
	assert_eq(sim.state, GameSim.State.LEVEL_UP)
	assert_eq(sim.state_hash(), h)
	assert_eq(sim.pending_choices().size(), 3)


func test_choosing_applies_the_card_and_resumes() -> void:
	var sim := SimKit.make(55)
	assert_true(SimKit.level_up_with(sim, 12))
	if sim.pending_choices().size() < 2:
		fail_test("en az 2 kart bekleniyordu")
		return
	var card := sim.pending_choices()[1]
	var fired: Array = []
	sim.bus.choice_made.connect(func(id: StringName) -> void: fired.append(id))
	assert_true(sim.choose(1))
	assert_eq(sim.state, GameSim.State.RUNNING)
	assert_eq(sim.pending_levels, 0)
	assert_eq(sim.loadout.level_of(card.skill_id), card.to_level, "kartın seviyesi uygulanır")
	assert_eq(SimKit.last_event(sim, SimEvents.CHOICE_MADE).get("skill_id", &""), card.skill_id)
	assert_eq(fired.size(), 1)
	assert_eq(sim.pending_choices().size(), 0, "RUNNING iken bekleyen kart yok")
	SimKit.run(sim, 10)
	assert_eq(sim.step_count, 11, "sim kaldığı yerden akar")


func test_multiple_levels_in_one_step_queue_up() -> void:
	var sim := SimKit.make(56)
	sim.debug_add_xp(100)  # eşikler 12,16,20,25 = 73 -> seviye 5, kalan 27
	assert_true(SimKit.run_to_level_up(sim, 3))
	assert_eq(sim.level, 5, "tek adımda 4 eşik")
	assert_eq(sim.pending_levels, 4)
	assert_eq(sim.xp, 27)
	assert_eq(sim.xp_to_next, 30, "need(5)")
	for i in 3:
		assert_true(sim.choose(0), "seçim %d" % (i + 1))
		assert_eq(sim.state, GameSim.State.LEVEL_UP, "kalan bekleyen seviye varken LEVEL_UP sürer")
		assert_eq(sim.pending_levels, 3 - i)
		assert_eq(sim.pending_choices().size() > 0, true, "yeni kartlar çekilir")
	assert_true(sim.choose(0))
	assert_eq(sim.state, GameSim.State.RUNNING)
	assert_eq(sim.pending_levels, 0)
	var lvls: Array = []
	for e in SimKit.events(sim, SimEvents.LEVEL_UP):
		lvls.append(int(e["level"]))
	assert_eq(lvls, [2, 3, 4, 5], "level_up olayları")


func test_loadout_slots_are_capped_at_six_and_six() -> void:
	var sim := SimKit.make(57)
	for id in ExpectedTables.PASSIVES:
		sim.debug_grant(id, 1)
	assert_eq(sim.loadout.passives().size(), 6, "6 pasif yuva")
	var actives: Array[StringName] = ExpectedTables.U1_ACTIVES.duplicate()
	actives.append_array(ExpectedTables.U2_ACTIVES)
	for id in actives:
		sim.debug_grant(id, 1)
	assert_lte(sim.loadout.actives().size(), 6, "en çok 6 aktif yuva")
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_no_new_cards_when_slots_are_full() -> void:
	var sim := SimKit.make(58)
	for id in ExpectedTables.PASSIVES:
		sim.debug_grant(id, 1)
	var held := {}
	for s in sim.loadout.passives():
		held[s.id] = true
	for round_i in 8:
		if not SimKit.level_up_with(sim, XpCurve.need(sim.level)):
			fail_test("tur %d: seviye atlanmadı" % round_i)
			return
		for c in sim.pending_choices():
			if c.kind == Choice.KIND_NEW:
				var is_passive := ExpectedTables.PASSIVES.has(c.skill_id)
				assert_false(
					is_passive and not held.has(c.skill_id),
					"dolu pasif yuvada yeni pasif önerilmez: %s" % c.skill_id
				)
		assert_true(sim.choose(0))


func test_maxed_skills_are_never_offered_as_upgrades() -> void:
	var sim := SimKit.make(59)
	sim.debug_grant(&"cift_tabanca", 5)
	for round_i in 6:
		if not SimKit.level_up_with(sim, XpCurve.need(sim.level)):
			fail_test("tur %d: seviye atlanmadı" % round_i)
			return
		for c in sim.pending_choices():
			assert_ne(c.skill_id, &"cift_tabanca", "maks. seviye beceri yükseltme kartı olamaz")
		assert_true(sim.choose(0))


func test_heal_card_when_nothing_is_left_to_offer() -> void:
	var sim := SimKit.make(60, {"data_kind": "fixture"})
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"son_mermi_patlar", 5)
	sim.debug_grant(&"cift_tabanca", 5)
	sim.debug_grant(&"barut_kesesi", 5)
	sim.debug_grant(&"hizli_doldurma", 5)
	sim.debug_grant(&"zincirleme_patlama")
	assert_eq(sim.loadout.evolution_ready(), &"", "evrim zaten alındı")
	assert_true(SimKit.level_up_with(sim, 12))
	var cards := sim.pending_choices()
	assert_eq(cards.size(), 1, "aday yoksa tek kart")
	if cards.is_empty():
		return
	assert_eq(cards[0].kind, Choice.KIND_HEAL)
	sim.hp = 40.0
	assert_true(sim.choose(0))
	assert_almost_eq(sim.hp, 65.0, 0.01, "Şifa: +%25 maks. can")
	assert_eq(sim.state, GameSim.State.RUNNING)


func test_heal_never_exceeds_max_hp() -> void:
	var sim := SimKit.make(61, {"data_kind": "fixture"})
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"son_mermi_patlar", 5)
	sim.debug_grant(&"cift_tabanca", 5)
	sim.debug_grant(&"barut_kesesi", 5)
	sim.debug_grant(&"hizli_doldurma", 5)
	sim.debug_grant(&"zincirleme_patlama")
	assert_true(SimKit.level_up_with(sim, 12))
	sim.hp = 95.0
	assert_true(sim.choose(0))
	assert_lte(sim.hp, sim.max_hp)
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_debug_force_choices_is_exact_and_single_use() -> void:
	var sim := SimKit.make(62)
	var forced: Array[StringName] = [&"agir_kursun", &"son_mermi_patlar", &"hizli_parmak"]
	sim.debug_force_choices(forced)
	assert_true(SimKit.level_up_with(sim, 12))
	var ids: Array[StringName] = []
	for c in sim.pending_choices():
		ids.append(c.skill_id)
	assert_eq(ids, forced, "zorlanan kartlar tam bu sırayla")
	assert_true(sim.choose(0))
	assert_true(SimKit.level_up_with(sim, XpCurve.need(sim.level)))
	assert_eq(sim.pending_choices().size(), 3, "zorlama tek kullanımlık; sonraki çekiliş normal")


func test_card_draws_are_deterministic_per_seed_and_independent_of_other_rng() -> void:
	var a := SimKit.make(63)
	var b := SimKit.make(63)
	for i in 500:
		a.rng_combat.randi()  # başka akışı kaydırmak çekilişi bozmamalı
	var ids_a: Array = []
	var ids_b: Array = []
	for round_i in 4:
		SimKit.level_up_with(a, XpCurve.need(a.level))
		SimKit.level_up_with(b, XpCurve.need(b.level))
		for c in a.pending_choices():
			ids_a.append(c.skill_id)
		for c in b.pending_choices():
			ids_b.append(c.skill_id)
		a.choose(0)
		b.choose(0)
	assert_gt(ids_a.size(), 0)
	assert_eq(ids_a, ids_b, "aynı tohum -> aynı kartlar (rng_choice ayrı akış)")


func test_new_skill_card_adds_to_loadout_and_upgrade_card_raises_level() -> void:
	var sim := SimKit.make(64)
	var forced: Array[StringName] = [&"cift_tabanca", &"seken_mermi", &"agir_kursun"]
	sim.debug_force_choices(forced)
	assert_true(SimKit.level_up_with(sim, 12))
	var up := SimKit.card_index(sim, &"cift_tabanca")
	assert_gte(up, 0)
	if up < 0:
		return
	assert_eq(sim.pending_choices()[up].kind, Choice.KIND_UPGRADE)
	assert_true(sim.choose(up))
	assert_eq(sim.loadout.level_of(&"cift_tabanca"), 2, "yükseltme: sv1 -> sv2")
	sim.debug_force_choices(forced)
	assert_true(SimKit.level_up_with(sim, XpCurve.need(sim.level)))
	var nw := SimKit.card_index(sim, &"seken_mermi")
	if nw < 0:
		fail_test("seken_mermi kartı yok")
		return
	assert_eq(sim.pending_choices()[nw].kind, Choice.KIND_NEW)
	assert_true(sim.choose(nw))
	assert_eq(sim.loadout.level_of(&"seken_mermi"), 1, "yeni beceri sv1")


func test_passive_choice_changes_stats_only_via_choose() -> void:
	var sim := SimKit.make(65)
	var forced: Array[StringName] = [&"agir_kursun", &"cevik_cizme", &"miknatis"]
	sim.debug_force_choices(forced)
	assert_true(SimKit.level_up_with(sim, 12))
	assert_almost_eq(sim.stats.bullet_dmg_mult, 1.0, 0.0001, "seçimden önce çarpan 1")
	assert_true(sim.choose(0))
	assert_almost_eq(sim.stats.bullet_dmg_mult, 1.1, 0.0001, "agir_kursun sv1: +%10")
