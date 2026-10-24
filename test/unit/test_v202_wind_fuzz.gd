extends GutTest
## U3 fuzz: rüzgar yüklü Zyfen, 3 bot politikası x 2 tohum; her 60 adımda bölge/düşman değişmezleri (sonlu değerler, CAP,
## yer düşmanı katı harabeye gömülmez, NaN/sonsuz yok) ve sim değişmezleri.

const STEPS := 1800
const LOAD := {
	"tufan": 1,
	"hortum": 5,
	"girdap": 5,
	"hava_cebi": 5,
	"nefes_dalgasi": 5,
	"bolunen_kesik": 5,
	"hava_bicaklari": 2,
	"furtina_gozu": 5,
}


func test_wind_load_keeps_zone_and_enemy_invariants_under_bot_movement() -> void:
	for policy in Bots.POLICIES:
		for s in [11, 29]:
			var sim := SimKit.make(
				s, {"character": &"zyfen", "data_kind": "real", "log_events": false}
			)
			for k in LOAD:
				sim.debug_grant(StringName(k), int(LOAD[k]))
			var rng := Bots.make_rng(s)
			var bad := PackedStringArray()
			var n := 0
			while n < STEPS and sim.state in [GameSim.State.RUNNING, GameSim.State.LEVEL_UP]:
				sim.hp = sim.max_hp
				if sim.state == GameSim.State.LEVEL_UP:
					Bots.choose(sim, rng)
					continue
				sim.step(Bots.move(policy, sim))
				n += 1
				if n % 60 == 0 and bad.size() < 5:
					bad.append_array(WindKit.zone_violations(sim))
					bad.append_array(sim.check_invariants())
			assert_eq(n, STEPS, "%s/%d" % [policy, s])
			assert_eq(bad, PackedStringArray(), "%s/%d ihlaller" % [policy, s])
			assert_eq(sim.fx.zone_dropped, 0, "%s/%d bölge kaybı" % [policy, s])
