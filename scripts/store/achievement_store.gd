class_name AchievementStore
extends RefCounted
## Yerel başarım kaydı (`user://achievements.json`, v1). Autoload DEĞİL; yol kurucudan enjekte edilir (testte geçici yol).
## Kural bilmez, sinyal dinlemez. İSKELET (S2): alanlar/sabitler gerçek, gövdeler B1'de (şimdilik Stub.todo).
## Şema ve kurallar: docs/plan/v2.0-plan.md "Kayıt dosyası".
## {"v":1,"unlocked":{"ilk_kan":1761270000},"totals":{"kills":0,"runs":0,"wins":0,"play_secs":0},
##  "best":{"score":0,"time":0,"level":0},"chars5":["gunslinger"]}

const VERSION := 1
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


## false = dosya yok/bozuk (durum sıfırlanır).
func load_file() -> bool:
	Stub.todo(&"AchievementStore.load_file")
	return false


## Başarıda dirty=false; başarısızlıkta dirty true KALIR (sonraki flush yeniden dener).
func save() -> bool:
	Stub.todo(&"AchievementStore.save")
	return false


func is_unlocked(_id: StringName) -> bool:
	Stub.todo(&"AchievementStore.is_unlocked")
	return false


## 0 = kilitli.
func unlocked_at(_id: StringName) -> int:
	Stub.todo(&"AchievementStore.unlocked_at")
	return 0


## false: zaten açık (ilk unix korunur), unix < 1 ya da MAX_UNLOCKED dolu.
func unlock(_id: StringName, _unix: int) -> bool:
	Stub.todo(&"AchievementStore.unlock")
	return false


## COUNTER_CAP'e kırpar; dirty.
func add_total(_key: StringName, _n: int = 1) -> void:
	Stub.todo(&"AchievementStore.add_total")


## Alan başına max.
func note_best(_score: int, _time: int, _level: int) -> void:
	Stub.todo(&"AchievementStore.note_best")


## true = yeni eklendi (tekil, en çok MAX_CHARS5).
func note_char5(_char_id: StringName) -> bool:
	Stub.todo(&"AchievementStore.note_char5")
	return false


## Tanımda olanlardan açılan sayısı.
func count_unlocked(_known: Array[StringName]) -> int:
	Stub.todo(&"AchievementStore.count_unlocked")
	return 0


## {"unlocked","totals","best","chars5"} temiz kopya; kök geçersizse {}. `unlocked` anahtarları SIRALI işlenir (ilk 64).
static func sanitize(_raw: Variant) -> Dictionary:
	Stub.todo(&"AchievementStore.sanitize")
	return {}
