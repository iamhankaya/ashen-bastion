extends SceneTree
## Orta oyun denge ölçümü (gate dışı, v2.0.1; v2.1 U1a: Lord ve mod/zorluk). Kullanım:
##   godot --headless -s res://tools/balance/mid_run.gd -- <politika> <karakter> <ilk_tohum> <tohum_sayısı> <çıktı.jsonl> [mod] [zorluk]
## politika: idle | kite | greedy | strong | strong_lord. strong = "usta" bot (balance_observe: tehdit varsa kaç, yoksa taş topla,
## evrim çiftlerini tamamlayan kart önceliği). strong_lord: Lord yokken strong ile BİREBİR aynı; Lord yaşarken Lord'a
## [LORD_BAND_MIN, LORD_BAND_MAX] px bandında kalır (uzaksa yaklaş, yakınsa kaç, bandın içinde teğet). Ölümlü koşu.
## mod (normal|quick|endless) verilmezse profilsiz legacy koşu (mod=normal, diff=hard); yalnız mod verilirse zorluk=normal.
## Çıktı satırı (JSON): v2.0.x alanları (süre, 0-5 dk / 10-20 dk can, 5 dk öldürme/seviye) + mode, diff, won, milestone_won,
## end_reason (died|won|timeout), reached_lord, lord_spawn_t, lord_alive_secs, lord_end (killed|player_died|timeout|none),
## lord_hp_frac_end, lord_hit_frac (Lord'un can kaybettiği adımların, Lord'un yaşadığı adımlara oranı; ilk Lord),
## lords_killed, post_lord_secs (ilk Lord ölümünden sona), level_at_1200, level_at_end. Yalnız stdout ve <çıktı.jsonl> yazılır.

const MAX_STEPS := 144000  # 2400 sn: Lord dövüşü (Lord 1200. sn'de doğar) dahil
const MAX_STEPS_ENDLESS := 216000  # 3600 sn
const LORD_BAND_MIN := 250.0
const LORD_BAND_MAX := 400.0
const STRONG_POLICIES: Array[String] = ["strong", "strong_lord"]
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
	var mode := String(args[5]) if args.size() > 5 else ""
	var diff := String(args[6]) if args.size() > 6 else "normal"
	var lines: PackedStringArray = []
	for k in n:
		var result := run_one(first + k, policy, character, mode, diff)
		if result.has("error"):
			printerr(result["error"])
			quit(1)
			return
		lines.append(JSON.stringify(result))
		print(lines[-1])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lines) + "\n")
	quit()


## Tek koşu. max_steps 0 ise MAX_STEPS (Sonsuz: MAX_STEPS_ENDLESS). Kendi RNG'si (Bots.make_rng); sim akışlarına dokunmaz.
static func run_one(
	seed_value: int,
	policy: String,
	character: StringName,
	mode: String = "",
	diff: String = "normal",
	max_steps: int = 0
) -> Dictionary:
	var opts := {"data_kind": "real", "log_events": false, "character": character}
	var profile: RunProfile = null
	if mode != "":
		var cfg := RunProfiles.load_default()
		if not cfg["errors"].is_empty():
			return {"error": "run_profiles: %s" % str(cfg["errors"][0])}
		profile = RunProfile.make(StringName(mode), StringName(diff), cfg["profiles"])
		if profile == null:
			return {"error": "bilinmeyen mod/zorluk: %s/%s" % [mode, diff]}
		opts.merge(profile.opts())
	var sim := SimKit.make(seed_value, opts)
	var rng := Bots.make_rng(seed_value)
	var scale := profile.time_scale if profile != null else 1.0
	var limit := max_steps
	if limit <= 0:
		limit = MAX_STEPS_ENDLESS if sim.end_mode == GameSim.END_MODE_ENDLESS else MAX_STEPS
	# 10-20 dk can penceresi legacy ile aynı: 1200 sn (Hızlı: 600) adımına kadar; sonrası Lord dövüşüdür.
	var cap_steps := int(roundf(1200.0 * scale * 60.0))
	var lord := make_lord_tracker(sim)
	var steps := 0
	var early: Array[float] = []
	var mid: Array[float] = []
	var kills5 := -1
	var level5 := -1
	var level_1200 := -1
	var guard := 0
	while steps < limit and guard < limit * 4:
		guard += 1
		if sim.state == GameSim.State.LEVEL_UP:
			if STRONG_POLICIES.has(policy):
				_choose(sim, rng, character)
			elif not Bots.choose(sim, rng):
				break
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		sim.step(move_for(sim, policy, lord["id"]))
		steps += 1
		_track_lord(sim, lord)
		if steps % 60 == 0:
			var frac := sim.hp / maxf(sim.max_hp, 1.0)
			if sim.time < 300.0 * scale:
				early.append(frac)
			elif sim.time >= 600.0 * scale and steps <= cap_steps:
				mid.append(frac)
		if kills5 < 0 and sim.time >= 300.0 * scale:
			kills5 = sim.kills
			level5 = sim.level
		if level_1200 < 0 and sim.time >= 1200.0:
			level_1200 = sim.level
	var reached: bool = lord["n"] > 0
	var killed: bool = lord["death_t"] >= 0.0
	var lord_end := "none"
	if reached:
		if killed:
			lord_end = "killed"
		else:
			lord_end = "player_died" if sim.state == GameSim.State.LOST else "timeout"
	var end_reason := "timeout"
	if sim.state == GameSim.State.WON:
		end_reason = "won"
	elif sim.state == GameSim.State.LOST:
		end_reason = "died"
	var alive_secs := 0.0
	var hp_frac_end := -1.0
	if reached:
		alive_secs = (lord["death_t"] if killed else sim.time) - lord["spawn_t"]
		hp_frac_end = 0.0 if killed else lord["hp_frac"]
	return {
		"seed": seed_value,
		"policy": policy,
		"character": String(character),
		"mode": mode if mode != "" else "normal",
		"diff": diff if mode != "" else "hard",
		"result": ["running", "level_up", "won", "lost"][sim.state],
		"won": sim.state == GameSim.State.WON,
		"milestone_won": sim.milestone_won,
		"end_reason": end_reason,
		"time": snappedf(sim.time, 0.1),
		"level": sim.level,
		"kills": sim.kills,
		"level_at_1200": level_1200,
		"level_at_end": sim.level,
		"evolutions": sim.evolved_log.size(),
		"hp_early": _mean(early),
		"hp_mid": _mean(mid),
		"mid_n": mid.size(),
		"kills5": kills5,
		"level5": level5,
		"reached_lord": reached,
		"lord_spawn_t": snappedf(lord["spawn_t"], 0.01),
		"lord_alive_secs": snappedf(alive_secs, 0.01),
		"lord_end": lord_end,
		"lord_hp_frac_end": snappedf(hp_frac_end, 0.001),
		"lord_hit_frac":
		snappedf(float(lord["hit_steps"]) / maxf(float(lord["alive_steps"]), 1.0), 0.001),
		"lords_killed": maxi(sim.lords_killed, lord["killed"]),
		"post_lord_secs": snappedf(sim.time - lord["death_t"], 0.01) if killed else 0.0,
	}


static func _mean(a: Array[float]) -> float:
	if a.is_empty():
		return -1.0
	var s := 0.0
	for v in a:
		s += v
	return snappedf(s / a.size(), 0.001)


## Lord izleyici durumu; boss_spawned sinyali aramayı tetikler (her adım tarama yapılmaz).
static func make_lord_tracker(sim: GameSim) -> Dictionary:
	var st := {
		"pending": false,
		"id": -1,
		"n": 0,
		"spawn_t": -1.0,
		"alive_steps": 0,
		"hit_steps": 0,
		"hp_frac": -1.0,
		"last_hp": 0.0,
		"death_t": -1.0,
		"killed": 0,
	}
	sim.bus.boss_spawned.connect(func(_type_id: StringName) -> void: st["pending"] = true)
	return st


## Canlı Lord'un kimliği (yoksa -1).
static func lord_id(sim: GameSim) -> int:
	for id in sim.alive_ids():
		if sim.enemies.def_of(EnemyPool.index_of(id)).ai == &"lord":
			return id
	return -1


## Her adımdan sonra çağrılır (`make_lord_tracker` sözlüğü). Yalnız İLK Lord'un süre/vuruş/can alanları tutulur; sonraki Lordlar (Sonsuz) yalnız öldürme sayacına girer.
static func _track_lord(sim: GameSim, st: Dictionary) -> void:
	if st["id"] < 0:
		if not st["pending"]:
			return
		st["pending"] = false
		st["id"] = lord_id(sim)
		if st["id"] < 0:
			return
		st["n"] += 1
		if st["n"] == 1:
			st["spawn_t"] = sim.time
			st["last_hp"] = sim.enemies.hp[EnemyPool.index_of(st["id"])]
			st["hp_frac"] = 1.0
		return
	if sim.enemies.is_alive(st["id"]):
		if st["n"] == 1:
			var i := EnemyPool.index_of(st["id"])
			st["alive_steps"] += 1
			if sim.enemies.hp[i] < st["last_hp"]:
				st["hit_steps"] += 1
			st["last_hp"] = sim.enemies.hp[i]
			st["hp_frac"] = sim.enemies.hp[i] / maxf(sim.enemies.max_hp[i], 1.0)
		return
	st["killed"] += 1
	if st["n"] == 1:
		st["death_t"] = sim.time
	st["id"] = -1


## Lord bandı: uzaksa yaklaş, yakınsa kaç, bandın içinde teğet (Lord'un etrafında dön). Saf işlev; duvar dolanma ayrı.
static func band_dir(player: Vector2, lord_pos: Vector2) -> Vector2:
	var to := lord_pos - player
	var d := to.length()
	if d < 0.001:
		return Vector2.RIGHT
	var dir := to / d
	if d > LORD_BAND_MAX:
		return dir
	if d < LORD_BAND_MIN:
		return -dir
	return dir.orthogonal()


## Politika hareketi. lord >= 0 (canlı Lord kimliği) ve politika strong_lord ise Lord bandı; aksi halde strong BİREBİR
## (strong_lord'un iki dalından biri burası, diğeri `_choose`'a giden STRONG_POLICIES).
static func move_for(sim: GameSim, policy: String, lord: int = -1) -> Vector2:
	if policy != "strong":
		return Bots.move(StringName(policy), sim)
	if policy == "strong_lord" and lord >= 0 and sim.enemies.is_alive(lord):
		var want := band_dir(sim.player_pos, sim.enemies.pos[EnemyPool.index_of(lord)])
		return Bots._around_walls(sim, want)
	var threat := Bots.move(&"kite", sim)
	for id in sim.alive_ids():
		if (
			sim.enemies.pos[EnemyPool.index_of(id)].distance_squared_to(sim.player_pos)
			< 260.0 * 260.0
		):
			return threat
	var g := Bots.move(&"greedy", sim)
	return g if g != Vector2.ZERO else threat


static func _choose(sim: GameSim, rng: RandomNumberGenerator, character: StringName) -> void:
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
