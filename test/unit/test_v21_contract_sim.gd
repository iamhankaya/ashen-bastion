extends GutTest
## v2.1 C sözleşmesi: RunProfile, GameSim'in mod/zorluk girişi, SimBus sinyalleri, WaveScaler, WavesValidator.validate_dict.
## Şekil testleri: çarpanların sim'e uygulanması U2'dedir (burada davranış DEĞİŞMEDİĞİ sınanır).


func _sim(opts: Dictionary = {}, seed_value: int = 5) -> GameSim:
	return GameSim.new(seed_value, &"gunslinger", opts)


# --- RunProfile ------------------------------------------------------------------------------


func test_contract_make_reads_mode_and_difficulty_fields() -> void:
	var p := V21Kit.profile(&"quick", &"easy")
	assert_eq(p.mode, &"quick")
	assert_eq(p.diff, &"easy")
	assert_eq(p.time_scale, 0.5)
	assert_eq(p.xp_mult, 1.5)
	assert_eq(p.lord_hp_mult, 0.5)
	assert_eq(p.enemy_hp, 0.7)
	assert_eq(p.xp, 1.25)
	assert_eq(p.end_mode, "lord")
	var e := V21Kit.profile(&"endless", &"normal")
	assert_eq(e.end_mode, "endless")
	assert_eq(e.lord_repeat_sec, 300.0)
	assert_eq(e.lord_hp_cap_mult, 8.0)
	assert_eq(e.enrage_after_sec, 2400.0)


func test_contract_make_unknown_names_give_null() -> void:
	assert_null(RunProfile.make(&"turbo", &"normal", V21Kit.cfg()))
	assert_null(RunProfile.make(&"normal", &"efsane", V21Kit.cfg()))
	assert_null(RunProfile.make(&"normal", &"normal", {}))


func test_contract_legacy_is_normal_mode_hard_difficulty_with_unit_multipliers() -> void:
	var p := RunProfile.legacy()
	assert_eq(p.mode, &"normal")
	assert_eq(p.diff, &"hard")
	assert_eq(p.time_scale, 1.0)
	assert_true(p.is_legacy())
	assert_true(
		V21Kit.profile(&"normal", &"hard").is_legacy(), "dosyadaki Normal/Zor da legacy eşdeğeri"
	)


func test_contract_non_legacy_profiles_are_detected() -> void:
	for pair in [
		[&"normal", &"normal"], [&"normal", &"easy"], [&"quick", &"hard"], [&"endless", &"hard"]
	]:
		assert_false(V21Kit.profile(pair[0], pair[1]).is_legacy(), "%s/%s" % pair)


func test_contract_curve_t_divides_by_time_scale() -> void:
	assert_eq(V21Kit.profile(&"quick", &"hard").curve_t(100.0), 200.0)
	assert_eq(V21Kit.profile(&"normal", &"hard").curve_t(100.0), 100.0)


func test_contract_opts_end_rules() -> void:
	var q := V21Kit.profile(&"quick", &"hard").opts()
	assert_eq(q["end_mode"], "lord")
	assert_eq(q["end_time"], 600.0, "Hızlı: 1200 · time_scale")
	var n := V21Kit.profile(&"normal", &"normal").opts()
	assert_eq(n["end_time"], 1200.0)
	var e := V21Kit.profile(&"endless", &"normal").opts()
	assert_eq(e["end_mode"], "endless")
	assert_eq(e["end_time"], 1200.0, "Sonsuz: ilk Lord 1200'de")
	var p := V21Kit.profile(&"normal", &"normal")
	assert_same(p.opts()["run_profile"], p)


# --- GameSim ---------------------------------------------------------------------------------


func test_contract_new_sim_constants_and_fields() -> void:
	assert_eq(GameSim.END_MODE_ENDLESS, "endless")
	var s := _sim()
	assert_null(s.run_profile)
	assert_false(s.milestone_won)
	assert_eq(s.lords_killed, 0)
	assert_false(s.lord_killed)


func test_contract_lord_mode_is_true_for_lord_and_endless_only() -> void:
	assert_true(_sim({"end_mode": "lord"}).lord_mode())
	assert_true(_sim({"end_mode": "endless"}).lord_mode())
	assert_false(_sim({"end_mode": "timer"}).lord_mode())
	assert_true(_sim().lord_mode(), "varsayılan = lord")


func test_contract_opts_precedence_direct_over_profile_over_default() -> void:
	var s0 := _sim()
	assert_eq(s0.end_mode, "lord")
	assert_eq(s0.end_time, 1200.0)
	var quick := V21Kit.profile(&"quick", &"hard")
	var s1 := _sim({"run_profile": quick})
	assert_same(s1.run_profile, quick)
	assert_eq(s1.end_time, 600.0, "profil opts'u")
	var s2 := _sim({"run_profile": quick, "end_time": 900.0, "end_mode": "timer"})
	assert_eq(s2.end_time, 900.0, "doğrudan değer profili ezer")
	assert_eq(s2.end_mode, "timer")
	var s3 := _sim({"run_profile": V21Kit.profile(&"endless", &"normal")})
	assert_eq(s3.end_mode, "endless")


func test_contract_non_profile_value_in_opts_is_ignored() -> void:
	var s := _sim({"run_profile": "normal"})
	assert_null(s.run_profile)
	assert_eq(s.end_time, 1200.0)


func test_contract_spawn_enemy_extra_hp_multiplier_defaults_to_one() -> void:
	var a := _sim()
	var b := _sim()
	var c := _sim()
	var ia := a.spawn_enemy(&"curumus_piyade", Vector2(100, 0))
	var ib := b.spawn_enemy(&"curumus_piyade", Vector2(100, 0), 1.0)
	var ic := c.spawn_enemy(&"curumus_piyade", Vector2(100, 0), 2.0)
	var ha := a.enemies.hp[EnemyPool.index_of(ia)]
	assert_eq(b.enemies.hp[EnemyPool.index_of(ib)], ha, "1.0 = eski davranış bayt bayt")
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(c.enemies.hp[EnemyPool.index_of(ic)], ha * 2.0, "ek çarpan HP'ye uygulanır")


func test_contract_spawn_enemy_unknown_type_is_minus_one_with_extra_arg() -> void:
	assert_eq(_sim().spawn_enemy(&"yok_boyle", Vector2.ZERO, 3.0), -1)


func _end(opts: Dictionary) -> Dictionary:
	var s := _sim(opts)
	var got := []
	s.bus.run_ended.connect(func(w: bool, st: Dictionary) -> void: got.append([w, st]))
	for i in 5:
		s.step(Vector2.ZERO)
	s.hp = 0.0
	s.step(Vector2.ZERO)
	assert_eq(got.size(), 1, "koşu bir kez biter")
	return got[0][1]


func test_contract_result_dictionary_carries_mode_diff_and_endless_fields() -> void:
	var legacy := _end({})
	assert_eq(legacy["mode"], "normal")
	assert_eq(legacy["diff"], "hard", "profilsiz = legacy = Normal/Zor")
	assert_eq(legacy["lords_killed"], 0)
	assert_eq(legacy["milestone_won"], false)
	for k in ["time", "level", "kills", "evolutions", "score"]:
		assert_true(legacy.has(k), "mevcut alan: %s" % k)
	var prof := _end({"run_profile": V21Kit.profile(&"quick", &"easy")})
	assert_eq(prof["mode"], "quick")
	assert_eq(prof["diff"], "easy")


func test_contract_new_bus_signals_have_the_planned_signatures() -> void:
	var found := {}
	for s in SimBus.new().get_signal_list():
		found[s["name"]] = s
	assert_true(found.has("milestone_reached"))
	assert_eq((found["milestone_reached"]["args"] as Array).size(), 0)
	assert_true(found.has("lord_slain"))
	var args: Array = found["lord_slain"]["args"]
	assert_eq(args.size(), 1)
	assert_eq(args[0]["name"], "n")
	assert_eq(args[0]["type"], TYPE_INT)


func test_contract_sim_never_emits_the_endless_signals_in_c() -> void:
	var s := _sim({"run_profile": V21Kit.profile(&"endless", &"normal")})
	var n := [0]
	s.bus.milestone_reached.connect(func() -> void: n[0] += 1)
	s.bus.lord_slain.connect(func(_k: int) -> void: n[0] += 1)
	for i in 120:
		s.step(Vector2.ZERO)
	assert_eq(n[0], 0, "sinyaller U2'de gerçek davranışa bağlanır")


# --- WaveScaler / WavesValidator.validate_dict -------------------------------------------------


func test_contract_validate_dict_accepts_the_shipped_waves() -> void:
	var data := GameData.load_default()
	assert_eq(WavesValidator.validate_dict(data.waves, data), [])


func test_contract_validate_dict_reports_the_same_codes_as_validate() -> void:
	var data := GameData.load_default()
	var bad := data.waves.duplicate(true)
	bad["bogus"] = 1
	bad["rows"][0]["bogus"] = 1
	var errs := WavesValidator.validate_dict(bad, data)
	assert_eq(errs.size(), 2, str(errs))
	for e in errs:
		assert_true(str(e).begins_with("[wave_unknown_key]"), str(e))


func test_contract_scaled_waves_pass_the_validator_for_each_time_scale() -> void:
	var data := GameData.load_default()
	for ts in [0.25, 0.5, 1.0, 2.0, 4.0]:
		var scaled := WaveScaler.scale(data.waves, ts)
		assert_eq(WavesValidator.validate_dict(scaled, data), [], "time_scale %s" % ts)


func test_contract_scale_halves_times_and_keeps_rates_and_counts() -> void:
	var data := GameData.load_default()
	var scaled := WaveScaler.scale(data.waves, 0.5)
	assert_eq(scaled["end_time"], 600.0)
	var rows: Array = scaled["rows"]
	var src: Array = data.waves["rows"]
	assert_eq(rows.size(), src.size())
	for i in rows.size():
		var r: Dictionary = rows[i]
		var o: Dictionary = src[i]
		match r["kind"]:
			"rate":
				assert_eq(r["rate"], o["rate"], "rate ölçeklenmez (K-C9)")
				assert_eq(r["to"], float(o["to"]) * 0.5)
			"group":
				assert_eq(r["group"], o["group"], "grup boyutu ölçeklenmez")
				assert_eq(r["every"][0], float(o["every"][0]) * 0.5)
				assert_eq(r["every"][1], float(o["every"][1]) * 0.5)
			"burst":
				assert_eq(r["count"], o["count"])
				assert_eq(r["at"], float(o["at"]) * 0.5)
			"boss":
				assert_eq(r["at"], float(o["at"]) * 0.5)
				assert_lte(float(r["warn"]), float(r["at"]), "warn <= at")
				assert_eq(r["warn"], float(o["warn"]) * 0.5)


func test_contract_scaled_lord_row_ends_at_end_time_and_warns_early() -> void:
	var scaled := WaveScaler.scale(GameData.load_default().waves, 0.5)
	var lord: Dictionary = {}
	for r: Dictionary in scaled["rows"]:
		if r["kind"] == "boss" and r["type"] == "kale_lordu":
			lord = r
	assert_eq(lord["at"], scaled["end_time"], "Lord 'at' = end_time")
	assert_eq(lord["at"], 600.0)
	assert_eq(lord["warn"], 2.5)


func test_contract_scale_is_a_deep_copy_and_identity_at_one() -> void:
	var data := GameData.load_default()
	var before := data.waves.duplicate(true)
	var scaled := WaveScaler.scale(data.waves, 0.5)
	scaled["rows"][0]["rate"][0] = 99.0
	scaled["rows"][1]["every"][0] = 99.0
	assert_eq(data.waves, before, "kaynak sözlük değişmez")
	var same := WaveScaler.scale(data.waves, 1.0)
	assert_eq(same, data.waves)
	same["rows"][0]["rate"][0] = 99.0
	assert_eq(data.waves, before, "1.0'da da kopya döner")
