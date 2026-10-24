extends SkillBehavior
## Delen Rüzgar: şarjörsüz; soğuma bitince menzildeki (850) EN YÜKSEK canlı düşmana, çizgideki herkesi delen (PIERCE_ALL)
## ince ve hızlı (yarıçap 10, hız 1400) tek kesik (WindUtil.spear). Mermi hasarı olduğu için zırh uygulanır.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/delen_ruzgar.json.

var _cooldown: float = 3.2
var _damage: float = 80.0
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
	if not WindUtil.spear(sim, _damage * sim.stats.bullet_dmg_mult):
		_cd = 0.0
		return
	_cd = _cooldown / sim.stats.fire_rate_mult
