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

var sim: GameSim
var _rng := RandomNumberGenerator.new()


func _init(sim_opts: Dictionary = {}) -> void:
	var o := {"end_mode": "timer", "end_time": 3600.0, "start_time": 900.0}
	o.merge(sim_opts, true)
	sim = GameSim.new(SEED, &"gunslinger", o)
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
	top_up()
	while sim.state == GameSim.State.LEVEL_UP:
		sim.choose(0)
	sim.step(Vector2.from_angle(i * 0.02))
