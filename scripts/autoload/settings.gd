extends Node
## Kullanıcı ayarları (user://settings.cfg). Yol enjekte edilebilir (testte geçici yol).

var sound_on: bool = true
var vibration_on: bool = true


func _ready() -> void:
	load_settings()
	apply_audio()


## Dosya yoksa ya da bozuksa varsayılanlar korunur. Biçim: JSON (ayrıştırma hatası motor günlüğüne düşmez).
func load_settings(path: String = "user://settings.cfg") -> void:
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return
	var d: Dictionary = json.data
	sound_on = bool(d.get("ses", true))
	vibration_on = bool(d.get("titresim", true))


## Yazılamazsa false döner (üretim kodunda push_error kullanılmaz).
func save_settings(path: String = "user://settings.cfg") -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"ses": sound_on, "titresim": vibration_on}))
	return true


func set_sound(on: bool) -> void:
	sound_on = on
	apply_audio()
	save_settings()
	Events.settings_changed.emit()


func set_vibration(on: bool) -> void:
	vibration_on = on
	save_settings()
	Events.settings_changed.emit()


## sound_on=false Master bus'ı susturur.
func apply_audio() -> void:
	var idx := AudioServer.get_bus_index(&"Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, not sound_on)


## vibration_on ve Android ise Input.vibrate_handheld(ms).
func vibrate(ms: int) -> void:
	if vibration_on and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)
