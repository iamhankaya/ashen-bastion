extends GutTest
## Kabul (v2.1 S): Hızlı mod (spec senaryo 6 ve K3-A). Süre ölçeği ×0,5: Lord 600. sn'de gelir (uyarı 2,5 sn önce),
## elit dalgaları 150/300/450, eğriler `curve_t` ile; Lord ölümüyle biter (end_time gelince bitmez). Hedef düzeltmesi
## (plan): kazanılan koşu ≤ 13 dk. Kazanma oranı farkı ve `level_at_end` ölçütü ölçümdür (balance.yml), burada değil.
## V21Slice "S" açılana dek pending (q1 süre kuralı C'den beri koşar).


func _quick(diff: StringName = &"hard", extra: Dictionary = {}) -> GameSim:
	var o := {"data": GameData.load_default(), "run_profile": V21Kit.profile(&"quick", diff)}
	o.merge(extra, true)
	return GameSim.new(5, &"gunslinger", o)


func _rows(sim: GameSim, kind: String) -> Array:
	var out: Array = []
	for r: Dictionary in sim.spawn_director.waves["rows"]:
		if r["kind"] == kind:
			out.append(r)
	return out


func test_q1_run_length_rules_come_from_the_profile() -> void:
	var s := _quick()
	assert_eq(s.end_mode, "lord")
	assert_eq(s.end_time, 600.0, "Hızlı: Lord 600. sn")
	assert_eq(_quick(&"easy").end_time, 600.0)
	assert_eq(GameSim.new(5, &"gunslinger", {}).end_time, 1200.0, "Normal 1200 kalır")


func test_s12_scheduled_waves_are_halved_and_consistent() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _quick()
	var waves: Dictionary = s.spawn_director.waves
	assert_eq(waves["end_time"], 600.0)
	# Elit dalgaları waves.json'da `boss` satırıdır; `burst` piyade halkalarıdır.
	var elite_at: Array = []
	for r in _rows(s, "boss"):
		if r["type"] != "kale_lordu":
			elite_at.append(r["at"])
	assert_has(elite_at, 150.0, "elit 300 -> 150")
	assert_has(elite_at, 300.0, "elit 600 -> 300")
	assert_has(elite_at, 450.0, "elit 900 -> 450")
	for r in _rows(s, "boss"):
		assert_lte(float(r["warn"]), float(r["at"]), "warn <= at")
		assert_lte(float(r["at"]), float(waves["end_time"]), "olay end_time'dan sonra değil")
	assert_eq(WavesValidator.validate_dict(waves, s.data), [], "ölçeklenmiş çizelge geçerli")


func test_s13_lord_arrives_at_600_with_an_early_warning() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _quick(&"hard", {"data": V21Acc.lord_only_data(), "start_time": 590.0})
	V21Acc.quiet_player(s)
	var w := V21Acc.watch(s)
	V21Acc.run_until(s, 900, func() -> bool: return not w["spawns"].is_empty())
	assert_eq(w["spawns"].size(), 1, "Lord doğdu")
	assert_almost_eq(float(w["spawns"][0]), 600.0, 0.1, "Lord 600. sn")
	assert_eq(w["warns"].size(), 1, "uyarı verildi")
	assert_almost_eq(float(w["warns"][0]), 597.5, 0.1, "uyarı 2,5 sn önce")


func test_s14_the_run_does_not_end_at_end_time_while_the_lord_lives() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _quick(&"hard", {"data": V21Acc.lord_only_data(), "start_time": 590.0})
	V21Acc.quiet_player(s)
	V21Acc.run_until(s, 60 * 40)  # 40 sn: 630. sn
	assert_gt(s.time, 620.0)
	assert_eq(s.state, GameSim.State.RUNNING, "Lord modunda süre bitişi yok")
	assert_gte(V21Acc.lord_id(s), 0, "Lord hâlâ yaşıyor")


func test_s15_enemy_curves_run_at_double_speed() -> void:
	if V21Slice.require(self, "S"):
		return
	var q := _quick(&"hard")
	var n := GameSim.new(5, &"gunslinger", {"data": GameData.load_default()})
	q.debug_set_time(150.0)
	n.debug_set_time(300.0)
	var hq := V21Acc.hp_of(q, q.spawn_enemy(&"curumus_piyade", Vector2(200, 0)))
	var hn := V21Acc.hp_of(n, n.spawn_enemy(&"curumus_piyade", Vector2(200, 0)))
	assert_almost_eq(hq, hn, hn * 0.001, "Hızlı 150. sn HP eğrisi = Normal 300. sn (curve_t)")


func test_s16_slaying_the_lord_wins_the_run() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _quick(&"hard", {"data": V21Acc.lord_only_data(), "start_time": 590.0})
	V21Acc.quiet_player(s)
	var won := []
	s.bus.run_ended.connect(func(w: bool, _st: Dictionary) -> void: won.append(w))
	V21Acc.run_until(s, 900, func() -> bool: return V21Acc.lord_id(s) >= 0)
	assert_gte(V21Acc.slay_lord(s), 0, "Lord bulundu ve öldürüldü")
	s.step(Vector2.ZERO)
	assert_eq(s.state, GameSim.State.WON)
	assert_eq(won, [true])
	assert_true(V21Runs.run_won(s))
