class_name SimHash
extends RefCounted
## GameSim.state_hash gövdesi (R9a çıkarımı). Alan sırası ve nicemleme DEĞİŞMEZ: altın hash'ler buna bağlıdır; yeni alan eklenmez.


## step_count, oyuncu (konum/hp/xp/seviye), canlı düşman (indeks, konum, hp), mermi/taş sayısı + toplam taş XP,
## şarjör, loadout seviyeleri, 4 RNG durumu. Konumlar 1/64 px nicemlenir. Aynı ikili + aynı tohum => aynı değer.
static func compute(sim: GameSim) -> int:
	var h := PackedInt64Array()
	h.append(sim.step_count)
	h.append(sim.state)
	h.append(GameSim._q(sim.player_pos.x))
	h.append(GameSim._q(sim.player_pos.y))
	h.append(GameSim._q(sim.hp))
	h.append(sim.xp)
	h.append(sim.level)
	h.append(sim.pending_levels)
	h.append(1 if sim.lord_killed else 0)
	h.append(sim.spawn_director.progress_hash())
	var enemies := sim.enemies
	for id in enemies.alive_ids():
		var i := EnemyPool.index_of(id)
		h.append(i)
		h.append(GameSim._q(enemies.pos[i].x))
		h.append(GameSim._q(enemies.pos[i].y))
		h.append(GameSim._q(enemies.hp[i]))
		h.append(GameSim._q(enemies.ai_timer[i]))
		h.append(GameSim._q(enemies.ai_aux[i]))
		h.append(GameSim._q(enemies.ai_dir[i].x))
		h.append(GameSim._q(enemies.ai_dir[i].y))
	h.append(sim.projectiles.count)
	h.append(sim.gems.count)
	h.append(sim.gems.total_value())
	h.append(sim.magazine.count)
	h.append(1 if sim.magazine.reloading else 0)
	h.append(GameSim._q(sim.magazine.reload_left))
	for s in sim.loadout.actives():
		h.append(hash(String(s.id)))
		h.append(s.level)
	for s in sim.loadout.passives():
		h.append(hash(String(s.id)))
		h.append(s.level)
	h.append(sim.rng_spawn.state)
	h.append(sim.rng_choice.state)
	h.append(sim.rng_map.state)
	h.append(sim.rng_combat.state)
	h.append_array(V11State.hash_items(sim))  # v1.1: sona eklenir, mevcut sıra değişmez
	h.append_array(sim.zones.hash_items())  # v2.0.2: bölge yokken boş (Gunslinger hash'i değişmez)
	h.append_array(V21Sim.hash_items(sim))  # v2.1: legacy/profilsizde boş
	return hash(h)
