extends SceneTree
## Orta oyun denge ölçümü (gate dışı, v2.0.1). Kullanım:
##   godot --headless -s res://tools/balance/mid_run.gd -- <politika> <karakter> <ilk_tohum> <tohum_sayısı> <çıktı.jsonl>
## politika: idle | kite | greedy | strong. strong = "usta" bot (balance_observe: tehdit varsa kaç, yoksa taş topla,
## evrim çiftlerini tamamlayan kart önceliği). Ölümlü koşu; hasar/can saniyede bir örneklenir.
## Çıktı satırı: süre, 0-5 dk ve 10-20 dk ortalama can oranı (yaşarken), 5 dk sonundaki öldürme/seviye.

const MAX_STEPS := 72000  # 1200 sn
## Karakter başına kart önceliği (v2.0.2). Evrim kartı her zaman en üstte (`_choose`); listede olmayan kimlik sona,
## 0-3 rastgele payla. Bilinmeyen karakter Gunslinger listesini kullanır (v2.0.1 ölçümleriyle birebir aynı).
const PRIORITY_BY_CHAR: Dictionary = {
	&"gunslinger":
	[
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
	],
	&"zyfen":
	[
		&"ay_oragi",
		&"tufan",
		&"kasirga_patlamasi",
		&"gogun_mizragi",
		&"furtina_gozu",
		&"hortum",
		&"bolunen_kesik",
		&"nefes_dalgasi",
		&"delen_ruzgar",
		&"girdap",
		&"hava_cebi",
		&"hava_bicaklari",
		&"agir_kursun",
		&"hizli_parmak",
		&"hizli_doldurma",
		&"fazladan_mermi",
		&"saglam_yelek",
		&"cevik_cizme",
		&"miknatis",
	],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var policy := String(args[0])
	var character := StringName(args[1])
	var first := int(args[2])
	var n := int(args[3])
	var out_path: String = args[4] if args.size() > 4 else ""
	var lines: PackedStringArray = []
	for k in n:
		lines.append(JSON.stringify(_run(first + k, policy, character)))
		print(lines[-1])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lines) + "\n")
	quit()


func _run(seed_value: int, policy: String, character: StringName) -> Dictionary:
	var sim := SimKit.make(
		seed_value, {"data_kind": "real", "log_events": false, "character": character}
	)
	var rng := Bots.make_rng(seed_value)
	var steps := 0
	var early: Array[float] = []
	var mid: Array[float] = []
	var kills5 := -1
	var level5 := -1
	var guard := 0
	while steps < MAX_STEPS and guard < MAX_STEPS * 4:
		guard += 1
		if sim.state == GameSim.State.LEVEL_UP:
			if policy == "strong":
				_choose(sim, rng, character)
			elif not Bots.choose(sim, rng):
				break
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		sim.step(_move(sim, policy))
		steps += 1
		if steps % 60 == 0:
			var frac := sim.hp / maxf(sim.max_hp, 1.0)
			if sim.time < 300.0:
				early.append(frac)
			elif sim.time >= 600.0:
				mid.append(frac)
		if kills5 < 0 and sim.time >= 300.0:
			kills5 = sim.kills
			level5 = sim.level
	return {
		"seed": seed_value,
		"policy": policy,
		"character": String(character),
		"result": ["running", "level_up", "won", "lost"][sim.state],
		"time": snappedf(sim.time, 0.1),
		"level": sim.level,
		"evolutions": sim.evolved_log.size(),
		"hp_early": _mean(early),
		"hp_mid": _mean(mid),
		"mid_n": mid.size(),
		"kills5": kills5,
		"level5": level5,
	}


func _mean(a: Array[float]) -> float:
	if a.is_empty():
		return -1.0
	var s := 0.0
	for v in a:
		s += v
	return snappedf(s / a.size(), 0.001)


func _move(sim: GameSim, policy: String) -> Vector2:
	if policy != "strong":
		return Bots.move(StringName(policy), sim)
	var threat := Bots.move(&"kite", sim)
	for id in sim.alive_ids():
		if (
			sim.enemies.pos[EnemyPool.index_of(id)].distance_squared_to(sim.player_pos)
			< 260.0 * 260.0
		):
			return threat
	var g := Bots.move(&"greedy", sim)
	return g if g != Vector2.ZERO else threat


func _choose(sim: GameSim, rng: RandomNumberGenerator, character: StringName) -> void:
	var priority: Array = PRIORITY_BY_CHAR.get(character, PRIORITY_BY_CHAR[&"gunslinger"])
	var cards := sim.pending_choices()
	var best := 0
	var best_rank := 1 << 20
	for i in cards.size():
		var rank := priority.find(cards[i].skill_id)
		if cards[i].kind == Choice.KIND_EVOLUTION:
			rank = -1
		elif rank < 0:
			rank = priority.size() + rng.randi_range(0, 3)
		if rank < best_rank:
			best_rank = rank
			best = i
	sim.choose(best)
