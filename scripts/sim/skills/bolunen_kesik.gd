extends SkillBehavior
## Bölünen Kesik (ritim): her `every_n`'inci şarjör kesiği ebeveyn olur (FLAG_SPLITTER, hasar x `damage_mult`). Ebeveyn İLK
## isabette biter ve `count` çocuğa bölünür: açılar 0,5 rad aralıklı simetrik, hasar ebeveyn x 0,6, `pierce` 3, ebeveynin
## vurduğu düşmana vurmaz, yarıçap/hız/kalan ömür ebeveynden miras, FLAG_SPLIT (çocuk bölünmez). Menzil sonunda bölünme
## yok (yalnız on_hit). Sayaç `ctx.index_in_mag`'dir; doldurmada kendiliğinden 1'e döner.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/bolunen_kesik.json.

const CHILD_DMG_MULT := 0.6
const CHILD_PIERCE := 3
const CHILD_ANGLE_STEP := 0.5

var _every_n: int = 3
var _damage_mult: float = 1.0
var _count: int = 2


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_every_n = maxi(1, int(lv.get("every_n", _every_n)))
	_damage_mult = float(lv.get("damage_mult", _damage_mult))
	_count = maxi(1, int(lv.get("count", _count)))


func modify_shot(ctx: ShotContext) -> void:
	if ctx.index_in_mag % _every_n != 0:
		return
	ctx.damage *= _damage_mult
	ctx.flags |= ProjectilePool.FLAG_SPLITTER
	ctx.tags.append("split")


func on_hit(enemy_id: int, proj_id: int) -> void:
	var sim := api()
	if sim == null:
		return
	var pr := sim.projectiles
	var f := pr.flags[proj_id]
	if (f & ProjectilePool.FLAG_SPLITTER) == 0 or (f & ProjectilePool.FLAG_SPLIT) != 0:
		return
	pr.flags[proj_id] = f & ~ProjectilePool.FLAG_SPLITTER
	pr.pierce[proj_id] = 0  # ebeveyn biter (isabet sonrası SimProjectiles._hit tüketir)
	var dir := pr.vel[proj_id].normalized()
	var spd := pr.vel[proj_id].length()
	var opts := {
		"radius": pr.rad[proj_id],
		"life": maxf(pr.life[proj_id], GameSim.STEP * 2.0),
		"pierce": CHILD_PIERCE,
		"flags": ProjectilePool.FLAG_WIND | ProjectilePool.FLAG_SPLIT,
		"gun": pr.gun[proj_id],
	}
	var dmg := pr.dmg[proj_id] * CHILD_DMG_MULT
	var origin := pr.pos[proj_id]
	for k in _count:
		var a := (float(k) - float(_count - 1) * 0.5) * CHILD_ANGLE_STEP
		var ci := sim.spawn_projectile(origin, dir.rotated(a) * spd, dmg, opts)
		if ci >= 0:
			pr.mark_hit(ci, enemy_id)
