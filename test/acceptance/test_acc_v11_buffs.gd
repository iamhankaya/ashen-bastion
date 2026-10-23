extends GutTest
## Kabul (v1.1 D2): süreli etkiler - Öfke Barutu, Kızgın Namlu, Sonsuz Tambur (P9-P14). Dilim D2 bitmeden pending.
## Sayılar test/helpers/expected_tables_v11.gd'den; JSON okunmaz.

const SLICE := "D2"
const TARGET := Vector2(450, 0)
const DAMAGE := BuffManager.Kind.DAMAGE
const FIRE_RATE := BuffManager.Kind.FIRE_RATE
const UNLIMITED := BuffManager.Kind.UNLIMITED


## Uzakta ölmeyen bir hedef; oyuncu durağan ve sürekli ateş eder.
func _sim(seed_value: int = 1, extra: Dictionary = {}) -> GameSim:
	var o := {"data_kind": "quiet_pickups"}
	o.merge(extra, true)
	var sim := SimKit.make(seed_value, o)
	var id := SimKit.add_enemy(sim, &"sovalye_hayaleti", TARGET)
	sim.enemies.hp[EnemyPool.index_of(id)] = 1.0e9
	sim.enemies.max_hp[EnemyPool.index_of(id)] = 1.0e9
	sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
	return sim


func _take(sim: GameSim, kind_id: StringName) -> void:
	assert_gte(SimKit.pickup_near(sim, kind_id, 0.0), 0, "%s doğdu" % kind_id)
	sim.debug_collect_pickups()


func _shot_dmgs(sim: GameSim, from_step: int, to_step: int) -> Array[float]:
	var out: Array[float] = []
	for e in SimKit.events(sim, SimEvents.SHOT):
		if int(e["step"]) > from_step and int(e["step"]) <= to_step:
			out.append(float(e["dmg"]))
	return out


## want'tan 0,001'den fazla sapan eleman sayısı.
func _count_off(values: Array[float], want: float) -> int:
	var n := 0
	for v in values:
		if absf(v - want) > 0.001:
			n += 1
	return n


## Aynı şarjör içinde ardışık aynı-tabanca atışları arasındaki ortalama adım aralığı.
func _mean_gap(sim: GameSim, from_step: int, to_step: int) -> float:
	var last := {}
	var sum := 0
	var n := 0
	for e in SimKit.events(sim, SimEvents.SHOT):
		var st := int(e["step"])
		if st <= from_step or st > to_step:
			continue
		var g := int(e["gun"])
		var idx := int(e["index_in_mag"])
		if last.has(g) and idx > int(last[g][1]):
			sum += st - int(last[g][0])
			n += 1
		last[g] = [st, idx]
	return float(sum) / float(maxi(n, 1))


func test_p9_ofke_barutu_multiplies_shot_damage_for_exactly_720_steps() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(1)
	SimKit.run(sim, 90)
	var base := _shot_dmgs(sim, 0, sim.step_count)
	assert_gt(base.size(), 3, "önce atışlar var")
	var base_dmg := base[0]
	_take(sim, &"ofke_barutu")
	var t0 := sim.step_count
	var st := SimKit.last_event(sim, SimEvents.BUFF_START)
	assert_eq(st.get("kind"), &"damage")
	assert_almost_eq(float(st.get("duration", 0.0)), 12.0, 0.001, "buff_start.duration")
	assert_false(bool(st.get("refreshed", true)), "ilk alış yenileme değil")
	SimKit.run(sim, 700)
	var during := _shot_dmgs(sim, t0, sim.step_count)
	assert_gt(during.size(), 10)
	assert_eq(_count_off(during, base_dmg * 1.5), 0, "etkinken her shot.dmg = 1,5 x önceki")
	SimKit.run(sim, 80)
	var ends := SimKit.events(sim, SimEvents.BUFF_END)
	assert_eq(ends.size(), 1, "bitişte tek buff_end")
	if not ends.is_empty():
		assert_eq(ends[0]["kind"], &"damage")
		assert_between(int(ends[0]["step"]) - t0, 719, 721, "süre tam 720 adım (+-1)")
	if ends.is_empty():
		return
	var after := _shot_dmgs(sim, int(ends[0]["step"]) + 1, sim.step_count)
	assert_gt(after.size(), 2)
	assert_eq(_count_off(after, base_dmg), 0, "bitişten sonra her shot.dmg eski hasar")
	assert_eq(sim.buffs.left_steps[DAMAGE], 0)


func test_p9_damage_buff_multiplies_explosion_damage_too() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(2)
	var before := sim.stats.explosion_dmg_mult
	var before_b := sim.stats.bullet_dmg_mult
	_take(sim, &"ofke_barutu")
	assert_almost_eq(sim.stats.explosion_dmg_mult, before * 1.5, 0.0001, "patlama hasarı da x1,5")
	assert_almost_eq(sim.stats.bullet_dmg_mult, before_b * 1.5, 0.0001, "mermi hasarı x1,5")
	SimKit.run(sim, ExpectedTablesV11.BUFF_STEPS + 2)
	assert_almost_eq(sim.stats.explosion_dmg_mult, before, 0.0001, "bitişte eski")
	assert_almost_eq(sim.stats.bullet_dmg_mult, before_b, 0.0001)


func test_p10_kizgin_namlu_shortens_shot_interval_by_1_4() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(3)
	SimKit.run(sim, 300)
	var gap_base := _mean_gap(sim, 0, sim.step_count)
	assert_gt(gap_base, 5.0, "ölçülebilir temel aralık")
	_take(sim, &"kizgin_namlu")
	var t0 := sim.step_count
	SimKit.run(sim, 300)
	var gap_fast := _mean_gap(sim, t0, sim.step_count)
	assert_almost_eq(
		gap_fast / gap_base,
		1.0 / 1.4,
		0.05,
		"aralık 1/1,4'e iner (%.2f / %.2f)" % [gap_fast, gap_base]
	)
	assert_almost_eq(sim.buffs.mult[FIRE_RATE], 1.4, 0.0001)


func test_p11_same_buff_again_refreshes_to_12_seconds_not_17() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(4)
	_take(sim, &"ofke_barutu")
	SimKit.run(sim, 420)
	assert_between(sim.buffs.left_steps[DAMAGE], 298, 301, "5 sn kalan")
	_take(sim, &"ofke_barutu")
	assert_between(sim.buffs.left_steps[DAMAGE], 719, 720, "kalan = 12 sn (yığılmaz)")
	var starts := SimKit.events(sim, SimEvents.BUFF_START)
	assert_eq(starts.size(), 2)
	if starts.size() == 2:
		assert_true(bool(starts[1]["refreshed"]), "buff_start.refreshed = true")
	var mult_once := sim.stats.bullet_dmg_mult
	_take(sim, &"ofke_barutu")
	assert_almost_eq(sim.stats.bullet_dmg_mult, mult_once, 0.0001, "çarpan yığılmaz")


func test_p12_damage_and_fire_rate_run_as_independent_timers() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(5)
	var base_dmg := sim.stats.bullet_dmg_mult
	var base_rate := sim.stats.fire_rate_mult
	_take(sim, &"ofke_barutu")
	SimKit.run(sim, 300)
	_take(sim, &"kizgin_namlu")
	assert_between(sim.buffs.left_steps[DAMAGE], 419, 421, "hasar 420 adım kaldı")
	assert_between(sim.buffs.left_steps[FIRE_RATE], 719, 720, "hız tam süre")
	assert_almost_eq(sim.stats.bullet_dmg_mult, base_dmg * 1.5, 0.0001)
	assert_almost_eq(sim.stats.fire_rate_mult, base_rate * 1.4, 0.0001)
	SimKit.run(sim, 430)
	assert_eq(sim.buffs.left_steps[DAMAGE], 0, "hasar bitti")
	assert_gt(sim.buffs.left_steps[FIRE_RATE], 250, "hız sürüyor")
	assert_almost_eq(sim.stats.bullet_dmg_mult, base_dmg, 0.0001, "hasar çarpanı eski")
	assert_almost_eq(sim.stats.fire_rate_mult, base_rate * 1.4, 0.0001, "hız çarpanı sürer")
	assert_eq(SimKit.count_events(sim, SimEvents.BUFF_END), 1, "yalnız hasar bitti")


func test_p13_unlimited_keeps_magazine_full_and_rhythm_cycling() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(6)
	sim.debug_grant(&"son_mermi_patlar", 1)
	var cap := sim.magazine.cap
	_take(sim, &"sonsuz_tambur")
	var t0 := sim.step_count
	assert_eq(
		sim.buffs.left_steps[UNLIMITED], ExpectedTablesV11.UNLIMITED_STEPS, "10 sn = 600 adım"
	)
	var bad_full := 0
	for i in ExpectedTablesV11.UNLIMITED_STEPS - 2:
		sim.step(Vector2.ZERO)
		if sim.magazine.count != cap or sim.magazine.reloading:
			bad_full += 1
	assert_eq(bad_full, 0, "etkinken count == cap ve doldurma yok")
	assert_eq(SimKit.count_events(sim, SimEvents.RELOAD_START), 0, "reload_start yok")
	var shots := SimKit.events(sim, SimEvents.SHOT)
	assert_gte(shots.size(), 60, "atış hızı nominal (doldurma beklemesi yok)")
	var prev := 0
	var seq_bad := 0
	var last_flag_bad := 0
	for e in shots:
		var idx := int(e["index_in_mag"])
		if prev != 0 and idx != prev % cap + 1:
			seq_bad += 1
		if bool(e["is_last"]) != (idx == cap):
			last_flag_bad += 1
		prev = idx
	assert_eq(seq_bad, 0, "index_in_mag 1..cap döner")
	assert_eq(last_flag_bad, 0, "is_last yalnız index == cap")
	assert_gte(
		SimKit.count_events(sim, SimEvents.EXPLOSION),
		shots.size() / cap - 2,
		"son_mermi_patlar ritmi sürer"
	)
	assert_eq(sim.check_invariants().size(), 0)
	SimKit.run(sim, 10)
	assert_eq(SimKit.count_events(sim, SimEvents.BUFF_END), 1)
	assert_eq(sim.magazine.count, cap, "bitişte count == cap")
	assert_eq(SimKit.count_events(sim, SimEvents.RELOAD_START), 0, "bitişte doldurma tetiklenmez")
	assert_gt(sim.step_count, t0)


func test_p13_rhythm_skill_seken_mermi_keeps_working_while_unlimited() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(7)
	sim.debug_grant(&"seken_mermi", 1)
	_take(sim, &"sonsuz_tambur")
	SimKit.run(sim, 300)
	var hit_flags := 0
	for e in SimKit.events(sim, SimEvents.SHOT):
		if int(e["index_in_mag"]) % 3 == 0:
			hit_flags += 1
	assert_gt(hit_flags, 3, "ritim n. mermiler üretilir (kontrol: gözlem)")
	assert_eq(sim.magazine.count, sim.magazine.cap)


func test_p14_pickup_while_reloading_cancels_reload_and_refills() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(8)
	assert_true(SimKit.run_until(sim, func() -> bool: return sim.magazine.reloading, 600))
	var ends_before := SimKit.count_events(sim, SimEvents.RELOAD_END)
	_take(sim, &"sonsuz_tambur")
	assert_false(sim.magazine.reloading, "doldurma iptal")
	assert_eq(sim.magazine.count, sim.magazine.cap, "şarjör dolu")
	assert_eq(
		SimKit.count_events(sim, SimEvents.RELOAD_END), ends_before + 1, "reload_end yayınlanır"
	)


func test_p14_reload_end_hooks_see_the_cancelled_reload() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(9)
	var fired := [0]
	sim.bus.reload_finished.connect(func() -> void: fired[0] += 1)
	assert_true(SimKit.run_until(sim, func() -> bool: return sim.magazine.reloading, 600))
	_take(sim, &"sonsuz_tambur")
	assert_eq(fired[0], 1, "bus.reload_finished iptal anında yayınlanır (görünüm tutarlı)")
