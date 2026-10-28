class_name Highscores
extends RefCounted
## Yerel en iyi 10 (`user://highscores.json`). Autoload DEĞİL; yol enjekte edilebilir. İçerik güvenilmez sayılır (sanitize).
## Şema (v2.1): {"v":2,"lists":{"<mod>:<zorluk>":[{"score","time","won","level","unix","mode","diff"}]}}; liste anahtarı otoritedir
## (giriş mode/diff'i anahtara göre yeniden yazılır), bilinmeyen anahtarlı listeler silinmeden saklanır. v1 ({"v":1,"entries":[]})
## `normal:normal`'a göçer: önce `.v1.bak` yedeği, sonra v2 yazımı (docs/data-schema.md, K-C6). Sıralama: skor azalan, eşitlikte
## `unix` küçük (eski) önde, o da eşitse ekleme sırası. Yazma: .tmp + rename. Kurallar: docs/plan/v1.1-plan.md §D.
## Bozuk/eksik/yarım dosya oyunu durdurmaz: liste boş açılır, bozuk dosya `.bad` olarak saklanır, sonraki `save` onarır.

const VERSION := 2
const V1 := 1
const MAX_ENTRIES := 10
const DEFAULT_PATH := "user://highscores.json"
const DEFAULT_KEY := "normal:normal"
## Skor tavanı (ScoreTable.display_cap ile aynı varsayılan); dosyadaki aşırı değerler buna kırpılır.
const SCORE_CAP := 99999999
## Tamsayıya çevrilen kayan nokta değerleri için üst sınır (taşma/NaN koruması).
const INT_LIMIT := 1.0e15

## v2.1: normal:normal listesinin görünümü (eski çağıranlar/testler için; `_lists["normal:normal"]` ile AYNI dizi).
var entries: Array[Dictionary] = []
## v2.1: "<mod>:<zorluk>" -> en iyi 10 listesi (giriş alanları mode/diff içermez; yazarken anahtardan eklenir).
var _lists: Dictionary = {}
## Bilinmeyen anahtarlı listeler (ileri uyumluluk): ham değer, gösterilmez, `save` aynen geri yazar.
var _unknown: Dictionary = {}
## v1 yedeği alınamadı: göç iptal, v1 dosyası dokunulmaz, `save` v2 yazmaz (K-C6 2).
var _write_blocked: bool = false
## Son load_file() bozuk dosya buldu mu (.bad olarak saklandı).
var corrupt: bool = false

var _path: String = DEFAULT_PATH


func _init(p_path: String = DEFAULT_PATH) -> void:
	_path = p_path
	_lists[DEFAULT_KEY] = entries


## Liste anahtarı: "<mod>:<zorluk>" (örn. "normal:hard").
static func key_of(mode: StringName, diff: StringName) -> String:
	return "%s:%s" % [mode, diff]


## (mod, zorluk) listesi (sıralı, en çok 10). Bilinmeyen/boş çift için boş dizi; dönen dizi değiştirilmemeli.
func list_for(mode: StringName, diff: StringName) -> Array[Dictionary]:
	var list: Variant = _lists.get(key_of(mode, diff), null)
	var out: Array[Dictionary] = []
	if list is Array:
		out.assign(list)
	return out


## false = dosya yok/bozuk (entries boş). Bozuk dosya `<yol>.bad` olarak saklanır; yarım `.tmp` hiç okunmaz.
## v1 dosyası `normal:normal`'a göçer (`.v1.bak` yedeği + v2 yazımı); yedek alınamazsa v1 dokunulmaz, oturum bellekte sürer.
func load_file() -> bool:
	entries = []
	_lists = {DEFAULT_KEY: entries}
	_unknown = {}
	_write_blocked = false
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
	var root: Dictionary = json.data
	if int(root["v"]) == V1:
		_lists[DEFAULT_KEY] = sanitize(root)
		_migrate_v1(text)
	else:
		_load_lists(root["lists"])
	entries = _lists[DEFAULT_KEY]
	return true


## {"rank": int (0 = dışarıda), "is_record": bool, "previous_best": int, "needed_for_top10": int, "index": int}.
## v2.1: `entry` "mode"/"diff" (RunProfiles adları) taşır; eksik olan eski çağıranlar için "normal" sayılır (ikisi de yoksa normal:normal)
## (controller her zaman verir: test_v21_contract_flow). Bilinmeyen/dizge olmayan değer: yazılmaz, sonuca "error" ("mode_diff_unknown").
func submit(entry: Dictionary) -> Dictionary:
	var result := {
		"rank": 0, "is_record": false, "previous_best": 0, "needed_for_top10": 0, "index": -1
	}
	var mode: Variant = entry.get("mode", "normal")
	var diff: Variant = entry.get("diff", "normal")
	if not (
		mode is String
		and diff is String
		and RunProfiles.MODES.has(mode)
		and RunProfiles.DIFFS.has(diff)
	):
		result["error"] = "mode_diff_unknown"
		return result
	var key := key_of(StringName(mode), StringName(diff))
	if not _lists.has(key):
		_lists[key] = [] as Array[Dictionary]
	var list: Array[Dictionary] = _lists[key]
	if not list.is_empty():
		result["previous_best"] = int(list[0]["score"])
	if list.size() >= MAX_ENTRIES:
		result["needed_for_top10"] = int(list[MAX_ENTRIES - 1]["score"])
	var e := _normalize(entry, false)
	if e.is_empty():
		return result
	var pos := _insert_pos(list, e)
	if pos >= MAX_ENTRIES:
		return result
	list.insert(pos, e)
	if list.size() > MAX_ENTRIES:
		list.resize(MAX_ENTRIES)
	result["rank"] = pos + 1
	result["index"] = pos
	result["is_record"] = pos == 0
	return result


## .tmp'ye yaz, sonra rename: yarım yazma ana dosyayı bozmaz. Başarısızlık oyunu durdurmaz (false).
## Göç iptal edildiyse (v1 yedeği yok) v2 yazılmaz: v1 dosyası olduğu gibi kalır.
func save() -> bool:
	if _write_blocked:
		return false
	var lists := {}
	for key: String in _lists:
		var list: Array = _lists[key]
		if not list.is_empty():
			lists[key] = _with_names(key, list)
	lists.merge(_unknown)
	# Yazma ya da rename başarısızsa önceki geçerli dosya olduğu gibi kalır (silip yeniden denemek yok).
	return StoreIo.write_atomic(_path, JSON.stringify({"v": VERSION, "lists": lists}))


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
	var d: Dictionary = data
	var v: Variant = d.get("v", null)
	if not (v is int or v is float) or float(v) != floorf(float(v)):
		return false
	if int(v) == V1:
		return d.get("entries", null) is Array
	return int(v) == VERSION and d.get("lists", null) is Dictionary


## Bilinen ("mod:zorluk") anahtarın listesi mi: {"mode","diff"} ya da boş sözlük.
static func _split_key(key: String) -> Dictionary:
	var parts := key.split(":")
	if parts.size() == 2 and RunProfiles.MODES.has(parts[0]) and RunProfiles.DIFFS.has(parts[1]):
		return {"mode": parts[0], "diff": parts[1]}
	return {}


## Anahtar otoritedir: girişlerdeki mode/diff anahtardan yazılır.
static func _with_names(key: String, list: Array) -> Array:
	var names := _split_key(key)
	var out: Array = []
	for e: Dictionary in list:
		out.append(e.merged(names))
	return out


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


## v2 `lists`: bilinen anahtarlar temizlenir (dizi değilse boş), bilinmeyenler ham saklanır.
func _load_lists(raw: Dictionary) -> void:
	for key: String in raw:
		if _split_key(key).is_empty():
			_unknown[key] = raw[key]
		else:
			_lists[key] = sanitize(raw[key])


## v1 baytlarını `.v1.bak`'a (varsa `.v1.<unix>[-n].bak`'a, mevcut yedeğin üzerine yazmadan) atomik yazar, sonra v2'yi yazar.
## Yedek yoksa göç iptal. v2 yazımı başarısızsa v1 dosyası sağlam kalır, göç sonraki açılışta yeniden denenir.
func _migrate_v1(v1_text: String) -> void:
	var bak := _path + ".v1.bak"
	if FileAccess.file_exists(bak) and FileAccess.get_file_as_string(bak) == v1_text:
		save()  # aynı v1 için yedek zaten var (önceki yarım göç): yeni kopya birikmez
		return
	if FileAccess.file_exists(bak):
		var stamp := int(Time.get_unix_time_from_system())
		bak = "%s.v1.%d.bak" % [_path, stamp]
		var n := 0
		while FileAccess.file_exists(bak):
			n += 1
			bak = "%s.v1.%d-%d.bak" % [_path, stamp, n]
	if not StoreIo.write_atomic(bak, v1_text):
		_write_blocked = true
		return
	save()


## Bozuk dosyanın içeriğini tek yedek olarak saklar (önceki .bad üzerine yazılır). Boş içerik saklanmaz.
func _keep_bad(text: String) -> void:
	if text.strip_edges() == "":
		return
	var f := FileAccess.open(_path + ".bad", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
