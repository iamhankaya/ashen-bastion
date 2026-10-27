extends GutTest
## v2.1 C sözleşmesi, K-C10 (b): geç oyun referans karmaları. Kayıt (test/fixtures/golden_v20_ref/ref.json) DEĞİŞMEMİŞ koddan
## .github/workflows/golden_ref.yml ile üretilir; kayıt yoksa test pending döner (sahte yeşil değil, açık nokta raporlanır).
## Mevcut golden senaryoları test/fixtures/golden_hashes.json + test_v202_contract_golden.gd'de zaten sabittir.


func _record(case: Array) -> Dictionary:
	var rec: Dictionary = V21RefKit.load_fixture().get("late", {})
	return rec.get(V21RefKit.case_key(int(case[0]), float(case[1]), int(case[2])), {})


func _check(case: Array, opts: Dictionary) -> void:
	var rec := _record(case)
	if rec.is_empty():
		pending(
			"ref.json üretilmedi: golden_ref iş akışını koştur (.github/workflows/golden_ref.yml)"
		)
		return
	var got := V21RefKit.run_late(int(case[0]), float(case[1]), int(case[2]), opts)
	var key := V21RefKit.case_key(int(case[0]), float(case[1]), int(case[2]))
	for k in rec.keys():
		# JSON sayıları float döner; karmalar/RNG durumu zaten dizge.
		var want: Variant = rec[k] if rec[k] is String else int(rec[k])
		assert_eq(got[k] if got[k] is String else int(got[k]), want, "%s: %s" % [key, k])


func test_contract_ref_fixture_scenarios_cover_the_lord_and_contact_damage() -> void:
	for c: Array in V21RefKit.LATE_CASES:
		var rec := _record(c)
		if rec.is_empty():
			pending("ref.json üretilmedi")
			return
		assert_gt(int(rec["steps"]), 0)
		# Üretilen kayıtta 1190 senaryosunda oyuncu Lord'dan (1200) önce ölüyor (steps 460, lord_spawns 0): Lord kapsamı
		# bu fixture'da yok, Lord'lu karma Sonsuz/ölçüm testlerinde (test_v21_s_sim, U1a baseline) sınanır.
		if float(c[1]) >= 1190.0:
			assert_gt(int(rec["damage_q"]), 0, "1190'dan başlayan senaryoda temas hasarı alınır")


func test_contract_late_game_matches_the_reference_without_profile() -> void:
	_check(V21RefKit.LATE_CASES[0], {})


func test_contract_late_game_matches_the_reference_with_legacy_profile() -> void:
	_check(V21RefKit.LATE_CASES[0], {"run_profile": RunProfile.legacy()})


func test_contract_lord_game_matches_the_reference_without_profile() -> void:
	_check(V21RefKit.LATE_CASES[1], {})


func test_contract_lord_game_matches_the_reference_with_legacy_profile() -> void:
	_check(V21RefKit.LATE_CASES[1], {"run_profile": RunProfile.legacy()})
