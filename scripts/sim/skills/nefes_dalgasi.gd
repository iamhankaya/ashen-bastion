extends SkillBehavior
## Nefes Dalgası (ritim): rüzgar toplama (doldurma) başlarken çevrede tek dalga; `radius` içindeki düşmanlara hasar
## (`&"dot"`) ve dışa `push` px itme (elit itilmez). Sonsuz Tambur'da doldurma olmadığı için tetiklenmez.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/nefes_dalgasi.json.

var _radius: float = 200.0
var _damage: float = 14.0
var _push: float = 120.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_radius = float(lv.get("radius", _radius))
	_damage = float(lv.get("damage", _damage))
	_push = float(lv.get("push", _push))


func on_reload_start() -> void:
	var sim := api()
	if sim == null:
		return
	var r := _radius * sim.stats.area_mult
	WindUtil.pulse_circle(
		sim, sim.player_pos, r, _damage * sim.stats.bullet_dmg_mult, _push, &"dot"
	)
	sim.fx.wind_wave.emit(sim.player_pos, r, false)
	sim.fx.skill_sfx.emit(&"nefes_dalgasi")
