extends GutTest
## PickupDirector: doÄŸuÅŸ zamanlamasÄ±, tÃ¼r/konum seÃ§imi, Ã¶mÃ¼r dolumu, skip_to, atlama (rng_pickup).

const SIM_OPTS := {"data_kind": "quiet", "log_events": true}


func _sim(seed_value: int = 1, opts: Dictionary = SIM_OPTS) -> GameSim:
	return SimKit.make(seed_value, opts)


func test_kind_distribution_follows_weights() -> void:
	var counts := {}
	var n := 200
	for s in n:
		var sim := _sim(1000 + s, {"data_kind": "quiet", "log_events": false})
		SimKit.run_until(
			sim, func() -> bool: return sim.pickups.count > 0, sim.pickup_director.next_step + 5
		)
		var id: StringName = sim.data.pickup_ids[sim.pickups.kind_idx[0]]
		counts[id] = int(counts.get(id, 0)) + 1
	var expect := {
		&"kizil_iksir": 0.30,
		&"cekim_tasi": 0.20,
		&"ofke_barutu": 0.15,
		&"kizgin_namlu": 0.15,
		&"kara_bomba": 0.15,
		&"sonsuz_tambur": 0.05,
	}
	for k in expect.keys():
		var frac := float(counts.get(k, 0)) / float(n)
		assert_almost_eq(frac, float(expect[k]), 0.09, "%s" % k)
