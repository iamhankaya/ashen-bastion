class_name Highscores
extends RefCounted
## Yerel en iyi 10 (`user://highscores.json`). Autoload DEĞİL; yol enjekte edilebilir. İçerik güvenilmez sayılır (sanitize).
## Şema: {"v":1,"entries":[{"score":int,"time":int,"won":bool,"level":int,"unix":int}]}. Sıralama: skor azalan, eşitlikte
## `unix` küçük (eski) önde, o da eşitse ekleme sırası. Yazma: .tmp + rename. Kurallar: docs/plan/v1.1-plan.md §D.
## İskelet (S3): sabitler, alanlar ve yol gerçek; gövdeler D3-2'de dolar.

const VERSION := 1
const MAX_ENTRIES := 10
const DEFAULT_PATH := "user://highscores.json"

var entries: Array[Dictionary] = []
## Son load_file() bozuk dosya buldu mu (.bad olarak saklandı).
var corrupt: bool = false

var _path: String = DEFAULT_PATH


func _init(p_path: String = DEFAULT_PATH) -> void:
	_path = p_path


@warning_ignore_start("unused_parameter")


## false = dosya yok/bozuk (entries boş).
func load_file() -> bool:
	Stub.todo(&"Highscores.load_file")
	return false


## {"rank": int (0 = dışarıda), "is_record": bool, "previous_best": int, "needed_for_top10": int, "index": int}
func submit(entry: Dictionary) -> Dictionary:
	Stub.todo(&"Highscores.submit")
	return {"rank": 0, "is_record": false, "previous_best": 0, "needed_for_top10": 0, "index": -1}


func save() -> bool:
	Stub.todo(&"Highscores.save")
	return false


static func sanitize(raw: Variant) -> Array[Dictionary]:
	Stub.todo(&"Highscores.sanitize")
	return []


## Skor azalan, eşitlikte unix artan.
static func better(a: Dictionary, b: Dictionary) -> bool:
	Stub.todo(&"Highscores.better")
	return false


## Yerel saat = UTC + tz_bias_min; "GG.AA.YYYY".
static func format_date(unix: int, tz_bias_min: int) -> String:
	Stub.todo(&"Highscores.format_date")
	return ""
