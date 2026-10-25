class_name SliceFile
extends RefCounted
## Dilim işareti dosyalarının TEK ayrıştırıcısı (tools/v2_slices.txt, tools/v11_slices.txt). V11Slice ve V2Slice bunu
## çağırır. Kurallar tools/ci/check_slices.py ile aynıdır; ikisi de tools/ci/tests/slice_cases.json vaka tablosunu okur.
## Biçim: '#' ile başlayan satırlar yorum; kalanlar boşluk/sekmeyle bölünür; yinelenen simge bir kez; `valid` doluysa
## listede olmayan simge hatadır (satır sonu yorumu '#' simgesi sayılır => hata). Hata varsa marks boştur.
## V2_SLICES_FORCE ortam değişkeni (boşluk/virgül ayraçlı) işareti zorlar (tur fazı: işaretsiz dilimi gerçek kodda koşmak).

const FORCE_ENV := "V2_SLICES_FORCE"


## {"ok": bool, "marks": PackedStringArray, "errors": PackedStringArray}
static func parse(text: String, valid: PackedStringArray = PackedStringArray()) -> Dictionary:
	var marks := PackedStringArray()
	var errors := PackedStringArray()
	var n := 0
	for line in text.split("\n"):
		n += 1
		var s := line.strip_edges()
		if s.is_empty() or s.begins_with("#"):
			continue
		for tok in s.split(" ", false):
			for t in tok.split("\t", false):
				if not valid.is_empty() and not valid.has(t):
					errors.append("satır %d: geçersiz simge '%s'" % [n, t])
				elif not marks.has(t):
					marks.append(t)
	return {
		"ok": errors.is_empty(),
		"marks": marks if errors.is_empty() else PackedStringArray(),
		"errors": errors
	}


## Dosya yoksa ok=false (hata: "dosya yok"); aksi halde parse.
static func read(path: String, valid: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"marks": PackedStringArray(),
			"errors": PackedStringArray(["dosya yok: " + path])
		}
	return parse(FileAccess.get_file_as_string(path), valid)


## Zorlama değişkenindeki simgeler (boş olabilir). Varsayılan V2_SLICES_FORCE; v2.0.2 V202_SLICES_FORCE geçirir.
static func forced(env_name: String = FORCE_ENV) -> PackedStringArray:
	var out := PackedStringArray()
	var raw := OS.get_environment(env_name).replace(",", " ")
	for tok in raw.split(" ", false):
		var t := tok.strip_edges()
		if not t.is_empty() and not out.has(t):
			out.append(t)
	return out
