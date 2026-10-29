extends GutTest
## Karakterizasyon (plan Faz 4 madde 10): mod x zorluk matrisi (3x3). RunProfiles/RunProfile değerleri, RunStrip metinleri,
## Highscores sıralama/kırpma. Baz: rf_runs_*.json. Highscores yolu AchKit.tmp_path (gerçek kayıt dosyasına dokunmaz).

const MODES := [&"quick", &"normal", &"endless"]
const DIFFS := [&"easy", &"normal", &"hard"]


func after_each() -> void:
	AchKit.cleanup()


func _cfg() -> Dictionary:
	return RunProfiles.load_default()["profiles"]


func test_rf_profiles_file_and_errors() -> void:
	var loaded := RunProfiles.load_default()
	assert_eq(loaded["errors"], [], "varsayılan profil dosyası geçerli")
	RfBaseline.check(self, "rf_runs_profiles_file", loaded)


func test_rf_run_profile_values_3x3() -> void:
	var cfg := _cfg()
	var out := {}
	for m in MODES:
		for d in DIFFS:
			var p := RunProfile.make(m, d, cfg)
			var vals := {}
			for prop in p.get_property_list():
				if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
					vals[prop["name"]] = var_to_str(p.get(prop["name"]))
			vals["legacy"] = p.is_legacy()
			out["%s:%s" % [m, d]] = vals
	out["legacy"] = {"legacy": RunProfile.legacy().is_legacy()}
	RfBaseline.check(self, "rf_runs_profile_values", out)


func test_rf_run_strip_texts_3x3() -> void:
	var cfg := _cfg()
	var out := {}
	for m in MODES:
		out["mode_%s" % m] = {
			"minutes": RunStrip.minutes(m, cfg),
			"duration": RunStrip.duration_text(m, cfg),
			"title": RunStrip.title_text(m, cfg),
			"desc": RunStrip.mode_desc(m, cfg),
		}
		for d in DIFFS:
			out["%s:%s" % [m, d]] = {
				"rules": RunStrip.rule_lines(m, d),
				"a11y": RunStrip.strip_a11y(m, d, cfg),
				"mode_a11y": [RunStrip.mode_a11y(m, cfg, true), RunStrip.mode_a11y(m, cfg, false)],
			}
	for d in DIFFS:
		out["diff_%s" % d] = {
			"rows": RunStrip.detail_rows(d, cfg),
			"a11y": [RunStrip.diff_a11y(d, true), RunStrip.diff_a11y(d, false)],
			"detail_a11y": RunStrip.detail_a11y(d, cfg),
		}
	out["no_data"] = {
		"minutes": RunStrip.minutes(&"quick", {}),
		"duration": RunStrip.duration_text(&"quick", {}),
		"desc": RunStrip.mode_desc(&"normal", {}),
		"rows": RunStrip.detail_rows(&"easy", {}),
	}
	RfBaseline.check(self, "rf_runs_strip_texts", out)


func test_rf_highscores_per_list_order_and_trim() -> void:
	var path := AchKit.tmp_path("rfhs")
	var hs := Highscores.new(path)
	var results := []
	for m in MODES:
		for d in DIFFS:
			for i in 12:  # 10'luk sınırı aşar; eşit skor, sıra kararlılığı
				var score := 1000 + ((i * 7) % 5) * 100
				(
					results
					. append(
						(
							hs
							. submit(
								{
									"mode": String(m),
									"diff": String(d),
									"score": score,
									"time": 60 + i,
									"level": 3 + i % 4,
									"won": i % 3 == 0,
									"unix": 1700000000 + i,
								}
							)
						)
					)
				)
	var lists := {}
	for m in MODES:
		for d in DIFFS:
			lists["%s:%s" % [m, d]] = hs.list_for(m, d)
	var bad := hs.submit({"mode": "yok", "diff": "normal", "score": 5})
	assert_eq(bad.get("error"), "mode_diff_unknown", "bilinmeyen mod reddedilir")
	hs.save()
	RfBaseline.check(
		self,
		"rf_runs_highscores",
		{
			"results": results,
			"lists": lists,
			"bad": bad,
			"saved": JSON.parse_string(AchKit.read_text(path))
		}
	)
