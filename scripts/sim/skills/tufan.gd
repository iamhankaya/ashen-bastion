extends SkillBehavior
## Tufan (Hortum evrimi): soğuma bitince oyuncuya yakın düşman varsa `count` dev hortum (KIND_GIANT) doğurur. Rezerv
## slotları (ZonePool.RESERVE) sayesinde Hava Cebi ile dolu havuzda bile kaybolmaz.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/tufan.json.

var _lv: Dictionary = {}
var _cooldown: float = 9.0
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
	WindSystem.cast_twisters(sim, ZonePool.KIND_GIANT, _lv)
	_cd = _cooldown / sim.stats.fire_rate_mult
