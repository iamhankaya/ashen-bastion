class_name V11Slice
extends RefCounted
## tools/v11_slices.txt okuyucusu. Bitmemiş v1.1 diliminin kabul testi `require` ile pending döner.
## Simgeler: D1 (prosedürel animasyon+gölge), D2 (eklentiler), D3 (skor+highscore+ekranlar), D4 (kareli yürüme).

const PATH := "res://tools/v11_slices.txt"


## '#' ile başlayan satırlar atlanır; kalanlar boşlukla bölünür (ortak ayrıştırıcı: SliceFile).
static func marks() -> PackedStringArray:
	return SliceFile.read(PATH)["marks"]


static func done(id: String) -> bool:
	return marks().has(id)


## Dilim bitmemişse testi pending yapar ve true döner (çağıran hemen `return` eder):
##   if V11Slice.require(self, "D2"): return
static func require(t: GutTest, id: String) -> bool:
	if done(id):
		return false
	t.pending("v1.1 dilimi %s bitmedi (tools/v11_slices.txt)" % id)
	return true
