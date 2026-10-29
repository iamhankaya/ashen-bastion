extends GutTest
## Karakterizasyon (plan Faz 4 madde 15): rig şerit-doku boyut doğrulaması (`walk.strip` dosyası ↔ hücre × kare). Baz: rf_asset_check.json.
## Gerçek veri, doku boyutu uyuşmayan şerit ve yer tutucu şerit için doğrulama çıktısı birebir sabit (R6b: sim'den validate katmanına taşınır).

const TMP := "user://rf_asset_check_tmp"
const WRONG_SIZE_TEX := "res://assets/gfx/char/zyfen_portrait.png"


func after_each() -> void:
	KitDev.remove_dir(TMP)


func _errors(g: GameData) -> Array:
	var errs := g.validate({}, true)
	errs.append_array(AssetCheck.validate(g))
	return Array(errs)


## res://data kopyası; zyfen.walk.strip değiştirilir.
func _with_strip(strip: String) -> GameData:
	var dst := TMP + "/" + str(Time.get_ticks_usec())
	KitDev.copy_dir("res://data", dst)
	var c: Dictionary = KitDev.read_json("res://data/characters/zyfen.json")
	c["rig"]["walk"]["strip"] = strip
	var f := FileAccess.open(dst + "/characters/zyfen.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(c, "  "))
	f.close()
	return GameData.load_dir(dst)


func test_rf_asset_check_outputs() -> void:
	var out := {
		"real_data": _errors(GameData.load_dir("res://data")),
		"strip_size_mismatch": _errors(_with_strip(WRONG_SIZE_TEX)),
		"strip_placeholder": _errors(_with_strip("placeholder:zyfen_strip")),
	}
	assert_eq(out["real_data"], [], "gerçek veri geçerli")
	assert_gt((out["strip_size_mismatch"] as Array).size(), 0, "boyut uyuşmazlığı hata verir")
	RfBaseline.check(self, "rf_asset_check", out)
