class_name PickupSystem
extends RefCounted
## Eklenti toplama, süreli etkilerin uygulanması, bomba fitili/patlaması (GameSim'in v1.1 kancalarının gövdeleri).
## GameSim dosyası gdlint 1000 satır sınırına dayandığından kancalar buraya devredilir: GameSim._collect_pickups,
## _apply_buffs, _buffs_ended, _tick_bombs, bomb_blast birer satırla bu sınıfı çağırır.
## Süre sayaçları tam sayı ADIM'dır; toplama yürüyerek olur (XP mıknatısı eklentiyi çekmez).

const DEFAULT_COLLECT_RADIUS := 72.0


## Oyuncu ≤ collect_radius ise eklentiyi toplar (artan indeks): pickup_collected, etki, havuzdan çıkarma.
## Bomba havuzu doluysa bomba eklentisi yerde kalır.
static func collect(sim: GameSim) -> void:
	if sim.pickups.count == 0:
		return
	var r := collect_radius(sim)
	var r2 := r * r
	var pk := sim.pickups
	var i := 0
	while i < pk.count:
		if pk.pos[i].distance_squared_to(sim.player_pos) > r2:
			i += 1
			continue
		var def := sim.data.get_pickup(sim.data.pickup_ids[pk.kind_idx[i]])
		if def.effect == &"bomb" and sim.bombs.is_full():
			i += 1
			continue
		var p := pk.pos[i]
		var kind := pk.kind_idx[i]
		pk.remove(i)  # son eleman i'ye geçer: i artırılmaz
		sim.log_event(SimEvents.PICKUP_COLLECT, {"kind_id": def.id, "pos": p})
		sim.bus.pickup_collected.emit(def.id, p)
		_apply_effect(sim, def, kind, p)


static func collect_radius(sim: GameSim) -> float:
	var sp: Variant = sim.data.pickup_cfg.get("spawn", {})
	if sp is Dictionary:
		return float((sp as Dictionary).get("collect_radius", DEFAULT_COLLECT_RADIUS))
	return DEFAULT_COLLECT_RADIUS


static func _apply_effect(sim: GameSim, def: PickupDef, kind: int, p: Vector2) -> void:
	match def.effect:
		&"heal":
			sim.hp = minf(sim.max_hp, sim.hp + def.amount)
		&"magnet":
			for g in sim.gems.count:
				sim.gems.pulled[g] = 1
		&"buff":
			var bk := BuffManager.kind_of(String(def.buff))
			if bk < 0:
				return
			var fresh := sim.buffs.start(bk, roundi(def.duration * 60.0), def.mult)
			sim.log_event(
				SimEvents.BUFF_START,
				{"kind": def.buff, "duration": def.duration, "refreshed": not fresh}
			)
			sim.bus.buff_started.emit(def.buff, def.duration)
			apply_buffs(sim)
		&"bomb":
			var fuse := roundi(def.fuse * 60.0)
			if sim.bombs.plant(p, fuse, def.radius, kind) >= 0:
				sim.log_event(
					SimEvents.BOMB_PLANT, {"pos": p, "radius": def.radius, "fuse": def.fuse}
				)
				sim.bus.bomb_planted.emit(p, def.radius, def.fuse)


## Biten süreli etkiler (BuffManager.Kind): buff_end olayı/sinyali, ardından apply_buffs.
static func buffs_ended(sim: GameSim, ended: PackedInt32Array) -> void:
	for k in ended:
		var kname := BuffManager.name_of(k)
		sim.log_event(SimEvents.BUFF_END, {"kind": kname})
		sim.bus.buff_ended.emit(kname)
	apply_buffs(sim)


## BuffManager çarpanlarını StatBlock.set_buffs'a ve Magazine.set_unlimited'a yansıtır.
static func apply_buffs(sim: GameSim) -> void:
	sim.stats.set_buffs(sim.buffs.damage_mult(), sim.buffs.fire_rate_mult())
	sim.magazine.set_unlimited(sim.buffs.unlimited())


## Fitili biten bombaları patlatır (GameSim.bomb_blast); WON/LOST sonrası step no-op olduğundan patlamaz.
static func tick_bombs(sim: GameSim) -> void:
	if sim.bombs.count == 0:
		return
	sim.bombs.tick(sim._bomb_ready)
	if sim._bomb_ready.is_empty():
		return
	var n := sim._bomb_ready.size()
	for k in n:  # patlamalar havuzu değiştirmez; indeksler artan
		var b := sim._bomb_ready[k]
		var def := sim.data.get_pickup(sim.data.pickup_ids[sim.bombs.kind_idx[b]])
		var pos := sim.bombs.pos[b]
		var radius := sim.bombs.radius[b]
		sim.bomb_blast(pos, radius, def.dmg, def.elite_frac, def.elite_min)
	for k in range(n - 1, -1, -1):
		sim.bombs.remove(sim._bomb_ready[k])


## Alan hasarı: normal düşmana dmg, elit/Lord için max(elite_min, elite_frac × maks. can); zırhı yok sayar
## (kind = &"explosion"). area_mult/explosion_dmg_mult uygulanmaz. Sırayla explosion (FX/ses yolu) → hasar →
## bomb_exploded. Vurulan sayıyı döndürür.
static func blast(
	sim: GameSim, pos: Vector2, radius: float, dmg: float, elite_frac: float, elite_min: float
) -> int:
	sim.w_explosions += 1
	if sim.logging():
		sim.log_event(
			SimEvents.EXPLOSION, {"pos": pos, "radius": radius, "dmg": dmg, "source": &"bomb"}
		)
	sim.bus.explosion.emit(pos, radius)
	var ids := PackedInt32Array()
	sim.grid.query_circle(pos, radius + sim._max_enemy_radius, ids)
	var hits := 0
	for id in ids:
		if not sim.enemies.is_alive(id):
			continue
		var i := EnemyPool.index_of(id)
		var reach := radius + sim.enemies.radius[i]
		if sim.enemies.pos[i].distance_squared_to(pos) > reach * reach:
			continue
		var amount := dmg
		if sim.enemies.is_elite(i):
			amount = maxf(elite_min, elite_frac * sim.enemies.max_hp[i])
		sim.damage_enemy(id, amount, &"explosion")
		hits += 1
	sim.log_event(SimEvents.BOMB_EXPLODE, {"pos": pos, "radius": radius, "hits": hits})
	sim.bus.bomb_exploded.emit(pos, radius)
	return hits


## GameSim.debug_spawn_pickup gövdesi: türü pickups.json ömrüyle yere koyar; indeks ya da -1 (bilinmeyen tür/dolu).
static func debug_spawn(sim: GameSim, kind_id: StringName, pos: Vector2) -> int:
	var kind := sim.data.pickup_ids.find(kind_id)
	if kind < 0:
		return -1
	var life := 25.0
	var sp: Variant = sim.data.pickup_cfg.get("spawn", {})
	if sp is Dictionary:
		life = float((sp as Dictionary).get("life", life))
	var i := sim.pickups.spawn(kind, pos, roundi(life * 60.0))
	if i >= 0:
		sim.log_event(SimEvents.PICKUP_SPAWN, {"kind_id": kind_id, "pos": pos})
		sim.bus.pickup_spawned.emit(kind_id, pos)
	return i
