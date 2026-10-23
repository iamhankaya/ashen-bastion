extends GutTest
## Settings: kaydet/yükle (geçici yol enjeksiyonu), bozuk dosya, Master bus kapatma.

const TMP := "user://test_settings.cfg"

var settings: Node


func before_each() -> void:
	settings = load("res://scripts/autoload/settings.gd").new()
	add_child_autofree(settings)


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	AudioServer.set_bus_mute(0, false)


func test_defaults_are_on() -> void:
	assert_true(settings.sound_on)
	assert_true(settings.vibration_on)


func test_save_then_load_roundtrip() -> void:
	settings.sound_on = false
	settings.vibration_on = false
	assert_true(settings.save_settings(TMP))
	var other: Node = load("res://scripts/autoload/settings.gd").new()
	add_child_autofree(other)
	other.load_settings(TMP)
	assert_false(other.sound_on)
	assert_false(other.vibration_on)


func test_missing_file_keeps_defaults() -> void:
	settings.load_settings("user://yok_boyle_dosya.cfg")
	assert_true(settings.sound_on)


func test_corrupt_file_keeps_defaults() -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("[[[ bozuk\n= =")
	f.close()
	settings.load_settings(TMP)
	assert_true(settings.sound_on)
	assert_true(settings.vibration_on)


func test_unwritable_path_returns_false() -> void:
	assert_false(settings.save_settings("user://yok_dizin/ayar.cfg"))


func test_sound_off_mutes_master_bus() -> void:
	settings.sound_on = false
	settings.apply_audio()
	assert_true(AudioServer.is_bus_mute(0))
	settings.sound_on = true
	settings.apply_audio()
	assert_false(AudioServer.is_bus_mute(0))


func test_vibrate_is_noop_on_desktop_without_error() -> void:
	settings.vibrate(30)
	settings.vibration_on = false
	settings.vibrate(30)
	assert_eq(Stub.calls().size(), 0)
