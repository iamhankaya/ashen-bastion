extends GutTest
## U1b göç: Barutçu kaldırıldı. Kayıtlı `karakter` (ayar) Gunslinger'a çözülür; başarım deposundaki `chars5` hiç
## yeniden yazılmaz/filtrelenmez (bayt karşılaştırması). Bozuk/eksik girdilerde çökme yok. Geçici yollar kullanılır.

const SETTINGS_TMP := "user://test_v202_migration_settings.cfg"
const STORE_TMP := "user://test_v202_migration_ach.json"
const SettingsScript := preload("res://scripts/autoload/settings.gd")

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func after_each() -> void:
	for p in [SETTINGS_TMP, STORE_TMP, STORE_TMP + ".bad", STORE_TMP + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _resolved_from_settings(text: String) -> StringName:
	_write(SETTINGS_TMP, text)
	var s: Node = autofree(SettingsScript.new())
	s.store_path = SETTINGS_TMP
	s.load_settings()
	return CharacterRoster.resolve(s.character_id, _data, null)


func test_barutcu_is_not_a_character_any_more() -> void:
	assert_null(_data.get_character(&"barutcu"))
	var ids := CharacterRoster.ids(_data)
	assert_false(ids.has(&"barutcu"), "barutcu listede yok")
	assert_true(ids.has(&"gunslinger") and ids.has(&"zyfen"), "mevcut karakterler listede")


func test_saved_barutcu_in_any_spelling_resolves_to_gunslinger() -> void:
	for saved in [
		"barutcu", "Barutcu", "BARUTCU", " barutcu", "barutcu\n", "../data/characters/barutcu"
	]:
		assert_eq(
			_resolved_from_settings(JSON.stringify({"karakter": saved})), &"gunslinger", saved
		)


func test_settings_character_field_absent_empty_or_wrong_type_goes_to_default() -> void:
	for text in ['{"ses": true}', '{"karakter": ""}', '{"karakter": 5}', '{"karakter": null}']:
		assert_eq(_resolved_from_settings(text), &"gunslinger", text)


func test_broken_settings_file_does_not_crash_and_resolves_to_default() -> void:
	for text in ["", "{", "[1,2]", "not json"]:
		assert_eq(_resolved_from_settings(text), &"gunslinger", text)


func test_saved_zyfen_still_resolves_to_zyfen() -> void:
	assert_eq(_resolved_from_settings('{"karakter": "zyfen"}'), &"zyfen")


func test_chars5_with_removed_character_is_kept_and_counts_two() -> void:
	var text := JSON.stringify(
		{
			"v": AchievementStore.VERSION,
			"unlocked": {},
			"totals": {"kills": 0, "runs": 0, "wins": 0, "play_secs": 0},
			"best": {"score": 0, "time": 0, "level": 0},
			"chars5": ["gunslinger", "barutcu"]
		}
	)
	_write(STORE_TMP, text)
	var st := AchievementStore.new(STORE_TMP)
	assert_true(st.load_file(AchKit.legacy_data().achievements))
	assert_false(st.corrupt)
	assert_eq(Array(st.chars5), ["gunslinger", "barutcu"])
	assert_eq(AchievementProgress.of(_data.get_achievement(&"two_roads"), st), 2)
	assert_true(st.save())
	# v2.0.3: sayaç sözlükleri yeni anahtarlar taşır; chars5 dizisi aynen korunur
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORE_TMP))
	assert_eq(saved["chars5"], ["gunslinger", "barutcu"], "chars5 aynen kalır")


func test_chars5_bad_shapes_load_without_crash_and_without_corrupt_flag() -> void:
	for raw in ['"barutcu"', "null", "5", "[]", '[5, null, "BARUTCU", {}]', '{"a": 1}']:
		_write(STORE_TMP, '{"v":1,"unlocked":{},"totals":{},"best":{},"chars5":%s}' % raw)
		var st := AchievementStore.new(STORE_TMP)
		st.load_file()
		assert_false(st.corrupt, raw)
		assert_eq(st.chars5.size(), 0, raw)
