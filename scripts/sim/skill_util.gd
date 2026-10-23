class_name SkillUtil
extends RefCounted
## Beceri davranışlarının ortak yardımcıları (saf, durumsuz). Mermi çıkışı SkillApi.spawn_projectile üzerindendir.

const MUZZLE_OFFSET := 30.0
const NEAR_RANGE_PAD := 0.0


## Menzil (px) -> mermi ömrü (sn), BULLET_SPEED ile.
static func life_for_range(range_px: float) -> float:
	return range_px / GameSim.BULLET_SPEED


## `dir` yönünde tek saçma/mermi; döner: mermi indeksi (-1 = havuz dolu).
static func pellet(
	api: GameSim, origin: Vector2, dir: Vector2, dmg: float, range_px: float, o: Dictionary = {}
) -> int:
	var opts := o.duplicate()
	opts["life"] = life_for_range(range_px)
	return api.spawn_projectile(origin + dir * MUZZLE_OFFSET, dir * GameSim.BULLET_SPEED, dmg, opts)


## `n` saçmayı `base_angle` etrafında `spread` radyanlık yelpazede eşit aralıkla atar.
static func fan(
	api: GameSim,
	origin: Vector2,
	base_angle: float,
	spread: float,
	n: int,
	dmg: float,
	range_px: float,
	o: Dictionary = {}
) -> void:
	for k in n:
		var f := 0.0 if n <= 1 else float(k) / float(n - 1) - 0.5
		pellet(api, origin, Vector2.from_angle(base_angle + f * spread), dmg, range_px, o)
	api.fx.volley_fired.emit(origin, n)


## `n` mermiyi 360° eşit aralıkla (başlangıç açısı `angle0`) atar.
static func radial(
	api: GameSim,
	origin: Vector2,
	angle0: float,
	n: int,
	dmg: float,
	range_px: float,
	o: Dictionary = {}
) -> void:
	for k in n:
		pellet(
			api, origin, Vector2.from_angle(angle0 + TAU * float(k) / float(n)), dmg, range_px, o
		)
	api.fx.volley_fired.emit(origin, n)
