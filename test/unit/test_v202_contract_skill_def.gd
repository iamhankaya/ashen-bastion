extends GutTest
## S1 sözleşmesi: SkillDef havuz/variant yardımcıları, Loadout karakter süzgeci ve card_for.

var data: GameData


func before_each() -> void:
	data = GameData.load_default()


func _def(extra: Dictionary = {}) -> SkillDef:
	var d := {"id": "x", "kind": "passive", "name": "Ad", "icon": "ikon", "max_level": 3}
	d["desc"] = ["bir", "iki", "üç"]
	d.merge(extra, true)
	return SkillDef.from_dict(d)


func test_available_to_table() -> void:
	var common := _def()
	assert_eq(common.pool, SkillDef.POOL_COMMON, "pool yoksa ortak")
	var special := _def({"pool": "zyfen"})
	var rows := [
		[common, &"gunslinger", true],
		[common, &"zyfen", true],
		[common, &"", true],
		[special, &"zyfen", true],
		[special, &"gunslinger", false],
		[special, &"", true],
	]
	for r in rows:
		assert_eq(r[0].available_to(r[1]), r[2], "%s / %s" % [r[0].pool, r[1]])


func test_name_icon_desc_fall_back_without_variant() -> void:
	var s := _def()
	assert_eq(s.name_for(&"zyfen"), "Ad")
	assert_eq(s.icon_for(&"zyfen"), "ikon")
	assert_eq(s.desc_for(&"zyfen", 2), "iki")


func test_variant_overrides_only_given_fields() -> void:
	var s := _def({"variants": {"zyfen": {"name": "Derin Nefes", "desc": ["a", "b", "c"]}}})
	assert_eq(s.name_for(&"zyfen"), "Derin Nefes")
	assert_eq(s.icon_for(&"zyfen"), "ikon", "icon verilmedi: ortak")
	assert_eq(s.desc_for(&"zyfen", 3), "c")
	assert_eq(s.name_for(&"gunslinger"), "Ad", "başka karakter etkilenmez")
	assert_eq(s.desc_for(&"gunslinger", 3), "üç")


func test_desc_for_range() -> void:
	var s := _def()
	assert_eq(s.desc_for(&"gunslinger", 0), "")
	assert_eq(s.desc_for(&"gunslinger", 4), "")
	assert_eq(s.desc_for(&"gunslinger", 1), "bir")


func test_loadout_without_character_is_unfiltered() -> void:
	var l := Loadout.new(data)
	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 200:
		for c in l.roll_choices(rng):
			seen[c.skill_id] = true
	assert_true(seen.has(&"girdap"), "filtresiz: Zyfen becerisi de çıkar")
	assert_true(seen.has(&"seken_mermi"))


func test_gunslinger_never_sees_zyfen_pool_skills() -> void:
	var l := Loadout.new(data, &"gunslinger")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 300:
		for c in l.roll_choices(rng):
			assert_ne(data.get_skill(c.skill_id).pool, &"zyfen", c.skill_id)
	assert_eq(l.evolution_ready(), &"")


func test_zyfen_sees_its_own_pool() -> void:
	var l := Loadout.new(data, &"zyfen")
	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 300:
		for c in l.roll_choices(rng):
			seen[c.skill_id] = true
	assert_true(seen.has(&"girdap"))
	assert_true(seen.has(&"furtina_gozu"))


func test_zyfen_evolution_ready_and_other_pool_evolution_ignored() -> void:
	var z := Loadout.new(data, &"zyfen")
	for i in 5:
		z.add_or_upgrade(&"hortum")
	z.add_or_upgrade(&"furtina_gozu")
	assert_eq(z.evolution_ready(), &"tufan")
	var g := Loadout.new(data, &"gunslinger")
	for i in 5:
		g.add_or_upgrade(&"hortum")  # add_or_upgrade havuza bakmaz (araç esnekliği)
	g.add_or_upgrade(&"furtina_gozu")
	assert_eq(g.evolution_ready(), &"", "Gunslinger Zyfen evrimini göremez")


func test_card_for_kinds_and_levels() -> void:
	var l := Loadout.new(data, &"zyfen")
	var fresh := l.card_for(&"hortum", 1)
	assert_eq(fresh.kind, Choice.KIND_NEW)
	assert_eq([fresh.from_level, fresh.to_level], [0, 1])
	assert_eq(fresh.title, "Hortum")
	l.add_or_upgrade(&"hortum")
	var up := l.card_for(&"hortum", 2)
	assert_eq(up.kind, Choice.KIND_UPGRADE)
	assert_eq([up.from_level, up.to_level], [1, 2])
	assert_eq(up.desc, data.get_skill(&"hortum").desc[1])
	var evo := l.card_for(&"tufan", 1)
	assert_eq(evo.kind, Choice.KIND_EVOLUTION)
	assert_null(l.card_for(&"yok_boyle", 1))


func test_card_for_uses_character_variant() -> void:
	var custom := GameData.load_dir(SimKit.REAL_DIR)  # taze kopya: paylaşılan önbelleğe yazılmaz
	custom._skills[&"agir_kursun"].variants = {"zyfen": {"name": "Bilenmiş Rüzgar"}}
	assert_eq(Loadout.new(custom, &"zyfen").card_for(&"agir_kursun", 1).title, "Bilenmiş Rüzgar")
	assert_eq(Loadout.new(custom, &"gunslinger").card_for(&"agir_kursun", 1).title, "Ağır Kurşun")


func test_forced_cards_match_card_for() -> void:
	var sim := SimKit.make(1, {"data_kind": "real", "character": &"zyfen"})
	sim.debug_force_choices([&"girdap", &"hortum"])
	sim.debug_add_xp(1000)
	SimKit.run_to_level_up(sim)
	var cards := sim.pending_choices()
	assert_eq(cards.size(), 2)
	assert_eq(cards[0].skill_id, &"girdap")
	assert_eq(cards[0].kind, Choice.KIND_NEW)
	assert_eq(cards[0].title, data.get_skill(&"girdap").display_name)
