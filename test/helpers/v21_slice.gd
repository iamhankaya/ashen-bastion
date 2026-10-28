class_name V21Slice
extends RefCounted
## tools/v21_slices.txt okuyucusu (V203Slice kalıbı). Bitmemiş v2.1 uygulama diliminin kabul testi `require` ile pending döner.
## Simgeler: M (ölçüm aracı), S (sim ve veri), K (kayıt/skor/başarım), A (UI seçim), B (UI skor/sonuç).
## V21_SLICES_FORCE=S işareti zorlar (T-turu: dilimi açmadan gerçek kodda koşmak).

const PATH := "res://tools/v21_slices.txt"
const FORCE_ENV := "V21_SLICES_FORCE"
const SYMBOLS: PackedStringArray = ["M", "S", "K", "A", "B"]


## Dosya işaretleri + V21_SLICES_FORCE. Dosya geçersizse yalnız zorlananlar (hatayı check_slices.py bildirir).
static func marks() -> PackedStringArray:
	var out := PackedStringArray(SliceFile.read(PATH, SYMBOLS)["marks"])
	for t in SliceFile.forced(FORCE_ENV):
		if SYMBOLS.has(t) and not out.has(t):
			out.append(t)
	return out


static func done(id: String) -> bool:
	return marks().has(id)


## Dilim bitmemişse testi pending yapar ve true döner (çağıran hemen `return` eder):
##   if V21Slice.require(self, "S"): return
static func require(t: GutTest, id: String) -> bool:
	if done(id):
		return false
	t.pending("v2.1 dilimi %s bitmedi (tools/v21_slices.txt)" % id)
	return true
