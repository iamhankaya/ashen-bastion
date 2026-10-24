class_name VerV2Run
extends RefCounted
## Doğrulama (v2.0, T20261024-65): iki karakterle bot koşusu. `AbRunner` karakter seçmediği için ayrı koşucu.
## Gate'te kısaltılmış (test_ver_v2_*), uzun varyantta ve kalibrasyonda aynı kod kullanılır. Sim'e dokunmaz.

const CHARACTERS: Array[StringName] = [&"gunslinger", &"barutcu"]


## opts: seed, policy, character, max_steps, check_every (0 = yok), godmode, tracker (true = gerçek AchievementTracker
## + geçici depo, koşu sonu finish çağrılır), pickups (true).
## Döner: steps, result, time, level, kills, score, violations, state_hash, unlocked (Array[StringName]), checks.
static func run(opts: Dictionary) -> Dictionary:
	var seed_value: int = int(opts.get("seed", 1))
	var policy: StringName = StringName(opts.get("policy", "kite"))
	var max_steps: int = int(opts.get("max_steps", 2400))
	var check_every: int = int(opts.get("check_every", 0))
	var god: bool = bool(opts.get("godmode", false))
	var sim := (
		SimKit
		. make(
			seed_value,
			{
				"data_kind": "real",
				"log_events": false,
				"pickups": bool(opts.get("pickups", true)),
				"character": StringName(opts.get("character", &"gunslinger")),
			}
		)
	)
	var tracker: AchievementTracker = null
	if bool(opts.get("tracker", false)):
		var st := AchKit.store()
		tracker = AchievementTracker.new(AchKit.data(), st, sim.character.id, AchKit.clock())
		tracker.attach(sim.bus)
	var rng := Bots.make_rng(seed_value)
	var steps := 0
	var violations := PackedStringArray()
	var checks := 0
	var guard := 0
	while steps < max_steps and guard < max_steps * 4 + 64:
		guard += 1
		if sim.state == GameSim.State.LEVEL_UP:
			if not Bots.choose(sim, rng):
				break
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		if god:
			SimKit.godmode(sim)
		sim.step(Bots.move(policy, sim))
		steps += 1
		if tracker != null:
			tracker.poll(sim)
		if check_every > 0 and steps % check_every == 0:
			checks += 1
			for v in sim.check_invariants():
				violations.append("adım %d: %s" % [sim.step_count, v])
	if check_every > 0:
		checks += 1
		for v in sim.check_invariants():
			violations.append("adım %d (son): %s" % [sim.step_count, v])
	var won := sim.state == GameSim.State.WON
	var unlocked: Array[StringName] = []
	if tracker != null:
		tracker.finish(won, {"time": int(sim.time), "level": sim.level, "score": sim.score.total()})
		unlocked = tracker.run_unlocked()
		tracker.detach()
	return {
		"steps": steps,
		"result": ["running", "level_up", "won", "lost"][sim.state],
		"time": sim.time,
		"level": sim.level,
		"kills": sim.kills,
		"score": sim.score.total(),
		"violations": violations,
		"checks": checks,
		"state_hash": sim.state_hash(),
		"unlocked": unlocked,
		"max_hp": sim.max_hp,
	}
