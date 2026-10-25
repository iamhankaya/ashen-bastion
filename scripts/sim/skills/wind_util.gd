class_name WindUtil
extends RefCounted
## Rüzgar davranışlarının ortak yardımcıları (saf, durumsuz): delen kesik, yer değiştirme, anlık daire dalgası.

const CRESCENT_SPEED := 900.0
const CRESCENT_RADIUS := 14.0
## displace: delta en çok bu kadar alt adıma bölünür (ince engeli atlamaz, harabe içine gömülmez).
const DISPLACE_STEPS := 4
const DISPLACE_STEP_LEN := 64.0
## Delen Rüzgar / Göğün Mızrağı kesiği: menzil, yarıçap, hız.
const SPEAR_RANGE := 850.0
const SPEAR_RADIUS := 10.0
const SPEAR_SPEED := 1400.0


## Oyuncu becerilerinin (şarjör dışı) mermi çıkış noktası: kolsuzda cast noktası (hedef yönüne göre aynalı), değilse
## oyuncudan namlu payı kadar önde.
static func skill_origin(api: GameSim, dir: Vector2) -> Vector2:
	var rig := api.character.rig
	if PlayerRig.is_armless(rig):
		return PlayerRig.cast_point_world(api.player_pos, dir.x < 0.0, rig)
	return api.player_pos + dir * SkillUtil.MUZZLE_OFFSET


## `radius` px içinde canlı bir düşman var mı (oyuncu merkezli; bölge becerilerinin "hedef var" denetimi).
static func enemies_near(api: GameSim, radius: float) -> bool:
	var ids := PackedInt32Array()
	api.grid.query_circle(api.player_pos, radius, ids)
	for id in ids:
		if api.enemies.is_alive(id):
			return true
	return false


## Menzildeki en yüksek canlı düşmana delen kesik (mermi hasarı: zırh uygulanır). Hedef yoksa false.
static func spear(api: GameSim, dmg: float) -> bool:
	var target := api.pick_highest_hp(api.player_pos, SPEAR_RANGE)
	if target < 0:
		return false
	var tpos := api.enemies.pos[EnemyPool.index_of(target)]
	var origin := skill_origin(api, tpos - api.player_pos)
	crescent(
		api, origin, tpos - origin, dmg, SPEAR_RANGE, {"radius": SPEAR_RADIUS, "speed": SPEAR_SPEED}
	)
	return true


## `dir` yönünde delen kesik (hilal) doğurur; döner: mermi indeksi (-1 = havuz dolu). `origin` olduğu gibi kullanılır.
## o: speed=900, radius=14, pierce=PIERCE_ALL, flags (FLAG_WIND eklenir); verilen diğer anahtarlar (gun, push, ...)
## havuza aynen geçer. Ömür = range_px / speed.
static func crescent(
	api: GameSim, origin: Vector2, dir: Vector2, dmg: float, range_px: float, o: Dictionary = {}
) -> int:
	var opts := o.duplicate()
	var spd := float(opts.get("speed", CRESCENT_SPEED))
	opts.erase("speed")
	opts["radius"] = float(opts.get("radius", CRESCENT_RADIUS))
	opts["pierce"] = int(opts.get("pierce", ProjectilePool.PIERCE_ALL))
	opts["flags"] = int(opts.get("flags", 0)) | ProjectilePool.FLAG_WIND
	opts["life"] = range_px / spd
	return api.spawn_projectile(origin, dir.normalized() * spd, dmg, opts)


## Düşmanı (havuz indeksi) `delta` kadar kaydırır. Elit/Lord yer değiştirmez. Yer düşmanları alt adımlarla
## `map.slide` ile çözülür (harabe içine gömülmez); uçan/hayalet engelden muaftır (EnemyAI ile aynı kural).
static func displace(api: GameSim, enemy_idx: int, delta: Vector2) -> void:
	var e := api.enemies
	if delta == Vector2.ZERO or e.is_elite(enemy_idx):
		return
	if e.def_of(enemy_idx).ai != &"ground":
		e.pos[enemy_idx] += delta
		return
	var n := clampi(ceili(delta.length() / DISPLACE_STEP_LEN), 1, DISPLACE_STEPS)
	var step := delta / float(n)
	var p := e.pos[enemy_idx]
	for _k in n:
		p = api.map.slide(p, p + step, e.radius[enemy_idx])
	e.pos[enemy_idx] = p


## `center` çevresinde `radius` içindeki (dist <= radius + düşman yarıçapı) canlı düşmanlara anlık hasar verir ve
## merkezden dışarı `push` px iter (elit itilmez). Sorgu yarıçapı radius + en büyük düşman yarıçapıdır. Merkezle
## çakışan düşman (mesafe 0) sağa itilir (NaN yok). Sıra: artan kimlik (grid sorgusu).
static func pulse_circle(
	api: GameSim,
	center: Vector2,
	radius: float,
	dmg: float,
	push: float,
	tag: StringName = &"bullet"
) -> void:
	var ids := PackedInt32Array()
	api.grid.query_circle(center, radius + api._max_enemy_radius, ids)
	for id in ids:
		if not api.enemies.is_alive(id):
			continue
		var i := EnemyPool.index_of(id)
		var reach := radius + api.enemies.radius[i]
		if api.enemies.pos[i].distance_squared_to(center) > reach * reach:
			continue
		var away := api.enemies.pos[i] - center
		api.damage_enemy(id, dmg, tag)
		if push > 0.0 and api.enemies.is_alive(id):
			displace(
				api,
				i,
				(away.normalized() if away.length_squared() > 0.0001 else Vector2.RIGHT) * push
			)
