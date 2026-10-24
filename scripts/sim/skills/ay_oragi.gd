extends SkillBehavior
## Ay Orağı (Bölünen Kesik evrimi): her `every_n`'inci şarjör kesiği dev hilal olur (hasar x `damage_mult`, yarıçap `radius`,
## hız `speed`, menzil `range`, PIERCE_ALL) ve BÖLÜNMEZ (FLAG_SPLIT). Temel saldırının kesiğini değiştirir; kesikte yoksa
## dokunmaz. modify_shot yalnız artırır (yarıçap max, pierce max): Rüzgar Kesiği ile sıra bağımsızdır.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/ay_oragi.json.

var _every_n: int = 2
var _damage_mult: float = 3.5
var _radius: float = 40.0
var _speed: float = 1300.0
var _range: float = 1100.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_every_n = maxi(1, int(lv.get("every_n", _every_n)))
	_damage_mult = float(lv.get("damage_mult", _damage_mult))
	_radius = float(lv.get("radius", _radius))
	_speed = float(lv.get("speed", _speed))
	_range = float(lv.get("range", _range))


func modify_shot(ctx: ShotContext) -> void:
	if ctx.index_in_mag % _every_n != 0:
		return
	ctx.damage *= _damage_mult
	ctx.radius = maxf(ctx.radius, _radius)
	ctx.speed = maxf(ctx.speed, _speed)
	ctx.life = _range / ctx.speed
	ctx.pierce = ProjectilePool.PIERCE_ALL
	ctx.flags = (
		(ctx.flags | ProjectilePool.FLAG_WIND | ProjectilePool.FLAG_SPLIT)
		& ~ProjectilePool.FLAG_SPLITTER
	)
	ctx.tags.append("crescent_moon")
