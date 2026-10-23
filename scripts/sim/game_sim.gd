class_name GameSim
extends RefCounted
## Sabit 60 Hz adımlı oyun durumu. Sahne ağacından VE autoload'lardan bağımsız saf GDScript.
## Gövdeler iskelettir (Stub.todo); gözlem kancaları (state_hash, event_log, check_invariants,
## alive_ids, debug_force_choices, work, RNG akışları, step sırası) gerçektir.
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
const RNG_STREAMS: Array[StringName] = [&"spawn", &"choice", &"map", &"combat"]

var bus: SimBus = SimBus.new()
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


func _init(p_seed: int, character_id: StringName, opts: Dictionary = {}) -> void:
	_seed = p_seed
	end_mode = str(opts.get("end_mode", END_MODE_LORD))
	end_time = float(opts.get("end_time", DEFAULT_END_TIME))
	time = float(opts.get("start_time", 0.0))
	_last_time = time
	_log_events = bool(opts.get("log_events", false))
	_max_log = int(opts.get("max_log", DEFAULT_MAX_LOG))
	var d: Variant = opts.get("data", null)
	data = d if d is GameData else GameData.load_default()
	character = data.get_character(character_id)
	if character != null:
		max_hp = character.max_hp
		hp = max_hp
		magazine.cap = character.mag_cap
		magazine.count = character.mag_cap
	loadout = Loadout.new(data)
	rng_spawn.seed = _stream_seed(&"spawn")
	rng_choice.seed = _stream_seed(&"choice")
	rng_map.seed = _stream_seed(&"map")
	rng_combat.seed = _stream_seed(&"combat")
	for k in WORK_KEYS:
		work[k] = 0


## Her çağrı tam STEP ilerler; |move| <= 1; State != RUNNING ise no-op.
func step(move: Vector2) -> void:
	if state != State.RUNNING:
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


## State == LEVEL_UP iken 1..3 eleman.
func pending_choices() -> Array[Choice]:
	return _choices.duplicate()


## State != LEVEL_UP ya da geçersiz indeks => false, hiçbir şey değişmez.
func choose(index: int) -> bool:
	if state != State.LEVEL_UP or index < 0 or index >= _choices.size():
		return false
	Stub.todo(&"GameSim.choose")
	return false


# --- SkillApi (beceri davranışlarının kullandığı yüzey) --------------------------------------


func spawn_projectile(p: Vector2, v: Vector2, dmg: float, o: Dictionary = {}) -> int:
	Stub.todo(&"GameSim.spawn_projectile")
	return -1


## Zırhı yok sayar; area_mult / explosion_dmg_mult uygular.
func explode(pos: Vector2, radius: float, dmg: float, source: StringName) -> void:
	Stub.todo(&"GameSim.explode")


## Çizgi üzerindeki tüm düşmanlara vurur (mesafe sırasıyla); vurulan sayıyı döndürür.
func hitscan(origin: Vector2, dir: Vector2, range_px: float, dmg: float) -> int:
	Stub.todo(&"GameSim.hitscan")
	return 0


func damage_enemy(id: int, amount: float, kind: StringName) -> void:
	Stub.todo(&"GameSim.damage_enemy")


## En yüksek canlı hedef; eşitlikte en düşük indeks. -1 = yok.
func pick_highest_hp(from: Vector2, range_px: float) -> int:
	Stub.todo(&"GameSim.pick_highest_hp")
	return -1


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
	Stub.todo(&"GameSim.debug_grant")


## enemy_id veya -1.
func debug_spawn(type_id: StringName, pos: Vector2) -> int:
	Stub.todo(&"GameSim.debug_spawn")
	return -1


## Stres/perf: n düşmanı halkaya koyar; doğan sayıyı döndürür.
func debug_fill(type_id: StringName, n: int, ring_radius: float) -> int:
	Stub.todo(&"GameSim.debug_fill")
	return 0


## Yalnızca ileri atlama; atlanan aralıktaki `at` olayları tetiklenmez.
func debug_set_time(t: float) -> void:
	Stub.todo(&"GameSim.debug_set_time")


func debug_add_xp(n: int) -> void:
	Stub.todo(&"GameSim.debug_add_xp")


## Sonraki roll_choices tam bu kimlikleri döner (tek kullanımlık).
func debug_force_choices(ids: Array[StringName]) -> void:
	_forced_choices = ids.duplicate()


## roll_choices çağıran sim kodu için: zorlanmış kimlikleri döndürür ve temizler (boşsa zorlama yok).
func take_forced_choices() -> Array[StringName]:
	var out := _forced_choices
	_forced_choices = []
	return out


## event_log'a kayıt ekler (yalnız opts.log_events ise ve max_log aşılmadıysa).
func log_event(type: StringName, fields: Dictionary = {}) -> void:
	if _log_events and event_log.size() < _max_log:
		event_log.append(SimEvents.make(step_count, type, fields))


# --- adım aşamaları (iskelet) --------------------------------------------------------------


func _phase_ticks(move: Vector2) -> void:
	Stub.todo(PHASES[0])


func _phase_player_move(move: Vector2) -> void:
	Stub.todo(PHASES[1])


func _phase_rebuild_hash() -> void:
	Stub.todo(PHASES[2])


func _phase_targeting_fire() -> void:
	Stub.todo(PHASES[3])


func _phase_skills() -> void:
	Stub.todo(PHASES[4])


func _phase_projectiles() -> void:
	Stub.todo(PHASES[5])


func _phase_enemy_ai() -> void:
	Stub.todo(PHASES[6])


func _phase_deaths_xp() -> void:
	Stub.todo(PHASES[7])


func _phase_spawn() -> void:
	Stub.todo(PHASES[8])


func _phase_status() -> void:
	Stub.todo(PHASES[9])


# --- yardımcılar -----------------------------------------------------------------------------


func _stream_seed(stream: StringName) -> int:
	return hash([_seed, String(stream)])


static func _q(v: float) -> int:
	return roundi(v * HASH_QUANT)
