class_name V203Slice
extends RefCounted
## tools/v203_slices.txt okuyucusu (V202Slice kalıbı). Bitmemiş v2.0.3 uygulama diliminin kabul testi `require` ile pending döner.
## Simgeler: A (animasyon), B (küreler), C (başarımlar), D (ana sayfa + ayarlar). V203_SLICES_FORCE=A işareti zorlar.

const PATH := "res://tools/v203_slices.txt"
const FORCE_ENV := "V203_SLICES_FORCE"
const SYMBOLS: PackedStringArray = ["A", "B", "C", "D"]


## Dosya işaretleri + V203_SLICES_FORCE. Dosya geçersizse yalnız zorlananlar (hatayı check_slices.py bildirir).
static func marks() -> PackedStringArray:
	var out := PackedStringArray(SliceFile.read(PATH, SYMBOLS)["marks"])
	for t in SliceFile.forced(FORCE_ENV):
		if SYMBOLS.has(t) and not out.has(t):
			out.append(t)
	return out


static func done(id: String) -> bool:
	return marks().has(id)


## Dilim bitmemişse testi pending yapar ve true döner (çağıran hemen `return` eder):
##   if V203Slice.require(self, "C"): return
static func require(t: GutTest, id: String) -> bool:
	if done(id):
		return false
	t.pending("v2.0.3 dilimi %s bitmedi (tools/v203_slices.txt)" % id)
	return true
