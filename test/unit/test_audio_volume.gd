extends GutTest
## v2.0.1 ses seviyeleri: yüzde->dB eşlemesi, kaydet/yükle, müzik kullanıcı seviyesi + duraklatma/duck toplamı,
## efekt yüzdesinin SFX ve UI kanallarına uygulanması, ayarlar ekranı.

const TMP := "user://test_audio_volume.cfg"

var st: Node
var _saved := {}


func before_each() -> void:
	st = get_node(^"/root/Settings")
	_saved = {
		"path": st.store_path,
		"m": st.music_pct,
		"s": st.sfx_pct,
		"x": st.music_extra_db,
		"snd": st.sound_on
	}
	st.store_path = TMP  # kaydetmeler geçici dosyaya (user://settings.cfg sızıntısı olmasın)
	st.music_pct = 100
	st.sfx_pct = 70
	st.music_extra_db = 0.0
	st.sound_on = true
	st.apply_audio()


func after_each() -> void:
	st.store_path = _saved["path"]
	st.music_pct = _saved["m"]
	st.sfx_pct = _saved["s"]
	st.music_extra_db = _saved["x"]
	st.sound_on = _saved["snd"]
	st.apply_audio()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _idx(bus: StringName) -> int:
	return AudioServer.get_bus_index(bus)


func _fresh() -> Node:
	var o: Node = load("res://scripts/autoload/settings.gd").new()
	add_child_autofree(o)
	return o


func _write(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- eşleme ---------------------------------------------------------------------------------


func test_pct_to_db_100_is_zero_and_0_is_silent() -> void:
	assert_almost_eq(AudioMix.pct_to_db(100), 0.0, 0.001)
	assert_eq(AudioMix.pct_to_db(0), AudioMix.SILENT_DB)
	assert_eq(AudioMix.bus_db(0, -8.0), AudioMix.SILENT_DB)


func test_pct_to_db_is_monotonic_perceptual_curve() -> void:
	var prev := AudioMix.pct_to_db(0)
	for p in range(5, 101, 5):
		var db := AudioMix.pct_to_db(p)
		assert_gt(db, prev, "%d%% bir öncekinden yüksek olmalı" % p)
		prev = db
	assert_almost_eq(AudioMix.pct_to_db(50), linear_to_db(0.25), 0.001)


func test_clamp_pct() -> void:
	assert_eq(AudioMix.clamp_pct(-20.0), 0)
	assert_eq(AudioMix.clamp_pct(250.0), 100)
	assert_eq(AudioMix.clamp_pct(42.6), 43)
	assert_eq(AudioMix.clamp_pct(NAN), 100)


# --- kalıcılık ------------------------------------------------------------------------------


func test_defaults_are_music_100_sfx_70() -> void:
	var o := _fresh()
	assert_eq(o.music_pct, 100)
	assert_eq(o.sfx_pct, 70)


func test_save_load_roundtrip() -> void:
	var o := _fresh()
	o.music_pct = 35
	o.sfx_pct = 85
	assert_true(o.save_settings(TMP))
	var other := _fresh()
	other.load_settings(TMP)
	assert_eq(other.music_pct, 35)
	assert_eq(other.sfx_pct, 85)


func test_load_clamps_out_of_range_values() -> void:
	_write('{"muzik_yuzde": 400, "efekt_yuzde": -30}')
	var o := _fresh()
	o.load_settings(TMP)
	assert_eq(o.music_pct, 100)
	assert_eq(o.sfx_pct, 0)


func test_load_missing_or_corrupt_fields_use_defaults() -> void:
	_write('{"ses": true}')
	var o := _fresh()
	o.music_pct = 10
	o.sfx_pct = 10
	o.load_settings(TMP)
	assert_eq(o.music_pct, 100)
	assert_eq(o.sfx_pct, 70)
	_write('{"muzik_yuzde": "yüksek", "efekt_yuzde": null}')
	o.load_settings(TMP)
	assert_eq(o.music_pct, 100)
	assert_eq(o.sfx_pct, 70)


func test_load_rounds_float_values_to_integers() -> void:
	_write('{"muzik_yuzde": 62.4, "efekt_yuzde": 62.6}')
	var o := _fresh()
	o.load_settings(TMP)
	assert_eq(o.music_pct, 62)
	assert_eq(o.sfx_pct, 63)


# --- kanallara uygulama ---------------------------------------------------------------------


func test_sfx_pct_applies_to_sfx_and_ui_buses() -> void:
	st.set_sfx_pct(50, false)
	for bus in [&"SFX", &"UI"]:
		assert_almost_eq(AudioServer.get_bus_volume_db(_idx(bus)), AudioMix.pct_to_db(50), 0.01)
		assert_false(AudioServer.is_bus_mute(_idx(bus)))


func test_zero_pct_mutes_bus_and_restoring_unmutes() -> void:
	st.set_sfx_pct(0, false)
	assert_true(AudioServer.is_bus_mute(_idx(&"SFX")))
	assert_true(AudioServer.is_bus_mute(_idx(&"UI")))
	st.set_music_pct(0, false)
	assert_true(AudioServer.is_bus_mute(_idx(&"Music")))
	st.set_sfx_pct(5, false)
	st.set_music_pct(5, false)
	assert_false(AudioServer.is_bus_mute(_idx(&"SFX")))
	assert_false(AudioServer.is_bus_mute(_idx(&"Music")))


func test_quick_mute_does_not_change_percentages() -> void:
	st.set_music_pct(40, false)
	st.set_sfx_pct(60, false)
	st.sound_on = false
	st.apply_audio()
	assert_true(AudioServer.is_bus_mute(_idx(&"Master")))
	assert_eq(st.music_pct, 40)
	assert_eq(st.sfx_pct, 60)
	st.sound_on = true
	st.apply_audio()
	assert_false(AudioServer.is_bus_mute(_idx(&"Master")))
	assert_almost_eq(AudioServer.get_bus_volume_db(_idx(&"Music")), AudioMix.pct_to_db(40), 0.01)


# --- müzik: kullanıcı seviyesi + duraklatma/duck toplamı ----------------------------------------


func _director() -> AudioDirector:
	var d := AudioDirector.new()
	add_child_autofree(d)
	return d


func test_user_music_level_adds_to_pause_and_duck() -> void:
	var d := _director()
	st.set_music_pct(50, false)
	var user_db := AudioMix.pct_to_db(50)
	var music := _idx(&"Music")
	d.set_paused(true)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), user_db + AudioDirector.PAUSE_DB, 0.01)
	d.set_paused(false)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), user_db, 0.01)
	d._on_boss_warning(&"elit_piyade")
	assert_almost_eq(AudioServer.get_bus_volume_db(music), user_db + AudioDirector.DUCK_DB, 0.01)
	d.set_paused(true)
	var both := user_db + AudioDirector.PAUSE_DB + AudioDirector.DUCK_DB
	assert_almost_eq(AudioServer.get_bus_volume_db(music), both, 0.01)


func test_changing_user_level_keeps_pause_offset() -> void:
	var d := _director()
	d.set_paused(true)
	st.set_music_pct(80, false)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(_idx(&"Music")),
		AudioMix.pct_to_db(80) + AudioDirector.PAUSE_DB,
		0.01
	)


func test_director_exit_resets_extra_but_keeps_user_level() -> void:
	var d := AudioDirector.new()
	add_child(d)
	st.set_music_pct(60, false)
	d.set_paused(true)
	remove_child(d)
	d.free()
	assert_almost_eq(st.music_extra_db, 0.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(_idx(&"Music")), AudioMix.pct_to_db(60), 0.01)


# --- ayarlar ekranı -----------------------------------------------------------------------------


func test_settings_screen_sliders_use_five_percent_steps_and_drive_buses() -> void:
	var sc := SettingsScreen.new()
	add_child_autofree(sc)
	sc.open()
	assert_eq(sc.music_slider.step, 5.0)
	assert_eq(sc.sfx_slider.step, 5.0)
	assert_eq(sc.music_slider.max_value, 100.0)
	assert_eq(sc.sfx_value.text, "%70")
	sc.sfx_slider.value = 30
	assert_eq(sc.sfx_value.text, "%30")
	assert_eq(st.sfx_pct, 30)
	assert_almost_eq(AudioServer.get_bus_volume_db(_idx(&"UI")), AudioMix.pct_to_db(30), 0.01)
	sc.music_slider.value = 55
	assert_eq(sc.music_value.text, "%55")
	assert_almost_eq(AudioServer.get_bus_volume_db(_idx(&"Music")), AudioMix.pct_to_db(55), 0.01)


func test_settings_screen_hits_are_large_for_touch() -> void:
	var sc := SettingsScreen.new()
	add_child_autofree(sc)
	assert_gte(sc.music_slider.custom_minimum_size.y, 120.0)
	assert_gte(sc.music_slider.get_theme_icon(&"grabber").get_width(), 72)
	assert_gte(sc.back_button.custom_minimum_size.y, 132.0)


func test_settings_screen_touch_drag_sets_value_and_release_previews() -> void:
	var sc := SettingsScreen.new()
	add_child_autofree(sc)
	sc.open()
	var s := sc.sfx_slider
	s.size = Vector2(936, 132)
	var ev := InputEventScreenDrag.new()
	ev.position = Vector2(s.size.x * 0.5, 40.0)
	s.gui_input.emit(ev)
	assert_between(s.value, 40.0, 60.0)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	s.gui_input.emit(up)
	assert_eq(st.sfx_pct, AudioMix.clamp_pct(s.value))
