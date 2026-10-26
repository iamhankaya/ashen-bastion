class_name AchievementStore
extends RefCounted
## Yerel başarım kaydı (`user://achievements.json`, v2; v1 okunur ve göçer). Autoload DEĞİL; yol kurucudan enjekte edilir (testte geçici yol).
## Kural bilmez, sinyal dinlemez. Bozuk/eksik dosya oyunu durdurmaz (Highscores ilkeleri); bilinmeyen kimlikler korunur.
## Şema ve kurallar: docs/plan/v2.0-plan.md "Kayıt dosyası".
## {"v":2,"unlocked":{"reaper":1761270000},"steps":{"reaper":[1761270000,1761280000]},"totals":{"kills":0,"runs":0,"wins":0,
##  "play_secs":0,"boss_kills":0},"best":{"score":0,"time":0,"level":0,...},"chars5":["gunslinger"]}
## `unlocked[aile]` = 1. kademenin tarihi (karakter kilidi/kısa yol); `steps[aile][k-1]` = (k+1). kademenin tarihi.

## Eski (göç edilen) sürüm; tanımsız yüklemede (`load_file()`) aynen bu biçimle yazılmaya devam eder.
const VERSION := 1
const VERSION_V2 := 2
## v1 -> v2 göçünden önce, ilk v2 yazımında bir kez alınan yedek (`<yol>.v1.bak`).
const BACKUP_SUFFIX := ".v1.bak"
const DEFAULT_PATH := "user://achievements.json"
const MAX_UNLOCKED := 64
const MAX_CHARS5 := 16
const COUNTER_CAP := 999999999
const TOTAL_KEYS: PackedStringArray = ["kills", "runs", "wins", "play_secs", "boss_kills"]
const BEST_KEYS: PackedStringArray = [
	"score",
	"time",
	"level",
	"kills",
	"reloads",
	"active_slots",
	"mult",
	"elite_kinds",
	"pickups",
	"clean_secs",
	"evolutions",
	"unlimited_kills",
	"bomb_hits",
]

var path: String = DEFAULT_PATH
## StringName -> unix (yalnız UI/serileştirme; sim'de kullanılmaz).
var unlocked: Dictionary = {}
## StringName -> Array[int] (kademe başına unix; uzunluk = açılan kademe sayısı).
var steps: Dictionary = {}
var totals: Dictionary = {}
var best: Dictionary = {}
var chars5: PackedStringArray = PackedStringArray()
var corrupt: bool = false
var dirty: bool = false
## v1 dosyası göçsüz (tanımsız) yüklendi: kayıt v1 biçiminde yazılır, eşleme kaybolmaz.
var _v1_layout: bool = false
## v1 dosyası göçtü: ilk v2 yazımından önce `<yol>.v1.bak` alınır.
var _backup_pending: bool = false


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	_reset()


## false = dosya yok/bozuk (durum sıfırlanır). Bozuk dosya `<yol>.bad` olarak saklanır; yarım `.tmp` hiç okunmaz.
## `defs` (GameData.achievements) doluysa v1 dosyası aile/kademe kaydına göçer (bellekte; ilk `save()` yedekli yazar).
func load_file(defs: Array = []) -> bool:
	_reset()
	var r := StoreIo.read_versioned_any(path, PackedInt32Array([VERSION, VERSION_V2]))
	corrupt = bool(r["corrupt"])
	if not bool(r["ok"]):
		return false
	var clean := sanitize(r["data"])
	if int(r["version"]) == VERSION:
		if not _has_families(defs):
			_v1_layout = true
		else:
			clean = AchievementMigration.migrate(clean, defs)
			_backup_pending = true
			dirty = true
	unlocked = clean["unlocked"]
	steps = clean["steps"]
	totals = clean["totals"]
	best = clean["best"]
	chars5 = clean["chars5"]
	return true


## Başarıda dirty=false; başarısızlıkta dirty true KALIR (sonraki flush yeniden dener).
func save() -> bool:
	if _backup_pending and not _write_backup():
		return false
	if not StoreIo.write_atomic(path, JSON.stringify(to_raw())):
		return false
	_backup_pending = false
	dirty = false
	return true


## Dosya sözlüğü (anahtarlar metin; `unlocked`/`steps` kimliğe göre sıralı). `_v1_layout` iken v1 biçimi.
func to_raw() -> Dictionary:
	var out := {"v": VERSION if _v1_layout else VERSION_V2}
	out["unlocked"] = _raw_unlocked(unlocked)
	if not _v1_layout:
		var sd := {}
		var ids: Array = steps.keys()
		ids.sort()
		for id in ids:
			sd[String(id)] = (steps[id] as Array).duplicate()
		out["steps"] = sd
	out["totals"] = totals
	out["best"] = best
	out["chars5"] = Array(chars5)
	return out


## Göçten önceki v1 dosyasını bir kez yedekler; yedek zaten varsa dokunmaz. false = yedek alınamadı (kayıt yazılmaz).
func _write_backup() -> bool:
	var bak := path + BACKUP_SUFFIX
	if FileAccess.file_exists(bak) or not FileAccess.file_exists(path):
		return true
	return DirAccess.copy_absolute(path, bak) == OK


static func _has_families(defs: Array) -> bool:
	for d: AchievementDef in defs:
		if not d.steps.is_empty():
			return true
	return false


static func _raw_unlocked(src: Dictionary) -> Dictionary:
	var ids: Array = src.keys()
	ids.sort()
	var un := {}
	for id in ids:
		un[String(id)] = int(src[id])
	return un


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


## 0 = kilitli. Ailede 1. kademenin tarihi.
func unlocked_at(id: StringName) -> int:
	return int(unlocked.get(id, 0))


## Açılan kademe sayısı (v2.0 tek eşikli kayıt: açıksa 1).
func step_count(id: StringName) -> int:
	return maxi((steps.get(id, []) as Array).size(), 1 if unlocked.has(id) else 0)


## k. kademenin tarihi (1..step_count); 0 = açılmamış.
func step_unix(id: StringName, k: int) -> int:
	var arr: Array = steps.get(id, [])
	if k < 1 or k > step_count(id):
		return 0
	return int(arr[k - 1]) if k <= arr.size() else unlocked_at(id)


## `k` kademeye kadar açar (alt kademeler aynı tarihi alır). false: k <= mevcut, unix < 1, k > MAX_STEPS ya da
## yeni aile için MAX_UNLOCKED dolu. Kademe asla geri alınmaz.
func unlock_step(id: StringName, k: int, unix: int) -> bool:
	if unix < 1 or k < 1 or k > AchievementDef.MAX_STEPS or k <= step_count(id):
		return false
	if not unlocked.has(id) and unlocked.size() >= MAX_UNLOCKED:
		return false
	var arr: Array = (steps.get(id, []) as Array).duplicate()
	if arr.is_empty() and unlocked.has(id):
		arr.append(int(unlocked[id]))  # v2.0 tek eşikli kayıttan gelen 1. kademe
	while arr.size() < k:
		arr.append(unix)
	if k >= 2 or steps.has(id):  # 1. kademenin tarihi zaten `unlocked`ta
		steps[id] = arr
	if not unlocked.has(id):
		unlocked[id] = int(arr[0])
	dirty = true
	return true


## false: zaten açık (ilk unix korunur), unix < 1 ya da MAX_UNLOCKED dolu.
func unlock(id: StringName, unix: int) -> bool:
	if unix < 1 or unlocked.has(id) or unlocked.size() >= MAX_UNLOCKED:
		return false
	unlocked[id] = unix
	dirty = true
	return true


## COUNTER_CAP'e kırpar; dirty.
func add_total(key: StringName, n: int = 1) -> void:
	var k := String(key)
	if n <= 0 or not totals.has(k):
		return
	totals[k] = mini(int(totals[k]) + n, COUNTER_CAP)
	dirty = true


## Alan başına max.
func note_best(score: int, time: int, level: int) -> void:
	note_best_key(&"score", score)
	note_best_key(&"time", time)
	note_best_key(&"level", level)


## Tek `best` alanı için max; bilinmeyen anahtar yok sayılır.
func note_best_key(key: StringName, value: int) -> void:
	var k := String(key)
	if not best.has(k):
		return
	var v := mini(value, COUNTER_CAP)
	if v > int(best[k]):
		best[k] = v
		dirty = true


## true = yeni eklendi (tekil, en çok MAX_CHARS5).
func note_char5(char_id: StringName) -> bool:
	var c := String(char_id)
	if not _valid_id(c, 32) or chars5.has(c) or chars5.size() >= MAX_CHARS5:
		return false
	chars5.append(c)
	dirty = true
	return true


## Tanımda olanlardan açılan sayısı.
func count_unlocked(known: Array[StringName]) -> int:
	var n := 0
	for id in known:
		if unlocked.has(id):
			n += 1
	return n


## Tanımlardaki toplam açık kademe (aile başına `total` ile sınırlı).
func count_steps(defs: Array) -> int:
	var n := 0
	for d in defs:
		n += mini(step_count(d.id), AchievementStep.total(d))
	return n


## {"unlocked","steps","totals","best","chars5"} temiz kopya; kök geçersizse {}. `unlocked` anahtarları SIRALI işlenir (ilk 64).
static func sanitize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var un := _clean_unlocked(d.get("unlocked", null))
	var st := _clean_steps(d.get("steps", null))
	for id in st:  # kademesi olan aile açık sayılır (tarih = 1. kademe)
		if not un.has(id) and un.size() < MAX_UNLOCKED:
			un[id] = (st[id] as Array)[0]
	return {
		"unlocked": un,
		"steps": st,
		"totals": _clean_counters(d.get("totals", null), TOTAL_KEYS),
		"best": _clean_counters(d.get("best", null), BEST_KEYS),
		"chars5": _clean_chars5(d.get("chars5", null)),
	}


static func _clean_unlocked(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	var keys: Array = []
	for k in (raw as Dictionary).keys():
		if k is String and _valid_id(k, 40):
			keys.append(k)
	keys.sort()
	for k in keys:
		if out.size() >= MAX_UNLOCKED:
			break
		var unix: Variant = StoreIo.int_of((raw as Dictionary)[k], false)
		if unix != null and int(unix) >= 1:
			out[StringName(k)] = int(unix)
	return out


## {kimlik: [unix, ...]}: geçerli kimlik, 1..MAX_STEPS elemanlı dizi; geçersiz unix atılır; en çok MAX_UNLOCKED aile (sıralı).
static func _clean_steps(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	var keys: Array = []
	for k in (raw as Dictionary).keys():
		if k is String and _valid_id(k, 40) and (raw as Dictionary)[k] is Array:
			keys.append(k)
	keys.sort()
	for k in keys:
		if out.size() >= MAX_UNLOCKED:
			break
		var arr: Array = []
		for v in (raw as Dictionary)[k]:
			var unix: Variant = StoreIo.int_of(v, false)
			if unix != null and int(unix) >= 1 and arr.size() < AchievementDef.MAX_STEPS:
				arr.append(int(unix))
		if not arr.is_empty():
			out[StringName(k)] = arr
	return out


static func _clean_counters(raw: Variant, keys: PackedStringArray) -> Dictionary:
	var out := {}
	for k in keys:
		out[k] = 0
	if not (raw is Dictionary):
		return out
	for k in keys:
		var n: Variant = StoreIo.int_of((raw as Dictionary).get(k, null), false)
		if n != null and int(n) >= 0:
			out[k] = mini(int(n), COUNTER_CAP)
	return out


static func _clean_chars5(raw: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not (raw is Array):
		return out
	for c in raw:
		if out.size() >= MAX_CHARS5:
			break
		if c is String and _valid_id(c, 32) and not out.has(c):
			out.append(c)
	return out


## [a-z0-9_]{1,max_len}
static func _valid_id(s: String, max_len: int) -> bool:
	if s.is_empty() or s.length() > max_len:
		return false
	for i in s.length():
		var c := s.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
		if not ok:
			return false
	return true


func _reset() -> void:
	unlocked = {}
	steps = {}
	totals = _zero_counters(TOTAL_KEYS)
	best = _zero_counters(BEST_KEYS)
	chars5 = PackedStringArray()
	corrupt = false
	dirty = false
	_v1_layout = false
	_backup_pending = false


static func _zero_counters(keys: PackedStringArray) -> Dictionary:
	var out := {}
	for k in keys:
		out[k] = 0
	return out


## v1 ham kaydını v2'ye çevirir (saf, idempotent, girdiyi değiştirmez; `defs` = `GameData.achievements`). Gövde:
## AchievementMigration. v2 (ya da sürümsüz değil, `v` >= 2) girdi aynen kopyalanır.
static func migrate_v1(raw: Dictionary, defs: Array) -> Dictionary:
	var v: Variant = raw.get("v", VERSION)
	if (v is int or v is float) and int(v) >= VERSION_V2:
		return raw.duplicate(true)
	var out := AchievementMigration.migrate(sanitize(raw), defs)
	var st := {}
	for id in out["steps"]:
		st[String(id)] = (out["steps"][id] as Array).duplicate()
	return {
		"v": VERSION_V2,
		"unlocked": _raw_unlocked(out["unlocked"]),
		"steps": st,
		"totals": out["totals"],
		"best": out["best"],
		"chars5": Array(out["chars5"]),
	}
