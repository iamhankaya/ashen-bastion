class_name GameSim
extends RefCounted
## Sabit 60 Hz adımlı oyun durumu. Sahne ağacından VE autoload'lardan bağımsız saf GDScript.
## Gözlem kancaları: state_hash, event_log, check_invariants, alive_ids, debug_*, work, RNG akışları, step sırası.
## Kurallar: docs/plan "Arayüzler > GameSim".

enum State { RUNNING, LEVEL_UP, WON, LOST }

const STEP := 1.0 / 60.0
const END_MODE_LORD := "lord"
const END_MODE_TIMER := "timer"
const DEFAULT_END_TIME := 1200.0
const DEFAULT_MAX_LOG := 200000
const HASH_QUANT := 64.0  # konumlar 1/64 px nicemlenir
## step() içindeki aşamaların sabit sırası (test bunu Stub.calls() ile doğrular).
const PHASES: Array[StringName] = [
	&"GameSim._phase_ticks",
	&"GameSim._phase_player_move",
	&"GameSim._phase_rebuild_hash",
	&"GameSim._phase_targeting_fire",
	&"GameSim._phase_skills",
	&"GameSim._phase_projectiles",
	&"GameSim._phase_enemy_ai",
	&"GameSim._phase_deaths_xp",
	&"GameSim._phase_spawn",
	&"GameSim._phase_status",
]
const WORK_KEYS: Array[StringName] = [
	&"hash_inserts",
	&"hash_queries",
	&"cells_scanned",
	&"collision_tests",
	&"enemy_updates",
	&"proj_updates",
	&"explosions",
]
const BULLET_SPEED := 900.0
const BULLET_RADIUS := 8.0
const RETARGET_INTERVAL := 0.1
const DRY_FIRE_INTERVAL := 0.5
const GEM_PULL_SPEED := 700.0
const BOUNCE_RANGE := 300.0
## Mermi çarpışma sorgusunun ızgara yarıçapı payı; bundan büyük düşmanlar (_big_ids) ayrıca denetlenir.
const SMALL_ENEMY_RADIUS := 40.0
const DEFAULT_START_SKILL_RANGE := 700.0
const RNG_STREAMS: Array[StringName] = [&"spawn", &"choice", &"map", &"combat"]

var bus: SimBus = SimBus.new()
## Yalnız görsel/işitsel efekt bildirimleri (sim kararları bağlı değil).
var fx: SimFx = SimFx.new()
var data: GameData = null
var character: CharacterDef = null
var end_mode: String = END_MODE_LORD
var end_time: float = DEFAULT_END_TIME

var state: int = State.RUNNING
var time: float = 0.0
var step_count: int = 0
var level: int = 1
var xp: int = 0
var xp_to_next: int = 12  # XpCurve.need(1); U1-6 _init'te XpCurve ile kurar
var pending_levels: int = 0
var hp: float = 100.0
var max_hp: float = 100.0
var kills: int = 0
var player_pos: Vector2 = Vector2.ZERO

var magazine: Magazine = Magazine.new()
var loadout: Loadout = null
var enemies: EnemyPool = EnemyPool.new()
var projectiles: ProjectilePool = ProjectilePool.new()
var gems: GemPool = GemPool.new()
var zones: ZonePool = ZonePool.new()
var stats: StatBlock = StatBlock.new()
var evolved_log: Array[StringName] = []
var event_log: Array = []
var work: Dictionary = {}
var spawn_dropped: int = 0
## Kale Lordu öldü (end_mode lord): _phase_status hp<=0'dan ÖNCE WON yapar.
var lord_killed: bool = false
## Şu an hasar veren merminin bayrakları (on_kill kancaları kaynağı görebilsin diye); mermi dışı kaynak 0.
var kill_source_flags: int = 0

# Alt sistemler ve temel silah durumu.
var grid: SpatialHash = SpatialHash.new()
var damage: DamageSystem = DamageSystem.new()
var spawn_director: SpawnDirector = null
var enemy_ai: EnemyAI = EnemyAI.new()
## cift_tabanca davranışı seviye değerlerini buraya yazar (setup).
var gun_damage: float = 15.0
var gun_interval: float = 0.30
var gun_cd: PackedFloat32Array = PackedFloat32Array([0.0, 0.15])
var gun_target: PackedInt32Array = PackedInt32Array([-1, -1])
## Tabanca başına nişan açısı (radyan); view kolu bununla döndürür.
var gun_aim: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var player_facing_left: bool = false
var last_move: Vector2 = Vector2.ZERO
## opts.trace_phases ise step() aşama adlarını sırayla buraya yazar (sıra testi).
var phase_trace: Array[StringName] = []
# Deterministik iş sayaçlarının sıcak yol kopyaları (step sonunda `work`'e yazılır).
var w_collision_tests: int = 0
var w_enemy_updates: int = 0
var w_proj_updates: int = 0
var w_explosions: int = 0

# Dört ayrı RNG akışı: hash(seed, akış_adı) ile türetilir (yeni özellik başka akışı kaydırmaz).
var rng_spawn: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_choice: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_map: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_combat: RandomNumberGenerator = RandomNumberGenerator.new()

var _seed: int = 0
var _log_events: bool = false
var _max_log: int = DEFAULT_MAX_LOG
var _choices: Array[Choice] = []
var _forced_choices: Array[StringName] = []
var _last_time: float = 0.0
var _time_regressed: bool = false
var _trace_phases: bool = false
var _retarget_cd: float = 0.0
var _dry_cd: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _max_enemy_radius: float = 40.0
var _big_ids: PackedInt32Array = PackedInt32Array()
var _scratch: PackedInt32Array = PackedInt32Array()
var _explode_buf: PackedInt32Array = PackedInt32Array()
var _bounce_buf: PackedInt32Array = PackedInt32Array()


func _init(p_seed: int, character_id: StringName, opts: Dictionary = {}) -> void:
	_seed = p_seed
	end_mode = str(opts.get("end_mode", END_MODE_LORD))
	end_time = float(opts.get("end_time", DEFAULT_END_TIME))
	time = float(opts.get("start_time", 0.0))
	_last_time = time
	_log_events = bool(opts.get("log_events", false))
	_trace_phases = bool(opts.get("trace_phases", false))
	_max_log = int(opts.get("max_log", DEFAULT_MAX_LOG))
	var d: Variant = opts.get("data", null)
	data = d if d is GameData else GameData.load_default()
	character = data.get_character(character_id)
	enemies.bind(data)
	for eid in data.enemy_ids:
		_max_enemy_radius = maxf(_max_enemy_radius, data.get_enemy(eid).radius)
	spawn_director = SpawnDirector.new(data.waves)
	spawn_director.skip_to(time)
	loadout = Loadout.new(data)
	loadout.bind_api(self)
	rng_spawn.seed = _stream_seed(&"spawn")
	rng_choice.seed = _stream_seed(&"choice")
	rng_map.seed = _stream_seed(&"map")
	rng_combat.seed = _stream_seed(&"combat")
	for k in WORK_KEYS:
		work[k] = 0
	magazine.changed.connect(_on_mag_changed)
	magazine.reload_started.connect(_on_reload_started)
	magazine.reload_finished.connect(_on_reload_finished)
	xp_to_next = XpCurve.need(level)
	if character != null:
		max_hp = character.max_hp
		hp = max_hp
		magazine.cap = character.mag_cap
		magazine.count = character.mag_cap
		magazine.base_reload = character.reload_time
		loadout.add_or_upgrade(character.starting_skill)
		_refresh_stats()
		gun_cd[1] = gun_interval * 0.5


## Her çağrı tam STEP ilerler; |move| <= 1; State != RUNNING ise no-op.
func step(move: Vector2) -> void:
	if state != State.RUNNING or character == null:
		return
	var m := move.limit_length(1.0)
	step_count += 1
	time += STEP
	if time < _last_time:
		_time_regressed = true
	_last_time = time
	_phase_ticks(m)
	_phase_player_move(m)
	_phase_rebuild_hash()
	_phase_targeting_fire()
	_phase_skills()
	_phase_projectiles()
	_phase_enemy_ai()
	_phase_deaths_xp()
	_phase_spawn()
	_phase_status()
	_sync_work()


## State == LEVEL_UP iken 1..3 eleman.
func pending_choices() -> Array[Choice]:
	return _choices.duplicate()


## State != LEVEL_UP ya da geçersiz indeks => false, hiçbir şey değişmez.
func choose(index: int) -> bool:
	if state != State.LEVEL_UP or index < 0 or index >= _choices.size():
		return false
	var c := _choices[index]
	match c.kind:
		Choice.KIND_HEAL:
			hp = minf(max_hp, hp + max_hp * Loadout.HEAL_FRACTION)
		Choice.KIND_EVOLUTION:
			loadout.apply_evolution(c.skill_id)
			evolved_log.append(c.skill_id)
			log_event(SimEvents.EVOLUTION, {"evo_id": c.skill_id})
			bus.evolution_gained.emit(c.skill_id)
		_:
			loadout.add_or_upgrade(c.skill_id)
	_refresh_stats()
	log_event(SimEvents.CHOICE_MADE, {"skill_id": c.skill_id})
	bus.choice_made.emit(c.skill_id)
	_choices.clear()
	pending_levels -= 1
	if pending_levels > 0:
		_roll_choices()
	else:
		state = State.RUNNING
	return true


# --- SkillApi (beceri davranışlarının kullandığı yüzey) --------------------------------------


func spawn_projectile(p: Vector2, v: Vector2, dmg: float, o: Dictionary = {}) -> int:
	var idx := projectiles.spawn(p, v, dmg, o)
	if idx >= 0 and _log_events:
		log_event(
			SimEvents.SHOT,
			{
				"gun": -1,
				"origin": p,
				"dir": v.normalized(),
				"dmg": dmg,
				"index_in_mag": 0,
				"is_last": false
			}
		)
	return idx


## Zırhı yok sayar; area_mult / explosion_dmg_mult uygular.
func explode(pos: Vector2, radius: float, dmg: float, source: StringName) -> void:
	var r := radius * stats.area_mult
	var d := dmg * stats.explosion_dmg_mult
	w_explosions += 1
	if _log_events:
		log_event(SimEvents.EXPLOSION, {"pos": pos, "radius": r, "dmg": d, "source": source})
	bus.explosion.emit(pos, r)
	grid.query_circle(pos, r + _max_enemy_radius, _explode_buf)
	for id in _explode_buf:
		if not enemies.is_alive(id):
			continue
		var i := EnemyPool.index_of(id)
		var reach := r + enemies.radius[i]
		if enemies.pos[i].distance_squared_to(pos) <= reach * reach:
			damage.damage_enemy(self, id, d, &"explosion")


## Çizgi üzerindeki tüm düşmanlara vurur (mesafe sırasıyla); vurulan sayıyı döndürür.
func hitscan(origin: Vector2, dir: Vector2, range_px: float, dmg: float) -> int:
	var hits: Array = []
	var d := dir.normalized()
	var end := origin + d * range_px
	for id in enemies.alive_ids():
		var i := EnemyPool.index_of(id)
		var q := Geometry2D.get_closest_point_to_segment(enemies.pos[i], origin, end)
		var reach := enemies.radius[i]
		if q.distance_squared_to(enemies.pos[i]) <= reach * reach:
			hits.append([origin.distance_squared_to(enemies.pos[i]), id])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for h in hits:
		damage.damage_enemy(self, h[1], dmg, &"bullet")
	return hits.size()


func damage_enemy(id: int, amount: float, kind: StringName) -> void:
	damage.damage_enemy(self, id, amount, kind)


## En yüksek canlı hedef; eşitlikte en düşük indeks. -1 = yok.
func pick_highest_hp(from: Vector2, range_px: float) -> int:
	var best := -1
	var best_hp := -INF
	for id in enemies.alive_ids():
		var i := EnemyPool.index_of(id)
		if enemies.pos[i].distance_to(from) > range_px:
			continue
		if enemies.hp[i] > best_hp or (enemies.hp[i] == best_hp and i < EnemyPool.index_of(best)):
			best = id
			best_hp = enemies.hp[i]
	return best


## Düşman doğurur (zamana bağlı çarpanlarla); id ya da havuz doluysa -1 (spawn_dropped++).
func spawn_enemy(type_id: StringName, pos: Vector2) -> int:
	var def := data.get_enemy(type_id)
	if def == null:
		return -1
	var scaled := def.scales_with_time
	var id := enemies.spawn(
		type_id,
		pos,
		Difficulty.enemy_hp_mult(time) if scaled else 1.0,
		1.0,  # temas çarpanı doğma anında değil tick anında uygulanır (DamageSystem.contact_tick)
		Difficulty.enemy_speed_mult(time) if scaled else 1.0
	)
	if id < 0:
		spawn_dropped += 1
		log_event(SimEvents.SPAWN_DROPPED, {"enemy_type": type_id})
	else:
		if _log_events:
			log_event(SimEvents.SPAWN, {"enemy_type": type_id, "id": id, "pos": pos})
	return id


# --- gözlem kancaları (testler/bot/gate; üretim mantığı çağırmaz) ------------------------------


## step_count, oyuncu (konum/hp/xp/seviye), canlı düşman (indeks, konum, hp), mermi/taş sayısı + toplam taş XP,
## şarjör, loadout seviyeleri, 4 RNG durumu. Konumlar 1/64 px nicemlenir. Aynı ikili + aynı tohum => aynı değer.
func state_hash() -> int:
	var h := PackedInt64Array()
	h.append(step_count)
	h.append(state)
	h.append(_q(player_pos.x))
	h.append(_q(player_pos.y))
	h.append(_q(hp))
	h.append(xp)
	h.append(level)
	h.append(pending_levels)
	for id in enemies.alive_ids():
		var i := EnemyPool.index_of(id)
		h.append(i)
		h.append(_q(enemies.pos[i].x))
		h.append(_q(enemies.pos[i].y))
		h.append(_q(enemies.hp[i]))
	h.append(projectiles.count)
	h.append(gems.count)
	h.append(gems.total_value())
	h.append(magazine.count)
	h.append(1 if magazine.reloading else 0)
	h.append(_q(magazine.reload_left))
	for s in loadout.actives():
		h.append(hash(String(s.id)))
		h.append(s.level)
	for s in loadout.passives():
		h.append(hash(String(s.id)))
		h.append(s.level)
	h.append(rng_spawn.state)
	h.append(rng_choice.state)
	h.append(rng_map.state)
	h.append(rng_combat.state)
	return hash(h)


## Boşsa sağlam. Denetler: hp<=max_hp, NaN/inf yok, havuz CAP'leri, xp aralığı, canlı kimlik/nesil uyumu,
## time monoton, şarjör 0..cap, yuva sayısı, taş XP korunumu.
func check_invariants() -> PackedStringArray:
	var out := PackedStringArray()
	if hp > max_hp:
		out.append("hp > max_hp")
	if not (is_finite(hp) and is_finite(max_hp) and is_finite(time)):
		out.append("hp/max_hp/time sonlu değil")
	if not (is_finite(player_pos.x) and is_finite(player_pos.y)):
		out.append("player_pos sonlu değil")
	if enemies.count > EnemyPool.CAP:
		out.append("enemies.count > CAP")
	if projectiles.count > ProjectilePool.CAP:
		out.append("projectiles.count > CAP")
	if gems.count > GemPool.CAP:
		out.append("gems.count > CAP")
	if xp < 0:
		out.append("xp < 0")
	if state != State.LEVEL_UP and xp >= xp_to_next:
		out.append("xp >= xp_to_next (LEVEL_UP dışında)")
	for id in enemies.alive_ids():
		var i := EnemyPool.index_of(id)
		if not enemies.is_alive(id):
			out.append("canlı kimlik nesil uyumsuz: %d" % id)
		elif not (
			is_finite(enemies.pos[i].x) and is_finite(enemies.pos[i].y) and is_finite(enemies.hp[i])
		):
			out.append("düşman %d konum/hp sonlu değil" % i)
	if _time_regressed:
		out.append("time geriye gitti")
	if magazine.count < 0 or magazine.count > magazine.cap:
		out.append("magazine.count aralık dışı")
	if (
		loadout.actives().size() > Loadout.ACTIVE_SLOTS
		or loadout.passives().size() > Loadout.PASSIVE_SLOTS
	):
		out.append("yuva sayısı sınırı aşıldı")
	if gems.dropped_total - gems.collected_total != gems.total_value():
		out.append("taş XP korunumu bozuldu")
	return out


## Canlı düşman kimlikleri, artan sırayla.
func alive_ids() -> PackedInt32Array:
	return enemies.alive_ids()


## Yuva sınırına uyar; evrim kimliği verilirse koşulsuz uygulanır.
func debug_grant(skill_id: StringName, lvl: int = 1) -> void:
	var def := data.get_skill(skill_id)
	if def == null:
		return
	if def.kind == SkillDef.KIND_EVOLUTION:
		loadout.apply_evolution(skill_id)
		evolved_log.append(skill_id)
	else:
		for k in lvl:
			loadout.add_or_upgrade(skill_id)
	_refresh_stats()


## enemy_id veya -1.
func debug_spawn(type_id: StringName, pos: Vector2) -> int:
	return spawn_enemy(type_id, pos)


## Stres/perf: n düşmanı halkaya koyar; doğan sayıyı döndürür.
func debug_fill(type_id: StringName, n: int, ring_radius: float) -> int:
	var made := 0
	for k in n:
		var a := TAU * float(k) / float(maxi(n, 1))
		if spawn_enemy(type_id, player_pos + Vector2.from_angle(a) * ring_radius) >= 0:
			made += 1
	return made


## Yalnızca ileri atlama; atlanan aralıktaki `at` olayları tetiklenmez.
func debug_set_time(t: float) -> void:
	if t <= time:
		return
	time = t
	_last_time = t
	spawn_director.skip_to(t)


func debug_add_xp(n: int) -> void:
	xp += n


## Sonraki roll_choices tam bu kimlikleri döner (tek kullanımlık).
func debug_force_choices(ids: Array[StringName]) -> void:
	_forced_choices = ids.duplicate()


## roll_choices çağıran sim kodu için: zorlanmış kimlikleri döndürür ve temizler (boşsa zorlama yok).
func take_forced_choices() -> Array[StringName]:
	var out := _forced_choices
	_forced_choices = []
	return out


## Olay kaydı açık mı (çağıranlar sözlük kurmadan önce sorar).
func logging() -> bool:
	return _log_events


## event_log'a kayıt ekler (yalnız opts.log_events ise ve max_log aşılmadıysa).
func log_event(type: StringName, fields: Dictionary = {}) -> void:
	if _log_events and event_log.size() < _max_log:
		event_log.append(SimEvents.make(step_count, type, fields))


# --- adım aşamaları ---------------------------------------------------------------------------


func _trace(k: int) -> void:
	if _trace_phases:
		phase_trace.append(PHASES[k])


## (1) tick'ler: şarjör, soğumalar, yenilenme.
func _phase_ticks(_move: Vector2) -> void:
	_trace(0)
	magazine.tick(STEP, stats)
	for g in 2:
		gun_cd[g] -= STEP
		_dry_cd[g] -= STEP
	_retarget_cd -= STEP
	if stats.regen > 0.0 and hp > 0.0:
		hp = minf(max_hp, hp + stats.regen * STEP)


## (2) oyuncu hareketi (sınırsız harita).
func _phase_player_move(move: Vector2) -> void:
	_trace(1)
	last_move = move
	if move.length_squared() > 0.0:
		player_pos += move * character.move_speed * stats.move_speed_mult * STEP
		if move.x < -0.1:
			player_facing_left = true
		elif move.x > 0.1:
			player_facing_left = false


## (3) hash yeniden kur (artan indeks sırasıyla).
func _phase_rebuild_hash() -> void:
	_trace(2)
	grid.clear()
	_big_ids.clear()
	for i in EnemyPool.CAP:
		if enemies.alive[i] == 1:
			var id := EnemyPool.make_id(enemies.gen[i], i)
			grid.insert(id, enemies.pos[i])
			if enemies.radius[i] > SMALL_ENEMY_RADIUS:
				_big_ids.append(id)


## (4) hedefleme + ateş (tabanca 0 sonra 1).
func _phase_targeting_fire() -> void:
	_trace(3)
	var need := _retarget_cd <= 0.0
	for g in 2:
		if gun_target[g] < 0 or not enemies.is_alive(gun_target[g]):
			gun_target[g] = -1
			need = true  # hedefsiz/ölü hedef: bir sonraki düşman gecikmesiz seçilir
	if need:
		_retarget_cd = RETARGET_INTERVAL
		var rng_px := character.attack_range * stats.range_mult
		gun_target[0] = Targeting.pick(0, player_pos, rng_px, enemies, grid, -1)
		gun_target[1] = Targeting.pick(1, player_pos, rng_px, enemies, grid, gun_target[0])
	for g in 2:
		var tid := gun_target[g]
		if tid >= 0:
			gun_aim[g] = (enemies.pos[EnemyPool.index_of(tid)] - player_pos).angle()
		elif last_move.length_squared() > 0.01:
			gun_aim[g] = last_move.angle()
		gun_cd[g] = maxf(gun_cd[g], -STEP)
		if gun_cd[g] > 0.0 or tid < 0:
			continue
		if magazine.reloading:
			if _dry_cd[g] <= 0.0:
				_dry_cd[g] = DRY_FIRE_INTERVAL
				log_event(SimEvents.DRY_FIRE, {"gun": g})
				bus.dry_fire.emit(g)
			continue
		if magazine.can_fire():
			_fire(g, tid)


## Tek kurşun: şarjörden çıkar, beceri kancaları ShotContext'i değiştirir, mermi doğar.
func _fire(g: int, tid: int) -> void:
	var res := magazine.consume()
	var ctx := ShotContext.new()
	ctx.gun = g
	ctx.index_in_mag = res["index"]
	ctx.is_last = res["is_last"]
	# Namlu aim açısına bağlı, aim namluya bağlı: iki yineleme yeter. Atış yönü = son aim; origin = muzzle_world(aim).
	var target_pos := enemies.pos[EnemyPool.index_of(tid)]
	var aim := (target_pos - player_pos).angle()
	var origin := player_pos
	for k in 2:
		origin = PlayerRig.muzzle_world(g, player_pos, aim, cos(aim) < 0.0, character.rig)
		aim = (target_pos - origin).angle()
	ctx.dir = Vector2.from_angle(aim)
	ctx.origin = PlayerRig.muzzle_world(g, player_pos, aim, ctx.dir.x < 0.0, character.rig)
	if g == 0:
		player_facing_left = ctx.dir.x < 0.0
	ctx.damage = gun_damage * stats.bullet_dmg_mult
	for st in loadout.actives():
		if st.behavior != null:
			st.behavior.modify_shot(ctx)
	if ctx.is_last:
		for st in loadout.actives():
			if st.behavior != null:
				st.behavior.on_last_bullet(ctx)
	(
		projectiles
		. spawn(
			ctx.origin,
			ctx.dir * BULLET_SPEED,
			ctx.damage,
			{
				"pierce": ctx.pierce,
				"bounces": ctx.bounces,
				"flags": ctx.flags,
				"ex_radius": ctx.ex_radius,
				"ex_dmg": ctx.ex_dmg,
				"push": ctx.push,
				"gun": g,
			}
		)
	)
	gun_cd[g] += gun_interval / stats.fire_rate_mult
	if g == 0:
		# Hedefsiz bekleyişten sonra iki tabanca eşzamanlı hazırsa ikinciyi yarım aralık geriye at.
		gun_cd[1] = maxf(gun_cd[1], gun_cd[0] - gun_interval / stats.fire_rate_mult * 0.5)
	if _log_events:
		log_event(
			SimEvents.SHOT,
			{
				"gun": g,
				"origin": ctx.origin,
				"dir": ctx.dir,
				"dmg": ctx.damage,
				"index_in_mag": ctx.index_in_mag,
				"is_last": ctx.is_last,
			}
		)
	bus.shot_fired.emit(g, ctx.origin, ctx.dir)
	if ctx.is_last:
		bus.last_bullet_fired.emit(ctx.origin)


## (5) bağımsız beceriler (tick) ve doldurma süresince on_reload_tick.
func _phase_skills() -> void:
	_trace(4)
	for st in loadout.actives():
		if st.behavior == null:
			continue
		st.behavior.tick(STEP)
		if magazine.reloading:
			st.behavior.on_reload_tick(STEP)


## (6) mermi hareketi + çarpışma + hit_ids.
func _phase_projectiles() -> void:
	_trace(5)
	var pr := projectiles
	var i := pr.count - 1
	while i >= 0:
		w_proj_updates += 1
		pr.pos[i] += pr.vel[i] * STEP
		pr.life[i] -= STEP
		var consumed := false
		_scratch.clear()
		if (pr.flags[i] & ProjectilePool.FLAG_LOB) == 0:
			grid.query_circle(pr.pos[i], BULLET_RADIUS + SMALL_ENEMY_RADIUS, _scratch)
			consumed = _projectile_vs(i, _scratch)
			if not consumed and not _big_ids.is_empty():
				consumed = _projectile_vs(i, _big_ids)  # elit/Lord: ızgara sorgusu dışında doğrudan denetlenir
		if not consumed and pr.life[i] <= 0.0:
			if pr.flags[i] & ProjectilePool.FLAG_EXPLODE_ON_EXPIRE:
				explode(pr.pos[i], pr.ex_radius[i], pr.ex_dmg[i], &"projectile")
			consumed = true
		kill_source_flags = 0
		if consumed:
			pr.remove(i)
		i -= 1


## Mermi `pi` aday düşmanlara (artan id sırası) çarpıyor mu; true = mermi tükendi.
func _projectile_vs(pi: int, ids: PackedInt32Array) -> bool:
	var pr := projectiles
	for id in ids:
		if not enemies.is_alive(id) or pr.has_hit(pi, id):
			continue
		w_collision_tests += 1
		var ei := EnemyPool.index_of(id)
		var reach := BULLET_RADIUS + enemies.radius[ei]
		if enemies.pos[ei].distance_squared_to(pr.pos[pi]) <= reach * reach:
			if _projectile_hit(pi, id):
				return true
	return false


## Mermi düşmana değdi. true = mermi tükendi.
func _projectile_hit(pi: int, id: int) -> bool:
	var pr := projectiles
	kill_source_flags = pr.flags[pi]
	damage.damage_enemy(self, id, pr.dmg[pi], &"bullet")
	pr.mark_hit(pi, id)
	for st in loadout.actives():
		if st.behavior != null:
			st.behavior.on_hit(id, pi)
	var f := pr.flags[pi]
	if pr.push[pi] > 0.0 and enemies.is_alive(id):
		var ei := EnemyPool.index_of(id)
		enemies.pos[ei] += pr.vel[pi].normalized() * pr.push[pi]
	if f & ProjectilePool.FLAG_EXPLODES:
		explode(pr.pos[pi], pr.ex_radius[pi], pr.ex_dmg[pi], &"projectile")
	if pr.pierce[pi] > 0:
		pr.pierce[pi] -= 1
		return false
	if (f & ProjectilePool.FLAG_RICOCHET) and pr.bounces[pi] > 0:
		var nxt := _nearest_unhit(pi, BOUNCE_RANGE)
		if nxt >= 0:
			var ni := EnemyPool.index_of(nxt)
			var dir := (enemies.pos[ni] - pr.pos[pi]).normalized()
			pr.vel[pi] = dir * pr.vel[pi].length()
			pr.bounces[pi] -= 1
			pr.life[pi] = maxf(pr.life[pi], 0.5)
			if f & ProjectilePool.FLAG_EXPLODE_ON_BOUNCE:
				explode(pr.pos[pi], pr.ex_radius[pi], pr.ex_dmg[pi], &"projectile")
			return false
	return true


## Mermi için vurulmamış en yakın canlı düşman (eşitlikte en düşük indeks); yoksa -1.
func _nearest_unhit(pi: int, range_px: float) -> int:
	grid.query_circle(projectiles.pos[pi], range_px, _bounce_buf)
	var best := -1
	var best_d := INF
	for id in _bounce_buf:
		if not enemies.is_alive(id) or projectiles.has_hit(pi, id):
			continue
		var d := enemies.pos[EnemyPool.index_of(id)].distance_squared_to(projectiles.pos[pi])
		if d < best_d or (d == best_d and EnemyPool.index_of(id) < EnemyPool.index_of(best)):
			best = id
			best_d = d
	return best


## (7) düşman AI + temas hasarı.
func _phase_enemy_ai() -> void:
	_trace(6)
	enemy_ai.step(self)
	damage.contact_tick(self, STEP)


## (8) taş mıknatısı ve toplama (ölüm/XP taşı düşürme hasar anında yapılır).
func _phase_deaths_xp() -> void:
	_trace(7)
	var pickup := character.pickup_radius * stats.pickup_mult
	var pick2 := pickup * pickup
	var grab := character.collision_radius + 12.0
	var grab2 := grab * grab
	var i := gems.count - 1
	while i >= 0:
		var to := player_pos - gems.pos[i]
		var d2 := to.length_squared()
		if gems.pulled[i] == 1 or d2 <= pick2:
			gems.pulled[i] = 1
			var step_len := GEM_PULL_SPEED * STEP
			if d2 <= step_len * step_len:
				gems.pos[i] = player_pos
				d2 = 0.0
			else:
				gems.pos[i] += to * (step_len / sqrt(d2))
				d2 = gems.pos[i].distance_squared_to(player_pos)
		if d2 <= grab2:
			var v := gems.collect(i)
			xp += v
			if _log_events:
				log_event(SimEvents.GEM_COLLECTED, {"value": v})
			bus.gem_collected.emit(v)
		i -= 1


## (9) doğurma.
func _phase_spawn() -> void:
	_trace(8)
	spawn_director.step(self)


## (10) durum: oyun sonu, seviye atlama.
func _phase_status() -> void:
	_trace(9)
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = XpCurve.need(level)
		pending_levels += 1
		log_event(SimEvents.LEVEL_UP, {"level": level})
		bus.level_up.emit(level)
	if lord_killed:
		_end_run(true)  # Lord ölümü hp<=0'dan önce işlenir
		return
	if hp <= 0.0:
		_end_run(false)  # bekleyen seçimler iptal edilir, seviye sayısı korunur
		return
	if end_mode == END_MODE_TIMER and time >= end_time:
		_end_run(true)
		return
	if pending_levels > 0:
		state = State.LEVEL_UP
		_roll_choices()


func _end_run(won: bool) -> void:
	pending_levels = 0
	_choices.clear()
	state = State.WON if won else State.LOST
	hp = maxf(hp, 0.0)
	log_event(SimEvents.RUN_END, {"won": won})
	var evos: Array = []
	for e in evolved_log:
		evos.append(e)
	bus.run_ended.emit(won, {"time": time, "level": level, "kills": kills, "evolutions": evos})


## Seçenekleri çeker (debug_force_choices varsa tam onları döndürür).
func _roll_choices() -> void:
	var forced := take_forced_choices()
	if forced.is_empty():
		_choices = loadout.roll_choices(rng_choice)
	else:
		_choices = []
		for id in forced:
			var def := data.get_skill(id)
			if def == null:
				continue
			var c := Choice.new()
			c.skill_id = id
			c.title = def.display_name
			c.icon = def.icon
			var have := loadout.level_of(id)
			if def.kind == SkillDef.KIND_EVOLUTION:
				c.kind = Choice.KIND_EVOLUTION
			else:
				c.kind = Choice.KIND_UPGRADE if have > 0 else Choice.KIND_NEW
			c.from_level = have
			c.to_level = have + 1
			c.desc = def.desc[c.to_level - 1] if c.to_level - 1 < def.desc.size() else ""
			_choices.append(c)
	var ids: Array = []
	for c in _choices:
		ids.append(c.skill_id)
	log_event(SimEvents.CHOICES, {"ids": ids})


# --- şarjör sinyalleri -----------------------------------------------------------------------


func _on_mag_changed(count: int, cap: int) -> void:
	bus.magazine_changed.emit(count, cap)


func _on_reload_started(duration: float) -> void:
	log_event(SimEvents.RELOAD_START, {"duration": duration})
	bus.reload_started.emit(duration)
	for st in loadout.actives():
		if st.behavior != null:
			st.behavior.on_reload_start()


func _on_reload_finished() -> void:
	log_event(SimEvents.RELOAD_END)
	bus.reload_finished.emit()
	# İlk kurşun doldurmanın bittiği adımdan bir sonraki adımda çıkar (tick aynı adımda bir STEP düşer).
	gun_cd[0] = STEP * 1.5
	gun_cd[1] = STEP * 1.5 + gun_interval / stats.fire_rate_mult * 0.5
	for st in loadout.actives():
		if st.behavior != null:
			st.behavior.on_reload_end()


# --- yardımcılar -----------------------------------------------------------------------------


func _stream_seed(stream: StringName) -> int:
	return hash([_seed, String(stream)])


## Pasif değişince istatistikleri, azami canı ve şarjör kapasitesini yeniler.
func _refresh_stats() -> void:
	stats.rebuild(loadout, data)
	var new_max := character.max_hp + stats.max_hp_add
	if new_max > max_hp:
		hp += new_max - max_hp
	max_hp = new_max
	hp = minf(hp, max_hp)
	magazine.set_cap(character.mag_cap + stats.mag_add)


func _sync_work() -> void:
	work[&"hash_inserts"] = grid.stat_inserts
	work[&"hash_queries"] = grid.stat_queries
	work[&"cells_scanned"] = grid.stat_cells_scanned
	work[&"collision_tests"] = w_collision_tests
	work[&"enemy_updates"] = w_enemy_updates
	work[&"proj_updates"] = w_proj_updates
	work[&"explosions"] = w_explosions


static func _q(v: float) -> int:
	return roundi(v * HASH_QUANT)
