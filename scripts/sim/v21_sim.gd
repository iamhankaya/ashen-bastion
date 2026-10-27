class_name V21Sim
extends RefCounted
## v2.1 koşu profilinin sim tarafı (U2): çarpanlar, XP birikimli kesir, Sonsuz Lord tekrarı. game_sim.gd satır tavanında
## olduğundan mantık burada yaşar; GameSim `v21` alanını yalnız legacy olmayan profilde ya da Sonsuz'da kurar.
## `sim.v21 == null` iken her yardımcı bugünkü değeri döndürür (RNG/hash baytı değişmez, K-C10).

## Profil (profilsiz Sonsuz'da legacy: tüm çarpanlar 1, tekrar yok).
var p: RunProfile = null
## XP birikimli kesir: gem değeri floori(carry), kalan sonraki ölüme taşınır (yuvarlama kaybı yok).
var xp_carry: float = 0.0
## Tamamlanmış tekrar doğuşu sayısı (HP basamağı üsteli).
var repeat_n: int = 0
## Sonraki Lord doğuş zamanı (önceki Lord ölümü + lord_repeat_sec); -1 = bekleyen yok.
var next_lord_t: float = -1.0
var warned: bool = false
var lord_type: StringName = &"kale_lordu"
var lord_warn: float = 5.0


## Legacy olmayan profil ya da Sonsuz için durum kurar; aksi null.
static func create(sim: GameSim) -> V21Sim:
	var endless := sim.end_mode == GameSim.END_MODE_ENDLESS
	if sim.run_profile == null or sim.run_profile.is_legacy():
		if not endless:
			return null
	var v := V21Sim.new()
	v.p = sim.run_profile if sim.run_profile != null else RunProfile.legacy()
	for row: Variant in sim.data.waves.get("rows", []):
		if row is Dictionary and row.get("kind", "") == "boss":
			var def := sim.data.get_enemy(StringName(str(row.get("type", ""))))
			if def != null and def.ai == &"lord":
				v.lord_type = def.id
				v.lord_warn = float(row.get("warn", 5.0))
	return v


## Hızlı: waves kopyası `time_scale` ile ölçeklenir; legacy/profilsiz: aynı sözlük.
static func waves_for(waves: Dictionary, profile: RunProfile) -> Dictionary:
	if profile == null or is_equal_approx(profile.time_scale, 1.0):
		return waves
	return WaveScaler.scale(waves, profile.time_scale)


static func time_scale(profile: RunProfile) -> float:
	return 1.0 if profile == null else profile.time_scale


## Zorluk/hız eğrilerinin okunduğu süre (Hızlı: t / 0,5).
static func curve_t(sim: GameSim) -> float:
	return sim.time if sim.v21 == null else sim.v21.p.curve_t(sim.time)


## Doğuşta HP çarpanı: zamana bağlı eğri × zorluk `enemy_hp`; Lord yalnız `lord_hp` · `lord_hp_mult`.
static func hp_mult(sim: GameSim, def: EnemyDef) -> float:
	if sim.v21 == null:
		return Difficulty.enemy_hp_mult(sim.time) if def.scales_with_time else 1.0
	var prof := sim.v21.p
	if def.ai == &"lord":
		return prof.lord_hp * prof.lord_hp_mult
	return (
		Difficulty.enemy_hp_mult(prof.curve_t(sim.time)) * prof.enemy_hp
		if def.scales_with_time
		else 1.0
	)


static func speed_mult(sim: GameSim, def: EnemyDef) -> float:
	return Difficulty.enemy_speed_mult(curve_t(sim)) if def.scales_with_time else 1.0


## Temas hasarına koşulsuz (Lord dahil) uygulanan çarpan: zorluk `enemy_dmg` × enrage.
static func contact_mult(sim: GameSim) -> float:
	if sim.v21 == null:
		return 1.0
	var prof := sim.v21.p
	var enrage := 1.0
	if prof.enrage_after_sec > 0.0 and sim.time >= prof.enrage_after_sec:
		enrage += prof.enrage_dmg_per_min * (sim.time - prof.enrage_after_sec) / 60.0
	return prof.enemy_dmg * enrage


## `rate` satırı birikim çarpanı: doğuş yoğunluğu × mod `rate_mult`.
static func rate_scale(sim: GameSim) -> float:
	return 1.0 if sim.v21 == null else sim.v21.p.spawn_density * sim.v21.p.rate_mult


## `group` boyutu ve `burst.count`: yoğunlukla çarpılır, en az 1; profilsizde eski yuvarlama.
static func count(sim: GameSim, n: float) -> int:
	if sim.v21 == null:
		return roundi(n)
	return maxi(1, roundi(n * sim.v21.p.spawn_density))


## Düşen taşın XP değeri (birikimli kesir; mult >= 1 olduğundan değer tabandan küçük olmaz).
static func xp_value(sim: GameSim, base: int) -> int:
	var v := sim.v21
	if v == null:
		return base
	v.xp_carry += float(base) * v.p.xp_mult * v.p.xp
	var out := floori(v.xp_carry)
	v.xp_carry -= float(out)
	return out


## Sonsuz'da Lord öldü (DamageSystem._kill): sayaç, bonus, sinyaller, tekrar zamanı. `lord_killed` set EDİLMEZ.
static func on_lord_killed(sim: GameSim) -> void:
	var v := sim.v21
	sim.lords_killed += 1
	sim.score.on_lord()
	if not sim.milestone_won:
		sim.milestone_won = true
		sim.bus.milestone_reached.emit()
	sim.bus.lord_slain.emit(sim.lords_killed)
	if v.p.lord_repeat_sec > 0.0:
		v.next_lord_t = sim.time + v.p.lord_repeat_sec
		v.warned = false


## Lord tekrarı (GameSim._phase_spawn): `warn` sn önce uyarı, süre dolunca doğuş; başarısızsa her adım yeniden denenir.
static func step(sim: GameSim) -> void:
	var v := sim.v21
	if v == null or v.next_lord_t < 0.0:
		return
	if not v.warned and sim.time >= v.next_lord_t - v.lord_warn:
		v.warned = true
		sim.log_event(SimEvents.BOSS_WARNING, {"kind": v.lord_type})
		sim.bus.boss_warning.emit(v.lord_type)
	if sim.time < v.next_lord_t:
		return
	var hp_step := minf(pow(v.p.lord_repeat_hp_mult, v.repeat_n + 1), v.p.lord_hp_cap_mult)
	sim.spawn_director.make_room_for_lord(sim)
	var pos := sim.spawn_director.ring_position(sim, TAU * sim.rng_spawn.randf())
	var id := sim.spawn_enemy(v.lord_type, pos, hp_step)
	if id < 0:
		return
	v.repeat_n += 1
	v.next_lord_t = -1.0
	v.warned = false
	sim.log_event(SimEvents.BOSS_SPAWN, {"enemy_type": v.lord_type, "id": id})
	sim.bus.boss_spawned.emit(v.lord_type)


## state_hash'e SONA eklenir: legacy/profilsizde boş (karma baytı değişmez); xp_carry her legacy olmayan profilde,
## Sonsuz durumu (tekrar, milestone, Lord sayısı) yalnız Sonsuz'da.
static func hash_items(sim: GameSim) -> PackedInt64Array:
	var h := PackedInt64Array()
	var v := sim.v21
	if v == null:
		return h
	h.append(GameSim._q(v.xp_carry))
	if sim.end_mode == GameSim.END_MODE_ENDLESS:
		h.append(v.repeat_n)
		h.append(GameSim._q(v.next_lord_t))
		h.append(1 if v.warned else 0)
		h.append(sim.lords_killed)
		h.append(1 if sim.milestone_won else 0)
	return h


## Sonuç sözlüğüne eklenen alanlar (profilsiz = normal/zor = legacy).
static func result_fields(sim: GameSim) -> Dictionary:
	var prof := sim.run_profile
	return {
		"mode": String(prof.mode) if prof != null else "normal",
		"diff": String(prof.diff) if prof != null else "hard",
		"lords_killed": sim.lords_killed,
		"milestone_won": sim.milestone_won,
	}
