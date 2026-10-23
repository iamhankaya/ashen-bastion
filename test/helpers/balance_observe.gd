extends SceneTree
## Denge gözlemi (gate DIŞI, sayı değiştirmez): hedefe yönelik "usta" bot ile tam oyun koşusu; 5/10/15/20. dk ve Lord
## sonrası anlık görüntüler. Kullanım:
##   godot --headless -s res://test/helpers/balance_observe.gd -- <ilk_tohum> <tohum_sayısı> <çıktı.jsonl> [ölümsüz]
## "Usta" bot: tehdit varsa kaçar, yoksa en yakın XP taşına gider; kartları evrim çiftlerini tamamlamaya göre seçer.
## ölümsüz=1: oyuncu ölmez (Lord dövüşü ve geç oyun yoğunluğu ölçmek için); hasar yine hesaplanır (hp_min kaydı).

const MAX_STEPS := 90000  # 1500 sn
const SNAP_TIMES: Array[float] = [300.0, 600.0, 900.0, 1080.0, 1200.0, 1260.0]
## Kart önceliği: önce ritim evrim çiftleri, sonra savunma, sonra kalan.
const PRIORITY: Array[StringName] = [
	&"zincirleme_patlama",
	&"kiyamet_mermisi",
	&"mermi_firtinasi",
	&"gurleyen_yelpaze",
	&"seken_mermi",
	&"barut_kesesi",
	&"son_mermi_patlar",
	&"hizli_doldurma",
	&"doldurma_sacilmasi",
	&"fazladan_mermi",
	&"agir_kursun",
	&"hizli_parmak",
	&"saglam_yelek",
	&"cevik_cizme",
	&"miknatis",
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var n := int(args[1]) if args.size() > 1 else 1
	var out_path: String = args[2] if args.size() > 2 else ""
	var immortal := args.size() > 3 and args[3] == "1"
	var lines: PackedStringArray = []
	for k in n:
		var row := _run(first + k, immortal)
		lines.append(JSON.stringify(row))
		print(lines[-1])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lines) + "\n")
	quit()


func _run(seed_value: int, immortal: bool) -> Dictionary:
	var sim := GameSim.new(seed_value, &"gunslinger", {})
	var rng := Bots.make_rng(seed_value)
	var snaps: Array = []
	var next_snap := 0
	var steps := 0
	var hp_min := 1.0
	var lord_t := -1.0
	var lord_dead_t := -1.0
	var ms_total := 0.0
	var ms_max := 0.0
	while steps < MAX_STEPS and sim.state in [GameSim.State.RUNNING, GameSim.State.LEVEL_UP]:
		if immortal:
			sim.hp = sim.max_hp
		if sim.state == GameSim.State.LEVEL_UP:
			_choose(sim, rng)
			continue
		var a := Time.get_ticks_usec()
		sim.step(_move(sim))
		var dt := float(Time.get_ticks_usec() - a) / 1000.0
		ms_total += dt
		ms_max = maxf(ms_max, dt)
		steps += 1
		hp_min = minf(hp_min, sim.hp / maxf(sim.max_hp, 1.0))
		if lord_t < 0.0 and _lord_alive(sim):
			lord_t = sim.time
		if next_snap < SNAP_TIMES.size() and sim.time >= SNAP_TIMES[next_snap]:
			snaps.append(_snap(sim, SNAP_TIMES[next_snap]))
			next_snap += 1
	if sim.lord_killed:
		lord_dead_t = sim.time
	return {
		"seed": seed_value,
		"immortal": immortal,
		"result": ["running", "level_up", "won", "lost"][sim.state],
		"time": snappedf(sim.time, 0.1),
		"level": sim.level,
		"kills": sim.kills,
		"evolutions": sim.evolved_log.size(),
		"evo_ids": Array(sim.evolved_log).map(func(s: StringName) -> String: return String(s)),
		"lord_spawn_t": snappedf(lord_t, 0.1),
		"lord_dead_t": snappedf(lord_dead_t, 0.1),
		"hp_min": snappedf(hp_min, 0.01),
		"spawn_dropped": sim.spawn_dropped,
		"ms_per_step": snappedf(ms_total / maxf(steps, 1), 0.001),
		"ms_max": snappedf(ms_max, 0.1),
		"snaps": snaps,
	}


func _snap(sim: GameSim, t: float) -> Dictionary:
	return {
		"t": t,
		"alive": sim.enemies.count,
		"level": sim.level,
		"hp_frac": snappedf(sim.hp / maxf(sim.max_hp, 1.0), 0.01),
		"kills": sim.kills,
		"actives": sim.loadout.actives().size(),
		"passives": sim.loadout.passives().size(),
		"evo": sim.evolved_log.size(),
		"hp_mult": snappedf(Difficulty.enemy_hp_mult(t), 0.01),
		"dmg_mult": snappedf(Difficulty.enemy_dmg_mult(t), 0.01),
		"cap": Difficulty.alive_cap(t),
	}


func _lord_alive(sim: GameSim) -> bool:
	for id in sim.alive_ids():
		if sim.enemies.type_id_of(EnemyPool.index_of(id)) == &"kale_lordu":
			return true
	return false


func _choose(sim: GameSim, rng: RandomNumberGenerator) -> void:
	var cards := sim.pending_choices()
	var best := 0
	var best_rank := 1 << 20
	for i in cards.size():
		var rank := PRIORITY.find(cards[i].skill_id)
		if cards[i].kind == Choice.KIND_EVOLUTION:
			rank = -1
		elif rank < 0:
			rank = PRIORITY.size() + rng.randi_range(0, 3)
		if rank < best_rank:
			best_rank = rank
			best = i
	sim.choose(best)


func _move(sim: GameSim) -> Vector2:
	var threat := Bots.move(&"kite", sim)
	for id in sim.alive_ids():
		if (
			sim.enemies.pos[EnemyPool.index_of(id)].distance_squared_to(sim.player_pos)
			< 260.0 * 260.0
		):
			return threat
	var g := Bots.move(&"greedy", sim)
	return g if g != Vector2.ZERO else threat
