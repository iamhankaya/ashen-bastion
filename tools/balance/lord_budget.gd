extends SceneTree
## Lord bütçesi (gate dışı, v2.0.2 D fazı): Hortum/Tufan'ın Kale Lordu'na verdiği hasar, dakikada Lord HP'sinin yüzdesi.
## Lord hareketsiz kukla (can çok büyük, oyuncudan 200 px); beceri farkı = (beceri + temel saldırı) − yalnız temel saldırı.
##   godot --headless -s res://tools/balance/lord_budget.gd -- [saniye=60] [tohum_sayısı=3] [çıktı.md]
## Plan: dakikada Lord HP'sinin ≤ %25'i (`boss_mult` düğmesi).

const LORD := &"kale_lordu"
const LORD_HP_BIG := 1.0e8
const OFFSET := Vector2(200.0, 0.0)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var secs: float = float(args[0]) if args.size() > 0 else 60.0
	var seeds: int = int(args[1]) if args.size() > 1 else 3
	var lord_hp: float = GameData.load_default().get_enemy(LORD).hp
	var cases := {
		"hortum sv5": {&"hortum": 5},
		"tufan (hortum sv5 + furtina_gozu + tufan)":
		{&"hortum": 5, &"furtina_gozu": 1, &"tufan": 1},
		"hortum sv1": {&"hortum": 1},
	}
	var lines: PackedStringArray = [
		"| durum | beceri farkı (hasar/dk) | Lord HP %% / dk (HP %d) |" % int(lord_hp),
		"|---|---|---|"
	]
	for label in cases:
		var diffs: Array[float] = []
		for s in seeds:
			var with_skill := _lord_damage(cases[label], secs, 1 + s)
			var base := _lord_damage({}, secs, 1 + s)
			diffs.append((with_skill - base) * 60.0 / secs)
		var mean := 0.0
		for d in diffs:
			mean += d / diffs.size()
		lines.append("| %s | %.0f | %.1f%% |" % [label, mean, 100.0 * mean / lord_hp])
	var md := "\n".join(lines) + "\n"
	print(md)
	if args.size() > 2:
		var f := FileAccess.open(args[2], FileAccess.WRITE)
		f.store_string(md)
	quit()


func _lord_damage(skills: Dictionary, secs: float, seed_value: int) -> float:
	var sim := SimKit.make(seed_value, {"character": &"zyfen", "log_events": false})
	SimKit.godmode(sim)
	for id in skills:
		sim.debug_grant(StringName(id), int(skills[id]))
	var id := sim.debug_spawn(LORD, sim.player_pos + OFFSET)
	var idx := EnemyPool.index_of(id)
	sim.enemies.hp[idx] = LORD_HP_BIG
	for n in int(round(secs / GameSim.STEP)):
		if sim.state != GameSim.State.RUNNING:
			break
		if sim.enemies.is_alive(id):
			sim.enemies.pos[idx] = sim.player_pos + OFFSET
		sim.step(Vector2.ZERO)
	return LORD_HP_BIG - sim.enemies.hp[idx]
