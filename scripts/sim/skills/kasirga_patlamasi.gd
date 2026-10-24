extends SkillBehavior
## Kasırga Patlaması (Nefes Dalgası evrimi): doldurma başında ve `min(interval; doldurma x 0,8)` sn aralıkla toplam
## `count` ekran boyu dalga (`big`). İkinci dalga zamanlayıcısı yalnız doldurma ilerlerken akar (`on_reload_tick`);
## seviye atlama/duraklatma sim'i durdurur, ölüm ya da doldurma sonu (`on_reload_end`) zamanlayıcıyı iptal eder.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/kasirga_patlamasi.json.

const REMAINING_WAVE_GAP := 0.8

var _damage: float = 40.0
var _radius: float = 900.0
var _push: float = 260.0
var _count: int = 2
var _interval: float = 0.5
var _waves_left: int = 0
var _timer: float = 0.0
var _gap: float = 0.5


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_damage = float(lv.get("damage", _damage))
	_radius = float(lv.get("radius", _radius))
	_push = float(lv.get("push", _push))
	_count = maxi(1, int(lv.get("count", _count)))
	_interval = float(lv.get("interval", _interval))


func on_reload_start() -> void:
	var sim := api()
	if sim == null:
		return
	_wave(sim)
	_gap = minf(_interval, sim.magazine.reload_total * REMAINING_WAVE_GAP)
	_waves_left = _count - 1
	_timer = _gap


func on_reload_tick(dt: float) -> void:
	if _waves_left <= 0:
		return
	_timer -= dt
	if _timer > 0.0:
		return
	var sim := api()
	if sim == null:
		return
	_wave(sim)
	_waves_left -= 1
	_timer += _gap


func on_reload_end() -> void:
	_waves_left = 0


func _wave(sim: GameSim) -> void:
	WindUtil.pulse_circle(
		sim, sim.player_pos, _radius, _damage * sim.stats.bullet_dmg_mult, _push, &"dot"
	)
	sim.fx.wind_wave.emit(sim.player_pos, _radius, true)
	sim.fx.skill_sfx.emit(&"kasirga_patlamasi")
