class_name V202Slice
extends RefCounted
## tools/v202_slices.txt okuyucusu (V2Slice kalıbı). Bitmemiş v2.0.2 diliminin kabul testi `require` ile pending döner.
## Simgeler: P (havuz), R (kolsuz rig), W (temel rüzgar), Z (bölgeler), E (evrimler), A (varlık bağlama).
## İşareti yalnız ilgili dilimin ayar turu (K fazı turları) açar; işaretli dilimde pending ya da sıfır test gate'i kırar
## (tools/ci/check_slices.py --v202). V202_SLICES_FORCE=P işareti zorlar (tur fazı).

const PATH := "res://tools/v202_slices.txt"
const FORCE_ENV := "V202_SLICES_FORCE"
const SYMBOLS: PackedStringArray = ["P", "R", "W", "Z", "E", "A"]


## Dosya işaretleri + V202_SLICES_FORCE. Dosya geçersizse yalnız zorlananlar (hatayı check_slices.py bildirir).
static func marks() -> PackedStringArray:
	var out := PackedStringArray(SliceFile.read(PATH, SYMBOLS)["marks"])
	for t in SliceFile.forced(FORCE_ENV):
		if SYMBOLS.has(t) and not out.has(t):
			out.append(t)
	return out


static func done(id: String) -> bool:
	return marks().has(id)


## Dilim bitmemişse testi pending yapar ve true döner (çağıran hemen `return` eder):
##   if V202Slice.require(self, "P"): return
static func require(t: GutTest, id: String) -> bool:
	if done(id):
		return false
	t.pending("v2.0.2 dilimi %s bitmedi (tools/v202_slices.txt)" % id)
	return true
