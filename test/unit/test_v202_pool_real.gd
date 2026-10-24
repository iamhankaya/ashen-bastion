extends GutTest
## U1: gerçek veride havuz ayrımı. Gunslinger ve Zyfen kendi havuzunu ve ortak pasifleri görür, birbirininkini görmez;
## ortak pasiflerin Zyfen adı/ikonu/açıklaması variant'tan gelir; havuz tükenince tek "Şifa" kartı çıkar.

## U1a'da `dinamit` hâlâ var: Barutçu'nun `starting_skill`'i olduğu için havuzu `common` (doğrulayıcı başlangıç becerisini
## karakter havuzu ya da ortak ister); Gunslinger hash'i için fark etmez. U1b'de dinamit silinir: Gunslinger 7, Zyfen 8.
const GUNSLINGER_ACTIVES := 8
const ZYFEN_ACTIVES := 9
const COMMON_PASSIVES: Array[StringName] = [
	&"agir_kursun",
	&"cevik_cizme",
	&"fazladan_mermi",
	&"hizli_doldurma",
	&"hizli_parmak",
	&"miknatis",
	&"saglam_yelek",
]

var data: GameData


func before_all() -> void:
	data = GameData.load_default()


func _ids(character: StringName, kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for d in data.skills_of_kind(kind):
		if d.available_to(character):
			out.append(d.id)
	out.sort()
	return out


func test_real_data_has_no_validation_errors() -> void:
	assert_eq(data.validate(), PackedStringArray())


func test_pool_counts_per_character() -> void:
	assert_eq(_ids(&"gunslinger", SkillDef.KIND_ACTIVE).size(), GUNSLINGER_ACTIVES)
	assert_eq(_ids(&"gunslinger", SkillDef.KIND_PASSIVE).size(), 8)
	assert_eq(_ids(&"gunslinger", SkillDef.KIND_EVOLUTION).size(), 4)
	assert_eq(_ids(&"zyfen", SkillDef.KIND_ACTIVE).size(), ZYFEN_ACTIVES)
	assert_eq(_ids(&"zyfen", SkillDef.KIND_PASSIVE).size(), 8)
	assert_eq(_ids(&"zyfen", SkillDef.KIND_EVOLUTION).size(), 4)


func test_no_cross_leak_and_common_passives_shared() -> void:
	for kind in [SkillDef.KIND_ACTIVE, SkillDef.KIND_PASSIVE, SkillDef.KIND_EVOLUTION]:
		var g := _ids(&"gunslinger", kind)
		var z := _ids(&"zyfen", kind)
		for id in g:
			if z.has(id):
				assert_eq(
					data.get_skill(id).pool, SkillDef.POOL_COMMON, "ortak olmayan sızdı: %s" % id
				)
	for id in COMMON_PASSIVES:
		assert_true(_ids(&"gunslinger", SkillDef.KIND_PASSIVE).has(id), id)
		assert_true(_ids(&"zyfen", SkillDef.KIND_PASSIVE).has(id), id)
	assert_false(_ids(&"zyfen", SkillDef.KIND_PASSIVE).has(&"barut_kesesi"))
	assert_false(_ids(&"gunslinger", SkillDef.KIND_PASSIVE).has(&"furtina_gozu"))


func test_empty_character_id_keeps_old_unfiltered_behavior() -> void:
	assert_eq(_ids(&"", SkillDef.KIND_ACTIVE).size(), GUNSLINGER_ACTIVES + 8)
	assert_eq(_ids(&"", SkillDef.KIND_PASSIVE).size(), 7 + 2)
	assert_eq(_ids(&"", SkillDef.KIND_EVOLUTION).size(), 8)


func test_evolutions_share_the_pool_of_their_raw_active() -> void:
	for evo in data.skills_of_kind(SkillDef.KIND_EVOLUTION):
		var raw := data.get_skill(StringName(str(evo.requires["active"])))
		assert_eq(evo.pool, raw.pool, evo.id)


func test_common_passives_have_zyfen_variants_of_full_length() -> void:
	for id in COMMON_PASSIVES:
		var d := data.get_skill(id)
		var v: Dictionary = d.variants.get("zyfen", {})
		assert_false(v.is_empty(), "variant yok: %s" % id)
		assert_ne(d.name_for(&"zyfen"), d.display_name, id)
		assert_eq(d.name_for(&"gunslinger"), d.display_name)
		assert_true(ResourceLoader.exists(d.icon_for(&"zyfen")), id)
		for lv in range(1, d.max_level + 1):
			assert_ne(d.desc_for(&"zyfen", lv), "", "%s sv%d" % [id, lv])


func test_deep_breath_is_the_zyfen_name_of_extra_magazine() -> void:
	var d := data.get_skill(&"fazladan_mermi")
	assert_eq(d.name_for(&"zyfen"), "Derin Nefes")
	assert_eq(d.desc_for(&"zyfen", 3), "Rüzgar toplamadan önce +3 kesik.")


func test_variant_names_fit_the_card_limit() -> void:
	for d in data.skills_of_kind(SkillDef.KIND_PASSIVE):
		assert_lte(d.name_for(&"zyfen").length(), DataV202Pool.NAME_MAX, d.id)


func test_loadout_state_carries_the_character_icon() -> void:
	var z := Loadout.new(data, &"zyfen")
	z.add_or_upgrade(&"agir_kursun")
	assert_true(z.state_of(&"agir_kursun").icon.contains("/zyfen/"))
	var g := Loadout.new(data, &"gunslinger")
	g.add_or_upgrade(&"agir_kursun")
	assert_eq(g.state_of(&"agir_kursun").icon, data.get_skill(&"agir_kursun").icon)


func test_skill_slot_refreshes_icon_when_character_changes() -> void:
	var slot := SkillSlot.new(&"passive", 78.0)
	var d := data.get_skill(&"agir_kursun")
	slot.set_skill(d.id, 1, d.icon_for(&"gunslinger"))
	var first := slot.icon
	slot.set_skill(d.id, 1, d.icon_for(&"zyfen"))
	assert_ne(slot.icon, first, "aynı kimlik/seviye, farklı ikon alanı yenilenmeli")
	slot.free()


## 20+ seviye boyunca her kart karakterin havuzundan; havuz bitince tek Şifa; kart listesi asla boş.
func _drain(character: StringName) -> void:
	var l := Loadout.new(data, character)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var healed := false
	for level in 120:
		var cards := l.roll_choices(rng)
		assert_gt(cards.size(), 0, "%s sv%d: boş kart listesi" % [character, level])
		for c in cards:
			if c.kind == Choice.KIND_HEAL:
				healed = true
				continue
			assert_true(data.get_skill(c.skill_id).available_to(character), c.skill_id)
		if healed:
			assert_eq(cards.size(), 1)
			break
		for c in cards:
			if c.kind == Choice.KIND_EVOLUTION:
				l.apply_evolution(c.skill_id)
			else:
				l.add_or_upgrade(c.skill_id)
	assert_true(healed, "%s: havuz tükenmedi / Şifa gelmedi" % character)


func test_card_pool_exhaustion_both_characters() -> void:
	_drain(&"gunslinger")
	_drain(&"zyfen")
