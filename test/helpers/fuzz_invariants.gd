extends SceneTree
## Uzun koşu invariant taraması (gate DIŞI; GATE_NIGHTLY'nin hafif karşılığı): ölümsüz bot, rastgele kart seçimi,
## 1500 sn (Lord dahil), her 120 adımda check_invariants(). Kullanım:
##   godot --headless -s res://test/helpers/fuzz_invariants.gd -- <politika> <ilk_tohum> <tohum_sayısı>
## Her koşu bir JSON satırı: ihlal sayısı, sonuç, süre, en çok düşman, doğuş kaybı, son state_hash.

const MAX_STEPS := 90000


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var policy := StringName(args[0] if args.size() > 0 else "kite")
	var first := int(args[1]) if args.size() > 1 else 1
	var n := int(args[2]) if args.size() > 2 else 1
	for k in n:
		print(JSON.stringify(_run(policy, first + k)))
	quit()


func _run(policy: StringName, seed_value: int) -> Dictionary:
	var sim := GameSim.new(seed_value, &"gunslinger", {})
	var rng := Bots.make_rng(seed_value)
	var violations: Array = []
	var steps := 0
	var max_alive := 0
	var max_proj := 0
	var max_gems := 0
	while steps < MAX_STEPS and sim.state in [GameSim.State.RUNNING, GameSim.State.LEVEL_UP]:
		sim.hp = sim.max_hp
		if sim.state == GameSim.State.LEVEL_UP:
			Bots.choose(sim, rng)
			continue
		sim.step(Bots.move(policy, sim))
		steps += 1
		max_alive = maxi(max_alive, sim.enemies.count)
		max_proj = maxi(max_proj, sim.projectiles.count)
		max_gems = maxi(max_gems, sim.gems.count)
		if steps % 120 == 0:
			for v in sim.check_invariants():
				if violations.size() < 5:
					violations.append("%.0fs: %s" % [sim.time, v])
	return {
		"policy": String(policy),
		"seed": seed_value,
		"result": ["running", "level_up", "won", "lost"][sim.state],
		"time": snappedf(sim.time, 0.1),
		"level": sim.level,
		"kills": sim.kills,
		"evolutions": sim.evolved_log.size(),
		"max_alive": max_alive,
		"max_proj": max_proj,
		"max_gems": max_gems,
		"spawn_dropped": sim.spawn_dropped,
		"violations": violations,
		"hash": sim.state_hash(),
	}
