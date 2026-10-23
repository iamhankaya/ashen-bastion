class_name EnemyAI
extends RefCounted
## Hareket, vurulma parlamasının sönmesi, uzaktaki düşmanı geri taşıma. Davranış saf sim içindedir.
## Tüm türler oyuncuya doğru ilerler; elit karga periyodik şarj atar (def.charge), Kale Lordu periyodik piyade
## çağırır ve canı eşiğin altına inince öfkelenir (def.summon). Temas hasarı DamageSystem'dedir.

const RECYCLE_DISTANCE := 1900.0
const FLASH_DECAY := 8.0  # saniyede
const SUMMON_RING := 150.0
## Yer düşmanı katı harabe tarafından bu kadar itilirse (px) dolanma moduna girer; mod DETOUR_TIME sn sürer.
const PUSH_DETOUR := 0.25
const DETOUR_TIME := 0.5
const DETOUR_FWD := 0.5  # dolanırken hedef yönü ağırlığı; teğet ağırlığı sqrt(1 - FWD^2)
const DETOUR_TAN := 0.866
const STUCK_CHECK := 90  # adım; bu aralıkta STUCK_DIST'ten az ilerleyen düşman dolanma tarafını değiştirir
const STUCK_DIST := 40.0
const SIDE_MARGIN := 0.15  # |teğet·hedef| bunun altındaysa taraf belirsiz sayılır


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
			var dir := to / sqrt(d2)
			if kind == EnemyPool.KIND_GROUND and e.ai_timer[i] > 0.0:
				# dolanma: sabit taraf (ai_aux = ±1), hedef yönü + teğet; harabenin arkasında takılmayı kırar
				dir = dir * DETOUR_FWD + Vector2(-dir.y, dir.x) * (e.ai_aux[i] * DETOUR_TAN)
			e.pos[i] = p + dir * (spd * dt)
		if kind == EnemyPool.KIND_GROUND:
			e.ai_timer[i] = maxf(0.0, e.ai_timer[i] - dt)
			if ((i + sim.step_count) & 1) == 0:  # iki adımda bir (maliyet)
				var before := e.pos[i]
				e.pos[i] = sim.map.resolve(before, e.radius[i] * 0.8)  # yer düşmanları harabelerden kayar
				var pushed := e.pos[i].distance_squared_to(before) > PUSH_DETOUR * PUSH_DETOUR
				if (sim.step_count + i) % STUCK_CHECK == 0:
					# dolanırken çukura/içbükey köşeye girdiyse (aralıkta ilerleme yok) taraf değiştir
					if (
						e.ai_timer[i] > 0.0
						and e.pos[i].distance_squared_to(e.ai_dir[i]) < STUCK_DIST * STUCK_DIST
					):
						e.ai_aux[i] = -e.ai_aux[i]
					e.ai_dir[i] = e.pos[i]  # ilerleme çapası
				if e.ai_timer[i] > 0.0:
					if e.pos[i] != before:
						e.ai_timer[i] = DETOUR_TIME  # hâlâ itiliyor: modu tazele
				elif pushed:
					_pick_side(e, i, e.pos[i] - before, to)
					e.ai_timer[i] = DETOUR_TIME
		if e.flash[i] > 0.0:
			e.flash[i] = maxf(0.0, e.flash[i] - FLASH_DECAY * dt)


## Dolanma tarafı: engel normaline dik iki teğetten hedefe yakın olanı (kısa taraf). Hedef normalle hizalıyken
## (belirsiz) mevcut taraf korunur; hiç yoksa indeks paritesi — böylece karar kararlı ve titremesizdir.
func _pick_side(e: EnemyPool, i: int, push: Vector2, to: Vector2) -> void:
	var tl := to.length()
	var pl := push.length()
	if tl > 1.0 and pl > 0.0:
		var n := push / pl
		var d := to / tl
		var t := Vector2(-n.y, n.x)
		var along := t.dot(d)
		if absf(along) > SIDE_MARGIN:
			var want := t if along > 0.0 else -t
			e.ai_aux[i] = 1.0 if Vector2(-d.y, d.x).dot(want) > 0.0 else -1.0
			return
	if e.ai_aux[i] == 0.0:
		e.ai_aux[i] = 1.0 if (i & 1) == 0 else -1.0


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
