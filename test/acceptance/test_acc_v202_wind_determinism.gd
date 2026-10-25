extends GutTest
## Kabul (v2.0.2 K, W/Z/E): Zyfen determinizmi. Aynı tohum + aynı bot politikası => aynı state_hash ve aynı RNG akışı
## (rng_combat tüketim sayısı sabit); farklı tohum farklı hash; gözlemci (sinyal dinleyici) ve olay kaydı bağlı/bağsız aynı hash.
## Plan U3 kabul: 3 politika x 2 tohum (bu dosyada 1500 adım; 7200 adımlık Tufan'lı altın koşu test_acc_v202_pool_golden.gd'de).

const STEPS := 1500
const SEEDS := [3, 41]
## Üç ortak pasif + rüzgar seti: hem bölgeler hem kesikler hem dalgalar işler.
const GRANTS := {
	"hava_bicaklari": 3,
	"girdap": 3,
	"hortum": 3,
	"hava_cebi": 3,
	"nefes_dalgasi": 3,
	"delen_ruzgar": 2,
	"bolunen_kesik": 3,
	"furtina_gozu": 2,
}


func _run(seed_value: int, policy: StringName, observe: bool, log_events: bool) -> Dictionary:
	var sim := SimKit.make(
		seed_value, {"character": &"zyfen", "data_kind": "real", "log_events": log_events}
	)
	SimKit.godmode(sim)
	for k in GRANTS:
		sim.debug_grant(StringName(k), int(GRANTS[k]))
	sim.xp_to_next = 1000000000 if policy == Bots.IDLE else sim.xp_to_next
	var seen := {"n": 0}
	if observe:
		var bump := func(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
			seen["n"] += 1
		for s in [
			sim.fx.wind_wave,
			sim.fx.wind_cast,
			sim.fx.skill_sfx,
			sim.fx.volley_fired,
			sim.fx.beam_fired,
			sim.bus.enemy_killed,
			sim.bus.enemy_hit,
			sim.bus.shot_fired,
			sim.bus.magazine_changed,
			sim.bus.explosion
		]:
			s.connect(bump)
	var rng := Bots.make_rng(seed_value)
	Bots.play(sim, policy, STEPS, rng)
	return {
		"hash": sim.state_hash(),
		"rng": sim.rng_combat.state,
		"kills": sim.kills,
		"level": sim.level,
		"zones": sim.zones.count,
		"seen": seen["n"],
		"violations": sim.check_invariants(),
	}


func test_w1_same_seed_same_policy_gives_identical_hash_and_rng_stream() -> void:
	if V202Slice.require(self, "W"):
		return
	for s in SEEDS:
		for p in Bots.POLICIES:
			var a := _run(s, p, false, false)
			var b := _run(s, p, false, false)
			assert_eq(a["hash"], b["hash"], "tohum %d / %s: state_hash" % [s, p])
			assert_eq(a["rng"], b["rng"], "tohum %d / %s: rng_combat tüketimi" % [s, p])
			assert_eq(a["kills"], b["kills"], "tohum %d / %s: kill" % [s, p])


func test_w2_different_seeds_give_different_hashes() -> void:
	if V202Slice.require(self, "W"):
		return
	var a := _run(SEEDS[0], Bots.KITE, false, false)
	var b := _run(SEEDS[1], Bots.KITE, false, false)
	assert_ne(a["hash"], b["hash"])
	assert_ne(a["rng"], b["rng"])


func test_z1_observers_and_event_log_do_not_change_the_hash_or_rng() -> void:
	if V202Slice.require(self, "Z"):
		return
	for s in SEEDS:
		var bare := _run(s, Bots.KITE, false, false)
		var watched := _run(s, Bots.KITE, true, true)
		assert_gt(watched["seen"], 0, "kontrol: gözlemci olay aldı")
		assert_eq(
			watched["hash"], bare["hash"], "tohum %d: gözlemci/olay günlüğü hash'i değiştirmez" % s
		)
		assert_eq(watched["rng"], bare["rng"], "tohum %d: rng akışı aynı" % s)


func test_z2_zyfen_runs_hold_the_invariants_and_actually_use_zones() -> void:
	if V202Slice.require(self, "Z"):
		return
	var r := _run(SEEDS[0], Bots.GREEDY, false, false)
	assert_eq(Array(r["violations"]), [], "değişmezler")
	var z := SimKit.make(
		SEEDS[0], {"character": &"zyfen", "data_kind": "real", "log_events": false}
	)
	SimKit.godmode(z)
	for k in GRANTS:
		z.debug_grant(StringName(k), int(GRANTS[k]))
	var peak := 0
	var rng := Bots.make_rng(SEEDS[0])
	for _k in 1200:
		Bots.play(z, Bots.KITE, 1, rng)
		peak = maxi(peak, z.zones.count)
	assert_gt(z.kills, 5, "kontrol: koşu öldürme üretti")
	assert_gt(peak, 0, "kontrol: rüzgar bölgeleri koşuda gerçekten doğdu")


func test_e1_gunslinger_run_is_unaffected_by_the_zyfen_wind_system() -> void:
	if V202Slice.require(self, "E"):
		return
	var a := SimKit.make(5, {"character": &"gunslinger", "data_kind": "real", "log_events": false})
	var b := SimKit.make(5, {"character": &"gunslinger", "data_kind": "real", "log_events": false})
	SimKit.godmode(a)
	SimKit.godmode(b)
	Bots.play(a, Bots.KITE, 900, Bots.make_rng(5))
	Bots.play(b, Bots.KITE, 900, Bots.make_rng(5))
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.zones.count, 0, "Gunslinger'da bölge yok")
	assert_eq(a.zones.hash_items().size(), 0, "hash'e bölge katkısı yok")
