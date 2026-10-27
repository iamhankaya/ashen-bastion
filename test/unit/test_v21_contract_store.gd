extends GutTest
## v2.1 C sözleşmesi: Highscores (mod, zorluk) imzaları, Settings seçimi, AchievementRules, V21Runs köprüsü.
## Dosya biçimi (v2), göç ve tracker enjeksiyonu U3'tedir; burada yalnız imza/şekil ve bellek içi davranış sınanır.

const TMP := "user://test_v21_contract_store.cfg"


func after_each() -> void:
	V21Kit.clear_fake_settings()


func _e(score: int, mode: String = "normal", diff: String = "normal") -> Dictionary:
	return {
		"score": score,
		"time": 60,
		"won": false,
		"level": 3,
		"unix": 1000,
		"mode": mode,
		"diff": diff,
	}


# --- Highscores ------------------------------------------------------------------------------


func test_contract_submit_goes_to_its_own_list_only() -> void:
	var h := Highscores.new("user://yok_v21_hs.json")
	var r := h.submit(_e(500, "quick", "easy"))
	assert_eq(r["rank"], 1)
	assert_false(r.has("error"))
	assert_eq(h.list_for(&"quick", &"easy").size(), 1)
	assert_eq(h.list_for(&"quick", &"easy")[0]["score"], 500)
	for other in [[&"normal", &"normal"], [&"quick", &"hard"], [&"endless", &"easy"]]:
		assert_eq(h.list_for(other[0], other[1]).size(), 0, "%s/%s" % other)
	assert_eq(h.entries.size(), 0, "entries yalnız normal:normal görünümü")


func test_contract_entries_is_the_normal_normal_view() -> void:
	var h := Highscores.new("user://yok_v21_hs.json")
	h.submit(_e(100))
	h.submit(_e(300))
	assert_eq(h.entries.size(), 2)
	assert_eq(h.entries[0]["score"], 300)
	assert_eq(h.list_for(&"normal", &"normal").size(), 2)
	assert_eq(h.list_for(&"normal", &"normal")[0]["score"], 300)


func test_contract_submit_without_mode_and_diff_writes_to_normal_normal() -> void:
	# Eski çağıranlar (v1.1 testleri) için uyum; controller her zaman mode/diff verir (test_v21_contract_flow).
	var h := Highscores.new("user://yok_v21_hs.json")
	var r := h.submit({"score": 100, "time": 1, "won": false, "level": 1, "unix": 1})
	assert_false(r.has("error"))
	assert_eq(r["rank"], 1)
	assert_eq(h.entries.size(), 1)
	assert_eq(h.list_for(&"normal", &"normal").size(), 1)
	assert_eq(h.list_for(&"quick", &"easy").size(), 0)


func test_contract_submit_with_non_string_names_is_an_error() -> void:
	var h := Highscores.new("user://yok_v21_hs.json")
	var bad := _e(100)
	bad["mode"] = 3
	assert_eq(h.submit(bad)["error"], "mode_diff_unknown")
	assert_eq(h.entries.size(), 0)


func test_contract_submit_with_unknown_names_is_an_error() -> void:
	var h := Highscores.new("user://yok_v21_hs.json")
	assert_eq(h.submit(_e(100, "turbo", "normal"))["error"], "mode_diff_unknown")
	assert_eq(h.submit(_e(100, "normal", "efsane"))["error"], "mode_diff_unknown")
	assert_eq(h.entries.size(), 0)


func test_contract_each_list_keeps_its_own_top_ten() -> void:
	var h := Highscores.new("user://yok_v21_hs.json")
	for i in 11:
		h.submit(_e(100 + i, "endless", "hard"))
	h.submit(_e(5, "quick", "hard"))
	var endless := h.list_for(&"endless", &"hard")
	assert_eq(endless.size(), 10)
	assert_eq(endless[0]["score"], 110)
	assert_eq(endless[9]["score"], 101, "en düşük (100) atıldı")
	assert_eq(h.list_for(&"quick", &"hard").size(), 1)


func test_contract_key_of_format() -> void:
	assert_eq(Highscores.key_of(&"quick", &"easy"), "quick:easy")
	assert_eq(Highscores.DEFAULT_KEY, "normal:normal")


func test_contract_load_file_resets_every_list() -> void:
	var h := Highscores.new("user://yok_v21_hs.json")
	h.submit(_e(100, "quick", "easy"))
	h.load_file()
	assert_eq(h.list_for(&"quick", &"easy").size(), 0)
	h.submit(_e(100))
	assert_eq(h.entries.size(), 1)
	assert_eq(
		h.list_for(&"normal", &"normal").size(), 1, "entries ve normal:normal listesi aynı dizi"
	)


# --- Settings --------------------------------------------------------------------------------


func _write(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_contract_settings_run_selection_roundtrip_and_tolerance() -> void:
	var st: Node = get_node(^"/root/Settings")
	var saved := [st.store_path, st.run_mode, st.run_diff]
	st.store_path = TMP
	st.run_mode = "endless"
	st.run_diff = "easy"
	assert_true(st.save_settings())
	st.run_mode = "normal"
	st.run_diff = "normal"
	st.load_settings(TMP)
	assert_eq(st.run_mode, "endless")
	assert_eq(st.run_diff, "easy")
	_write('{"ses": true}')
	st.load_settings(TMP)
	assert_eq(st.run_mode, "normal", "eksik anahtar: varsayılan")
	assert_eq(st.run_diff, "normal")
	_write('{"kosu_modu": "turbo", "kosu_zorluk": 7}')
	st.load_settings(TMP)
	assert_eq(st.run_mode, "normal", "bilinmeyen ad: varsayılan")
	assert_eq(st.run_diff, "normal")
	st.store_path = saved[0]
	st.run_mode = saved[1]
	st.run_diff = saved[2]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


# --- AchievementRules ------------------------------------------------------------------------


func test_contract_rules_block_lord_bound_tiers_on_easy_only() -> void:
	var r := AchievementRules.new(V21Kit.cfg())
	for id in ["lordslayer:1", "lordslayer:2", "lordslayer:3", "endure:4", "ascension:3"]:
		assert_false(r.allows(id, &"easy"), "%s Kolay'da kapalı" % id)
		assert_true(r.allows(id, &"normal"), "%s Normal'de açık" % id)
		assert_true(r.allows(id, &"hard"), "%s Zor'da açık" % id)
	for id in ["endure:3", "ascension:2", "kills_total:1"]:
		assert_true(r.allows(id, &"easy"), "%s Lord'a bağlı değil" % id)
	assert_true(r.allows("endure:4", &"yok_boyle"), "bilinmeyen zorluk: kural yok")


func test_contract_rules_totals_on_easy_count_only_runs_and_play_secs() -> void:
	var r := AchievementRules.new(V21Kit.cfg())
	for key in [&"runs", &"play_secs"]:
		assert_true(r.counts_total(key, &"easy"), str(key))
	for key in [&"kills", &"wins", &"boss_kills", &"chars5"]:
		assert_false(r.counts_total(key, &"easy"), str(key))
		assert_true(r.counts_total(key, &"normal"), str(key))
		assert_true(r.counts_total(key, &"hard"), str(key))


func test_contract_empty_rules_allow_everything() -> void:
	var r := AchievementRules.new()
	assert_true(r.allows("endure:4", &"easy"))
	assert_true(r.counts_total(&"kills", &"easy"))


func test_contract_tier_id_format() -> void:
	assert_eq(AchievementRules.tier_id(&"endure", 4), "endure:4")


# --- V21Runs ---------------------------------------------------------------------------------


func test_contract_selection_defaults_and_set_selection_saves() -> void:
	var fake := V21Kit.use_fake_settings()
	assert_eq(V21Runs.selection(), {"mode": &"normal", "diff": &"normal"})
	V21Runs.set_selection(&"quick", &"easy")
	assert_eq(fake.run_mode, "quick")
	assert_eq(fake.run_diff, "easy")
	assert_eq(fake.saves, 1)
	assert_eq(V21Runs.selection(), {"mode": &"quick", "diff": &"easy"})
	V21Runs.set_selection(&"turbo", &"easy")
	V21Runs.set_selection(&"quick", &"efsane")
	assert_eq(fake.run_mode, "quick", "bilinmeyen ad yok sayılır")
	assert_eq(fake.saves, 1)


func test_contract_run_opts_follow_the_selection() -> void:
	var fake := V21Kit.use_fake_settings()
	var normal := V21Runs.run_opts()
	assert_eq(normal["end_mode"], "lord")
	assert_eq(normal["end_time"], 1200.0)
	assert_eq(normal["run_profile"].mode, &"normal")
	fake.run_mode = "quick"
	fake.run_diff = "hard"
	var quick := V21Runs.run_opts()
	assert_eq(quick["end_time"], 600.0)
	assert_eq(quick["run_profile"].diff, &"hard")
	fake.run_mode = "endless"
	assert_eq(V21Runs.run_opts()["end_mode"], "endless")


func test_contract_run_won_covers_state_won_and_the_endless_milestone() -> void:
	var s := GameSim.new(1, &"gunslinger")
	assert_false(V21Runs.run_won(s))
	s.state = GameSim.State.WON
	assert_true(V21Runs.run_won(s))
	s.state = GameSim.State.LOST
	assert_false(V21Runs.run_won(s))
	s.milestone_won = true
	assert_true(V21Runs.run_won(s), "Sonsuz: sim LOST kalır, kilometre taşı kazanma sayılır")
	assert_false(V21Runs.run_won(null))


func test_contract_score_fields_take_mode_and_diff_from_the_finished_run() -> void:
	var fake := V21Kit.use_fake_settings()
	fake.run_mode = "endless"
	var stats := {"score": 1234, "time": 61.9, "level": 7, "mode": "quick", "diff": "easy"}
	var f := V21Runs.score_fields(stats, true)
	assert_eq(f["score"], 1234)
	assert_eq(f["time"], 61)
	assert_eq(f["won"], true)
	assert_eq(f["level"], 7)
	assert_eq(f["mode"], "quick", "geçerli seçim değil, biten koşunun çifti")
	assert_eq(f["diff"], "easy")
	assert_gt(f["unix"], 1_700_000_000)
	var bare := V21Runs.score_fields({"score": 1}, false)
	assert_eq(bare["mode"], "endless", "stats'ta yoksa geçerli seçim")
	assert_eq(bare["diff"], "normal")


func test_contract_scores_key_uses_the_pair_or_the_selection() -> void:
	V21Kit.use_fake_settings()
	assert_eq(V21Runs.scores_key(), {"mode": &"normal", "diff": &"normal"})
	assert_eq(V21Runs.scores_key(&"endless", &"hard"), {"mode": &"endless", "diff": &"hard"})
	assert_eq(
		V21Runs.scores_key(&"endless", &""),
		{"mode": &"normal", "diff": &"normal"},
		"eksik çift = seçim"
	)
