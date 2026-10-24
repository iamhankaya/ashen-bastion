extends SkillBehavior
## Girdap: oyuncunun çevresinde sürekli halka; her `interval` sn'de içindeki düşmanlara tek darbe (hasar `&"dot"`, zırhı
## yok sayar) ve dışa `push` px itme (elit/Lord hasar alır, itilmez). Yarıçap her adım `taban x area_mult` (Fırtına Gözü
## anında etki eder); `current_radius()` görünümün halka çizimi içindir. Bölge değil, davranışın kendisidir.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/girdap.json.

const SFX_EVERY := 4.0

var _radius: float = 90.0
var _damage: float = 6.0
var _interval: float = 0.5
var _push: float = 14.0
var _left: float = 0.0
var _sfx_left: float = 0.0  # ses döngüsü: halka sürekli, ses her SFX_EVERY sn'de bir tek seferlik


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_radius = float(lv.get("radius", _radius))
	_damage = float(lv.get("damage", _damage))
	_interval = float(lv.get("interval", _interval))
	_push = float(lv.get("push", _push))
	_left = _interval


func tick(dt: float) -> void:
	_sfx_left -= dt
	if _sfx_left <= 0.0:
		_sfx_left = SFX_EVERY
		var s := api()
		if s != null:
			s.fx.skill_sfx.emit(&"girdap")
	_left -= dt
	if _left > 0.0:
		return
	_left += _interval
	var sim := api()
	if sim == null:
		return
	WindUtil.pulse_circle(
		sim, sim.player_pos, current_radius(), _damage * sim.stats.bullet_dmg_mult, _push, &"dot"
	)


## Etkin halka yarıçapı (px): taban x area_mult.
func current_radius() -> float:
	var sim := api()
	return _radius * (sim.stats.area_mult if sim != null else 1.0)
