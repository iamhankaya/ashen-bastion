class_name Highscores
extends RefCounted
## Yerel en iyi 10 (`user://highscores.json`). Autoload DEĞİL; yol enjekte edilebilir. İçerik güvenilmez sayılır (sanitize).
## Şema: {"v":1,"entries":[{"score":int,"time":int,"won":bool,"level":int,"unix":int}]}. Sıralama: skor azalan, eşitlikte
## `unix` küçük (eski) önde, o da eşitse ekleme sırası. Yazma: .tmp + rename. Kurallar: docs/plan/v1.1-plan.md §D.
## Bozuk/eksik/yarım dosya oyunu durdurmaz: liste boş açılır, bozuk dosya `.bad` olarak saklanır, sonraki `save` onarır.

const VERSION := 1
const MAX_ENTRIES := 10
const DEFAULT_PATH := "user://highscores.json"
## Skor tavanı (ScoreTable.display_cap ile aynı varsayılan); dosyadaki aşırı değerler buna kırpılır.
const SCORE_CAP := 99999999
## Tamsayıya çevrilen kayan nokta değerleri için üst sınır (taşma/NaN koruması).
const INT_LIMIT := 1.0e15

var entries: Array[Dictionary] = []
## Son load_file() bozuk dosya buldu mu (.bad olarak saklandı).
var corrupt: bool = false

var _path: String = DEFAULT_PATH


func _init(p_path: String = DEFAULT_PATH) -> void:
	_path = p_path


## false = dosya yok/bozuk (entries boş). Bozuk dosya `<yol>.bad` olarak saklanır; yarım `.tmp` hiç okunmaz.
func load_file() -> bool:
	entries = []
	corrupt = false
	if not FileAccess.file_exists(_path):
		return false
	var text := FileAccess.get_file_as_string(_path)
	var json := JSON.new()
	var ok := json.parse(text) == OK and _valid_root(json.data)
	if not ok:
		corrupt = true
		_keep_bad(text)
		return false
	entries = sanitize(json.data)
	return true


## {"rank": int (0 = dışarıda), "is_record": bool, "previous_best": int, "needed_for_top10": int, "index": int}
func submit(entry: Dictionary) -> Dictionary:
	var result := {
		"rank": 0, "is_record": false, "previous_best": 0, "needed_for_top10": 0, "index": -1
	}
	if not entries.is_empty():
		result["previous_best"] = int(entries[0]["score"])
	if entries.size() >= MAX_ENTRIES:
		result["needed_for_top10"] = int(entries[MAX_ENTRIES - 1]["score"])
	var e := _normalize(entry, false)
	if e.is_empty():
		return result
	var pos := _insert_pos(entries, e)
	if pos >= MAX_ENTRIES:
		return result
	entries.insert(pos, e)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	result["rank"] = pos + 1
	result["index"] = pos
	result["is_record"] = pos == 0
	return result


## .tmp'ye yaz, sonra rename: yarım yazma ana dosyayı bozmaz. Başarısızlık oyunu durdurmaz (false).
func save() -> bool:
	var tmp := _path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var wrote := f.store_string(JSON.stringify({"v": VERSION, "entries": entries}))
	f.close()
	# Yazma ya da rename başarısızsa önceki geçerli dosya olduğu gibi kalır (silip yeniden denemek yok).
	if not wrote or DirAccess.rename_absolute(tmp, _path) != OK:
		DirAccess.remove_absolute(tmp)
		return false
	return true


## Ham veriyi (tüm dosya sözlüğü ya da yalnız `entries` dizisi) temiz, sıralı, en çok 10 girişe indirir.
## Geçersiz girişler tek tek atılır; sıralama kararlıdır (eşitte önce gelen önde).
static func sanitize(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Variant = raw
	if raw is Dictionary:
		list = (raw as Dictionary).get("entries", null)
	if not (list is Array):
		return out
	for item in list:
		var e := _normalize(item, true)
		if e.is_empty():
			continue
		var pos := _insert_pos(out, e)
		if pos < MAX_ENTRIES:
			out.insert(pos, e)
			if out.size() > MAX_ENTRIES:
				out.resize(MAX_ENTRIES)
	return out


## Skor azalan, eşitlikte unix artan (kesin; tam eşitlik false: kararlılık için sıra korunur).
static func better(a: Dictionary, b: Dictionary) -> bool:
	var sa := int(a.get("score", 0))
	var sb := int(b.get("score", 0))
	if sa != sb:
		return sa > sb
	return int(a.get("unix", 0)) < int(b.get("unix", 0))


## Yerel saat = UTC + tz_bias_min; "GG.AA.YYYY".
static func format_date(unix: int, tz_bias_min: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + tz_bias_min * 60)
	return "%02d.%02d.%04d" % [d["day"], d["month"], d["year"]]


static func _valid_root(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var v: Variant = (data as Dictionary).get("v", null)
	if not (v is int or v is float) or float(v) != float(VERSION):
		return false
	return (data as Dictionary).get("entries", null) is Array


## Yeni girişin ekleneceği indeks: kendinden kesin kötü olan ilk girişin önü (eşitler önde kalır).
static func _insert_pos(list: Array[Dictionary], e: Dictionary) -> int:
	for i in list.size():
		if better(e, list[i]):
			return i
	return list.size()


## Tam sayı alanlara dönüştürür; geçersizse {} döner. strict=false: eksik alanlar varsayılanla doldurulur (submit).
## score <= 0 hiçbir yolda kabul edilmez.
static func _normalize(raw: Variant, strict: bool) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var score: Variant = _int_of(d.get("score", null), true)
	if score == null or int(score) <= 0:
		return {}
	var out := {"score": mini(int(score), SCORE_CAP)}
	for k in ["time", "level", "unix"]:
		var v: Variant = d.get(k, null)
		if v == null and not strict:
			out[k] = 0
			continue
		var n: Variant = _int_of(v, false)
		if n == null or int(n) < 0:
			return {}
		out[k] = int(n)
	var won: Variant = d.get("won", null)
	if won == null and not strict:
		won = false
	if not (won is bool):
		return {}
	out["won"] = won
	return {
		"score": out["score"],
		"time": out["time"],
		"won": out["won"],
		"level": out["level"],
		"unix": out["unix"],
	}


## int ya da tamsayı değerli float -> int; diğer her şey null. clamp_big: devasa değerler sınıra çekilir (skor).
static func _int_of(v: Variant, clamp_big: bool) -> Variant:
	if v is int:
		return v
	if v is float:
		var f: float = v
		if is_nan(f) or is_inf(f) or f != floorf(f):
			return null
		if absf(f) > INT_LIMIT:
			return int(INT_LIMIT) if (clamp_big and f > 0.0) else null
		return int(f)
	return null


## Bozuk dosyanın içeriğini tek yedek olarak saklar (önceki .bad üzerine yazılır). Boş içerik saklanmaz.
func _keep_bad(text: String) -> void:
	if text.strip_edges() == "":
		return
	var f := FileAccess.open(_path + ".bad", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
