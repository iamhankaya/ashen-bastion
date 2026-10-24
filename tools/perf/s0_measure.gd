extends SceneTree
## v2.0 S0 ölçümü (bilgi; gate'e girmez): ağır aday testlerin süre tahmini için tek örnek koşu.
## Kullanım: godot --headless -s res://tools/perf/s0_measure.gd
## (1) 2400 adımlık sim (log_events açık, gerçek veri) politika başına: iki-sim çifti = 2 × bu süre.
## (2) MapSim chunk üretimi: gerçek harabe tanımlarıyla bir chunk ve 200 tohum × 13×13 chunk (M1 mülkiyet testi).

const STEPS := 2400
const SEEDS_M1 := 200
const RADIUS_M1 := 6


func _init() -> void:
	var data := GameData.load_default()
	print("--- 2400 adımlık sim (gunslinger, gerçek veri, log_events=true) ---")
	for policy in Bots.POLICIES:
		var sim := GameSim.new(7, &"gunslinger", {"data": data, "log_events": true})
		var t0 := Time.get_ticks_usec()
		for i in STEPS:
			sim.step(Bots.move(policy, sim))
			if sim.state != GameSim.State.RUNNING:
				break
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		print(
			(
				"%s: %.0f ms (%.3f ms/adım; durum %d; düşman %d)"
				% [policy, ms, ms / STEPS, sim.state, sim.enemies.count]
			)
		)
	print("--- MapSim chunk üretimi (%d harabe tanımı) ---" % data.ruins.size())
	var one := MapSim.new(1, data.ruins)
	var t1 := Time.get_ticks_usec()
	for k in 100:
		one._generate(Vector2i(k, 0))
	print(
		(
			"bir chunk: %.3f ms (100 chunk ortalaması)"
			% [float(Time.get_ticks_usec() - t1) / 1000.0 / 100.0]
		)
	)
	var n := RADIUS_M1 * 2 + 1
	var t2 := Time.get_ticks_usec()
	for sd in SEEDS_M1:
		var m := MapSim.new(sd + 1, data.ruins)
		for dy in range(-RADIUS_M1, RADIUS_M1 + 1):
			for dx in range(-RADIUS_M1, RADIUS_M1 + 1):
				m._generate(Vector2i(dx, dy))
	var total := float(Time.get_ticks_usec() - t2) / 1000.0
	print(
		(
			"%d tohum × %d×%d chunk: %.0f ms (yalnız üretim; çember karşılaştırması hariç)"
			% [SEEDS_M1, n, n, total]
		)
	)
	quit()
