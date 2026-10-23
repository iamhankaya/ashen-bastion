extends SkillBehavior
## Evrim (doldurma_sacilmasi 5 + fazladan_mermi): doldurma başında 2 x şarjör kapasitesi salvo, doldurma boyunca
## 0,15 sn'de bir altılı halka.

const RANGE := 480.0
const RING_TWIST := 0.37

var _salvo_mult: int = 2
var _damage: float = 20.0
var _ring_every: float = 0.15
var _ring_count: int = 6
var _ring_left: float = 0.0
var _ring_n: int = 0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_salvo_mult = int(lv.get("salvo_mult", _salvo_mult))
	_damage = float(lv.get("damage", _damage))
	_ring_every = float(lv.get("ring_every", _ring_every))
	_ring_count = int(lv.get("ring_count", _ring_count))


func on_reload_start() -> void:
	var sim := api()
	if sim == null:
		return
	_ring_left = _ring_every
	_ring_n = 0
	SkillUtil.radial(
		sim,
		sim.player_pos,
		TAU * sim.rng_combat.randf(),
		_salvo_mult * sim.magazine.cap,
		_damage * sim.stats.bullet_dmg_mult,
		RANGE,
		{"flags": ProjectilePool.FLAG_RADIAL}
	)


func on_reload_tick(dt: float) -> void:
	_ring_left -= dt
	if _ring_left > 0.0:
		return
	_ring_left += _ring_every
	var sim := api()
	if sim == null:
		return
	_ring_n += 1
	SkillUtil.radial(
		sim,
		sim.player_pos,
		_ring_n * RING_TWIST,
		_ring_count,
		_damage * sim.stats.bullet_dmg_mult,
		RANGE,
		{"flags": ProjectilePool.FLAG_RADIAL}
	)
