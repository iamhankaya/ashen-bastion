extends SceneTree
## Denge raporu (gate dışı): bot politikalarıyla tam oyun koşuları. Kullanım:
##   godot --headless -s res://tools/balance/sim_run.gd -- <politika> <ilk_tohum> <tohum_sayısı> [çıktı.json]
## politika: idle | kite | greedy. Her koşu: sonuç, süre, seviye, en çok eşzamanlı düşman, en düşük can oranı.
## test/helpers/bots.gd botlarını kullanır (kendi RNG'si; sim akışlarına dokunmaz).

const MAX_STEPS := 144000  # 2400 sn: Lord (1190) dövüşü de ölçülür (mid_run.gd ile aynı)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var policy := StringName(args[0] if args.size() > 0 else "kite")
	var first := int(args[1]) if args.size() > 1 else 1
	var n := int(args[2]) if args.size() > 2 else 1
	var out_path: String = args[3] if args.size() > 3 else ""
	var rows: Array = []
	for k in n:
		rows.append(_run(policy, first + k))
		print(JSON.stringify(rows[-1]))
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(rows, "  "))
	quit()


func _run(policy: StringName, seed_value: int) -> Dictionary:
	var sim := GameSim.new(seed_value, &"gunslinger", {})
	var rng := Bots.make_rng(seed_value)
	var steps := 0
	var smart := policy == &"smart"
	var max_alive := 0
	var hp_min := 1.0
	var below_half := 0
	while steps < MAX_STEPS and sim.state in [GameSim.State.RUNNING, GameSim.State.LEVEL_UP]:
		if sim.state == GameSim.State.LEVEL_UP:
			if smart:
				_smart_choose(sim, rng)
			else:
				Bots.choose(sim, rng)
			continue
		sim.step(_smart_move(sim) if smart else Bots.move(policy, sim))
		steps += 1
		max_alive = maxi(max_alive, sim.enemies.count)
		var frac := sim.hp / maxf(sim.max_hp, 1.0)
		hp_min = minf(hp_min, frac)
		if frac < 0.5 and steps % 60 == 0:
			below_half += 1
	return {
		"policy": String(policy),
		"seed": seed_value,
		"result": ["running", "level_up", "won", "lost"][sim.state],
		"time": snappedf(sim.time, 0.1),
		"level": sim.level,
		"kills": sim.kills,
		"max_alive": max_alive,
		"hp_min": snappedf(hp_min, 0.01),
		"secs_below_half": below_half,
		"evolutions": sim.evolved_log.size(),
		"spawn_dropped": sim.spawn_dropped,
		"score": sim.score.total(),
		"score_parts": sim.score.parts(),
		"best_mult": sim.score.best_mult,
	}


## Gelişmiş bot: tehdit varsa kaç, yoksa en yakın XP taşına git, yoksa daire çiz.
func _smart_move(sim: GameSim) -> Vector2:
	var threat := Bots.move(&"kite", sim)
	var near_threat := false
	for id in sim.alive_ids():
		if (
			sim.enemies.pos[EnemyPool.index_of(id)].distance_squared_to(sim.player_pos)
			< 260.0 * 260.0
		):
			near_threat = true
			break
	if near_threat:
		return threat
	var g := Bots.move(&"greedy", sim)
	return g if g != Vector2.ZERO else threat


## Evrim > aktif yükseltme > yeni aktif > pasif yükseltme > yeni pasif (eşitlikte bot RNG'si).
func _smart_choose(sim: GameSim, rng: RandomNumberGenerator) -> void:
	var cards := sim.pending_choices()
	var best := 0
	var best_score := -1.0
	for i in cards.size():
		var c: Choice = cards[i]
		var def := sim.data.get_skill(c.skill_id)
		var score := 1.0
		if c.kind == Choice.KIND_EVOLUTION:
			score = 6.0
		elif def != null and def.kind == SkillDef.KIND_ACTIVE:
			score = 4.0 if c.kind == Choice.KIND_UPGRADE else 3.0
		elif def != null:
			score = 2.0 if c.kind == Choice.KIND_UPGRADE else 1.5
		score += rng.randf() * 0.4
		if score > best_score:
			best_score = score
			best = i
	sim.choose(best)
