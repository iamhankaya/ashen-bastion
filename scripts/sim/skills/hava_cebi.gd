extends SkillBehavior
## Hava Cebi: ölen düşmanın yerinde olasılıkla (`chance`) küçük bir cep (KIND_POCKET) açılır; düşmanları çeker ve vurur.
## Kill başına tam 1 `rng_combat.randf()`. Cep tiki ile ölen düşman cep doğurmaz (zincir yok; bayrak
## `WindSystem.in_pocket_tick`, bu durumda randf de tüketilmez). Havuz rezervi dolu ise cep doğmaz (`fx.zone_dropped`++).
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/hava_cebi.json.

var _chance: float = 0.25
var _radius: float = 70.0
var _damage: float = 8.0
var _life: float = 1.2
var _pull: float = 30.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_chance = float(lv.get("chance", _chance))
	_radius = float(lv.get("radius", _radius))
	_damage = float(lv.get("damage", _damage))
	_life = float(lv.get("life", _life))
	_pull = float(lv.get("pull", _pull))


func on_kill(_enemy_id: int, pos: Vector2) -> void:
	var sim := api()
	if sim == null or sim.wind.in_pocket_tick:
		return
	if sim.rng_combat.randf() >= _chance:
		return
	(
		WindSystem
		. spawn_zone(
			sim,
			ZonePool.KIND_POCKET,
			pos,
			{
				"radius": _radius * sim.stats.area_mult,
				"life": _life * sim.stats.wind_time_mult,
				"tick_every": WindSystem.TICK_EVERY,
				"dmg": _damage * sim.stats.bullet_dmg_mult,
				"pull": _pull,
			}
		)
	)
	sim.fx.skill_sfx.emit(&"hava_cebi")
