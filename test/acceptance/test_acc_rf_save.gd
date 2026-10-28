extends GutTest
## Karakterizasyon (plan Faz 4 madde 8): kayıt göçü matrisi. Her girdi için yükle -> normalize -> kaydet çıktısı sabit.
## Girdiler: gerçek v2.0 başarım kaydı, eksik alan, fazla alan, bozuk JSON, boş dosya; Highscores v1 fixture'ları.
## Baz: rf_save_*.json. Kayıt yolu AchKit.tmp_path (gerçek user://achievements.json'a dokunmaz); after_each temizler.

const HS_FIX := "res://test/fixtures/hs_v1/"
const ACH_CASES := {
	"empty_file": "",
	"bad_json": "{not json",
	"not_object": "[1,2,3]",
	"empty_object": "{}",
	"missing_totals": '{"v":1,"unlocked":{"a":5}}',
	"extra_fields":
	'{"v":1,"unlocked":{},"totals":{"kills":3,"zzz":9},"best":{},"chars5":[],"future":1}',
	"wrong_types": '{"v":"x","unlocked":"no","totals":[],"best":7,"chars5":"y"}',
}


func after_each() -> void:
	AchKit.cleanup()


func _ach_roundtrip(text: String, defs: Array) -> Dictionary:
	var path := AchKit.tmp_path("rf")
	AchKit.write_text(path, text)
	var s := AchievementStore.new(path)
	var ok := s.load_file(defs)
	var raw := s.to_raw()
	s.save()
	return {
		"loaded": ok,
		"corrupt": s.corrupt,
		"raw": raw,
		"saved": JSON.parse_string(AchKit.read_text(path)),
		"bad_kept": FileAccess.file_exists(path + ".bad"),
	}


func test_rf_achievement_store_matrix_legacy_defs() -> void:
	var defs := AchKit.legacy_data().achievements
	var out := {}
	for k in ACH_CASES:
		out[k] = _ach_roundtrip(ACH_CASES[k], defs)
	out["real_v20"] = _ach_roundtrip(
		FileAccess.get_file_as_string("res://test/fixtures/ach_v20/achievements.json"), defs
	)
	RfBaseline.check(self, "rf_save_ach_legacy", out)


func test_rf_achievement_store_matrix_v2_defs() -> void:
	var defs := AchKit.data().achievements
	var out := {}
	for k in ACH_CASES:
		out[k] = _ach_roundtrip(ACH_CASES[k], defs)
	out["real_v20"] = _ach_roundtrip(
		FileAccess.get_file_as_string("res://test/fixtures/ach_v20/achievements.json"), defs
	)
	RfBaseline.check(self, "rf_save_ach_v2", out)


func test_rf_highscores_v1_fixtures() -> void:
	var out := {}
	for f in DirAccess.get_files_at(HS_FIX):
		if not f.ends_with(".json"):
			continue
		var path := AchKit.tmp_path("rfhs")
		AchKit.write_text(path, FileAccess.get_file_as_string(HS_FIX + f))
		var hs := Highscores.new(path)
		var ok := hs.load_file()
		hs.save()
		out[f] = {
			"loaded": ok,
			"corrupt": hs.corrupt,
			"saved": JSON.parse_string(AchKit.read_text(path)),
		}
	assert_gt(out.size(), 0, "hs_v1 fixture'ları bulundu")
	RfBaseline.check(self, "rf_save_highscores_v1", out)
