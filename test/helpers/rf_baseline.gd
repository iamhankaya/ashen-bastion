class_name RfBaseline
extends RefCounted
## Karakterizasyon bazı (T20261028-35): test/characterization/baseline/<ad>.json ile karşılaştırır.
## Baz dosyası yoksa test başarısız değil pending olur; değer pending mesajında (JUnit'e girer) tek satırdır:
##   CHAR_BASELINE <ad> <tek satır JSON>
## Bazı yalnız tester fazı üretir (tools/ci/baseline_changes.txt gerekçesiyle); refactor dilimleri değiştirmez.

const DIR := "res://test/characterization/baseline/"


## Değeri JSON üzerinden kanonik metne çevirir (anahtarlar sıralı; sayı türü JSON turundan sonra eşitlenir).
static func canon(v: Variant) -> String:
	var parsed: Variant = JSON.parse_string(JSON.stringify(v, "", true))
	return JSON.stringify(parsed, "", true)


static func check(t: GutTest, name: String, actual: Variant) -> void:
	var path := DIR + name + ".json"
	var line := canon(actual)
	if not FileAccess.file_exists(path):
		# Kapı GUT günlüğünün yalnız son 30 satırını gösterir; değer JUnit'e pending mesajı olarak girer
		# (tools/ci/rf_extract_baselines.py gut-junit-N artifact'larından ayıklar).
		t.pending("CHAR_BASELINE %s %s" % [name, line])
		return
	var expected := canon(JSON.parse_string(FileAccess.get_file_as_string(path)))
	t.assert_eq(line, expected, "karakterizasyon bazı: " + name)


## Yerleşim bazı (rf_ui_*_rects): yol|sınıf|x,y,w,h satırlarını karşılaştırır. Metin ölçüsüne bağlı yatay boyut
## platformlar arası (font rasterleştirici: Linux/Mac/Windows) birkaç piksel oynar; bu yüzden x ve genişlik
## X_TOL_PX içinde eşit sayılır. Yol, sınıf, y ve yükseklik (satır sarma/dikey akış) AYNEN eşit olmalıdır.
const X_TOL_PX := 8.0


static func check_rects(t: GutTest, name: String, actual: Variant) -> void:
	var path := DIR + name + ".json"
	var line := canon(actual)
	if not FileAccess.file_exists(path):
		t.pending("CHAR_BASELINE %s %s" % [name, line])
		return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var why := _rects_diff(JSON.parse_string(line), expected, "")
	t.assert_eq(
		why, "", "karakterizasyon bazı (yerleşim, x/genişlik ±%s px): %s" % [X_TOL_PX, name]
	)


static func _rects_diff(a: Variant, e: Variant, at: String) -> String:
	if a is Dictionary and e is Dictionary:
		if a.keys().size() != e.keys().size():
			return "%s: anahtar sayısı %d != %d" % [at, a.keys().size(), e.keys().size()]
		for k in e:
			if not a.has(k):
				return "%s: anahtar yok %s" % [at, k]
			var d := _rects_diff(a[k], e[k], "%s/%s" % [at, k])
			if d != "":
				return d
		return ""
	if a is Array and e is Array:
		if a.size() != e.size():
			return "%s: eleman sayısı %d != %d" % [at, a.size(), e.size()]
		for i in e.size():
			var d := _rects_diff(a[i], e[i], at)
			if d != "":
				return d
		return ""
	if a is String and e is String and a != e:
		var pa: PackedStringArray = (a as String).rsplit("|", true, 1)
		var pe: PackedStringArray = (e as String).rsplit("|", true, 1)
		if pa.size() == 2 and pe.size() == 2 and pa[0] == pe[0]:
			var ra := pa[1].split(",")
			var re := pe[1].split(",")
			if ra.size() == 4 and re.size() == 4:
				if (
					ra[1] == re[1]
					and ra[3] == re[3]
					and absf(float(ra[0]) - float(re[0])) <= X_TOL_PX
					and absf(float(ra[2]) - float(re[2])) <= X_TOL_PX
				):
					return ""
		return "%s: %s != %s" % [at, a, e]
	if typeof(a) != typeof(e) or a != e:
		return "%s: %s != %s" % [at, a, e]
	return ""
