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
