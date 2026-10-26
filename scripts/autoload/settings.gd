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
## v2.0.1: kanal seviyeleri yüzde (0-100, tamsayı). Müzik varsayılanı 100, efekt 70 (efektler müziği bastırmasın).
const MUSIC_DEFAULT := 100
const SFX_DEFAULT := 70
var music_pct: int = MUSIC_DEFAULT
var sfx_pct: int = SFX_DEFAULT
## v2.0.3: dekoratif hareketi durdurur (hareketli portre, küre süzülmesi, ana sayfa kül/kor/meşale/sancak). A okur, D arayüzü bağlar.
var hareket_azalt: bool = false
## AudioDirector'ın Music kanalına eklediği anlık pay (duraklatma/duck, dB); kullanıcı seviyesinin ÜSTÜNE eklenir.
var music_extra_db: float = 0.0


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
	music_pct = _pct_from(d.get("muzik_yuzde"), MUSIC_DEFAULT)
	sfx_pct = _pct_from(d.get("efekt_yuzde"), SFX_DEFAULT)
	hareket_azalt = bool(d.get("hareket_azalt", false))
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
						"muzik_yuzde": music_pct,
						"efekt_yuzde": sfx_pct,
						"hareket_azalt": hareket_azalt,
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


func set_hareket_azalt(on: bool) -> void:
	hareket_azalt = on
	save_settings()
	Events.settings_changed.emit()


## Sayı değilse/eksikse varsayılan; sayıysa 0-100'e sıkıştırılıp tamsayıya yuvarlanır.
static func _pct_from(v: Variant, fallback: int) -> int:
	if (v is float or v is int) and is_finite(float(v)):
		return AudioMix.clamp_pct(float(v))
	return fallback


## Tek ses uygulama noktası: sound_on=false Master'ı susturur (hızlı sessize alma, yüzdelere dokunmaz);
## Music = müzik yüzdesi + AudioDirector payı; SFX ve UI = efekt yüzdesi. %0 kanalı susturur.
func apply_audio() -> void:
	_set_bus(&"Master", not sound_on, 0.0)
	_set_bus(&"Music", music_pct <= 0, AudioMix.bus_db(music_pct, music_extra_db))
	for bus in [&"SFX", &"UI"]:
		_set_bus(bus, sfx_pct <= 0, AudioMix.bus_db(sfx_pct))


static func _set_bus(bus: StringName, mute: bool, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, mute)
	if bus != &"Master":
		AudioServer.set_bus_volume_db(idx, db)


## `persist=false`: kaydırma sırasında yalnız sesi uygular; bırakılınca `persist=true` ile yazılır.
func set_music_pct(pct: int, persist: bool = true) -> void:
	music_pct = AudioMix.clamp_pct(pct)
	apply_audio()
	if persist:
		save_settings()
		Events.settings_changed.emit()


func set_sfx_pct(pct: int, persist: bool = true) -> void:
	sfx_pct = AudioMix.clamp_pct(pct)
	apply_audio()
	if persist:
		save_settings()
		Events.settings_changed.emit()


## AudioDirector: duraklatma/duck payı (dB, <= 0). Kullanıcı müzik seviyesinin üstüne eklenir.
func set_music_extra_db(db: float) -> void:
	music_extra_db = db
	apply_audio()


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
