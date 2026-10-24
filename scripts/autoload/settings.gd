extends Node
## Kullanıcı ayarları (user://settings.cfg). Yol enjekte edilebilir (testte geçici yol).
## v2.0: `karakter` (seçili karakter kimliği) aynı dosyada; geçersiz/kilitli kimlik yükte değil ÇÖZÜMLEMEDE
## (`CharacterRoster.resolve`) düzeltilir. Settings yalnız dizgeyi tutar (sim/veri bağımlılığı kazanmaz).

var sound_on: bool = true
var vibration_on: bool = true
## F-ashen-bastion-002 kesme dikdörtgeni düzeltmesi (RenderFix); yalnız debug APK'da arayüzden değişir.
var cull_fix: bool = true
## v2.0: seçili karakter kimliği ("" = seçilmemiş -> varsayılan). İçerik güvenilmez (yalnız dizge alınır).
var character_id: String = ""
## v2.0: ayar dosyası yolu (boş yol parametreleri bunu kullanır). Testler geçici dosyaya çevirir, `after_each`'te geri alır.
var store_path: String = "user://settings.cfg"


func _ready() -> void:
	load_settings()
	apply_audio()


## Dosya yoksa ya da bozuksa varsayılanlar korunur. Biçim: JSON (ayrıştırma hatası motor günlüğüne düşmez).
func load_settings(path: String = "") -> void:
	if path == "":
		path = store_path
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return
	var d: Dictionary = json.data
	sound_on = bool(d.get("ses", true))
	vibration_on = bool(d.get("titresim", true))
	cull_fix = bool(d.get("kesme_duzeltmesi", true))
	var ch: Variant = d.get("karakter", "")
	character_id = ch if ch is String else ""
	RenderFix.enabled = cull_fix


## Yazılamazsa false döner (üretim kodunda push_error kullanılmaz).
func save_settings(path: String = "") -> bool:
	var f := FileAccess.open(path if path != "" else store_path, FileAccess.WRITE)
	if f == null:
		return false
	(
		f
		. store_string(
			(
				JSON
				. stringify(
					{
						"ses": sound_on,
						"titresim": vibration_on,
						"kesme_duzeltmesi": cull_fix,
						"karakter": character_id,
					}
				)
			)
		)
	)
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


## Seçili karakteri kaydeder (boş yol = store_path) ve settings_changed yayınlar.
func set_character(id: String, path: String = "") -> void:
	character_id = id
	save_settings(path)
	Events.settings_changed.emit()


func set_cull_fix(on: bool) -> void:
	cull_fix = on
	RenderFix.enabled = on
	save_settings()
	Events.settings_changed.emit()


## vibration_on ve Android ise Input.vibrate_handheld(ms).
func vibrate(ms: int) -> void:
	if vibration_on and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)
