extends GutTest
## Loadout: yuvalar, upgrade/new, evrim koşulu, roll_choices kuralları, StatBlock pasif toplamı.

var data: GameData


func before_each() -> void:
	data = GameData.load_default()


func _loadout() -> Loadout:
	return Loadout.new(data)


func test_add_and_upgrade_caps_at_max_level() -> void:
	var l := _loadout()
	l.add_or_upgrade(&"seken_mermi")
	assert_eq(l.level_of(&"seken_mermi"), 1)
	for i in 10:
		l.add_or_upgrade(&"seken_mermi")
	assert_eq(l.level_of(&"seken_mermi"), 5)
	assert_eq(l.actives().size(), 1)
	l.add_or_upgrade(&"agir_kursun")
	assert_eq(l.passives().size(), 1)


func test_unknown_and_evolution_ids_are_ignored_by_add() -> void:
	var l := _loadout()
	l.add_or_upgrade(&"yok")
	assert_eq(l.actives().size() + l.passives().size(), 0)


func test_slot_limits() -> void:
	var l := _loadout()
	var ids: Array[StringName] = [
		&"agir_kursun",
		&"barut_kesesi",
		&"cevik_cizme",
		&"fazladan_mermi",
		&"hizli_doldurma",
		&"hizli_parmak",
		&"miknatis",
	]
	for id in ids:
		l.add_or_upgrade(id)
	assert_eq(l.passives().size(), Loadout.PASSIVE_SLOTS, "7. pasif yuvaya sığmaz")
	assert_eq(l.level_of(&"miknatis"), 0)


func test_stat_block_sums_passives_as_totals() -> void:
	var l := _loadout()
	for i in 3:
		l.add_or_upgrade(&"agir_kursun")
	l.add_or_upgrade(&"fazladan_mermi")
	l.add_or_upgrade(&"fazladan_mermi")
	for i in 5:
		l.add_or_upgrade(&"hizli_doldurma")
	l.add_or_upgrade(&"saglam_yelek")
	var st := StatBlock.new()
	st.rebuild(l, data)
	assert_almost_eq(st.bullet_dmg_mult, 1.3, 1e-6)
	assert_eq(st.mag_add, 2)
	assert_almost_eq(st.reload_time_mult, 0.5, 1e-6)
	assert_eq(st.max_hp_add, 15.0)
	assert_almost_eq(st.regen, 0.25, 1e-6)
	assert_eq(st.fire_rate_mult, 1.0)


func test_roll_choices_gives_three_distinct_cards() -> void:
	var l := _loadout()
	l.add_or_upgrade(&"cift_tabanca")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 20:
		var cards := l.roll_choices(rng)
		assert_eq(cards.size(), 3)
		var seen := {}
		for c in cards:
			assert_false(seen.has(c.skill_id), "aynı beceri iki kart")
			seen[c.skill_id] = true
			assert_ne(c.kind, Choice.KIND_HEAL)
			assert_ne(c.title, "")


func test_roll_choices_is_deterministic_for_same_seed() -> void:
	var a := _loadout()
	var b := _loadout()
	var ra := RandomNumberGenerator.new()
	var rb := RandomNumberGenerator.new()
	ra.seed = 9
	rb.seed = 9
	for k in 5:
		var ca := a.roll_choices(ra)
		var cb := b.roll_choices(rb)
		for i in ca.size():
			assert_eq(ca[i].skill_id, cb[i].skill_id)


func test_card_kinds_and_levels() -> void:
	var l := _loadout()
	l.add_or_upgrade(&"cift_tabanca")
	l.add_or_upgrade(&"cift_tabanca")
	var rng := RandomNumberGenerator.new()
	var seen_upgrade := false
	for s in 30:
		rng.seed = s
		for c in l.roll_choices(rng):
			if c.skill_id == &"cift_tabanca":
				seen_upgrade = true
				assert_eq(c.kind, Choice.KIND_UPGRADE)
				assert_eq(c.from_level, 2)
				assert_eq(c.to_level, 3)
			else:
				assert_eq(c.kind, Choice.KIND_NEW)
				assert_eq(c.to_level, 1)
	assert_true(seen_upgrade)


func test_heal_card_when_nothing_to_offer() -> void:
	var l := _loadout()
	# tüm becerileri maksimuma çıkar; 6 pasif yuvası dolu ve hepsi maks.
	for id in [&"cift_tabanca", &"seken_mermi", &"son_mermi_patlar"]:
		for i in 5:
			l.add_or_upgrade(id)
	for id in [
		&"agir_kursun",
		&"barut_kesesi",
		&"cevik_cizme",
		&"fazladan_mermi",
		&"hizli_doldurma",
		&"hizli_parmak"
	]:
		for i in 5:
			l.add_or_upgrade(id)
	var cards := l.roll_choices(RandomNumberGenerator.new())
	assert_eq(cards.size(), 1)
	assert_eq(cards[0].kind, Choice.KIND_HEAL)
	assert_eq(cards[0].skill_id, Loadout.HEAL_ID)


func test_fewer_than_three_cards_when_few_candidates() -> void:
	var l := _loadout()
	for id in [&"cift_tabanca", &"seken_mermi", &"son_mermi_patlar"]:
		for i in 5:
			l.add_or_upgrade(id)
	for id in [
		&"agir_kursun", &"barut_kesesi", &"cevik_cizme", &"fazladan_mermi", &"hizli_doldurma"
	]:
		for i in 5:
			l.add_or_upgrade(id)
	l.add_or_upgrade(&"hizli_parmak")  # 6. pasif, seviye 1 -> tek aday
	var cards := l.roll_choices(RandomNumberGenerator.new())
	assert_eq(cards.size(), 1)
	assert_eq(cards[0].skill_id, &"hizli_parmak")


func _evolution_data() -> GameData:
	# Fixture verisinde zincirleme_patlama = seken_mermi 5 + barut_kesesi.
	return GameData.load_dir(KitDev.data_dir())


func test_evolution_ready_needs_max_active_and_passive() -> void:
	var g := _evolution_data()
	var l := Loadout.new(g)
	assert_eq(l.evolution_ready(), &"")
	for i in 5:
		l.add_or_upgrade(&"seken_mermi")
	assert_eq(l.evolution_ready(), &"", "pasif yok")
	l.add_or_upgrade(&"barut_kesesi")
	assert_eq(l.evolution_ready(), &"zincirleme_patlama")


func test_evolution_card_is_last_and_apply_replaces_slot() -> void:
	var g := _evolution_data()
	var l := Loadout.new(g)
	l.add_or_upgrade(&"cift_tabanca")
	for i in 5:
		l.add_or_upgrade(&"seken_mermi")
	l.add_or_upgrade(&"barut_kesesi")
	var rng := RandomNumberGenerator.new()
	for s in 10:
		rng.seed = s
		var cards := l.roll_choices(rng)
		assert_eq(cards[cards.size() - 1].kind, Choice.KIND_EVOLUTION)
		assert_eq(cards[cards.size() - 1].skill_id, &"zincirleme_patlama")
		for i in cards.size() - 1:
			assert_ne(cards[i].kind, Choice.KIND_EVOLUTION)
	l.apply_evolution(&"zincirleme_patlama")
	assert_eq(l.level_of(&"seken_mermi"), 0)
	assert_eq(l.level_of(&"zincirleme_patlama"), 1)
	assert_eq(l.level_of(&"barut_kesesi"), 1, "pasif kalır")
	assert_eq(l.actives()[1].id, &"zincirleme_patlama", "aynı yuvada")
	assert_eq(l.evolution_ready(), &"", "tekrar önerilmez")
