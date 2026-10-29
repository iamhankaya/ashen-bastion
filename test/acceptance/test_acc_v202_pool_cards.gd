extends GutTest
## Kabul (v2.0.2 K, P): kart havuzu karaktere göre ayrılır. Gunslinger'a özel 8 beceri + 4 evrim, Zyfen'e özel 13 beceri,
## 7 ortak pasif (plan "Arayüzler/1"). Çapraz sızıntı yok; havuz tükenince çökme yok; `character == null` sim'i çökertmez.
## Mutasyon kontrolü (havuz süzgeci): `Loadout.roll_choices` / `evolution_ready` süzgeci kaldırılırsa p1/p2/p4 kırmızı olur
## (kanıt kapanış raporunda).

const LEVEL_UPS := 70

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func _all_skills() -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for k in [SkillDef.KIND_ACTIVE, SkillDef.KIND_PASSIVE, SkillDef.KIND_EVOLUTION]:
		out.append_array(_data.skills_of_kind(k))
	return out


func _allowed(character: StringName, skill_id: StringName) -> bool:
	var d := _data.get_skill(skill_id)
	return d != null and (d.pool == &"common" or d.pool == character)


## `n` seviye atlamasını oynar (kart sırası dönerek seçilir), her teklifi denetler; ihlal listesini ve görülen kimlikleri döner.
func _play_levels(character: StringName, seed_value: int, n: int) -> Dictionary:
	var sim := SimKit.make(seed_value, {"character": character, "data_kind": "real"})
	SimKit.godmode(sim)
	var bad: Array[String] = []
	var seen := {}
	for k in n:
		if not SimKit.level_up_with(sim, sim.xp_to_next):
			bad.append("seviye %d: LEVEL_UP'a girilemedi" % (k + 1))
			break
		var cards := sim.pending_choices()
		if cards.is_empty() or cards.size() > 3:
			bad.append("seviye %d: %d kart" % [k + 1, cards.size()])
			break
		var ids := {}
		for c in cards:
			seen[c.skill_id] = true
			if c.kind != Choice.KIND_HEAL and not _allowed(character, c.skill_id):
				bad.append(
					"seviye %d: %s kartı %s havuzuna ait değil" % [k + 1, c.skill_id, character]
				)
			if ids.has(c.skill_id) and c.kind != Choice.KIND_HEAL:
				bad.append("seviye %d: yinelenen kart %s" % [k + 1, c.skill_id])
			ids[c.skill_id] = true
		sim.choose(k % cards.size())
	return {"bad": bad, "seen": seen, "sim": sim}


func test_p1_zyfen_never_offered_gunslinger_only_cards() -> void:
	if V202Slice.require(self, "P"):
		return
	for s in [1, 7, 23]:
		var r := _play_levels(&"zyfen", s, LEVEL_UPS)
		assert_eq(r["bad"], [] as Array[String], "tohum %d" % s)
		for id in ExpectedTablesV202.GUNSLINGER_ONLY:
			assert_false(
				r["seen"].has(StringName(id)), "tohum %d: Zyfen'e %s teklif edildi" % [s, id]
			)


func test_p2_gunslinger_never_offered_zyfen_only_cards() -> void:
	if V202Slice.require(self, "P"):
		return
	for s in [1, 7, 23]:
		var r := _play_levels(&"gunslinger", s, LEVEL_UPS)
		assert_eq(r["bad"], [] as Array[String], "tohum %d" % s)
		for id in ExpectedTablesV202.SKILLS:
			if (
				StringName(id) == &"furtina_gozu"
				or ExpectedTablesV202.SKILLS[id]["kind"] != "passive"
			):
				assert_false(
					r["seen"].has(StringName(id)),
					"tohum %d: Gunslinger'a %s teklif edildi" % [s, id]
				)


func test_p3_each_character_is_offered_its_own_specific_and_the_common_cards() -> void:
	if V202Slice.require(self, "P"):
		return
	var z := _play_levels(&"zyfen", 3, LEVEL_UPS)["seen"] as Dictionary
	var g := _play_levels(&"gunslinger", 3, LEVEL_UPS)["seen"] as Dictionary
	var z_own := 0
	for id in [
		"hava_bicaklari",
		"girdap",
		"hortum",
		"delen_ruzgar",
		"bolunen_kesik",
		"hava_cebi",
		"nefes_dalgasi",
		"furtina_gozu"
	]:
		z_own += 1 if z.has(StringName(id)) else 0
	assert_gte(z_own, 6, "Zyfen kendi becerilerinin çoğunu görür (%d/8)" % z_own)
	var g_own := 0
	for id in [
		"yelpaze_atis",
		"seken_mermi",
		"son_mermi_patlar",
		"doldurma_sacilmasi",
		"sarapnel",
		"keskin_nisan",
		"barut_kesesi"
	]:
		g_own += 1 if g.has(StringName(id)) else 0
	assert_gte(g_own, 5, "Gunslinger kendi becerilerinin çoğunu görür (%d/7)" % g_own)
	for id in ExpectedTablesV202.COMMON_NAMES:
		assert_true(
			z.has(StringName(id)) or g.has(StringName(id)),
			"ortak %s iki karakterde de hiç çıkmadı" % id
		)


func test_p4_evolution_ready_only_for_the_owning_characters_pool() -> void:
	if V202Slice.require(self, "P"):
		return
	var z := Loadout.new(_data, &"zyfen")
	var g := Loadout.new(_data, &"gunslinger")
	var open := Loadout.new(_data)  # karaktersiz: filtresiz (eski davranış)
	for lo in [z, g, open]:
		lo.add_or_upgrade(&"hortum")
		for _k in 4:
			lo.add_or_upgrade(&"hortum")
		lo.add_or_upgrade(&"furtina_gozu")
	assert_eq(z.evolution_ready(), &"tufan", "Zyfen'de Tufan hazır")
	assert_eq(g.evolution_ready(), &"", "Gunslinger'da Zyfen evrimi hazır sayılmaz")
	assert_eq(open.evolution_ready(), &"tufan", "filtresiz Loadout eski davranış")


func test_p5_gunslinger_evolution_not_offered_to_zyfen() -> void:
	if V202Slice.require(self, "P"):
		return
	var z := Loadout.new(_data, &"zyfen")
	for _k in 5:
		z.add_or_upgrade(&"seken_mermi")
	z.add_or_upgrade(&"barut_kesesi")
	assert_eq(z.evolution_ready(), &"", "Zyfen'de zincirleme_patlama hazır olmaz")
	var g := Loadout.new(_data, &"gunslinger")
	for _k in 5:
		g.add_or_upgrade(&"seken_mermi")
	g.add_or_upgrade(&"barut_kesesi")
	assert_ne(g.evolution_ready(), &"", "Gunslinger'da hazır (kontrol: test boş geçmesin)")


func test_p6_exhausted_pool_never_crashes_and_still_offers_a_card() -> void:
	if V202Slice.require(self, "P"):
		return
	for ch in [&"zyfen", &"gunslinger"]:
		var r := _play_levels(ch, 11, 90)  # 20+ seviye: havuz tükenir, kalan teklif şifa kartıdır
		assert_eq(r["bad"], [] as Array[String], str(ch))
		var sim: GameSim = r["sim"]
		assert_eq(sim.state, GameSim.State.RUNNING, "%s koşu hâlâ RUNNING" % ch)
		assert_gte(sim.level, 60, "%s en az 60. seviye" % ch)


func test_p7_missing_character_does_not_crash_the_sim() -> void:
	if V202Slice.require(self, "P"):
		return
	var sim := SimKit.make(1, {"character": &"yok_boyle_biri", "data_kind": "real"})
	assert_null(sim.character, "bilinmeyen karakter => character null")
	SimKit.run(sim, 30)
	assert_eq(sim.step_count, 0, "karaktersiz sim adım atmaz (çökmez)")
	assert_eq(sim.loadout.character_id, &"", "Loadout filtresiz")


func test_p8_debug_grant_and_add_or_upgrade_ignore_the_pool() -> void:
	if V202Slice.require(self, "P"):
		return
	var sim := SimKit.make(1, {"character": &"gunslinger", "data_kind": "real"})
	sim.debug_grant(&"girdap", 2)
	assert_eq(sim.loadout.level_of(&"girdap"), 2, "debug_grant havuza bakmaz")
	var lo := Loadout.new(_data, &"zyfen")
	lo.add_or_upgrade(&"sarapnel")
	assert_eq(lo.level_of(&"sarapnel"), 1, "add_or_upgrade havuza bakmaz")


func test_p9_pool_assignments_match_the_plan_counts() -> void:
	if V202Slice.require(self, "P"):
		return
	var by_pool := {"common": [], "gunslinger": [], "zyfen": []}
	var others := 0  # yeni karakterlerin havuzları (sayıları bu plana ait değil)
	for d in _all_skills():
		var pool := str(d.pool)
		if by_pool.has(pool):
			by_pool[pool].append(str(d.id))
		else:
			others += 1
			assert_true(
				_data.get_character(StringName(pool)) != null,
				"%s: havuz %s ne ortak ne katalogdaki karakter" % [d.id, pool]
			)
	assert_eq(by_pool["common"].size(), 7, "ortak pasif sayısı")
	assert_eq(by_pool["gunslinger"].size(), 12, "Gunslinger'a özel (8 beceri + 4 evrim)")
	assert_eq(by_pool["zyfen"].size(), 13, "Zyfen'e özel")
	var want: Array = ExpectedTablesV202.GUNSLINGER_ONLY.duplicate()
	want.sort()
	var got: Array = by_pool["gunslinger"].duplicate()
	got.sort()
	assert_eq(got, want, "Gunslinger havuzu planla aynı kimlikler")
	assert_eq(
		_all_skills().size(), 32 + others, "toplam beceri (dinamit çıkmış; yeni havuzlar eklenir)"
	)
	assert_null(_data.get_skill(&"dinamit"), "dinamit kaldırıldı")


func test_p10_common_passives_have_variants_only_when_common() -> void:
	if V202Slice.require(self, "P"):
		return
	for d in _all_skills():
		if d.pool != &"common":
			assert_true(d.variants.is_empty(), "%s özel havuzda variants taşımaz" % d.id)
		else:
			assert_true(d.variants.has("zyfen"), "%s ortak pasifin Zyfen varyantı var" % d.id)
