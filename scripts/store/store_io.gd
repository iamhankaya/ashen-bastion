class_name StoreIo
extends RefCounted
## Sürümlü yerel kayıt dosyası G/Ç yardımcıları (v2.0). Başarım deposu kullanır; `Highscores`'a DOKUNULMAZ (H* testleri
## korunur). Başarım bilmez. İSKELET (S2): `int_of` ve sabitler gerçek; gövdeler B1'de (şimdilik Stub.todo).

const MAX_BYTES := 262144
## Tamsayıya çevrilen kayan nokta değerleri için üst sınır (taşma/NaN koruması; Highscores.INT_LIMIT ile aynı).
const INT_LIMIT := 1.0e15


## {"ok": bool, "data": Variant, "corrupt": bool}. Dosya yok => ok=false, corrupt=false. Bozuk (ayrıştırma hatası,
## `v` != version, kök sözlük değil) => ok=false, corrupt=true ve içerik `<yol>.bad` (tek yedek, boş içerik saklanmaz).
## `MAX_BYTES`'tan büyük => ok=false, corrupt=true (.bad yazılmaz). `<yol>.tmp` hiç okunmaz.
static func read_versioned(_path: String, _version: int) -> Dictionary:
	Stub.todo(&"StoreIo.read_versioned")
	return {"ok": false, "data": null, "corrupt": false}


## `<yol>.tmp`'ye yazar, sonra `DirAccess.rename_absolute`. Başarısızlıkta `.tmp` silinir, false; önceki dosya kalır.
static func write_atomic(_path: String, _text: String) -> bool:
	Stub.todo(&"StoreIo.write_atomic")
	return false


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
