extends GutTest
## U3 determinizm: aynı tohum aynı hash; gözlemci (FxRenderer + WindRenderer) bağlı/bağsız aynı hash; Tufan'lı altın koşu.
## Zyfen, 3 politika x 2 tohum x 2400 adım (rüzgar becerileri dolu). Rüzgar sim'e yazmaz (yalnız okur).

const STEPS := 2400
const SEEDS: Array[int] = [3, 5]
const LOAD := {
	"tufan": 1,
	"hortum": 3,
	"girdap": 4,
	"hava_cebi": 4,
	"nefes_dalgasi": 3,
	"furtina_gozu": 3,
}


func _run(policy: StringName, seed_value: int, observed: bool) -> int:
	var sim := SimKit.make(
		seed_value, {"character": &"zyfen", "data_kind": "real", "log_events": false}
	)
	for k in LOAD:
		sim.debug_grant(StringName(k), int(LOAD[k]))
	var fx: FxRenderer = null
	if observed:
		fx = FxRenderer.new()
		add_child_autofree(fx)
		fx.bind(sim, null)
	var rng := Bots.make_rng(seed_value)
	var n := 0
	while n < STEPS and sim.state in [GameSim.State.RUNNING, GameSim.State.LEVEL_UP]:
		sim.hp = sim.max_hp  # ölümsüz: tüm koşu rüzgar yükü ile oynansın
		if sim.state == GameSim.State.LEVEL_UP:
			Bots.choose(sim, rng)
			continue
		sim.step(Bots.move(policy, sim))
		n += 1
		if fx != null:
			fx.update_fx(GameSim.STEP)
	assert_eq(n, STEPS, "%s/%d tam koştu" % [policy, seed_value])
	assert_eq(sim.check_invariants().size(), 0, "değişmezler: %s" % [sim.check_invariants()])
	return sim.state_hash()


func test_observer_attached_or_not_gives_same_hash_and_reruns_repeat() -> void:
	for policy in Bots.POLICIES:
		for s in SEEDS:
			var a := _run(policy, s, false)
			var b := _run(policy, s, true)
			assert_eq(b, a, "%s/%d gözlemci bağlı = bağsız" % [policy, s])
			assert_eq(_run(policy, s, false), a, "%s/%d tekrar koşu aynı" % [policy, s])


func test_different_seeds_differ() -> void:
	assert_ne(_run(&"kite", SEEDS[0], false), _run(&"kite", SEEDS[1], false))
