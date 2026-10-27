extends GutTest
## v2.1 U1b: Sonsuz 40. dk uzun testi — GATE DIŞI: `bash tools/verify_long.sh` (nightly.yml). Ölümsüz kite botu, Sonsuz/Normal profili,
## 2400 sn (144000 adım); gerçek veri. Eşikler TAHMİN (plan T20261027-18, U1b); nightly kırmızıysa gerekçesiyle ayarlanır:
##  (a) 30. -> 40. dk her adımda canlı düşman sayısı doğuş tavanını (+ boss payı) aşmaz,
##  (b) `Performance.OBJECT_COUNT` 30. -> 40. dk artışı <= %5 (sızıntı yok),
##  (c) adım süresi p99 (40. dk son dakika) <= P99_RATIO x Normal 20. dk son dakika; ikisi aynı süreçte ölçülür, mutlak süre yok.
## Diske yazmaz (olay günlüğü kapalı, kayıt yok).

const STEPS_PER_MIN := 3600
const MIN_30 := 30 * STEPS_PER_MIN
const MIN_40 := 40 * STEPS_PER_MIN
const MIN_20 := 20 * STEPS_PER_MIN
const OBJECT_GROWTH_MAX := 0.05
const P99_RATIO := 2.0


## Ölümsüz kite koşusu. Döner: steps, violations (PackedStringArray), obj_from/obj_to (OBJECT_COUNT, from_step/to_step'te),
## p99_usec (son dakikanın adım süresi p99'u), alive_max, endless (profil Sonsuz mu).
func _run(mode: StringName, diff: StringName, to_step: int, from_step: int) -> Dictionary:
	var profile := V21Kit.profile(mode, diff)
	var opts := {"data_kind": "real", "log_events": false, "character": &"gunslinger"}
	opts.merge(profile.opts())
	var sim := SimKit.make(7, opts)
	var rng := Bots.make_rng(7)
	var steps := 0
	var guard := 0
	var obj_from := 0
	var obj_to := 0
	var alive_max := 0
	var violations := PackedStringArray()
	var usec := PackedFloat64Array()
	while steps < to_step and guard < to_step * 4:
		guard += 1
		if sim.state == GameSim.State.LEVEL_UP:
			if not Bots.choose(sim, rng):
				break
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		SimKit.godmode(sim)
		var move := Bots.move(&"kite", sim)
		var t0 := Time.get_ticks_usec()
		sim.step(move)
		var dt := Time.get_ticks_usec() - t0
		steps += 1
		if steps > to_step - STEPS_PER_MIN:
			usec.append(dt)
		if steps >= from_step:
			alive_max = maxi(alive_max, sim.enemies.count)
			var cap := (
				mini(
					Difficulty.alive_cap(V21Sim.curve_t(sim)),
					EnemyPool.CAP - SpawnDirector.BOSS_RESERVE
				)
				+ SpawnDirector.BOSS_RESERVE
			)
			if sim.enemies.count > cap and violations.size() < 5:
				violations.append("adım %d: canlı %d > tavan %d" % [steps, sim.enemies.count, cap])
		if steps == from_step:
			obj_from = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	obj_to = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	usec.sort()
	var p99 := usec[int(0.99 * (usec.size() - 1))] if not usec.is_empty() else -1.0
	return {
		"steps": steps,
		"violations": violations,
		"obj_from": obj_from,
		"obj_to": obj_to,
		"p99_usec": p99,
		"alive_max": alive_max,
		"endless": sim.end_mode == GameSim.END_MODE_ENDLESS,
	}


func test_m1_endless_minute_40_stays_within_alive_cap_object_growth_and_step_time() -> void:
	var normal := _run(&"normal", &"normal", MIN_20, MIN_20)
	var endless := _run(&"endless", &"normal", MIN_40, MIN_30)
	assert_true(endless["endless"], "Sonsuz profili uygulandı")
	assert_eq(int(endless["steps"]), MIN_40, "40 dk (2400 sn) tamamlandı")
	assert_eq(endless["violations"], PackedStringArray(), "30-40 dk canlı düşman <= tavan")
	var growth := (
		float(endless["obj_to"] - endless["obj_from"]) / maxf(float(endless["obj_from"]), 1.0)
	)
	assert_lte(growth, OBJECT_GROWTH_MAX, "OBJECT_COUNT 30->40 dk artışı <= %5")
	assert_gt(float(normal["p99_usec"]), 0.0, "Normal 20. dk referansı ölçüldü")
	assert_lte(
		float(endless["p99_usec"]),
		P99_RATIO * float(normal["p99_usec"]),
		"adım süresi p99 <= %sx Normal 20. dk" % P99_RATIO
	)
	(
		gut
		. p(
			(
				"Sonsuz 40. dk: canlı max %d, OBJECT_COUNT %d->%d (%.1f%%), p99 %.0f us (Normal 20. dk %.0f us)"
				% [
					endless["alive_max"],
					endless["obj_from"],
					endless["obj_to"],
					growth * 100.0,
					endless["p99_usec"],
					normal["p99_usec"]
				]
			)
		)
	)
