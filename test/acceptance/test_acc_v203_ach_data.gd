extends GutTest
## Kabul (v2.0.3 C): aşamalı başarım VERİSİ. Kaynak: görev kararları (2026-10-26: 19 aile, A seti grup adları, İngilizce aile adları),
## docs/design/v2.0.3/DESIGN.md §4.2 (grup eşlemesi), docs/data-schema.md "Başarım — aile/kademe (v2.0.3)" ve sözleşme raporu.
## Beklentiler burada sabittir; veri JSON'undan türetilmez. Eski 22 kayıt tablosu: ExpectedTablesV2.ACHIEVEMENTS (v2.0 planı).
## Dilim C kapalıyken pending. Kimlik adları (`reaper` vb.) sözleşmede sabit değildir: aileler görünen ada göre bulunur.

const FAMILY_GROUPS := {
	"THE WATCH": ["Endure", "Untouched", "Vigil"],
	"THE CULLING": ["Rampage", "Reaper", "Unbound", "Demolisher"],
	"THE CROWNED": ["Bossbane", "Elite Trio", "Lordslayer"],
	"THE ARMORY":
	["Ascendant", "Ascension", "Quick Hands", "Unbroken", "Renown", "Scavenger", "Full Arsenal"],
	"THE ROAD": ["Garrison", "Two Roads"],
}

## Eski kimlik -> ailenin toplam sayacına taşınan iki kayıt (run_elit_piyade → total_boss_kills, run_won → total_wins).
const SCOPE_CHANGED := ["piyade_avcisi", "kale_lordu_devrildi"]


func _gate() -> bool:
	return V203Slice.require(self, "C")


func _defs() -> Array:
	return GameData.load_default().achievements


func _by_name(display_name: String) -> AchievementDef:
	for a in _defs():
		if a.display_name == display_name:
			return a
	return null


# --- şema: aile sayısı, kademe sınırları, gruplar -------------------------------------------------------------


func test_c1_every_record_is_a_family_and_count_is_the_19_approved() -> void:
	if _gate():
		return
	var total := 0
	for g in FAMILY_GROUPS:
		total += (FAMILY_GROUPS[g] as Array).size()
	assert_eq(total, 19, "kullanıcı kararı: 19 aile")
	assert_eq(_defs().size(), 19, "kayıt = aile; eski tek kademeli kayıt kalmaz")
	for a in _defs():
		assert_false(a.steps.is_empty(), "%s: steps" % a.id)
		assert_eq(a.target, 0, "%s: aile kaydında target yok" % a.id)
		assert_eq(a.tier, &"", "%s: aile kaydında tier yok" % a.id)


func test_c1_family_names_are_exactly_the_approved_english_names() -> void:
	if _gate():
		return
	var want: Array[String] = []
	for g in FAMILY_GROUPS:
		want.append_array(FAMILY_GROUPS[g])
	var got: Array[String] = []
	for a in _defs():
		got.append(a.display_name)
	want.sort()
	got.sort()
	assert_eq(got, want)


func test_c1_steps_are_valid_and_total_stays_within_the_budget() -> void:
	if _gate():
		return
	var total := 0
	for a in _defs():
		var s: Array[int] = a.steps
		assert_between(s.size(), 1, AchievementDef.MAX_STEPS, "%s: 1..5 kademe" % a.id)
		if s.is_empty():
			continue
		assert_gt(s[0], 0, a.id)
		for i in range(1, s.size()):
			assert_gt(s[i], s[i - 1], "%s: kesin artan" % a.id)
		total += s.size()
	assert_between(total, 19, 80, "toplam kademe <= 80")


func test_c2_groups_match_the_design_mapping_and_are_fixed_uppercase() -> void:
	if _gate():
		return
	for g in FAMILY_GROUPS:
		assert_true(AchievementDef.GROUPS.has(g), g)
		for n in FAMILY_GROUPS[g]:
			var a := _by_name(n)
			assert_not_null(a, n)
			if a != null:
				assert_eq(String(a.group), g, "%s grubu" % n)
	var re := RegEx.create_from_string("^[A-Z ]+$")
	for g in AchievementDef.GROUPS:
		assert_not_null(re.search(g), "%s: sabit büyük harf, ASCII" % g)


# --- eski 22 başarım: anlam korunur -------------------------------------------------------------------------------


func test_c3_every_old_achievement_is_mapped_exactly_once() -> void:
	if _gate():
		return
	var seen := {}
	for a in _defs():
		for old in a.legacy:
			assert_false(seen.has(old), "%s iki ailede" % old)
			seen[old] = a.id
	assert_eq(seen.size(), 22)
	for row in ExpectedTablesV2.ACHIEVEMENTS:
		assert_true(seen.has(row[0]), "%s hiçbir aileye eşlenmedi" % row[0])


func test_c3_old_achievement_keeps_stat_scope_and_threshold_at_its_mapped_step() -> void:
	if _gate():
		return
	var old := {}
	for row in ExpectedTablesV2.ACHIEVEMENTS:
		old[row[0]] = row
	for a in _defs():
		for old_id in a.legacy:
			var row: Array = old.get(old_id, [])
			assert_false(row.is_empty(), String(old_id))
			if row.is_empty():
				continue
			var k := int(a.legacy[old_id])
			# Spec bilerek iki kimliğin stat/kapsamını değiştirir (tek koşu bayrağı → toplam sayaç); VLAD kararı (T20261026-63).
			if not SCOPE_CHANGED.has(String(old_id)):
				assert_eq(String(a.stat), row[1], "%s: stat" % old_id)
				assert_eq(String(a.scope), row[4], "%s: kapsam" % old_id)
			assert_eq(a.thresholds()[k - 1], row[2], "%s: eşik %s kademe %d" % [old_id, a.id, k])


func test_c3_total_boss_kills_is_used_by_the_boss_family_and_is_total_scoped() -> void:
	if _gate():
		return
	var used := 0
	for a in _defs():
		if a.stat == &"total_boss_kills":
			used += 1
			assert_eq(a.scope, &"total", a.id)
			assert_eq(String(a.group), "THE CROWNED", "boss sayacı taç grubunda")
	assert_gte(used, 1, "total_boss_kills bir ailede kullanılır")


func test_c4_shipped_data_validates_in_complete_mode_and_texts_fit() -> void:
	if _gate():
		return
	assert_eq(GameData.load_dir("res://data").validate({}, true), PackedStringArray())
	var ids := {}
	for a in _defs():
		assert_false(ids.has(a.id), "tekil kimlik %s" % a.id)
		ids[a.id] = true
		assert_lte(a.display_name.length(), 22, a.id)
		assert_lte(a.desc.length(), 60, a.id)
		assert_ne(a.desc, "", "%s: açıklama (Türkçe)" % a.id)
		assert_eq(a.display_name, a.display_name.strip_edges(), a.id)


func test_c4_unlock_reference_to_a_family_resolves_in_the_shipped_data() -> void:
	if _gate():
		return
	var d := GameData.load_default()
	var checked := 0
	for id in d.character_ids:
		var u := d.get_character(id).unlock_achievement
		if u != &"":
			checked += 1
			assert_not_null(d.get_achievement(u), "kilit başarımı aile kimliği: %s" % id)
	# Gönderilen karakterlerin hiçbirinde kilit yoksa döngü hiçbir şey denemez (risky); çözümleme yolunu doğrudan sına:
	if checked == 0:
		var fam: AchievementDef = _defs()[0]
		var c := CharacterDef.from_dict(
			{"id": "kilitli", "unlock": {"achievement": String(fam.id)}}
		)
		assert_eq(c.unlock_achievement, fam.id, "unlock.achievement aile kimliği olarak okunur")
		assert_not_null(d.get_achievement(c.unlock_achievement), "gerçek aile kimliği çözülür")
	assert_null(d.get_achievement(&"no_such_family"), "bilinmeyen aile kimliği çözülmez")
