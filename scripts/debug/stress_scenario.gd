class_name StressScenario
extends RefCounted
## Stres senaryosu (perf ölçümü): 400 düşman + ~500 mermi, sabit tohum. Mikro-ölçüm (tools/perf/micro.gd) ve cihaz
## içi stres koşusu (stress_run.gd) aynı senaryoyu kullanır. Sim kurallarını değiştirmez; yalnız debug_* kancaları ve
## doğrudan mermi doğurma kullanır.

const SEED := 20261023
const ENEMIES := 400
const PROJECTILES := 500
const RING := 450.0
const STEPS := 600
## Ölüm yükü (görünüm ölçümü): her DEATH_EVERY adımda DEATH_KILLS düşman havuzdan çıkarılır + `enemy_killed` yayınlanır
## (hayalet/FX görünüm yükü). Sim kurallarına dokunmaz: XP/ölüm sayacı değişmez, sonraki top_up havuzu doldurur.
const DEATH_EVERY := 20
const DEATH_KILLS := 5

var sim: GameSim
var death_load: bool = false
var _rng := RandomNumberGenerator.new()


func _init(sim_opts: Dictionary = {}, p_death_load: bool = false) -> void:
	death_load = p_death_load
	var o := {"end_mode": "timer", "end_time": 3600.0, "start_time": 900.0}
	o.merge(sim_opts, true)
	sim = GameSim.new(SEED, CharacterRoster.DEFAULT_ID, o)
	_rng.seed = SEED + 1
	top_up()


## Düşman ve mermi sayısını hedefe tamamlar.
func top_up() -> void:
	sim.hp = sim.max_hp  # ölümsüz: senaryo süresince koşu sürmeli
	if sim.enemies.count < ENEMIES:
		sim.debug_fill(&"curumus_piyade", ENEMIES - sim.enemies.count, RING + _rng.randf() * 200.0)
	while sim.projectiles.count < PROJECTILES:
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		sim.spawn_projectile(sim.player_pos + dir * 60.0, dir * 700.0, 5.0, {"life": 1.0})


## Bir sim adımı (oyuncu daire çizer, seviye atlamada ilk kartı seçer).
func step(i: int) -> void:
	if death_load and i % DEATH_EVERY == 0:
		_kill_some()
	top_up()
	while sim.state == GameSim.State.LEVEL_UP:
		sim.choose(0)
	sim.step(Vector2.from_angle(i * 0.02))


## Periyodik ölüm yükü: ilk canlı DEATH_KILLS düşman (artan indeks) çıkarılır, ölüm olayı yayınlanır.
func _kill_some() -> void:
	var killed := 0
	for id in sim.alive_ids():
		if killed >= DEATH_KILLS:
			break
		var i := EnemyPool.index_of(id)
		var type_id := sim.enemies.type_id_of(i)
		var pos := sim.enemies.pos[i]
		sim.enemies.kill(id)
		sim.bus.enemy_killed.emit(type_id, pos)
		killed += 1
