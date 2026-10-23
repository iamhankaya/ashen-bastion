extends GutTest
## Kabul: şarjör/doldurma ritmi (HUD'un okuduğu yüzey dahil). Plan "Magazine (kesin kurallar)".

const TARGET := Vector2(450, 0)


func _sim_with_target(extra: Dictionary = {}) -> GameSim:
	var sim := SimKit.make(21, extra)
	var id := SimKit.add_enemy(sim, &"sovalye_hayaleti", TARGET)
	assert_ne(id, -1, "hedef doğmadı")
	return sim


func test_reload_starts_after_sixth_shot_lasts_one_second_and_refills() -> void:
	var sim := _sim_with_target()
	SimKit.run(sim, 150)
	var starts := SimKit.events(sim, SimEvents.RELOAD_START)
	var ends := SimKit.events(sim, SimEvents.RELOAD_END)
	assert_gt(starts.size(), 0, "doldurma başlamalı")
	assert_gt(ends.size(), 0, "doldurma bitmeli")
	if starts.is_empty() or ends.is_empty():
		return
	assert_almost_eq(float(starts[0]["duration"]), 1.0, 0.01, "temel doldurma 1,0 sn")
	var gap := int(ends[0]["step"]) - int(starts[0]["step"])
	assert_between(gap, 59, 62, "doldurma ~60 adım sürer")
	var sixth: Dictionary = SimKit.events(sim, SimEvents.SHOT)[5]
	assert_between(
		int(starts[0]["step"]) - int(sixth["step"]), 0, 2, "doldurma 6. kurşunun hemen ardından"
	)


func test_no_shot_while_reloading_but_dry_fire_with_target() -> void:
	var sim := _sim_with_target()
	SimKit.run(sim, 150)
	var starts := SimKit.events(sim, SimEvents.RELOAD_START)
	var ends := SimKit.events(sim, SimEvents.RELOAD_END)
	if starts.is_empty() or ends.is_empty():
		fail_test("doldurma olayı yok")
		return
	var s0 := int(starts[0]["step"])
	var e0 := int(ends[0]["step"])
	for s in SimKit.events(sim, SimEvents.SHOT):
		var st := int(s["step"])
		assert_false(st > s0 and st < e0, "doldurma sırasında kurşun çıkmaz (adım %d)" % st)
	var dry := SimKit.events(sim, SimEvents.DRY_FIRE)
	assert_gt(dry.size(), 0, "doldururken hedef varsa kuru tetik olayı")
	var last_by_gun := {}
	for d in dry:
		var g := int(d["gun"])
		if last_by_gun.has(g):
			assert_gte(
				int(d["step"]) - int(last_by_gun[g]),
				29,
				"kuru tetik tabanca başına <= 0,5 sn'de bir"
			)
		last_by_gun[g] = int(d["step"])


func test_shooting_resumes_right_after_reload_end() -> void:
	var sim := _sim_with_target()
	SimKit.run(sim, 160)
	var ends := SimKit.events(sim, SimEvents.RELOAD_END)
	if ends.is_empty():
		fail_test("doldurma bitmedi")
		return
	var e0 := int(ends[0]["step"])
	var resumed := 0
	for s in SimKit.events(sim, SimEvents.SHOT):
		if int(s["step"]) >= e0:
			resumed = int(s["step"])
			break
	assert_gt(resumed, 0, "doldurma sonrası ateş devam etmeli")
	assert_lte(resumed - e0, 20, "doldurma bitince 0,33 sn içinde yeni kurşun")
	var second_cycle_first: Dictionary = {}
	for s in SimKit.events(sim, SimEvents.SHOT):
		if int(s["step"]) >= e0:
			second_cycle_first = s
			break
	assert_eq(int(second_cycle_first.get("index_in_mag", -1)), 1, "yeni şarjör indeks 1'den başlar")


func test_hud_signals_follow_the_cycle() -> void:
	var sim := _sim_with_target()
	var counts: Array = []
	var starts: Array = []
	var finishes: Array = [0]
	var last_bullets: Array = [0]
	sim.bus.magazine_changed.connect(func(c: int, cap: int) -> void: counts.append([c, cap]))
	sim.bus.reload_started.connect(func(d: float) -> void: starts.append(d))
	sim.bus.reload_finished.connect(func() -> void: finishes[0] += 1)
	sim.bus.last_bullet_fired.connect(func(_o: Vector2) -> void: last_bullets[0] += 1)
	SimKit.run(sim, 62 + 50)
	# İlk şarjör: 5,4,3,2,1,0 sırasıyla görülmeli (alt dizi), sonra 6'ya dolum.
	var seen: Array[int] = []
	for c in counts:
		seen.append(int(c[0]))
	var want: Array[int] = [5, 4, 3, 2, 1, 0, 6]
	var wi := 0
	for v in seen:
		if wi < want.size() and v == want[wi]:
			wi += 1
	assert_eq(wi, want.size(), "magazine_changed sırası 5,4,3,2,1,0,6 olmalı; görülen: %s" % [seen])
	for c in counts:
		assert_eq(int(c[1]), 6, "cap sinyali 6")
	assert_eq(starts.size(), 1, "reload_started bir kez")
	if not starts.is_empty():
		assert_almost_eq(float(starts[0]), 1.0, 0.01)
	assert_eq(finishes[0], 1, "reload_finished bir kez")
	assert_eq(last_bullets[0], 1, "last_bullet_fired döngü başına bir kez")


func test_magazine_state_readable_for_hud() -> void:
	var sim := _sim_with_target()
	assert_eq(sim.magazine.count, 6)
	assert_eq(sim.magazine.cap, 6)
	assert_false(sim.magazine.reloading)
	SimKit.run_until(sim, func() -> bool: return sim.magazine.reloading, 80)
	assert_true(sim.magazine.reloading, "6 kurşun sonra doldurma")
	assert_eq(sim.magazine.count, 0)
	assert_gt(sim.magazine.reload_left, 0.0)
	assert_almost_eq(sim.magazine.reload_total, 1.0, 0.01, "HUD halkası için toplam süre")
	SimKit.run_until(sim, func() -> bool: return not sim.magazine.reloading, 80)
	assert_false(sim.magazine.reloading)
	assert_eq(sim.magazine.count, 6, "doldurma bitince şarjör cap kadar dolu")


func test_hizli_doldurma_level5_halves_reload() -> void:
	var sim := _sim_with_target()
	sim.debug_grant(&"hizli_doldurma", 5)
	SimKit.run(sim, 120)
	var starts := SimKit.events(sim, SimEvents.RELOAD_START)
	assert_gt(starts.size(), 0)
	if not starts.is_empty():
		assert_almost_eq(float(starts[0]["duration"]), 0.5, 0.01, "sv5: 1,0 x (1-0,5) = 0,5 sn")
	var s1 := _sim_with_target()
	s1.debug_grant(&"hizli_doldurma", 1)
	SimKit.run(s1, 120)
	var st1 := SimKit.events(s1, SimEvents.RELOAD_START)
	if not st1.is_empty():
		assert_almost_eq(float(st1[0]["duration"]), 0.9, 0.01, "sv1: 0,9 sn")


func test_fazladan_mermi_level3_gives_nine_round_cycles() -> void:
	var sim := _sim_with_target()
	sim.debug_grant(&"fazladan_mermi", 3)
	assert_eq(sim.magazine.cap, 9, "cap = 6 + 3")
	SimKit.run(sim, 200)
	var ends := SimKit.events(sim, SimEvents.RELOAD_END)
	var starts := SimKit.events(sim, SimEvents.RELOAD_START)
	if starts.is_empty():
		fail_test("doldurma başlamadı")
		return
	var s0 := int(starts[0]["step"])
	var n := 0
	var last_idx := 0
	for s in SimKit.events(sim, SimEvents.SHOT):
		if int(s["step"]) <= s0:
			n += 1
			last_idx = int(s["index_in_mag"])
	assert_eq(n, 9, "ilk şarjörde 9 kurşun")
	assert_eq(last_idx, 9, "son kurşunun indeksi 9")
	assert_gt(ends.size(), 0)


func test_fazladan_mermi_level5_gives_eleven() -> void:
	var sim := _sim_with_target()
	sim.debug_grant(&"fazladan_mermi", 5)
	assert_eq(sim.magazine.cap, 11, "sv5: şarjör 11")


func test_cap_increase_during_level_up_choice_adds_rounds_immediately() -> void:
	var sim := SimKit.make(23)  # hedef yok: şarjör tam dolu kalır
	var forced: Array[StringName] = [&"fazladan_mermi", &"agir_kursun", &"hizli_parmak"]
	sim.debug_force_choices(forced)
	assert_true(SimKit.level_up_with(sim, 12), "seviye atlamalı")
	assert_true(sim.choose(0), "fazladan_mermi seçilir")
	assert_eq(sim.magazine.cap, 7, "cap 6 -> 7")
	assert_eq(sim.magazine.count, 7, "cap artışı mevcut mermiyi anında artırır")


func test_dry_fire_not_emitted_without_target_and_reload_not_started_when_full() -> void:
	var sim := SimKit.make(22)
	SimKit.run(sim, 90)
	assert_eq(SimKit.count_events(sim, SimEvents.DRY_FIRE), 0)
	assert_eq(SimKit.count_events(sim, SimEvents.RELOAD_START), 0)
	assert_ne(SimKit.add_enemy(sim, &"sovalye_hayaleti", TARGET), -1)
	SimKit.run(sim, 30)
	assert_gt(SimKit.count_events(sim, SimEvents.SHOT), 0, "hedef gelince ateş başlar")
