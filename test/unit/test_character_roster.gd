extends GutTest
## CharacterRoster (S3 gerçek, saf): resolve tüm dal tablosu, kilit güvenli yönü, step sarmaz, kilit nedeni.

var _real: GameData


func before_all() -> void:
	_real = GameData.load_dir("res://data")


func after_all() -> void:
	KitDev.remove_tmp()


## data_valid + (isteğe bağlı) kilitli ikinci karakter "kilitli" (unlock: bes_dakika).
func _data_with_locked() -> GameData:
	var base: Dictionary = KitDev.read_json(
		"res://test/fixtures/data_valid/characters/gunslinger.json"
	)
	var locked := base.duplicate(true)
	locked["id"] = "kilitli"
	locked["unlock"] = {"achievement": "bes_dakika"}
	return GameData.load_dir(KitDev.data_dir_with({"characters/kilitli.json": locked}))


func _store(unlocked_ids: Array, corrupt: bool = false) -> AchievementStore:
	# İskelet depo Stub'dur; kilit okuması için küçük bir sahte depo (is_unlocked gerçek davranışı taklit eder).
	var s := _FakeStore.new()
	s.open_ids = unlocked_ids
	s.corrupt = corrupt
	return s


class _FakeStore:
	extends AchievementStore
	var open_ids: Array = []

	func is_unlocked(id: StringName) -> bool:
		return open_ids.has(id)


func test_ids_follow_order_field() -> void:
	# F-030: vitrin sırası `order` alanı (gunslinger 1, zyfen 2), dosya adı sırası değil.
	assert_eq(CharacterRoster.ids(_real), [&"gunslinger", &"zyfen"] as Array[StringName])


func test_resolve_empty_unknown_or_missing_goes_to_default() -> void:
	for saved in ["", "yok", "Gunslinger", "barutcu "]:
		assert_eq(CharacterRoster.resolve(saved, _real, null), &"gunslinger", saved)


func test_resolve_valid_saved_wins() -> void:
	assert_eq(CharacterRoster.resolve("zyfen", _real, null), &"zyfen")
	assert_eq(CharacterRoster.resolve("gunslinger", _real, null), &"gunslinger")


func test_resolve_default_is_order_independent() -> void:
	# zyfen `order` ile öne alınsa da varsayılan gunslinger'dır.
	var d := GameData.load_dir("res://data")  # özel kopya
	d.get_character(&"zyfen").order = 0
	d._sort_character_ids()
	assert_eq(CharacterRoster.ids(d)[0], &"zyfen")
	assert_eq(CharacterRoster.resolve("", d, null), &"gunslinger")
	assert_eq(CharacterRoster.resolve("", _real, null), &"gunslinger")


func test_resolve_single_character_data() -> void:
	var g := GameData.load_dir(KitDev.data_dir())
	assert_eq(CharacterRoster.resolve("barutcu", g, null), &"gunslinger")
	assert_eq(CharacterRoster.resolve("gunslinger", g, null), &"gunslinger")


func test_resolve_without_default_uses_first_unlocked() -> void:
	var only: Dictionary = KitDev.read_json(
		"res://test/fixtures/data_valid/characters/gunslinger.json"
	)
	only["id"] = "tek_ve_garip"
	var g := GameData.load_dir(
		KitDev.data_dir_with(
			{"characters/gunslinger.json": null, "characters/tek_ve_garip.json": only}
		)
	)
	assert_eq(CharacterRoster.resolve("", g, null), &"tek_ve_garip")


func test_resolve_no_characters_returns_empty() -> void:
	var g := GameData.load_dir(KitDev.data_dir_with({"characters/gunslinger.json": null}))
	assert_eq(CharacterRoster.resolve("gunslinger", g, null), &"")


func test_locked_character_is_not_selectable_when_store_missing_or_corrupt() -> void:
	var g := _data_with_locked()
	assert_eq(
		CharacterRoster.resolve("kilitli", g, null),
		&"gunslinger",
		"store null => kilitli (güvenli yön)"
	)
	assert_eq(
		CharacterRoster.resolve("kilitli", g, _store(["bes_dakika"], true)),
		&"gunslinger",
		"bozuk kayıt => kilitli"
	)


func test_locked_character_unlocks_with_the_achievement() -> void:
	var g := _data_with_locked()
	assert_eq(CharacterRoster.resolve("kilitli", g, _store([])), &"gunslinger")
	assert_eq(CharacterRoster.resolve("kilitli", g, _store(["bes_dakika"])), &"kilitli")


func test_is_unlocked_without_unlock_field_is_always_true() -> void:
	var c := _real.get_character(&"zyfen")
	assert_true(CharacterRoster.is_unlocked(c, null))
	assert_true(CharacterRoster.is_unlocked(c, _store([], true)))


func test_lock_reason_uses_achievement_display_name() -> void:
	var g := GameData.load_dir(
		KitDev.data_dir_with({"characters/kilitli.json": _locked_json("bes_dakika")})
	)
	assert_eq(
		CharacterRoster.lock_reason(g.get_character(&"kilitli"), g), "Beş Dakika başarımını aç"
	)


func test_lock_reason_falls_back_to_id_for_unknown_achievement() -> void:
	var g := GameData.load_dir(
		KitDev.data_dir_with({"characters/kilitli.json": _locked_json("olmayan")})
	)
	assert_eq(CharacterRoster.lock_reason(g.get_character(&"kilitli"), g), "olmayan başarımını aç")


func _locked_json(ach: String) -> Dictionary:
	var d: Dictionary = KitDev.read_json(
		"res://test/fixtures/data_valid/characters/gunslinger.json"
	)
	d["id"] = "kilitli"
	d["unlock"] = {"achievement": ach}
	return d


func test_step_moves_and_does_not_wrap() -> void:
	var ids: Array[StringName] = [&"a", &"b", &"c"]
	assert_eq(CharacterRoster.step(ids, &"a", 1), &"b")
	assert_eq(CharacterRoster.step(ids, &"b", 1), &"c")
	assert_eq(CharacterRoster.step(ids, &"c", 1), &"c", "uçta aynı kalır")
	assert_eq(CharacterRoster.step(ids, &"a", -1), &"a")
	assert_eq(CharacterRoster.step(ids, &"c", -1), &"b")
	assert_eq(CharacterRoster.step(ids, &"b", 5), &"c", "yön işareti kadar tek adım")
	assert_eq(CharacterRoster.step(ids, &"b", 0), &"b")


func test_step_edge_cases() -> void:
	var empty: Array[StringName] = []
	assert_eq(CharacterRoster.step(empty, &"x", 1), &"x")
	var ids: Array[StringName] = [&"a", &"b"]
	assert_eq(CharacterRoster.step(ids, &"yok", 1), &"a", "listede yoksa ilk eleman")
	var one: Array[StringName] = [&"a"]
	assert_eq(CharacterRoster.step(one, &"a", 1), &"a")
	assert_eq(CharacterRoster.step(one, &"a", -1), &"a")
