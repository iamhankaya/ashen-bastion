extends GutTest
## Gerçek karakter kataloğu sözleşmesi (R1): sabit kimlik/sayı yok, her karakter için aynı denetim. Yeni karakter
## eklemek bu testi değiştirmez; kırılırsa yeni karakterin verisi eksiktir.

const MID := "res://tools/balance/mid_run.gd"
const PRIORITY_FILE := "res://tools/balance/card_priority.json"

var _data: GameData


class _AllOpen:
	extends AchievementStore

	func is_unlocked(_id: StringName) -> bool:
		return true


func before_all() -> void:
	_data = GameData.load_default()


func test_catalog_is_valid_and_has_the_default_character() -> void:
	assert_eq(_data.validate(), PackedStringArray())
	var ids := CharacterRoster.ids(_data)
	assert_true(ids.has(CharacterRoster.DEFAULT_ID), "varsayılan karakter katalogda")
	var seen := {}
	for id in ids:
		assert_false(seen.has(id), "yinelenen kimlik %s" % id)
		seen[id] = true


func test_every_character_has_portrait_name_and_active_starting_skill_in_its_pool() -> void:
	for id in CharacterRoster.ids(_data):
		var c := _data.get_character(id)
		assert_ne(c.display_name, "", "%s: ad" % id)
		assert_ne(UiKit.character_upper(c), "", "%s: büyük harfli ad" % id)
		assert_ne(c.portrait, "", "%s: portre yolu" % id)
		if not c.placeholder:
			assert_true(ResourceLoader.exists(c.portrait), "%s: portre dosyası" % id)
		var sk := _data.get_skill(c.starting_skill)
		assert_not_null(sk, "%s: başlangıç becerisi" % id)
		if sk != null:
			assert_eq(sk.kind, SkillDef.KIND_ACTIVE, "%s: başlangıç becerisi aktif" % id)
			assert_true(sk.available_to(id), "%s: başlangıç becerisi havuzda" % id)


func test_every_character_has_a_nonempty_card_pool() -> void:
	for id in CharacterRoster.ids(_data):
		var l := Loadout.new(_data, id)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		assert_gt(l.roll_choices(rng).size(), 0, "%s: ilk kart seçimi boş" % id)


func test_unlock_rules_reference_real_achievements_and_a_free_character_exists() -> void:
	var free := 0
	for id in CharacterRoster.ids(_data):
		var c := _data.get_character(id)
		if c.unlock_achievement == &"":
			free += 1
			continue
		assert_not_null(_data.get_achievement(c.unlock_achievement), "%s: kilit başarımı" % id)
		assert_ne(CharacterRoster.lock_reason(c, _data), "", "%s: kilit nedeni" % id)
	assert_gt(free, 0, "kilitsiz karakter olmalı (ilk açılış)")


func test_resolve_returns_each_character_when_everything_is_unlocked() -> void:
	var all := AchievementProgressView.of_store(_AllOpen.new())
	for id in CharacterRoster.ids(_data):
		assert_eq(CharacterRoster.resolve(String(id), _data, all), id)


func test_card_priority_file_references_real_characters_and_skills() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRIORITY_FILE))
	assert_true(parsed is Dictionary, "card_priority.json okunur")
	assert_true(parsed.has(String(CharacterRoster.DEFAULT_ID)), "varsayılan karakter listesi")
	var ids := CharacterRoster.ids(_data)
	for ch in parsed:
		assert_true(ids.has(StringName(ch)), "listede olmayan karakter: %s" % ch)
		for sid in parsed[ch]:
			assert_not_null(_data.get_skill(StringName(sid)), "%s: beceri yok: %s" % [ch, sid])


func test_card_priority_falls_back_to_the_default_character_list() -> void:
	var mid: GDScript = load(MID)
	var fallback: Array = mid.priority_of(&"zz_listesiz")
	assert_eq(fallback, mid.priority_of(CharacterRoster.DEFAULT_ID))
	assert_gt(fallback.size(), 0)
