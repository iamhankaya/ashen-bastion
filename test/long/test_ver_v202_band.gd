extends GutTest
## v2.0.2 D: Zyfen güç bandı raporu — BİLGİ RAPORU, gate'i etkilemez (GATE DIŞI, verify_long.sh).
## DpsProbe ile 10/50/200 yoğunlukta her Zyfen evriminin toplam DPS'i (temel saldırı + beceri), aktif sv5'e oranı
## (hedef 1,8-2,2) ve Kasırga Patlaması/Tufan ÷ Mermi Fırtınası (üst sınır 3). Çıktı: gut.p satırları (`BAND_JSON`).
## Yalnız iddia: ölçüm sonlu ve pozitif. Denge AYARI yapmaz; tam tablo için tools/balance/dps_density.gd.

const DENSITIES: Array[int] = [10, 50, 200]
const SECONDS := 10.0


func after_all() -> void:
	SimKit.remove_tmp()


func _dps(cid: StringName, setup: Dictionary, n: int) -> float:
	return DpsProbe.measure(cid, setup, &"crowd", n, SECONDS)["dps"]


func test_zyfen_band_report() -> void:
	var data := GameData.load_default()
	var rows := {}
	var bad := 0
	for sk in data.skills_of_kind(SkillDef.KIND_EVOLUTION):
		if not sk.available_to(&"zyfen") or sk.requires.is_empty():
			continue
		var req: Dictionary = sk.requires
		var act := StringName(req["active"])
		var evo_setup := {act: int(req["active_level"]), StringName(req["passive"]): int(req["passive_min_level"])}
		evo_setup[sk.id] = 1
		var ratios := []
		for n in DENSITIES:
			var a := _dps(&"zyfen", {act: int(req["active_level"])}, n)
			var e := _dps(&"zyfen", evo_setup, n)
			bad += 0 if (a > 0.0 and e > 0.0 and is_finite(e)) else 1
			ratios.append(snappedf(e / maxf(a, 1e-9), 0.01))
		rows[String(sk.id)] = ratios
		gut.p("%s evrim ÷ aktif sv5 (10/50/200): %s (hedef 1,8-2,2)" % [sk.id, str(ratios)])
	gut.p("BAND_JSON " + JSON.stringify({"seconds": SECONDS, "ratios": rows}))
	assert_eq(bad, 0, "ölçümler sonlu ve pozitif")
	assert_gt(rows.size(), 0, "Zyfen evrimleri raporlandı")
