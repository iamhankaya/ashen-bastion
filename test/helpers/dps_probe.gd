class_name DpsProbe
extends RefCounted
## Ham DPS ölçer (v2.0.2 S2; D fazı ve denge tabloları için). Oyuncunun çevresine N hareketsiz "kukla" düşman koyar
## (can çok büyük, zırhsız; her adımdan önce sabit konuma geri taşınır), belirli süre koşar, kuklalardan düşen toplam canı
## süreye böler. Ölçüm sim'in gerçek yolunu kullanır (hedefleme, atış, davranışlar, hasar); yalnız oyuncu ölümsüzdür.
## Düzenler: &"ring" (R px yarıçaplı halka), &"line" (tek eksen üzerinde sıralı; delme ölçümü), &"cluster" (sıkı küme).
## Sonuç: {"dps", "total", "seconds", "dummies", "per_dummy", "shots"}. Tek seferlik ölçüm, rastgelelik tohumla sabit.

const DUMMY_TYPE := &"curumus_piyade"
const DUMMY_HP := 1.0e7
const DEFAULT_SECONDS := 20.0
const DEFAULT_DUMMIES := 12


## skills: {beceri_kimliği: seviye}. Evrim kimlikleri seviye 1 ile koşulsuz uygulanır (debug_grant).
static func measure(
	character: StringName,
	skills: Dictionary = {},
	layout: StringName = &"ring",
	dummies: int = DEFAULT_DUMMIES,
	seconds: float = DEFAULT_SECONDS,
	seed_value: int = 1
) -> Dictionary:
	var sim := SimKit.make(seed_value, {"character": character, "log_events": false})
	SimKit.godmode(sim)
	for id in skills:
		sim.debug_grant(StringName(id), int(skills[id]))
	var spots := _layout(sim.player_pos, layout, dummies)
	var ids: Array[int] = []
	for p in spots:
		var id := sim.debug_spawn(DUMMY_TYPE, p)
		if id >= 0:
			sim.enemies.hp[EnemyPool.index_of(id)] = DUMMY_HP
			ids.append(id)
	var shots := [0]
	sim.bus.shot_fired.connect(func(_g: int, _o: Vector2, _d: Vector2) -> void: shots[0] += 1)
	var steps := int(round(seconds / GameSim.STEP))
	for n in steps:
		if sim.state != GameSim.State.RUNNING:
			break
		for k in ids.size():
			sim.enemies.pos[EnemyPool.index_of(ids[k])] = spots[k]
		sim.step(Vector2.ZERO)
	var total := 0.0
	for id in ids:
		if sim.enemies.is_alive(id):
			total += DUMMY_HP - sim.enemies.hp[EnemyPool.index_of(id)]
	return {
		"dps": total / seconds,
		"total": total,
		"seconds": seconds,
		"dummies": ids.size(),
		"per_dummy": total / maxf(ids.size(), 1),
		"shots": shots[0],
	}


static func _layout(center: Vector2, layout: StringName, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in n:
		match layout:
			&"line":
				out.append(center + Vector2(160.0 + 40.0 * k, 0.0))
			&"cluster":
				out.append(center + Vector2(260.0, 0.0) + Vector2(36.0 * (k % 4), 36.0 * (k / 4)))
			_:
				out.append(center + Vector2.from_angle(TAU * float(k) / float(maxi(n, 1))) * 260.0)
	return out
