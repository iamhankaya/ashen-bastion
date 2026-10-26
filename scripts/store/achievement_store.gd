class_name AchievementStore
extends RefCounted
## Yerel başarım kaydı (`user://achievements.json`, v1). Autoload DEĞİL; yol kurucudan enjekte edilir (testte geçici yol).
## Kural bilmez, sinyal dinlemez. Bozuk/eksik dosya oyunu durdurmaz (Highscores ilkeleri); bilinmeyen kimlikler korunur.
## Şema ve kurallar: docs/plan/v2.0-plan.md "Kayıt dosyası".
## {"v":1,"unlocked":{"ilk_kan":1761270000},"totals":{"kills":0,"runs":0,"wins":0,"play_secs":0},
##  "best":{"score":0,"time":0,"level":0},"chars5":["gunslinger"]}

const VERSION := 1
## v2.0.3: `v2` biçimi (aile/kademe `steps`) C fazında yazılır; o zamana dek okuma/yazma `VERSION` ile sürer.
const VERSION_V2 := 2
## v1 -> v2 göçünden önce, ilk v2 yazımında bir kez alınan yedek (`<yol>.v1.bak`).
const BACKUP_SUFFIX := ".v1.bak"
const DEFAULT_PATH := "user://achievements.json"
const MAX_UNLOCKED := 64
const MAX_CHARS5 := 16
const COUNTER_CAP := 999999999
const TOTAL_KEYS: PackedStringArray = ["kills", "runs", "wins", "play_secs"]
const BEST_KEYS: PackedStringArray = ["score", "time", "level"]

var path: String = DEFAULT_PATH
## StringName -> unix (yalnız UI/serileştirme; sim'de kullanılmaz).
var unlocked: Dictionary = {}
var totals: Dictionary = {"kills": 0, "runs": 0, "wins": 0, "play_secs": 0}
var best: Dictionary = {"score": 0, "time": 0, "level": 0}
var chars5: PackedStringArray = PackedStringArray()
var corrupt: bool = false
var dirty: bool = false


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


## false = dosya yok/bozuk (durum sıfırlanır). Bozuk dosya `<yol>.bad` olarak saklanır; yarım `.tmp` hiç okunmaz.
func load_file() -> bool:
	_reset()
	var r := StoreIo.read_versioned(path, VERSION)
	corrupt = bool(r["corrupt"])
	if not bool(r["ok"]):
		return false
	var clean := sanitize(r["data"])
	unlocked = clean["unlocked"]
	totals = clean["totals"]
	best = clean["best"]
	chars5 = clean["chars5"]
	return true


## Başarıda dirty=false; başarısızlıkta dirty true KALIR (sonraki flush yeniden dener).
func save() -> bool:
	var ids: Array = unlocked.keys()
	ids.sort()
	var un := {}
	for id in ids:
		un[String(id)] = int(unlocked[id])
	var text := JSON.stringify(
		{"v": VERSION, "unlocked": un, "totals": totals, "best": best, "chars5": Array(chars5)}
	)
	if not StoreIo.write_atomic(path, text):
		return false
	dirty = false
	return true


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


## 0 = kilitli.
func unlocked_at(id: StringName) -> int:
	return int(unlocked.get(id, 0))


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
	var vals := {"score": score, "time": time, "level": level}
	for k in BEST_KEYS:
		var v := mini(int(vals[k]), COUNTER_CAP)
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


## {"unlocked","totals","best","chars5"} temiz kopya; kök geçersizse {}. `unlocked` anahtarları SIRALI işlenir (ilk 64).
static func sanitize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	return {
		"unlocked": _clean_unlocked(d.get("unlocked", null)),
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
	totals = {"kills": 0, "runs": 0, "wins": 0, "play_secs": 0}
	best = {"score": 0, "time": 0, "level": 0}
	chars5 = PackedStringArray()
	corrupt = false
	dirty = false


## v1 ham kaydını v2'ye çevirir (saf, idempotent, girdiyi değiştirmez; `defs` = `GameData.achievements`).
## SÖZLEŞME TASLAĞI: gövdesini C fazı doldurur (docs/data-schema.md "Kayıt göçü"); imza değişmez.
static func migrate_v1(raw: Dictionary, _defs: Array) -> Dictionary:
	return raw.duplicate(true)
