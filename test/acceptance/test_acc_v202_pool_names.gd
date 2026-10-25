extends GutTest
## Kabul (v2.0.2 K, P): ortak pasiflerin karaktere göre ad/ikon/açıklaması (Derin Nefes dahil) ve kart taşması.
## Beklenen adlar plan "Arayüzler/2" tablosundan ELLE (ExpectedTablesV202.COMMON_NAMES). Zyfen adları öneridir (plan Açık nokta #4);
## değişirse yalnız tablo güncellenir. Kart üretimi sözleşmesi: `Loadout.card_for` + `SkillDef.name_for/icon_for/desc_for`.

const NAME_MAX := 18  # plan: ad <= 18 karakter (diakritikli); Türkçe harfler tek karakterdir
const ICON_DIR := "res://assets/ui/icons/zyfen/"

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func _def(id: String) -> SkillDef:
	return _data.get_skill(StringName(id))


func test_p1_every_common_passive_has_plan_names_per_character() -> void:
	if V202Slice.require(self, "P"):
		return
	for id in ExpectedTablesV202.COMMON_NAMES:
		var want: Array = ExpectedTablesV202.COMMON_NAMES[id]
		var d := _def(id)
		assert_not_null(d, id)
		assert_eq(d.name_for(&"gunslinger"), want[0], "%s Gunslinger adı" % id)
		assert_eq(d.name_for(&"zyfen"), want[1], "%s Zyfen adı" % id)
		assert_eq(d.name_for(&""), d.display_name, "%s karaktersiz çağrı display_name" % id)
		assert_eq(d.name_for(&"yok_boyle_biri"), d.display_name, "%s bilinmeyen karakter" % id)


func test_p2_common_passive_icons_are_zyfen_specific_files_that_exist() -> void:
	if V202Slice.require(self, "P"):
		return
	for id in ExpectedTablesV202.COMMON_NAMES:
		var d := _def(id)
		var z := d.icon_for(&"zyfen")
		assert_true(z.begins_with(ICON_DIR), "%s Zyfen ikon yolu %s" % [id, z])
		assert_true(z.ends_with("%s.svg" % id.replace("_", "-")), "%s ikon dosya adı" % id)
		assert_true(ResourceLoader.exists(z), "%s Zyfen ikonu yüklenebilir" % id)
		assert_eq(d.icon_for(&"gunslinger"), d.icon, "%s Gunslinger ikonu değişmedi" % id)
		assert_ne(z, d.icon_for(&"gunslinger"), "%s iki karakterin ikonu farklı" % id)


func test_p3_common_passive_names_fit_the_card() -> void:
	if V202Slice.require(self, "P"):
		return
	for id in ExpectedTablesV202.COMMON_NAMES:
		var d := _def(id)
		for ch in [&"gunslinger", &"zyfen"]:
			var n := d.name_for(ch)
			assert_gt(n.length(), 0, "%s/%s adı boş" % [id, ch])
			assert_lte(n.length(), NAME_MAX, "%s/%s adı %d karakter" % [id, ch, n.length()])


func test_p4_variant_descriptions_cover_every_level() -> void:
	if V202Slice.require(self, "P"):
		return
	for id in ExpectedTablesV202.COMMON_NAMES:
		var d := _def(id)
		for lv in range(1, d.max_level + 1):
			var z := d.desc_for(&"zyfen", lv)
			assert_gt(z.length(), 0, "%s sv%d Zyfen açıklaması" % [id, lv])
			assert_gt(
				d.desc_for(&"gunslinger", lv).length(),
				0,
				"%s sv%d Gunslinger açıklaması" % [id, lv]
			)
		assert_eq(d.desc_for(&"zyfen", 0), "", "%s sv0 boş" % id)
		assert_eq(d.desc_for(&"zyfen", d.max_level + 1), "", "%s aralık dışı boş" % id)
		if id in ["fazladan_mermi", "hizli_doldurma"]:  # plan: rüzgar temalı yeniden yazılan metinler
			assert_ne(
				d.desc_for(&"zyfen", 1), d.desc_for(&"gunslinger", 1), "%s açıklamalar ayrı" % id
			)


func test_p5_derin_nefes_card_text_says_wind_not_bullets() -> void:
	if V202Slice.require(self, "P"):
		return
	var d := _def("fazladan_mermi")
	assert_eq(d.name_for(&"zyfen"), "Derin Nefes")
	for lv in range(1, 6):
		var t := d.desc_for(&"zyfen", lv)
		assert_true(t.contains("+%d" % lv), "sv%d açıklaması +%d içerir: %s" % [lv, lv, t])
		assert_false(
			t.contains("mermi") or t.contains("Mermi"), "Zyfen metninde 'mermi' yok: %s" % t
		)


func test_p6_level_up_cards_use_the_characters_names_and_icons() -> void:
	if V202Slice.require(self, "P"):
		return
	for pair in [[&"zyfen", 1], [&"gunslinger", 0]]:
		var ch: StringName = pair[0]
		var lo := Loadout.new(_data, ch)
		for id in ExpectedTablesV202.COMMON_NAMES:
			var d := _def(id)
			var c := lo.card_for(StringName(id), 1)
			assert_not_null(c, "%s/%s kartı" % [ch, id])
			if c == null:
				continue
			assert_eq(c.title, d.name_for(ch), "%s/%s kart başlığı" % [ch, id])
			assert_eq(c.icon, d.icon_for(ch), "%s/%s kart ikonu" % [ch, id])
			assert_eq(c.desc, d.desc_for(ch, 1), "%s/%s kart açıklaması" % [ch, id])


func test_p7_card_for_next_level_uses_that_levels_description() -> void:
	if V202Slice.require(self, "P"):
		return
	var lo := Loadout.new(_data, &"zyfen")
	lo.add_or_upgrade(&"fazladan_mermi")
	lo.add_or_upgrade(&"fazladan_mermi")
	var c := lo.card_for(&"fazladan_mermi", 3)
	assert_eq(c.to_level, 3)
	assert_eq(c.desc, _def("fazladan_mermi").desc_for(&"zyfen", 3))
