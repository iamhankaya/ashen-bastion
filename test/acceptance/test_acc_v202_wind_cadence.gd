extends GutTest
## Kabul (v2.0.2 K, W/Z/E): aktif ve evrim becerilerin atış ritmi (plan Arayüzler/6 `cooldown` sütunu). Ardışık iki atış arası
## adım sayısı = cooldown x 60 (+-2 adım), `fire_rate_mult` ile bölünür. Düşman menzilde sabit kukladır; tabanca susturulur.

const TOL := 2


## Ardışık `n` atışın başladığı adımlar. `probe` her adımda sim üzerinde "yeni atış var mı" döner.
func _casts(sim: GameSim, probe: Callable, n: int, max_steps: int) -> Array[int]:
	var out: Array[int] = []
	for _k in max_steps:
		sim.step(Vector2.ZERO)
		if probe.call():
			out.append(sim.step_count)
			if out.size() >= n:
				break
	return out


func _gap(c: Array[int]) -> int:
	return c[c.size() - 1] - c[c.size() - 2] if c.size() >= 2 else -1


func test_w1_delen_ruzgar_cooldown_by_level() -> void:
	if V202Slice.require(self, "W"):
		return
	for lv in [1, 5]:
		var want: float = ExpectedTablesV202.SKILLS["delen_ruzgar"]["levels"][lv - 1]["cooldown"]
		var sim := AccV202.zyfen({"delen_ruzgar": lv})
		AccV202.dummy(sim, Vector2(300, 0))
		var seen := {"last": 0}
		var probe := func() -> bool:
			var n := 0
			for i in sim.projectiles.count:
				if sim.projectiles.rad[i] == 10.0 and sim.projectiles.life[i] > 0.58:
					n += 1
			var fresh: bool = n > 0 and seen["last"] == 0
			seen["last"] = n
			return fresh
		var c := _casts(sim, probe, 3, int(want * 60.0 * 4.0))
		assert_eq(c.size(), 3, "sv%d: 3 atış" % lv)
		assert_between(
			_gap(c),
			int(round(want * 60.0)) - TOL,
			int(round(want * 60.0)) + TOL,
			"sv%d cooldown %.1f sn" % [lv, want]
		)


func test_w2_hava_bicaklari_cooldown_by_level() -> void:
	if V202Slice.require(self, "W"):
		return
	for lv in [1, 5]:
		var want: float = ExpectedTablesV202.SKILLS["hava_bicaklari"]["levels"][lv - 1]["cooldown"]
		var sim := AccV202.zyfen({"hava_bicaklari": lv})
		AccV202.dummy(sim, Vector2(300, 0))
		var seen := {"last": 0}
		var probe := func() -> bool:
			var fresh: bool = sim.projectiles.count > 0 and seen["last"] == 0
			seen["last"] = sim.projectiles.count
			return fresh
		var c := _casts(sim, probe, 3, int(want * 60.0 * 4.0))
		assert_eq(c.size(), 3, "sv%d: 3 atış" % lv)
		assert_between(
			_gap(c),
			int(round(want * 60.0)) - TOL,
			int(round(want * 60.0)) + TOL,
			"sv%d cooldown %.1f sn" % [lv, want]
		)


func test_z1_hortum_cooldown_by_level() -> void:
	if V202Slice.require(self, "Z"):
		return
	for lv in [1, 5]:
		var want: float = ExpectedTablesV202.SKILLS["hortum"]["levels"][lv - 1]["cooldown"]
		var sim := AccV202.zyfen({"hortum": lv})
		AccV202.dummy(sim, Vector2(300, 0))
		var seen := {"gen": 0}
		var probe := func() -> bool:
			var top := 0
			for i in sim.zones.count:
				top = maxi(top, sim.zones.gen[i])
			var fresh: bool = top > seen["gen"]
			seen["gen"] = top
			return fresh
		var c := _casts(sim, probe, 3, int(want * 60.0 * 5.0))
		assert_eq(c.size(), 3, "sv%d: 3 atış" % lv)
		assert_between(
			_gap(c),
			int(round(want * 60.0)) - TOL,
			int(round(want * 60.0)) + TOL,
			"sv%d cooldown %.1f sn" % [lv, want]
		)


func test_e1_gogun_mizragi_and_tufan_cooldowns() -> void:
	if V202Slice.require(self, "E"):
		return
	# Göğün Mızrağı: 1,8 sn; ilk mızrak ardışık salvoların başlangıcıdır
	var sim := AccV202.zyfen({})
	sim.debug_grant(&"gogun_mizragi")
	AccV202.dummy(sim, Vector2(300, 0))
	var seen := {"last": 0, "since": 999}
	var probe := func() -> bool:
		seen["since"] += 1
		var n := 0
		for i in sim.projectiles.count:
			if sim.projectiles.rad[i] == 10.0 and sim.projectiles.life[i] > 0.58:
				n += 1
		var fresh: bool = n > 0 and seen["last"] == 0 and seen["since"] > 30  # salvo içi 0,12 sn aralıklar sayılmaz
		seen["last"] = n
		if fresh:
			seen["since"] = 0
		return fresh
	var c := _casts(sim, probe, 3, 800)
	assert_eq(c.size(), 3, "3 salvo")
	assert_between(_gap(c), 108 - TOL, 108 + TOL, "Göğün Mızrağı cooldown 1,8 sn")
	# Tufan: 9,0 sn
	var t := AccV202.zyfen({})
	t.debug_grant(&"tufan")
	AccV202.dummy(t, Vector2(300, 0))
	var s2 := {"gen": 0}
	var probe2 := func() -> bool:
		var top := 0
		for i in t.zones.count:
			top = maxi(top, t.zones.gen[i])
		var fresh: bool = top > s2["gen"]
		s2["gen"] = top
		return fresh
	var c2 := _casts(t, probe2, 2, 9 * 60 * 3)  # 3 dev hortum aynı adımda doğar: tek atış sayılır
	assert_eq(c2.size(), 2, "2 Tufan atışı")
	assert_between(_gap(c2), 540 - TOL, 540 + TOL, "Tufan cooldown 9,0 sn")
