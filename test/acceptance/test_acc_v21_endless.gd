extends GutTest
## Kabul (v2.1 S): Sonsuz mod (spec senaryo 8, K4-A, plan K-C1/K-C2/K-C3). İlk Lord ölümü kazanma sayılır (kilometre taşı),
## koşu sürer ve yalnız ölümle biter; Lord ölümünden `lord_repeat_sec` (300) sonra HP ×1,5 (tavan ×8) ile döner; 1200. sn
## sonrası temas hasarı artar (enrage). Determinizm testi tester'ındır (Sonsuz altın hash dışıdır). 40. dk performansı
## nightly (test/long). V21Slice "S" açılana dek pending; e1 (profil/opts) C'den beri koşar.

const START := 1190.0


func _endless(diff: StringName = &"hard", extra: Dictionary = {}) -> GameSim:
	var o := {
		"data": V21Acc.lord_only_data(),
		"run_profile": V21Kit.profile(&"endless", diff),
		"start_time": START,
	}
	o.merge(extra, true)
	var s := GameSim.new(5, &"gunslinger", o)
	V21Acc.quiet_player(s)
	return s


## Lord'u doğar doğmaz öldürür; ilk Lord ölümüne kadar ilerler. Kayıt sözlüğü döner.
func _to_first_kill(s: GameSim) -> Dictionary:
	var w := V21Acc.watch(s)
	V21Acc.run_until(s, 60 * 40, func() -> bool: return V21Acc.lord_id(s) >= 0)
	assert_gte(V21Acc.slay_lord(s), 0, "ilk Lord doğdu ve öldürüldü")
	s.step(Vector2.ZERO)
	return w


func after_all() -> void:
	V21Acc.release()


func test_e1_endless_profile_sets_the_end_rules() -> void:
	var s := GameSim.new(5, &"gunslinger", {"run_profile": V21Kit.profile(&"endless", &"normal")})
	assert_eq(s.end_mode, GameSim.END_MODE_ENDLESS)
	assert_eq(s.end_time, 1200.0, "ilk Lord 1200'de")
	assert_true(s.lord_mode())


func test_s22_first_lord_death_is_a_win_but_the_run_goes_on() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _endless()
	var ended := []
	s.bus.run_ended.connect(func(w: bool, _st: Dictionary) -> void: ended.append(w))
	var w := _to_first_kill(s)
	assert_true(s.milestone_won, "kilometre taşı kazanma")
	assert_eq(s.lords_killed, 1)
	assert_false(s.lord_killed, "lord_killed Sonsuz'da set edilmez (K-C2)")
	assert_eq(s.state, GameSim.State.RUNNING, "koşu sürer")
	assert_true(ended.is_empty(), "run_ended yayılmadı")
	assert_true(V21Runs.run_won(s))
	assert_eq(w["milestone"][0], 1, "milestone_reached bir kez")
	assert_eq(w["slain"], [1], "lord_slain(1)")
	V21Acc.run_until(s, 600)
	assert_eq(s.state, GameSim.State.RUNNING, "10 sn sonra hâlâ koşuyor")


func test_s23_player_death_ends_the_run_and_keeps_the_win() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _endless()
	_to_first_kill(s)
	var got := []
	s.bus.run_ended.connect(func(w: bool, st: Dictionary) -> void: got.append([w, st]))
	s.hp = 0.0
	s.step(Vector2.ZERO)
	assert_eq(s.state, GameSim.State.LOST, "Sonsuz yalnız ölümle biter")
	assert_eq(got.size(), 1)
	assert_true(got[0][1]["milestone_won"], "sonuç sözlüğü kilometre taşını taşır")
	assert_eq(got[0][1]["lords_killed"], 1)
	assert_eq(got[0][1]["mode"], "endless")
	assert_true(V21Runs.run_won(s), "skor/başarım won=true görür")


func test_s24_lord_returns_300s_after_the_death_with_more_hp() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _endless()
	var w := _to_first_kill(s)
	var t_kill := s.time
	V21Acc.run_until(s, 60 * 299)
	assert_eq(w["spawns"].size(), 1, "299 sn içinde tekrar yok")
	V21Acc.run_until(s, 60 * 3, func() -> bool: return w["spawns"].size() > 1)
	assert_eq(w["spawns"].size(), 2, "ölümden ~300 sn sonra Lord döndü")
	assert_almost_eq(float(w["spawns"][1]) - t_kill, 300.0, 2.0)
	var id := V21Acc.lord_id(s)
	assert_gte(id, 0)
	assert_almost_eq(V21Acc.hp_of(s, id), 45000.0 * 1.5, 1.0, "ikinci Lord HP ×1,5 (Zor)")
	assert_eq(s.lords_killed, 1, "tekrar doğuş sayaç artırmaz")


func test_s25_second_kill_counts_but_the_milestone_fires_once() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _endless()
	var w := _to_first_kill(s)
	V21Acc.run_until(s, 60 * 305, func() -> bool: return w["spawns"].size() > 1)
	assert_gte(V21Acc.slay_lord(s), 0)
	s.step(Vector2.ZERO)
	assert_eq(s.lords_killed, 2)
	assert_eq(w["slain"], [1, 2], "lord_slain(n) sırayla")
	assert_eq(w["milestone"][0], 1, "milestone_reached yalnız ilk")
	assert_eq(s.state, GameSim.State.RUNNING)


func test_s26_a_lord_that_never_dies_does_not_repeat() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _endless()
	var w := V21Acc.watch(s)
	V21Acc.run_until(s, 60 * 400)
	assert_eq(w["spawns"].size(), 1, "ölmeyen Lord için tekrar yok")
	assert_false(s.milestone_won)


func test_s27_repeat_hp_is_capped() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _endless(&"hard")
	var w := _to_first_kill(s)
	var hp_seen: Array = []
	for k in 6:  # 1,5^n: 1,5 2,25 3,375 5,06 7,59 -> tavan 8 (11,4 olurdu)
		V21Acc.run_until(s, 60 * 320, func() -> bool: return w["spawns"].size() > k + 1)
		var id := V21Acc.lord_id(s)
		assert_gte(id, 0, "tekrar %d" % [k + 1])
		if id < 0:
			return
		hp_seen.append(V21Acc.hp_of(s, id))
		V21Acc.slay_lord(s)
		s.step(Vector2.ZERO)
	for hp: float in hp_seen:
		assert_lte(hp, 45000.0 * 8.0 + 1.0, "Lord HP tavanı ×8")
	assert_almost_eq(float(hp_seen[5]), 45000.0 * 8.0, 1.0, "6. tekrar tavanda")


func test_s28_simultaneous_lord_and_player_death_counts_the_milestone() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _endless()
	V21Acc.run_until(s, 60 * 40, func() -> bool: return V21Acc.lord_id(s) >= 0)
	V21Acc.slay_lord(s)
	s.hp = 0.0
	s.step(Vector2.ZERO)
	assert_true(s.milestone_won, "Lord-önce sırası korunur (K-C2)")
	assert_eq(s.state, GameSim.State.LOST)
	assert_true(V21Runs.run_won(s))


func test_s29_spawning_continues_past_1200_and_lord_death() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := (
		GameSim
		. new(
			9,
			&"gunslinger",
			{
				"data": GameData.load_default(),
				"run_profile": V21Kit.profile(&"endless", &"hard"),
				"start_time": 1250.0,
				"log_events": false,
			}
		)
	)
	V21Acc.quiet_player(s)
	var before := s.enemies.count + s.kills
	V21Acc.run_until(s, 60 * 20)
	assert_gt(s.enemies.count + s.kills, before + 20, "doğuş durmadı")


func test_s30_enrage_raises_contact_damage_only_in_endless_after_the_threshold() -> void:
	if V21Slice.require(self, "S"):
		return
	var loss := {}
	# 1190: ~2 sn'lik pencere eşiğin (1200) altında biter; 1200'de başlasa pencere eşiği aşardı.
	var cases := [["endless", 1100.0], ["endless", 1190.0], ["endless", 1500.0]]
	cases.append(["normal", 1500.0])
	for key in cases:
		var s := SimKit.make(
			3,
			{
				"data_kind": "quiet",
				"pickups": false,
				"run_profile": V21Kit.profile(StringName(key[0]), &"hard")
			}
		)
		s.debug_set_time(key[1])
		s.gun_damage = 0.0
		s.max_hp = 100000.0
		s.hp = 100000.0
		s.spawn_enemy(V21Acc.LORD, s.player_pos)  # Lord zaman eğrisinden muaf: yalnız enrage farkı kalır
		for i in 120:
			s.step(Vector2.ZERO)
		loss["%s@%d" % [key[0], int(key[1])]] = 100000.0 - s.hp
	assert_gt(loss["endless@1100"], 0.0, "Lord temas hasarı verdi (kurulum)")
	assert_almost_eq(loss["endless@1190"], loss["endless@1100"], 0.01, "eşik altında çarpan 1")
	assert_almost_eq(
		loss["endless@1500"] / loss["endless@1100"], 6.0, 0.05, "300 sn sonra ×(1+1,0·5)"
	)
	assert_almost_eq(loss["normal@1500"], loss["endless@1100"], 0.01, "Normal modda enrage yok")


func test_s31_endless_run_is_deterministic_through_a_repeat() -> void:
	if V21Slice.require(self, "S"):
		return
	var results := []
	for r in 2:
		var s := _endless(&"normal")
		var w := _to_first_kill(s)
		V21Acc.run_until(s, 60 * 310, func() -> bool: return w["spawns"].size() > 1)
		V21Acc.run_until(s, 120)
		results.append([s.state_hash(), s.lords_killed, s.time, s.rng_spawn.state])
	assert_eq(results[0], results[1], "aynı tohum ve betik: aynı durum")
