class_name V2Slice
extends RefCounted
## tools/v2_slices.txt okuyucusu (V11Slice kalıbı). Bitmemiş v2.0 diliminin kabul testi `require` ile pending döner.
## Simgeler: K (karakter), B (başarım), M (bakım). İşareti yalnız ilgili dilimin ayar turu açar; işaretli dilimde pending
## ya da sıfır test gate'i kırar (tools/ci/check_slices.py). V2_SLICES_FORCE=K işareti zorlar (tur fazı).

const PATH := "res://tools/v2_slices.txt"
const SYMBOLS: PackedStringArray = ["K", "B", "M"]


## Dosya işaretleri + V2_SLICES_FORCE. Dosya geçersizse yalnız zorlananlar (hatayı check_slices.py bildirir).
static func marks() -> PackedStringArray:
	var out := PackedStringArray(SliceFile.read(PATH, SYMBOLS)["marks"])
	for t in SliceFile.forced():
		if SYMBOLS.has(t) and not out.has(t):
			out.append(t)
	return out


static func done(id: String) -> bool:
	return marks().has(id)


## Dilim bitmemişse testi pending yapar ve true döner (çağıran hemen `return` eder):
##   if V2Slice.require(self, "K"): return
static func require(t: GutTest, id: String) -> bool:
	if done(id):
		return false
	t.pending("v2.0 dilimi %s bitmedi (tools/v2_slices.txt)" % id)
	return true
