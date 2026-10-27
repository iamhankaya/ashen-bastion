class_name V21Kit
extends RefCounted
## v2.1 test yardımcıları (sahip: C fazı; dilimler kendi yardımcılarını ayrı dosyaya yazar). Global durumu ({Settings, V21Runs})
## DEĞİŞTİREN her yardımcı geri alma Callable'ı döndürür; test `after_each`'te çağırır.


## Doğrulanmış run_profiles.json verisi (her çağrıda diskten; derin kopya, serbestçe bozulabilir).
static func cfg() -> Dictionary:
	var res := RunProfiles.load_default()
	assert(res["errors"].is_empty(), "run_profiles.json geçerli olmalı: %s" % [res["errors"]])
	return (res["profiles"] as Dictionary).duplicate(true)


static func profile(mode: StringName, diff: StringName) -> RunProfile:
	return RunProfile.make(mode, diff, cfg())


## `path` ("modes.endless.time_scale") sözlükte değerle değiştirilir (değer null ise anahtar silinir); yeni sözlük döner.
static func mutated(base: Dictionary, path: String, value: Variant) -> Dictionary:
	var d := base.duplicate(true)
	var parts := path.split(".")
	var cur: Dictionary = d
	for i in parts.size() - 1:
		cur = cur[parts[i]]
	if value == null:
		cur.erase(parts[parts.size() - 1])
	else:
		cur[parts[parts.size() - 1]] = value
	return d


## Controller testlerini sabit bir (mod, zorluk) çiftine alır (Settings'e YAZMAZ, bellek içi); geri alma döner.
static func pin_selection(mode: String, diff: String) -> Callable:
	var st := (Engine.get_main_loop() as SceneTree).root.get_node("Settings")
	var old := [st.run_mode, st.run_diff]
	st.run_mode = mode
	st.run_diff = diff
	return func() -> void:
		st.run_mode = old[0]
		st.run_diff = old[1]


## Settings yerine geçen sahte nesne (run_mode/run_diff/save_settings); V21Runs.settings_override'a atanır.
class FakeSettings:
	extends RefCounted
	var run_mode: String = "normal"
	var run_diff: String = "normal"
	var saves: int = 0

	func save_settings() -> bool:
		saves += 1
		return true


static func use_fake_settings() -> FakeSettings:
	var f := FakeSettings.new()
	V21Runs.settings_override = f
	return f


static func clear_fake_settings() -> void:
	V21Runs.settings_override = null
	V21Runs.reset_cache()
