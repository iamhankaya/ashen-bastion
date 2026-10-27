extends GutTest
## Kabul (v2.1 S): profil/regresyon ve zorluk düğmelerinin etkisi (spec senaryo 1 ve K1 düğmeleri: düşman HP, temas hasarı,
## doğuş yoğunluğu, XP, Lord HP; oyuncu HP düğmesi yok). Sözleşme: docs/data-schema.md v2.1, K-C7, K-C10.
## Regresyon testleri (r1-r3) C'den beri gerçek kodda koşar (referans-fixture karşılaştırması test_v21_contract_golden_ref'te); çarpan testleri (s1-s8) V21Slice "S" açılana dek pending.
## Kazanma/Lord'a ulaşma ORANI (senaryo 2-5) istatistiktir: balance.yml ölçümüdür, kapı değil (rapor: Kapsam).

const STEPS := 600
const PIYADE := &"curumus_piyade"
const LORD := &"kale_lordu"


func _sim(profile: RunProfile, seed_value: int = 7, extra: Dictionary = {}) -> GameSim:
	var o := {"data": GameData.load_default()}
	if profile != null:
		o["run_profile"] = profile
	o.merge(extra, true)
	return GameSim.new(seed_value, &"gunslinger", o)


func _run_steps(sim: GameSim, n: int) -> void:
	var i := 0
	while i < n and sim.state != GameSim.State.WON and sim.state != GameSim.State.LOST:
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			continue
		sim.step(GoldenKit.move_at(i))
		i += 1


func _enemy_hp(sim: GameSim, id: int) -> float:
	return sim.enemies.hp[EnemyPool.index_of(id)]


# --- Senaryo 1: regresyon (legacy = profilsiz) -------------------------------------------------


func test_r1_profileless_equals_legacy_profile_state_hash() -> void:
	var a := _sim(null)
	var b := _sim(RunProfile.legacy())
	_run_steps(a, STEPS)
	_run_steps(b, STEPS)
	assert_gt(a.step_count, 0, "sim ilerledi")
	assert_eq(a.state_hash(), b.state_hash(), "opts yok == run_profile=legacy()")
	assert_eq(a.rng_spawn.state, b.rng_spawn.state)


func _late(seed_value: int, start: float, profile: RunProfile) -> Array:
	# Ölümsüz oyuncu: Lord doğuşu (1200) ve Lord temas hasarı yolu kesin koşar.
	var o := {"data": GameData.load_default(), "start_time": start}
	if profile != null:
		o["run_profile"] = profile
	var s := GameSim.new(seed_value, &"gunslinger", o)
	s.max_hp = 1.0e9
	s.hp = 1.0e9
	var lords := [0]
	s.bus.boss_spawned.connect(func(_t: StringName) -> void: lords[0] += 1)
	_run_steps(s, 1800)
	return [s.state_hash(), s.rng_combat.state, 1.0e9 - s.hp, lords[0]]


func test_r2_file_normal_hard_is_legacy_equivalent_in_a_late_game_hash() -> void:
	for c in [[11, 600.0], [23, 1190.0]]:
		var bare := _late(c[0], c[1], null)
		var prof := _late(c[0], c[1], V21Kit.profile(&"normal", &"hard"))
		assert_eq(prof, bare, "tohum %s, başlangıç %s" % [c[0], c[1]])
	var lord_run := _late(23, 1190.0, null)
	assert_gt(lord_run[3], 0, "1190'dan başlayan senaryoda Lord doğar (kurulum)")
	assert_gt(lord_run[2], 0.0, "temas hasarı alındı (kurulum)")


func test_r3_default_selection_is_normal_normal_and_not_legacy() -> void:
	var sel := RunProfiles.default_selection(V21Kit.cfg())
	assert_eq([str(sel["mode"]), str(sel["diff"])], ["normal", "normal"])
	assert_false(V21Kit.profile(&"normal", &"normal").is_legacy(), "Normal çarpanları 1 değil")


# --- Zorluk düğmeleri (S dilimi) ---------------------------------------------------------------


func test_s1_enemy_hp_follows_the_difficulty_multiplier() -> void:
	if V21Slice.require(self, "S"):
		return
	var hard := _sim(V21Kit.profile(&"normal", &"hard"))
	var easy := _sim(V21Kit.profile(&"normal", &"easy"))
	var norm := _sim(V21Kit.profile(&"normal", &"normal"))
	var h := _enemy_hp(hard, hard.spawn_enemy(PIYADE, Vector2(200, 0)))
	var e := _enemy_hp(easy, easy.spawn_enemy(PIYADE, Vector2(200, 0)))
	var n := _enemy_hp(norm, norm.spawn_enemy(PIYADE, Vector2(200, 0)))
	assert_gt(h, 0.0)
	assert_almost_eq(e / h, 0.70, 0.01, "Kolay düşman HP ×0,70")
	assert_almost_eq(n / h, 0.85, 0.01, "Normal düşman HP ×0,85")


func test_s2_lord_hp_uses_lord_hp_and_mode_only_not_enemy_hp() -> void:
	if V21Slice.require(self, "S"):
		return
	var base := _sim(V21Kit.profile(&"normal", &"hard"))
	var lord_base := _enemy_hp(base, base.spawn_enemy(LORD, Vector2(300, 0)))
	assert_eq(lord_base, 45000.0, "Zor/Normal Lord = bugünkü 45000")
	var cases := [
		[&"normal", &"easy", 0.70],
		[&"normal", &"normal", 0.85],
		[&"quick", &"hard", 0.50],
		[&"quick", &"easy", 0.50 * 0.70],
	]
	for c in cases:
		var s := _sim(V21Kit.profile(c[0], c[1]))
		var hp := _enemy_hp(s, s.spawn_enemy(LORD, Vector2(300, 0)))
		assert_almost_eq(hp / lord_base, c[2], 0.005, "Lord HP %s/%s" % [c[0], c[1]])


func _contact_loss(profile: RunProfile) -> float:
	var s := SimKit.make(3, {"data_kind": "quiet", "pickups": false, "run_profile": profile})
	s.gun_damage = 0.0  # düşman ölmesin: tick sayısı iki koşuda aynı kalsın
	s.max_hp = 100000.0
	s.hp = 100000.0
	var id := s.spawn_enemy(PIYADE, s.player_pos)
	assert_gte(id, 0)
	for i in 120:
		s.step(Vector2.ZERO)
	return 100000.0 - s.hp


func test_s3_contact_damage_follows_the_difficulty_multiplier() -> void:
	if V21Slice.require(self, "S"):
		return
	var hard := _contact_loss(V21Kit.profile(&"normal", &"hard"))
	var easy := _contact_loss(V21Kit.profile(&"normal", &"easy"))
	var norm := _contact_loss(V21Kit.profile(&"normal", &"normal"))
	assert_gt(hard, 0.0, "piyade temas hasarı verdi (kurulum)")
	assert_almost_eq(easy / hard, 0.55, 0.02, "Kolay temas ×0,55")
	assert_almost_eq(norm / hard, 0.75, 0.02, "Normal temas ×0,75")


func _alive_after(profile: RunProfile, seconds: float) -> int:
	var s := SimKit.make(
		9, {"data_kind": "real", "pickups": false, "log_events": false, "run_profile": profile}
	)
	s.gun_damage = 0.0
	s.max_hp = 1.0e9
	s.hp = 1.0e9
	for i in int(seconds / GameSim.STEP):
		s.step(Vector2.ZERO)
	return s.enemies.count + s.kills


func test_s4_spawn_density_scales_the_number_of_spawns() -> void:
	if V21Slice.require(self, "S"):
		return
	var hard := _alive_after(V21Kit.profile(&"normal", &"hard"), 40.0)
	var easy := _alive_after(V21Kit.profile(&"normal", &"easy"), 40.0)
	var norm := _alive_after(V21Kit.profile(&"normal", &"normal"), 40.0)
	assert_gt(hard, 20, "yeterli örnek (kurulum)")
	assert_between(float(easy) / hard, 0.60, 0.80, "Kolay doğuş ×0,70 (%d/%d)" % [easy, hard])
	assert_between(float(norm) / hard, 0.75, 0.95, "Normal doğuş ×0,85 (%d/%d)" % [norm, hard])


func _xp_dropped(profile: RunProfile, kills: int) -> int:
	var s := SimKit.make(5, {"data_kind": "quiet", "pickups": false, "run_profile": profile})
	for i in kills:
		var id := s.spawn_enemy(PIYADE, Vector2(100 + i, 0))
		s.damage_enemy(id, 1.0e9, &"bullet")
	return s.gems.dropped_total


func test_s5_xp_carry_loses_no_fraction_over_a_series() -> void:
	if V21Slice.require(self, "S"):
		return
	var base := _xp_dropped(V21Kit.profile(&"normal", &"hard"), 8)
	assert_gt(base, 0, "piyade taş düşürür (kurulum)")
	assert_eq(_xp_dropped(V21Kit.profile(&"normal", &"easy"), 8), base * 5 / 4, "Kolay ×1,25")
	assert_eq(_xp_dropped(V21Kit.profile(&"quick", &"hard"), 8), base * 3 / 2, "Hızlı ×1,5")
	assert_eq(_xp_dropped(V21Kit.profile(&"normal", &"normal"), 8), base, "Normal ×1,0")


func test_s6_xp_multiplier_never_loses_a_gem_on_a_single_kill() -> void:
	if V21Slice.require(self, "S"):
		return
	# Tek öldürmede birikimli kesir: değer xp_value'dan küçük olmaz (roundi reddedildi, K-C7).
	var one_hard := _xp_dropped(V21Kit.profile(&"normal", &"hard"), 1)
	assert_gte(_xp_dropped(V21Kit.profile(&"normal", &"easy"), 1), one_hard)
	assert_gte(_xp_dropped(V21Kit.profile(&"quick", &"hard"), 1), one_hard)


func test_s7_no_difficulty_changes_the_player_hp() -> void:
	if V21Slice.require(self, "S"):
		return
	for d in [&"easy", &"normal", &"hard"]:
		var s := _sim(V21Kit.profile(&"normal", d))
		assert_eq(s.max_hp, _sim(null).max_hp, "oyuncu HP düğmesi yok: %s" % d)


func test_s8_profile_runs_are_deterministic() -> void:
	if V21Slice.require(self, "S"):
		return
	for pair in [[&"quick", &"easy"], [&"normal", &"normal"]]:
		var a := _sim(V21Kit.profile(pair[0], pair[1]), 21)
		var b := _sim(V21Kit.profile(pair[0], pair[1]), 21)
		_run_steps(a, 900)
		_run_steps(b, 900)
		assert_eq(a.state_hash(), b.state_hash(), "%s/%s" % pair)
