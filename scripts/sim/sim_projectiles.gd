class_name SimProjectiles
extends RefCounted
## GameSim faz 6 (mermi hareketi + çarpışma + hit_ids) gövdesi (R9b çıkarımı; yalnız taşıma, davranış/RNG/sıra DEĞİŞMEZ).


## Mermiler ters sırayla gezilir; isabet, delme, sekme ve süre sonu patlaması burada işlenir. Faz izi ve `_tick_bombs` GameSim'de kalır.
static func step(sim: GameSim) -> void:
	var pr := sim.projectiles
	var i := pr.count - 1
	while i >= 0:
		sim.w_proj_updates += 1
		pr.pos[i] += pr.vel[i] * GameSim.STEP
		pr.life[i] -= GameSim.STEP
		var consumed := false
		sim._scratch.clear()
		if (pr.flags[i] & ProjectilePool.FLAG_LOB) == 0:
			sim.grid.query_circle(pr.pos[i], pr.rad[i] + GameSim.SMALL_ENEMY_RADIUS, sim._scratch)
			for id in sim._scratch:
				if not sim.enemies.is_alive(id) or pr.has_hit(i, id):
					continue
				sim.w_collision_tests += 1
				var ei := EnemyPool.index_of(id)
				var reach := pr.rad[i] + sim.enemies.radius[ei]
				if sim.enemies.pos[ei].distance_squared_to(pr.pos[i]) <= reach * reach:
					if _hit(sim, i, id):
						consumed = true
						break
			if not consumed and not sim._big_ids.is_empty():
				consumed = _vs(sim, i, sim._big_ids)  # elit/Lord: ızgara sorgusu dışında doğrudan denetlenir
		if not consumed and pr.life[i] <= 0.0:
			if pr.flags[i] & ProjectilePool.FLAG_EXPLODE_ON_EXPIRE:
				sim.explode(pr.pos[i], pr.ex_radius[i], pr.ex_dmg[i], &"projectile")
			consumed = true
		sim.kill_source_flags = 0
		if consumed:
			pr.remove(i)
		i -= 1


## Mermi `pi` aday düşmanlara (artan id sırası) çarpıyor mu; true = mermi tükendi.
static func _vs(sim: GameSim, pi: int, ids: PackedInt32Array) -> bool:
	var pr := sim.projectiles
	for id in ids:
		if not sim.enemies.is_alive(id) or pr.has_hit(pi, id):
			continue
		sim.w_collision_tests += 1
		var ei := EnemyPool.index_of(id)
		var reach := pr.rad[pi] + sim.enemies.radius[ei]
		if sim.enemies.pos[ei].distance_squared_to(pr.pos[pi]) <= reach * reach:
			if _hit(sim, pi, id):
				return true
	return false


## Mermi düşmana değdi. true = mermi tükendi.
static func _hit(sim: GameSim, pi: int, id: int) -> bool:
	var pr := sim.projectiles
	var enemies := sim.enemies
	sim.kill_source_flags = pr.flags[pi]
	sim.damage.damage_enemy(sim, id, pr.dmg[pi], &"bullet")
	pr.mark_hit(pi, id)
	for st in sim.loadout.actives():
		if st.behavior != null:
			st.behavior.on_hit(id, pi)
	var f := pr.flags[pi]
	if pr.push[pi] > 0.0 and enemies.is_alive(id) and not enemies.is_elite(EnemyPool.index_of(id)):
		var ei := EnemyPool.index_of(id)
		enemies.pos[ei] += pr.vel[pi].normalized() * pr.push[pi]
	if f & ProjectilePool.FLAG_EXPLODES:
		sim.explode(pr.pos[pi], pr.ex_radius[pi], pr.ex_dmg[pi], &"projectile")
	if pr.pierce[pi] > 0:
		pr.pierce[pi] -= 1
		return false
	if (f & ProjectilePool.FLAG_RICOCHET) and pr.bounces[pi] > 0:
		var nxt := _nearest_unhit(sim, pi, GameSim.BOUNCE_RANGE)
		if nxt >= 0:
			var ni := EnemyPool.index_of(nxt)
			var dir := (enemies.pos[ni] - pr.pos[pi]).normalized()
			pr.vel[pi] = dir * pr.vel[pi].length()
			pr.bounces[pi] -= 1
			pr.life[pi] = maxf(pr.life[pi], 0.5)
			if f & ProjectilePool.FLAG_EXPLODE_ON_BOUNCE:
				sim.explode(pr.pos[pi], pr.ex_radius[pi], pr.ex_dmg[pi], &"projectile")
			return false
	return true


## Mermi için vurulmamış en yakın canlı düşman (eşitlikte en düşük indeks); yoksa -1.
static func _nearest_unhit(sim: GameSim, pi: int, range_px: float) -> int:
	sim.grid.query_circle(sim.projectiles.pos[pi], range_px, sim._bounce_buf)
	var best := -1
	var best_d := INF
	for id in sim._bounce_buf:
		if not sim.enemies.is_alive(id) or sim.projectiles.has_hit(pi, id):
			continue
		var d := sim.enemies.pos[EnemyPool.index_of(id)].distance_squared_to(
			sim.projectiles.pos[pi]
		)
		if d < best_d or (d == best_d and EnemyPool.index_of(id) < EnemyPool.index_of(best)):
			best = id
			best_d = d
	return best
