extends GutTest
## Kabul: hasar kuralları (zırh, alan, temas), öldürme ve XP taşı. Plan "Hasar kuralları" + "Kimlik".
## Sovalye hayaleti (zırh 3, temas 18, can 220) sim içinde kısa sürede ölmez; temas testleri bunu kullanır.


func test_armor_formula_is_max_of_flat_and_twenty_percent() -> void:
	assert_almost_eq(DamageSystem.after_armor(15.0, 3.0), 12.0, 0.0001)
	assert_almost_eq(DamageSystem.after_armor(15.0, 0.0), 15.0, 0.0001)
	assert_almost_eq(DamageSystem.after_armor(10.0, 9.0), 2.0, 0.0001, "taban %20")
	assert_almost_eq(
		DamageSystem.after_armor(15.0, 100.0), 3.0, 0.0001, "zırh ne olursa olsun en az %20"
	)
	assert_almost_eq(DamageSystem.after_armor(100.0, 6.0), 94.0, 0.0001)


func test_bullet_hit_on_armored_enemy_applies_armor() -> void:
	var sim := SimKit.make(111)
	var id := SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(400, 0))
	assert_ne(id, -1)
	SimKit.run(sim, 60)
	var hits := 0
	for d in SimKit.events(sim, SimEvents.DAMAGE):
		if str(d["kind"]) == "bullet" and int(d["target"]) == id:
			hits += 1
			assert_almost_eq(float(d["raw"]), 15.0, 0.001, "ham hasar 15")
			assert_almost_eq(float(d["amount"]), 12.0, 0.001, "zırh 3 sonrası 12")
	assert_gt(hits, 0, "mermi isabet etmeli")
	assert_lt(SimKit.enemy_hp(sim, id), 220.0, "can düşer")


func test_bullet_hit_on_unarmored_enemy_deals_full_damage() -> void:
	var sim := SimKit.make(112)
	var id := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(300, 0))
	assert_ne(id, -1)
	SimKit.run(sim, 40)
	for d in SimKit.events(sim, SimEvents.DAMAGE):
		if str(d["kind"]) == "bullet":
			assert_almost_eq(float(d["amount"]), float(d["raw"]), 0.001, "zırhsız: tam hasar")


func test_contact_hurts_immediately_then_every_0_6_seconds() -> void:
	var sim := SimKit.make(113)
	var hits: Array = []
	var clock := [0]  # lambda sim'i yakalamaz (sim <-> bus döngüsü sızıntı yapar)
	sim.bus.player_damaged.connect(func(a: float, h: float) -> void: hits.append([clock[0], a, h]))
	assert_ne(SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(30, 0)), -1)
	for i in 115:
		clock[0] = sim.step_count + 1
		sim.step(Vector2.ZERO)
	assert_gte(hits.size(), 3, "~115 adımda 3-4 temas tick'i")
	if hits.size() < 3:
		return
	assert_lte(int(hits[0][0]), 2, "ilk tick temasta HEMEN")
	assert_almost_eq(float(hits[0][1]), 18.0, 0.2, "temas hasarı 18 x zorluk çarpanı(~1)")
	assert_almost_eq(float(hits[0][2]), 100.0 - float(hits[0][1]), 0.001, "bildirilen kalan can")
	for i in range(1, hits.size()):
		var gap := int(hits[i][0]) - int(hits[i - 1][0])
		assert_between(gap, 35, 38, "tick aralığı 0,6 sn = 36 adım (tick %d)" % i)


func test_at_most_four_contacts_count_per_tick() -> void:
	var sim := SimKit.make(114)
	for i in 6:
		assert_ne(SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(20 + i * 4, 10 - i * 3)), -1)
	SimKit.run(sim, 2)
	assert_almost_eq(
		sim.hp, 100.0 - 4.0 * 18.0, 0.8, "6 temas var, tick başına en çok 4 sayılır (4 x 18 = 72)"
	)


func test_contact_damage_scales_with_time() -> void:
	var sim := SimKit.make(115, {"start_time": 600.0})
	assert_ne(SimKit.add_enemy(sim, &"curumus_piyade", Vector2(25, 0)), -1)
	SimKit.run(sim, 2)
	# piyade temas 6; 10. dk hasar çarpanı 1,4 -> 8,4
	assert_almost_eq(100.0 - sim.hp, 6.0 * Difficulty.enemy_dmg_mult(sim.time), 0.2)
	assert_gt(100.0 - sim.hp, 8.0)


func test_no_contact_no_damage_until_contact_then_immediate_tick() -> void:
	var sim := SimKit.make(116)
	var id := SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(600, 0))
	assert_ne(id, -1)
	SimKit.run(sim, 60)
	assert_eq(sim.hp, 100.0, "temas yokken hasar yok")
	if id == -1:
		return
	sim.enemies.pos[EnemyPool.index_of(id)] = Vector2(25, 0)
	SimKit.run(sim, 2)
	assert_lt(sim.hp, 100.0, "temas başlar başlamaz ilk tick (zamanlayıcı hazır bekliyordu)")


func test_kill_drops_gem_with_enemy_xp_and_collecting_gives_xp() -> void:
	var sim := SimKit.make(117)
	assert_ne(SimKit.add_enemy(sim, &"curumus_piyade", Vector2(350, 0)), -1)
	assert_true(
		SimKit.run_until(
			sim, func() -> bool: return SimKit.count_events(sim, SimEvents.KILL) > 0, 240
		),
		"piyade ölmeli"
	)
	assert_eq(sim.kills, 1)
	var kill := SimKit.last_event(sim, SimEvents.KILL)
	assert_eq(kill.get("type", &""), &"curumus_piyade")
	var dropped := SimKit.last_event(sim, SimEvents.GEM_DROPPED)
	assert_eq(int(dropped.get("value", -1)), 1, "piyade XP'si 1")
	assert_eq(sim.xp, 0, "taş toplanana kadar XP yok")
	var kill_pos: Vector2 = kill.get("pos", Vector2.ZERO)
	var dir := (kill_pos - sim.player_pos).normalized()
	assert_true(
		SimKit.run_until(
			sim,
			func() -> bool: return SimKit.count_events(sim, SimEvents.GEM_COLLECTED) > 0,
			240,
			dir
		),
		"taşa yürüyünce toplanmalı"
	)
	assert_eq(int(SimKit.last_event(sim, SimEvents.GEM_COLLECTED).get("value", -1)), 1)
	assert_eq(sim.xp, 1)


func test_kills_counter_matches_kill_events() -> void:
	var sim := SimKit.make(118)
	for i in 5:
		SimKit.add_enemy(sim, &"curumus_piyade", Vector2(200 + i * 30, (i - 2) * 40))
	SimKit.run(sim, 300)
	assert_eq(sim.kills, SimKit.count_events(sim, SimEvents.KILL))
	assert_gt(sim.kills, 0)
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_higher_xp_enemy_drops_proportional_gem() -> void:
	var sim := SimKit.make(119)
	SimKit.godmode(sim)
	assert_ne(SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(300, 0)), -1)
	sim.debug_grant(&"cift_tabanca", 5)
	assert_true(
		SimKit.run_until(
			sim, func() -> bool: return SimKit.count_events(sim, SimEvents.KILL) > 0, 900
		),
		"sovalye ölmeli"
	)
	assert_eq(
		int(SimKit.last_event(sim, SimEvents.GEM_DROPPED).get("value", -1)),
		5,
		"şövalye hayaleti XP 5"
	)
