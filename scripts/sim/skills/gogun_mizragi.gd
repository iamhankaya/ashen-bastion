extends SkillBehavior
## Göğün Mızrağı (Delen Rüzgar evrimi): soğuma bitince art arda `count` mızrak, `gap` sn arayla; her biri ATIŞ ANINDA
## menzildeki en yüksek canlı düşmanı hedefler (delen_ruzgar ile aynı kesik: yarıçap 10, hız 1400, PIERCE_ALL).
## Atış anında hedef yoksa o mızrak atlanır. Soğuma salvonun BAŞLANGICINDAN sayılır.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/gogun_mizragi.json.

var _cooldown: float = 1.8
var _count: int = 4
var _damage: float = 100.0
var _gap: float = 0.12
var _cd: float = 0.0
var _left: int = 0
var _gap_left: float = 0.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_cooldown = float(lv.get("cooldown", _cooldown))
	_count = maxi(1, int(lv.get("count", _count)))
	_damage = float(lv.get("damage", _damage))
	_gap = float(lv.get("gap", _gap))


func tick(dt: float) -> void:
	var sim := api()
	if sim == null:
		return
	_cd -= dt
	var dmg := _damage * sim.stats.bullet_dmg_mult
	if _left > 0:
		_gap_left -= dt
		if _gap_left <= 0.0:
			WindUtil.spear(sim, dmg)
			_left -= 1
			_gap_left += _gap
		return
	if _cd > 0.0:
		return
	if not WindUtil.spear(sim, dmg):
		_cd = 0.0
		return
	_left = _count - 1
	_gap_left = _gap
	_cd = _cooldown / sim.stats.fire_rate_mult
