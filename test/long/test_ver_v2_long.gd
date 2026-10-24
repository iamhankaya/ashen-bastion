extends GutTest
## Doğrulama (T20261024-65) (a) uzun sürüm — GATE DIŞI: `bash tools/verify_long.sh`.
## İki karakter × 3 politika: 20 dk ölümsüz koşu, her 60 adımda `check_invariants()` boş; doğal koşu (ölüm ya da 20 dk).
## Kalibrasyon (b) ayrı dosyada: test_ver_v2_calibration.gd.

const TWENTY_MIN := 72000


func test_ver_v2_20_minute_godmode_runs_keep_invariants_clean_for_both_characters() -> void:
	for cid in VerV2Run.CHARACTERS:
		for policy in Bots.POLICIES:
			var r := (
				VerV2Run
				. run(
					{
						"seed": 3000 + absi(hash(String(policy))) % 89,
						"policy": policy,
						"character": cid,
						"max_steps": TWENTY_MIN,
						"check_every": 60,
						"godmode": true,
					}
				)
			)
			var tag := "%s/%s" % [cid, policy]
			assert_eq(r["violations"], PackedStringArray(), "20 dk ölümsüz " + tag)
			assert_eq(int(r["steps"]), TWENTY_MIN, "20 dk tamamlandı " + tag)
			gut.p("%s: level %d, öldürme %d, skor %d" % [tag, r["level"], r["kills"], r["score"]])


func test_ver_v2_natural_runs_keep_invariants_clean_for_both_characters() -> void:
	for cid in VerV2Run.CHARACTERS:
		for policy in Bots.POLICIES:
			for sd in [21, 22, 23]:
				var r := (
					VerV2Run
					. run(
						{
							"seed": sd,
							"policy": policy,
							"character": cid,
							"max_steps": TWENTY_MIN,
							"check_every": 60,
						}
					)
				)
				assert_eq(
					r["violations"],
					PackedStringArray(),
					"doğal koşu %s/%s tohum %d" % [cid, policy, sd]
				)


func test_ver_v2_long_runs_same_seed_same_hash_for_both_characters() -> void:
	for cid in VerV2Run.CHARACTERS:
		var a := VerV2Run.run(
			{
				"seed": 77,
				"policy": &"kite",
				"character": cid,
				"max_steps": TWENTY_MIN,
				"godmode": true
			}
		)
		var b := VerV2Run.run(
			{
				"seed": 77,
				"policy": &"kite",
				"character": cid,
				"max_steps": TWENTY_MIN,
				"godmode": true
			}
		)
		assert_eq(a["state_hash"], b["state_hash"], "20 dk aynı tohum aynı hash " + String(cid))
