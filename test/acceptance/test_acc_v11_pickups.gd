extends GutTest
## Kabul (v1.1 D2): harita eklentileri - doğuş zamanı/konum/dağılım, ömür, toplama, iksir, çekim taşı, determinizm.
## Plan "Test stratejisi" P1-P8, P18-P21. Dilim D2 bitmeden pending. Etki testleri: test_acc_v11_buffs / _bomb.

const SLICE := "D2"
const HZ := 60
const FIRST_MIN := 30 * HZ
const FIRST_MAX := 45 * HZ
const GAP_MIN := 45 * HZ
const GAP_MAX := 60 * HZ
const DIST_MIN := 450.0
const DIST_MAX := 700.0
const CLEARANCE := 40.0
const SHORTCUT_SEEDS := 200
const DIST_STEP_SEEDS := 10
const DIST_SEEDS := 600
const WEIGHT_TOL := 5.0


func _sim(seed_value: int = 1, extra: Dictionary = {}) -> GameSim:
	var o := {"data_kind": "quiet_pickups"}
	o.merge(extra, true)
	return SimKit.make(seed_value, o)


## İlk doğuşu hızlandırır: bir adım atıp direktörün sonraki doğuşunu hemen sonrasına çeker (tür/konum çekimleri
## doğal akışla aynı rng_pickup sırasını izler). Dönüş: doğan eklenti indeksi (yoksa -1).
func _first_spawn_fast(sim: GameSim) -> int:
	sim.step(Vector2.ZERO)
	sim.pickup_director.next_step = sim.step_count + 1
	SimKit.run(sim, 3)
	return 0 if sim.pickups.count > 0 else -1


func test_p1_first_spawn_between_30_and_45_seconds_when_idle() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(1)
	SimKit.run(sim, 60 * HZ)
	var spawns := SimKit.steps_of(sim, SimEvents.PICKUP_SPAWN)
	assert_gte(spawns.size(), 1, "60 sn içinde en az bir pickup_spawn")
	if spawns.is_empty():
		return
	assert_between(spawns[0], FIRST_MIN, FIRST_MAX, "ilk doğuş adımı 30-45 sn")
	assert_eq(SimKit.count_events(sim, SimEvents.PICKUP_COLLECT), 0, "boşta oyuncu toplamaz")
	assert_lte(sim.pickups.count, 2, "yerdeki eklenti sayısı max_alive'ı aşmaz")


func test_p1_natural_first_spawn_window_holds_for_several_seeds() -> void:
	if V11Slice.require(self, SLICE):
		return
	var bad := PackedStringArray()
	for s in DIST_STEP_SEEDS:
		var sim := _sim(100 + s)
		SimKit.run_until(sim, func() -> bool: return sim.pickups.count > 0, FIRST_MAX + 5)
		var spawns := SimKit.steps_of(sim, SimEvents.PICKUP_SPAWN)
		if spawns.size() != 1 or spawns[0] < FIRST_MIN or spawns[0] > FIRST_MAX:
			bad.append("tohum %d: %s" % [100 + s, str(spawns)])
	assert_eq(bad.size(), 0, "ilk doğuş 30-45 sn: %s" % str(bad))


func test_p2_spawn_distance_and_clearance_over_many_seeds() -> void:
	if V11Slice.require(self, SLICE):
		return
	var bad := PackedStringArray()
	for s in SHORTCUT_SEEDS:
		var sim := _sim(1000 + s)
		if _first_spawn_fast(sim) < 0:
			bad.append("tohum %d: doğuş yok" % (1000 + s))
			continue
		var p: Vector2 = sim.pickups.pos[0]
		var d := p.distance_to(sim.player_pos)
		if d < DIST_MIN or d > DIST_MAX + CLEARANCE:
			bad.append("tohum %d: uzaklık %.1f" % [1000 + s, d])
		if sim.map.resolve(p, CLEARANCE).distance_to(p) >= 0.5:
			bad.append("tohum %d: katı harabeye clearance içinde" % (1000 + s))
	assert_eq(bad.size(), 0, "ilk 5 ihlal: %s" % str(bad.slice(0, 5)))


func test_p3_consecutive_spawn_gaps_are_45_to_60_seconds() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(7)
	SimKit.run(sim, 330 * HZ)
	var spawns := SimKit.steps_of(sim, SimEvents.PICKUP_SPAWN)
	assert_gte(spawns.size(), 5, "330 sn'de >= 5 doğuş")
	for i in range(1, spawns.size()):
		var gap := spawns[i] - spawns[i - 1]
		assert_between(gap, GAP_MIN - 1, GAP_MAX + 1, "aralık %d (alive < max_alive iken)" % i)


func test_p3_spawn_is_skipped_while_max_alive_reached_then_resumes() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(11)
	SimKit.run(sim, 1700)
	assert_eq(SimKit.count_events(sim, SimEvents.PICKUP_SPAWN), 0, "ilk doğuştan önce eklenti yok")
	var far := sim.player_pos + Vector2(2000, 0)
	assert_gte(sim.debug_spawn_pickup(&"kizil_iksir", far), 0)
	assert_gte(sim.debug_spawn_pickup(&"cekim_tasi", far + Vector2(50, 0)), 0)
	SimKit.run(sim, 4400 - sim.step_count)
	assert_eq(
		SimKit.count_events(sim, SimEvents.PICKUP_SPAWN), 2, "alive == max_alive: doğuş atlanır"
	)
	SimKit.run(sim, 6400 - sim.step_count)
	assert_gte(
		SimKit.count_events(sim, SimEvents.PICKUP_SPAWN),
		3,
		"yer açılınca doğuş sürer (atlama sonrası)"
	)


func test_p3_debug_set_time_does_not_burst_spawns() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(12)
	SimKit.run(sim, 100)
	sim.pickup_director.next_step = 10  # eskimiş
	sim.debug_set_time(sim.time + 5.0)
	assert_gte(
		sim.pickup_director.next_step, sim.step_count, "skip_to: geride kalan next_step çekilir"
	)
	SimKit.run(sim, 30)
	assert_lte(sim.pickups.count, 1, "birikmiş doğuş yok")


func test_p4_first_spawn_kind_distribution_matches_weights() -> void:
	if V11Slice.require(self, SLICE):
		return
	var counts := {}
	var n := 0
	for s in DIST_SEEDS:
		var sim := _sim(5000 + s)
		if _first_spawn_fast(sim) < 0:
			continue
		var kind: StringName = sim.data.pickup_ids[sim.pickups.kind_idx[0]]
		counts[kind] = int(counts.get(kind, 0)) + 1
		n += 1
	assert_eq(n, DIST_SEEDS, "her tohumda ilk doğuş")
	if n == 0:
		return
	for id in ExpectedTablesV11.PICKUP_ORDER:
		var got := 100.0 * float(counts.get(id, 0)) / float(maxi(n, 1))
		var want: float = ExpectedTablesV11.PICKUPS[id]["weight"]
		assert_between(
			got,
			want - WEIGHT_TOL,
			want + WEIGHT_TOL,
			"%s payı %%%.1f (ağırlık %.0f)" % [id, got, want]
		)


func test_p5_unclaimed_pickup_lives_exactly_1500_steps_then_expires() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(3)
	var idx := sim.debug_spawn_pickup(&"kizil_iksir", sim.player_pos + Vector2(900, 0))
	assert_gte(idx, 0)
	SimKit.run(sim, ExpectedTablesV11.LIFE_STEPS - 1)
	assert_eq(sim.pickups.count, 1, "1499. adımda hâlâ yerde")
	SimKit.run(sim, 2)
	assert_eq(sim.pickups.count, 0, "1501. adımda yok")
	var ex := SimKit.events(sim, SimEvents.PICKUP_EXPIRE)
	assert_eq(ex.size(), 1, "tek pickup_expire")
	if not ex.is_empty():
		assert_eq(ex[0]["kind_id"], &"kizil_iksir")
		assert_between(int(ex[0]["step"]), 1500, 1501, "ömür 1500 adım")


func test_p5_expire_signal_matches_event() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(4)
	var got: Array = []
	sim.bus.pickup_expired.connect(func(k: StringName) -> void: got.append(k))
	sim.debug_spawn_pickup(&"kara_bomba", sim.player_pos + Vector2(900, 0))
	SimKit.run(sim, 1502)
	assert_eq(got, [&"kara_bomba"])


func test_p6_collect_radius_72_inclusive_73_not() -> void:
	if V11Slice.require(self, SLICE):
		return
	var a := _sim(5)
	SimKit.pickup_near(a, &"kizil_iksir", 72.0)
	SimKit.run(a, 1)
	assert_eq(SimKit.count_events(a, SimEvents.PICKUP_COLLECT), 1, "72 px: toplanır (<= dahil)")
	assert_eq(a.pickups.count, 0)
	var b := _sim(5)
	SimKit.pickup_near(b, &"kizil_iksir", 73.0)
	SimKit.run(b, 10)
	assert_eq(SimKit.count_events(b, SimEvents.PICKUP_COLLECT), 0, "73 px: toplanmaz")
	assert_eq(b.pickups.count, 1)


func test_p6_xp_magnet_radius_does_not_pull_pickups() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(6)
	SimKit.pickup_near(sim, &"kizil_iksir", 100.0)  # XP çekim yarıçapı 110 içinde, toplama 72 dışında
	var before := sim.pickups.pos[0]
	SimKit.run(sim, 120)
	assert_eq(sim.pickups.count, 1, "XP mıknatısı eklentiyi çekmez")
	assert_eq(sim.pickups.pos[0], before, "eklenti yerinden oynamaz")


func test_p6_walking_into_pickup_collects_it_via_normal_step_path() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(8)
	SimKit.pickup_near(sim, &"kizil_iksir", 300.0)
	var ok := SimKit.run_until(
		sim, func() -> bool: return sim.pickups.count == 0, 120, Vector2.RIGHT
	)
	assert_true(ok, "yürüyerek alınır (debug_collect kullanılmadan)")
	assert_eq(SimKit.count_events(sim, SimEvents.PICKUP_COLLECT), 1)


func test_p6_several_pickups_collected_in_one_step() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(9)
	SimKit.pickup_near(sim, &"kizil_iksir", 10.0)
	SimKit.pickup_near(sim, &"cekim_tasi", 20.0)
	SimKit.pickup_near(sim, &"ofke_barutu", 30.0)
	SimKit.run(sim, 1)
	var ev := SimKit.events(sim, SimEvents.PICKUP_COLLECT)
	assert_eq(ev.size(), 3, "bir adımda birden çok toplama")
	var kinds := {}
	for e in ev:
		kinds[e["kind_id"]] = true
	# Sıra: havuz indeksi artan (swap-remove ile son eleman boşalan indekse geçer); tür kümesi tam olmalı.
	assert_eq(kinds.size(), 3, "üç ayrı tür toplandı")
	assert_true(
		kinds.has(&"kizil_iksir") and kinds.has(&"cekim_tasi") and kinds.has(&"ofke_barutu")
	)
	assert_eq(sim.pickups.count, 0)


func test_p7_iksir_heals_25_and_never_exceeds_max_hp() -> void:
	if V11Slice.require(self, SLICE):
		return
	for case in [[50.0, 75.0], [90.0, 100.0], [100.0, 100.0]]:
		var sim := _sim(13)
		sim.hp = case[0]
		SimKit.pickup_near(sim, &"kizil_iksir", 0.0)
		sim.debug_collect_pickups()
		assert_almost_eq(sim.hp, case[1], 0.001, "hp %.0f -> %.0f" % [case[0], case[1]])
		assert_eq(sim.pickups.count, 0, "can doluyken de tüketilir")
		assert_eq(sim.check_invariants().size(), 0, "check_invariants boş")


func test_p8_cekim_tasi_pulls_every_gem_present_not_later_ones() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(14)
	for k in 200:
		sim.gems.drop(sim.player_pos + Vector2.from_angle(TAU * k / 200.0) * 3000.0, 1)
	SimKit.pickup_near(sim, &"cekim_tasi", 0.0)
	sim.debug_collect_pickups()
	var unpulled := 0
	for i in sim.gems.count:
		if sim.gems.pulled[i] != 1:
			unpulled += 1
	assert_eq(sim.gems.count, 200)
	assert_eq(unpulled, 0, "havuzdaki tüm taşlar pulled=1")
	sim.gems.drop(sim.player_pos + Vector2(0, 3000), 1)
	var late := sim.gems.count - 1
	assert_eq(sim.gems.pulled[late], 0, "sonradan düşen taş çekilmez")
	var rng := Bots.make_rng(14)
	Bots.play(sim, Bots.IDLE, 700, rng)
	assert_gte(SimKit.count_events(sim, SimEvents.LEVEL_UP), 4, "çok sayıda seviye atlama (kuyruk)")
	assert_eq(sim.check_invariants().size(), 0, "XP korunumu bozulmadı")
	assert_eq(sim.gems.count, 1, "yalnız sonradan düşen taş kalır")
	assert_eq(sim.gems.pulled[0], 0)


func test_p18_same_seed_greedy_pickup_bot_has_identical_hash_every_300_steps() -> void:
	if V11Slice.require(self, SLICE):
		return
	var runs: Array = []
	var collected: Array[int] = []
	for r in 2:
		var sim := _sim(21)
		SimKit.godmode(sim)
		var rng := Bots.make_rng(21)
		var hashes: Array[int] = []
		for seg in 14:
			Bots.play(sim, Bots.GREEDY_PICKUP, 300, rng)
			hashes.append(sim.state_hash())
		runs.append(hashes)
		collected.append(SimKit.count_events(sim, SimEvents.PICKUP_COLLECT))
	assert_eq(runs[0], runs[1], "state_hash her 300 adımda eşit")
	assert_gte(collected[0], 1, "bot en az bir eklenti topladı (test kapsamı)")
	assert_eq(collected[0], collected[1])


func test_p18_real_data_greedy_pickup_bot_is_deterministic() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hashes: Array[int] = []
	for r in 2:
		var sim := SimKit.make(33, {"data_kind": "real", "log_events": false})
		SimKit.godmode(sim)
		var rng := Bots.make_rng(33)
		Bots.play(sim, Bots.GREEDY_PICKUP, 4800, rng)
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1], "gerçek veride 80 sn aynı hash")


func test_p19_pickups_on_off_leave_the_four_old_rng_streams_and_enemies_equal() -> void:
	if V11Slice.require(self, SLICE):
		return
	var summaries: Array = []
	for on in [true, false]:
		var sim := SimKit.make(42, {"data_kind": "real", "pickups": on, "log_events": false})
		SimKit.godmode(sim)
		SimKit.run(sim, 300 * HZ)
		var pos_sum := 0.0
		var ids := sim.alive_ids()
		for id in ids:
			pos_sum += sim.enemies.pos[EnemyPool.index_of(id)].length()
		(
			summaries
			. append(
				{
					"spawn": sim.rng_spawn.state,
					"choice": sim.rng_choice.state,
					"map": sim.rng_map.state,
					"combat": sim.rng_combat.state,
					"alive": ids.size(),
					"pos": snappedf(pos_sum, 0.01),
				}
			)
		)
	assert_eq(summaries[0], summaries[1], "eklentili/eklentisiz: eski dört akış ve düşmanlar eşit")


func test_p21_start_time_does_not_grant_free_pickups() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(61, {"start_time": 900.0})
	SimKit.run(sim, 1000)
	assert_eq(sim.pickups.count, 0, "start_time koşusunda ilk 1000 adımda eklenti yok")
	SimKit.run(sim, 2800 - sim.step_count)
	var spawns := SimKit.steps_of(sim, SimEvents.PICKUP_SPAWN)
	assert_gte(spawns.size(), 1)
	if not spawns.is_empty():
		assert_gte(spawns[0], FIRST_MIN, "ilk doğuş step_count'a (0'dan) göre >= 30 sn")
		assert_lte(spawns[0], FIRST_MAX)


func test_pickups_opt_false_never_spawns() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(62, {"pickups": false})
	SimKit.run(sim, 3000)
	assert_eq(SimKit.count_events(sim, SimEvents.PICKUP_SPAWN), 0)
	assert_eq(sim.pickups.count, 0)
