extends GutTest
## v2.0.3 sözleşme (A ad alanı): `portrait_video` karakter alanı ve `Settings.hareket_azalt`. A okur/kullanır, D yalnız
## arayüzünü bağlar. `zz` ayırıcısı için test_v203_c_zz_schema.gd'ye bak.

const FIX := "res://test/fixtures"
const TMP := "user://test_v203_settings.cfg"

var settings: Node


func before_each() -> void:
	settings = load("res://scripts/autoload/settings.gd").new()
	add_child_autofree(settings)


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _codes(errs: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	for e in errs:
		out.append(e.get_slice("]", 0).trim_prefix("["))
	return out


func _char_errs(over: Dictionary) -> PackedStringArray:
	var base: Dictionary = KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json")
	var d := base.duplicate(true)
	d.merge(over, true)
	return GameData.load_dir(KitDev.data_dir_with({"characters/gunslinger.json": d})).validate(
		{}, true
	)


func test_portrait_video_missing_file_reports_asset_missing() -> void:
	var errs := (
		GameData
		. load_dir(KitDev.data_dir("%s/char_bad_portrait_video_missing" % FIX))
		. validate({}, true)
	)
	assert_true(_codes(errs).has("asset_missing"), str(errs))


func test_portrait_video_placeholder_is_accepted() -> void:
	var over := {"portrait_video": "placeholder:anim.ogv"}
	assert_eq(_char_errs(over), PackedStringArray())


func test_portrait_video_must_be_an_ogv_file() -> void:
	assert_true(_codes(_char_errs({"portrait_video": "placeholder:anim.mp4"})).has("bad_type"))
	assert_true(_codes(_char_errs({"portrait_video": 5})).has("bad_type"))


func test_character_def_exposes_portrait_video() -> void:
	var d: Dictionary = KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json")
	assert_eq(CharacterDef.from_dict(d).portrait_video, "")
	d["portrait_video"] = "res://assets/video/portrait/gunslinger.ogv"
	assert_eq(
		CharacterDef.from_dict(d).portrait_video, "res://assets/video/portrait/gunslinger.ogv"
	)


func test_hareket_azalt_defaults_off() -> void:
	assert_false(settings.hareket_azalt)


func test_hareket_azalt_roundtrips_in_settings_file() -> void:
	settings.hareket_azalt = true
	assert_true(settings.save_settings(TMP))
	var other: Node = load("res://scripts/autoload/settings.gd").new()
	add_child_autofree(other)
	other.load_settings(TMP)
	assert_true(other.hareket_azalt)


func test_old_settings_file_without_key_opens_with_motion_on() -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string('{"ses":false,"titresim":true,"karakter":"gunslinger"}')
	f.close()
	settings.load_settings(TMP)
	assert_false(settings.hareket_azalt)
	assert_false(settings.sound_on, "diğer anahtarlar korunur")


func test_set_hareket_azalt_emits_settings_changed() -> void:
	watch_signals(Events)
	settings.store_path = TMP
	settings.set_hareket_azalt(true)
	assert_true(settings.hareket_azalt)
	assert_signal_emitted(Events, "settings_changed")
