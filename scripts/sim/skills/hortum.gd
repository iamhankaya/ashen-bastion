extends SkillBehavior
## Hortum (v2.0.2 Zyfen): soğuma bitince oyuncuya yakın düşman varsa `count` hortum doğurur (KIND_TWISTER). Hortum düşman
## kümesini kovalar (WindSystem), her 0,4 sn hasar verir, merkeze çeker, ömrü bitince savurur. Soğuma
## `fire_rate_mult`'a bölünür; alan `area_mult`, ömür `wind_time_mult` ile çarpılır (doğuş anında).
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/hortum.json.

var _lv: Dictionary = {}
var _cooldown: float = 6.0
var _cd: float = 0.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	_lv = def.level_data(level) if def != null else {}
	_cooldown = float(_lv.get("cooldown", _cooldown))


func tick(dt: float) -> void:
	_cd -= dt
	if _cd > 0.0:
		return
	var sim := api()
	if sim == null or not WindUtil.enemies_near(sim, WindSystem.RETARGET_RANGE):
		_cd = 0.0
		return
	WindSystem.cast_twisters(sim, ZonePool.KIND_TWISTER, _lv)
	_cd = _cooldown / sim.stats.fire_rate_mult
