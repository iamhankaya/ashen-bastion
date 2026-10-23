class_name EnemyAI
extends RefCounted
## Hareket, vurulma parlamasının sönmesi, uzaktaki düşmanı geri taşıma. Davranış saf sim içindedir.
## Tüm türler oyuncuya doğru ilerler; elit karga periyodik şarj atar (def.charge), Kale Lordu periyodik piyade
## çağırır ve canı eşiğin altına inince öfkelenir (def.summon). Temas hasarı DamageSystem'dedir.

const RECYCLE_DISTANCE := 1900.0
const FLASH_DECAY := 8.0  # saniyede
const SUMMON_RING := 150.0


func step(sim: GameSim) -> void:
	var dt := GameSim.STEP
	var target := sim.player_pos
	var recycle2 := RECYCLE_DISTANCE * RECYCLE_DISTANCE
	var e := sim.enemies
	var kinds := e.type_kind
	for i in EnemyPool.CAP:
		if e.alive[i] == 0:
			continue
		sim.w_enemy_updates += 1
		var p := e.pos[i]
		var to := target - p
		var d2 := to.length_squared()
		var kind := kinds[e.type_idx[i]]
		var spd := e.speed[i]
		var charging := false
		var is_lord := false
		if kind == EnemyPool.KIND_SPECIAL:
			var def := e.def_of(i)
			if not def.summon.is_empty():
				_lord(sim, i, def, dt)
				spd = e.speed[i]
				is_lord = true
			elif not def.charge.is_empty():
				charging = e.ai_aux[i] > 0.0  # şarj durumu bu adımın BAŞINDAKİ değer
				spd = _charge(e, i, def, to, dt)
				charging = charging or e.ai_aux[i] > 0.0
		if d2 > recycle2 and not is_lord:
			e.pos[i] = sim.spawn_director.recycle_position(sim)
		elif charging and spd > 0.0:
			e.pos[i] = p + e.ai_dir[i] * spd * dt  # şarj: kilitli yönde düz çizgi
		elif d2 > 1.0:
			e.pos[i] = p + to * (spd * dt / sqrt(d2))
		if kind == EnemyPool.KIND_GROUND and ((i + sim.step_count) & 1) == 0:  # iki adımda bir (maliyet)
			e.pos[i] = sim.map.resolve(e.pos[i], e.radius[i] * 0.8)  # yer düşmanları harabelerden kayar
		if e.flash[i] > 0.0:
			e.flash[i] = maxf(0.0, e.flash[i] - FLASH_DECAY * dt)


## Elit karga: her `every` sn'de `duration` sn kilitli yönde `speed` hızıyla şarj. Geçerli hızı döndürür.
func _charge(e: EnemyPool, i: int, def: EnemyDef, to: Vector2, dt: float) -> float:
	if e.ai_aux[i] > 0.0:
		e.ai_aux[i] = maxf(0.0, e.ai_aux[i] - dt)
		return float(def.charge.get("speed", e.speed[i]))
	e.ai_timer[i] -= dt
	if e.ai_timer[i] <= 0.0:
		e.ai_timer[i] = float(def.charge.get("every", 4.0))
		e.ai_aux[i] = float(def.charge.get("duration", 0.8))
		e.ai_dir[i] = to.normalized() if to.length_squared() > 1.0 else Vector2.RIGHT
	return e.speed[i]


## Kale Lordu: periyodik çağırma; canı `enrage_hp_frac` altına inince hız çarpanı (bir kez) ve daha sık çağırma.
func _lord(sim: GameSim, i: int, def: EnemyDef, dt: float) -> void:
	var e := sim.enemies
	var sm := def.summon
	var enraged := e.ai_aux[i] > 0.0
	if not enraged and e.hp[i] < e.max_hp[i] * float(sm.get("enrage_hp_frac", 0.0)):
		e.ai_aux[i] = 1.0
		e.speed[i] *= float(sm.get("enrage_speed_mult", 1.0))
		enraged = true
	e.ai_timer[i] -= dt
	if e.ai_timer[i] > 0.0:
		return
	e.ai_timer[i] += (
		float(sm.get("enrage_every", sm.get("every", 8.0)))
		if enraged
		else float(sm.get("every", 8.0))
	)
	var n := int(sm.get("count", 1))
	var type_id := StringName(str(sm.get("type", "")))
	var a0 := TAU * sim.rng_spawn.randf()
	for k in n:
		sim.spawn_enemy(
			type_id, e.pos[i] + Vector2.from_angle(a0 + TAU * float(k) / float(n)) * SUMMON_RING
		)
