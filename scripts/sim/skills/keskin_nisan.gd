extends SkillBehavior
## Şarjörsüz hitscan: soğuma bitince menzildeki (900) en yüksek canlı düşmana, çizgideki herkesi delen tek atış.

const RANGE := 900.0

var _cooldown: float = 3.0
var _damage: float = 90.0
var _cd: float = 0.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_cooldown = float(lv.get("cooldown", _cooldown))
	_damage = float(lv.get("damage", _damage))


func tick(dt: float) -> void:
	_cd -= dt
	if _cd > 0.0:
		return
	var sim := api()
	if sim == null:
		return
	var target := sim.pick_highest_hp(sim.player_pos, RANGE)
	if target < 0:
		_cd = 0.0
		return
	var dir := (sim.enemies.pos[EnemyPool.index_of(target)] - sim.player_pos).normalized()
	sim.fx.beam_fired.emit(sim.player_pos, sim.player_pos + dir * RANGE)
	sim.hitscan(sim.player_pos, dir, RANGE, _damage * sim.stats.bullet_dmg_mult)
	_cd = _cooldown / sim.stats.fire_rate_mult
