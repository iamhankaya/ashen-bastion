extends GutTest
## Kabul (v1.1): determinizm - aynı tohum iki koşu her 300 adımda aynı hash; politika başına ayrı test
## (R3a: test_acc_v11_determinism.gd'den ayrıldı).

const SEG := 300


func _run_hashes(seed_value: int, policy: StringName, segments: int) -> Array[int]:
	var sim := SimKit.make(seed_value, {"data_kind": "real", "log_events": false})
	SimKit.godmode(sim)
	var rng := Bots.make_rng(seed_value)
	var out: Array[int] = []
	for s in segments:
		Bots.play(sim, policy, SEG, rng)
		out.append(sim.state_hash())
	return out


func _same_seed(pol: StringName) -> void:
	if V11Slice.require(self, "D2") or V11Slice.require(self, "D3"):
		return
	var a := _run_hashes(31, pol, 16)
	var b := _run_hashes(31, pol, 16)
	assert_eq(a, b, "%s: aynı tohum iki koşu her 300 adımda eşit" % pol)
	var c := _run_hashes(32, pol, 16)
	assert_ne(a[a.size() - 1], c[c.size() - 1], "%s: farklı tohum farklı" % pol)


func test_same_seed_same_hash_every_300_steps_idle() -> void:
	_same_seed(&"idle")


func test_same_seed_same_hash_every_300_steps_kite() -> void:
	_same_seed(&"kite")


func test_same_seed_same_hash_every_300_steps_greedy() -> void:
	_same_seed(&"greedy")


func test_same_seed_same_hash_every_300_steps_greedy_pickup() -> void:
	_same_seed(&"greedy_pickup")
