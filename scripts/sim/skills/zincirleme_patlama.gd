extends SkillBehavior
## Evrim (seken_mermi 5 + barut_kesesi): her 2. kurşun seker (8 sekme) ve her sekmede patlar (hasar 40, yarıçap 90;
## alan/patlama çarpanları sim'in `explode`ında uygulanır). Değerler plan "Evrimler" tablosundandır; veri kaydı
## (data/skills/zincirleme_patlama.json) U2-3'te gelir, seviye verisi varsa o öncelikli.

const EVERY_N := 2
const BOUNCES := 8
const EX_RADIUS := 90.0
const EX_DAMAGE := 40.0

var _every_n: int = EVERY_N
var _bounces: int = BOUNCES
var _ex_radius: float = EX_RADIUS
var _ex_damage: float = EX_DAMAGE


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_every_n = maxi(1, int(lv.get("every_n", EVERY_N)))
	_bounces = int(lv.get("bounces", BOUNCES))
	_ex_radius = float(lv.get("ex_radius", EX_RADIUS))
	_ex_damage = float(lv.get("ex_damage", EX_DAMAGE))


func modify_shot(ctx: ShotContext) -> void:
	if ctx.index_in_mag % _every_n != 0:
		return
	ctx.bounces += _bounces
	ctx.flags |= ProjectilePool.FLAG_RICOCHET | ProjectilePool.FLAG_EXPLODE_ON_BOUNCE
	ctx.ex_radius = maxf(ctx.ex_radius, _ex_radius)
	ctx.ex_dmg = maxf(ctx.ex_dmg, _ex_damage)
	ctx.tags.append("chain_explosion")
