class_name StoreIo
extends RefCounted
## Sürümlü yerel kayıt dosyası G/Ç yardımcıları (v2.0). Başarım deposu kullanır; `Highscores`'a DOKUNULMAZ (H* testleri
## korunur). Başarım bilmez.

const MAX_BYTES := 262144
## Tamsayıya çevrilen kayan nokta değerleri için üst sınır (taşma/NaN koruması; Highscores.INT_LIMIT ile aynı).
const INT_LIMIT := 1.0e15


## {"ok": bool, "data": Variant, "corrupt": bool}. Dosya yok => ok=false, corrupt=false. Bozuk (ayrıştırma hatası,
## `v` != version, kök sözlük değil) => ok=false, corrupt=true ve içerik `<yol>.bad` (tek yedek, boş içerik saklanmaz).
## `MAX_BYTES`'tan büyük => ok=false, corrupt=true (.bad yazılmaz). `<yol>.tmp` hiç okunmaz.
static func read_versioned(path: String, version: int) -> Dictionary:
	return read_versioned_any(path, PackedInt32Array([version]))


## `read_versioned` ile aynı, ama `versions` içindeki her `v` kabul edilir (v2.0.3 kayıt göçü); sonuca `version` (okunan `v`) eklenir.
static func read_versioned_any(path: String, versions: PackedInt32Array) -> Dictionary:
	var out := {"ok": false, "data": null, "corrupt": false, "version": -1}
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	if f.get_length() > MAX_BYTES:
		f.close()
		out["corrupt"] = true
		return out
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) == OK and _valid_root(json.data, versions):
		out["ok"] = true
		out["data"] = json.data
		out["version"] = int(json.data["v"])
		return out
	out["corrupt"] = true
	_keep_bad(path, text)
	return out


## `<yol>.tmp`'ye yazar, sonra `DirAccess.rename_absolute`. Başarısızlıkta `.tmp` silinir, false; önceki dosya kalır.
static func write_atomic(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var wrote := f.store_string(text)
	f.close()
	if not wrote or DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(tmp)
		return false
	return true


## int ya da tamsayı değerli float -> int; diğer her şey null (bool, metin, NaN, inf, kesirli). clamp_big: ham değer
## `INT_LIMIT` üstündeyse (yalnız pozitif) `int(INT_LIMIT)`'e çekilir, değilse null. Highscores._int_of ile aynı kurallar.
static func int_of(v: Variant, clamp_big: bool) -> Variant:
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


static func _valid_root(data: Variant, versions: PackedInt32Array) -> bool:
	if not (data is Dictionary):
		return false
	var v: Variant = (data as Dictionary).get("v", null)
	return (v is int or v is float) and versions.has(int(v)) and float(v) == floorf(float(v))


## Bozuk dosyanın içeriğini tek yedek olarak saklar (önceki .bad üzerine yazılır). Boş içerik saklanmaz.
static func _keep_bad(path: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	var f := FileAccess.open(path + ".bad", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
