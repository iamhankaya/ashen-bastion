class_name AssetCheck
extends RefCounted
## Rig şerit dokusu boyut doğrulaması (R6b). Sim katmanı doku yüklemez (Texture2D yok): `GameData.validate()` şeridin beklenen boyutunu
## `_strip_probes`a yazar, dosyanın gerçek boyutu burada karşılaştırılır. Çağıran `g.validate()` sonrası bu çıktıyı ekler.
## Hata kodu/iletisi eski `DataV202Rig` ile aynıdır (`bad_type`).


static func validate(g: GameData) -> PackedStringArray:
	var out := PackedStringArray()
	for p in g._strip_probes:
		var tex := load(p["path"]) as Texture2D
		if tex != null and (tex.get_width() != p["w"] or tex.get_height() != p["h"]):
			GameData._err(
				out,
				"bad_type",
				p["ctx"],
				"şerit %dx%d, beklenen %dx%d" % [tex.get_width(), tex.get_height(), p["w"], p["h"]]
			)
	return out
