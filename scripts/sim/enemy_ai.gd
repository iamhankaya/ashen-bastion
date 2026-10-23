class_name EnemyAI
extends RefCounted
## Hareket, vurulma parlamasının sönmesi, uzaktaki düşmanı geri taşıma. Davranış saf sim içindedir
## (U1: tüm türler oyuncuya doğru ilerler; engel yok). Temas hasarı DamageSystem'dedir.

const RECYCLE_DISTANCE := 1900.0
const FLASH_DECAY := 8.0  # saniyede


func step(sim: GameSim) -> void:
	var dt := GameSim.STEP
	var target := sim.player_pos
	var recycle2 := RECYCLE_DISTANCE * RECYCLE_DISTANCE
	var e := sim.enemies
	for i in EnemyPool.CAP:
		if e.alive[i] == 0:
			continue
		sim.w_enemy_updates += 1
		var p := e.pos[i]
		var to := target - p
		var d2 := to.length_squared()
		if d2 > recycle2:
			e.pos[i] = sim.spawn_director.recycle_position(sim)
		elif d2 > 1.0:
			e.pos[i] = p + to * (e.speed[i] * dt / sqrt(d2))
		if e.flash[i] > 0.0:
			e.flash[i] = maxf(0.0, e.flash[i] - FLASH_DECAY * dt)
