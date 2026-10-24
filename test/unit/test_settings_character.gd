extends GutTest
## Settings v2.0: `karakter` anahtarı (kaydet/yükle turu, set_sound sonrası korunur, tip denetimi), yol enjeksiyonu.
## Gerçek user://settings.cfg'ye DOKUNULMAZ (testler geçici yol kullanır; gate USER_LEAK ile denetler).

const TMP := "user://test_settings_character.cfg"
const SettingsScript := preload("res://scripts/autoload/settings.gd")

var _real_md5: String = ""
var _cull_before: bool = true


func before_each() -> void:
	_real_md5 = (
		FileAccess.get_md5("user://settings.cfg")
		if FileAccess.file_exists("user://settings.cfg")
		else ""
	)
	_cull_before = RenderFix.enabled
	_clean()


func after_each() -> void:
	RenderFix.enabled = _cull_before
	_clean()
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, false)


func _clean() -> void:
	for p in [TMP, TMP + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _settings() -> Node:
	var s: Node = SettingsScript.new()
	s.store_path = TMP
	return autofree(s)


func _write(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TMP))


func test_default_character_is_empty_and_store_path_is_default() -> void:
	var s: Node = autofree(SettingsScript.new())
	assert_eq(s.character_id, "")
	assert_eq(s.store_path, "user://settings.cfg")


func test_set_character_saves_and_load_restores() -> void:
	var s := _settings()
	s.set_character("barutcu")
	assert_eq(s.character_id, "barutcu")
	assert_eq(_read()["karakter"], "barutcu")
	var s2 := _settings()
	s2.load_settings()
	assert_eq(s2.character_id, "barutcu")


func test_set_character_with_explicit_path_ignores_store_path() -> void:
	var s: Node = autofree(SettingsScript.new())
	s.set_character("barutcu", TMP)
	assert_eq(_read()["karakter"], "barutcu")


func test_set_sound_after_set_character_keeps_character() -> void:
	var s := _settings()
	s.set_character("barutcu")
	s.set_sound(false)
	var d := _read()
	assert_eq(d["karakter"], "barutcu", "set_sound karakteri silmemeli")
	assert_eq(d["ses"], false)
	s.set_vibration(false)
	assert_eq(_read()["karakter"], "barutcu")
	s.set_cull_fix(false)
	assert_eq(_read()["karakter"], "barutcu")


func test_old_file_without_character_key_loads_with_empty_character() -> void:
	_write('{"ses":false,"titresim":true,"kesme_duzeltmesi":true}')
	var s := _settings()
	s.load_settings()
	assert_eq(s.character_id, "")
	assert_false(s.sound_on)


func test_wrong_typed_character_is_ignored() -> void:
	for raw in ["5", "null", "[]", '{"a":1}', "true", "1.5"]:
		_write('{"karakter":%s}' % raw)
		var s := _settings()
		s.character_id = "eski"
		s.load_settings()
		assert_eq(s.character_id, "", "tip yanlış karakter: %s" % raw)


func test_missing_or_corrupt_file_keeps_current_character() -> void:
	var s := _settings()
	s.character_id = "barutcu"
	s.load_settings()  # dosya yok
	assert_eq(s.character_id, "barutcu")
	_write("{bozuk json")
	s.load_settings()
	assert_eq(s.character_id, "barutcu")
	_write("[1,2]")
	s.load_settings()
	assert_eq(s.character_id, "barutcu")


func test_unknown_or_locked_id_is_stored_verbatim_and_fixed_at_resolve() -> void:
	var s := _settings()
	s.set_character("yok_boyle_biri")
	var s2 := _settings()
	s2.load_settings()
	assert_eq(s2.character_id, "yok_boyle_biri", "Settings yalnız dizgeyi tutar")
	var g := GameData.load_dir("res://data")
	assert_eq(CharacterRoster.resolve(s2.character_id, g, null), &"gunslinger")


func test_save_to_injected_path_never_touches_real_settings_file() -> void:
	var s := _settings()
	s.set_character("barutcu")
	s.set_sound(true)
	var now := (
		FileAccess.get_md5("user://settings.cfg")
		if FileAccess.file_exists("user://settings.cfg")
		else ""
	)
	assert_eq(now, _real_md5, "user://settings.cfg değişmedi")


func test_set_character_emits_settings_changed() -> void:
	var s := _settings()
	watch_signals(Events)
	s.set_character("barutcu")
	assert_signal_emitted(Events, "settings_changed")


func test_unwritable_path_does_not_crash() -> void:
	var s: Node = autofree(SettingsScript.new())
	s.set_character("barutcu", "user://yok_dizin_zz/alt/ayar.cfg")
	assert_eq(s.character_id, "barutcu", "bellekte kalır")
	assert_false(s.save_settings("user://yok_dizin_zz/alt/ayar.cfg"))
