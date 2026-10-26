extends GutTest
## Doğrulama (T20261024-65) (b): başarım hedef kalibrasyonu — BİLGİ RAPORU, gate'i etkilemez (GATE DIŞI, verify_long.sh).
## 20 tohum × 3 politika × 2 karakter doğal koşu (ölüm ya da 20 dk); gerçek AchievementTracker ile her başarımın
## kaç koşuda açıldığı. Denge AYARI yapmaz; öneri raporlanır, karar kullanıcıdadır. Çıktı: gut.p satırları
## (`KALIBRASYON_JSON`); dosyaya yazmaz (user:// sızıntısı yok).
## Yalnız iddia: koşular değişmezleri bozmaz ve 22 başarım kimliği raporda eksiksizdir.

const SEEDS := 20
const MAX_STEPS := 72000


func test_ver_v2_calibration_report() -> void:
	var ids: Array[StringName] = []
	for a in AchKit.legacy_data().achievements:
		ids.append(a.id)
	var table := {}  # "char/policy" -> {id: açılan koşu sayısı}
	var meta := {}
	var bad := 0
	for cid in VerV2Run.CHARACTERS:
		for policy in Bots.POLICIES:
			var key := "%s/%s" % [cid, policy]
			var counts := {}
			var times := []
			for id in ids:
				counts[String(id)] = 0
			for sd in SEEDS:
				var r := (
					VerV2Run
					. run(
						{
							"seed": 5000 + sd,
							"policy": policy,
							"character": cid,
							"max_steps": MAX_STEPS,
							"check_every": 600,
							"tracker": true,
						}
					)
				)
				bad += (r["violations"] as PackedStringArray).size()
				times.append(float(r["time"]))
				for id in r["unlocked"]:
					counts[String(id)] += 1
			table[key] = counts
			times.sort()
			meta[key] = {"median_time": times[times.size() / 2], "max_time": times[-1]}
			gut.p(
				(
					"%s medyan süre %.0f sn, en uzun %.0f sn"
					% [key, meta[key]["median_time"], meta[key]["max_time"]]
				)
			)
			gut.p("%s: %s" % [key, JSON.stringify(counts)])
	gut.p("KALIBRASYON_JSON " + JSON.stringify({"seeds": SEEDS, "table": table, "meta": meta}))
	assert_eq(bad, 0, "kalibrasyon koşularında değişmez ihlali yok")
	assert_eq(ids.size(), 22, "22 başarım")
