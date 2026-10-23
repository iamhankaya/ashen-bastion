class_name V11State
extends RefCounted
## v1.1 durumunun gözlem kancaları: state_hash eklemeleri, check_invariants eklemeleri, run_ended istatistikleri.
## GameSim dosyası gdlint 1000 satır sınırında olduğundan ayrıdır; GameSim.state_hash/check_invariants/_end_run çağırır.


## state_hash'e SONA eklenen v1.1 öğeleri (sıra sabittir): skor, SERİ, eklentiler, etkiler, bombalar, direktör, rng_pickup.
static func hash_items(sim: GameSim) -> PackedInt64Array:
	var h := PackedInt64Array()
	h.append(sim.score.total())
	h.append(sim.score.streak_count)
	h.append(sim.score.last_kill_step)
	h.append(sim.pickups.count)
	for i in mini(sim.pickups.count, PickupPool.CAP):
		h.append(sim.pickups.kind_idx[i])
		h.append(GameSim._q(sim.pickups.pos[i].x))
		h.append(GameSim._q(sim.pickups.pos[i].y))
		h.append(sim.pickups.left_steps[i])
	for k in BuffManager.COUNT:
		h.append(sim.buffs.left_steps[k])
	h.append(sim.bombs.count)
	for i in mini(sim.bombs.count, BombPool.CAP):
		h.append(GameSim._q(sim.bombs.pos[i].x))
		h.append(GameSim._q(sim.bombs.pos[i].y))
		h.append(sim.bombs.fuse_steps[i])
	h.append(sim.pickup_director.next_step)
	h.append(sim.rng_pickup.state)
	for id in sim.enemies.alive_ids():  # F-021 kaçış durumu (yer düşmanı)
		var k := EnemyPool.index_of(id)
		h.append(sim.enemies.stuck_n[k])
		h.append(GameSim._q(sim.enemies.esc_left[k]))
		h.append(GameSim._q(sim.enemies.esc_side[k]))
		h.append(GameSim._q(sim.enemies.push_n[k].x))
		h.append(GameSim._q(sim.enemies.push_n[k].y))
	return h


## v1.1 değişmezleri: eklenti/bomba CAP'leri, süre sayaçları aralığı, SERİ çarpanı, skor monotonluğu, sınırsız şarjör.
## Skor monotonluğu için sim._last_score izlenir (bu çağrı onu günceller).
static func check(sim: GameSim, out: PackedStringArray) -> void:
	if sim.pickups.count > PickupPool.CAP:
		out.append("pickups.count > CAP")
	if sim.bombs.count > BombPool.CAP:
		out.append("bombs.count > CAP")
	for k in BuffManager.COUNT:
		if sim.buffs.left_steps[k] < 0 or sim.buffs.left_steps[k] > sim.buffs.total_steps[k]:
			out.append("buff %d left_steps aralık dışı" % k)
	for i in mini(sim.pickups.count, PickupPool.CAP):
		if sim.pickups.left_steps[i] < 0:
			out.append("eklenti %d left_steps < 0" % i)
	for i in mini(sim.bombs.count, BombPool.CAP):
		if sim.bombs.fuse_steps[i] < 0 or sim.bombs.fuse_steps[i] > sim.bombs.fuse_total[i]:
			out.append("bomba %d fuse_steps aralık dışı" % i)
	var max_mult := 1
	for t in sim.data.score_table.tiers:
		max_mult = maxi(max_mult, t.y)
	if sim.score.mult < 1 or sim.score.mult > max_mult:
		out.append("SERİ çarpanı aralık dışı")
	for v in sim.score.parts().values():
		if v < 0:
			out.append("skor bileşeni < 0")
			break
	var total := sim.score.total()
	if total < sim._last_score:
		out.append("skor geriye gitti")
	sim._last_score = maxi(sim._last_score, total)
	if (
		sim.buffs.left_steps[BuffManager.Kind.UNLIMITED] > 0
		and sim.magazine.count != sim.magazine.cap
	):
		out.append("sınırsız şarjörde magazine.count != cap")


## ScoreKeeper.gained -> score olayı + bus.score_changed.
static func on_score_gained(sim: GameSim, gain: int, source: StringName) -> void:
	var total := sim.score.total()
	sim.log_event(
		SimEvents.SCORE, {"gain": gain, "total": total, "mult": sim.score.mult, "source": source}
	)
	sim.bus.score_changed.emit(total, sim.score.mult, gain)


## run_ended sözlüğüne eklenen alanlar: score, score_parts, best_mult.
static func end_stats(sim: GameSim) -> Dictionary:
	return {
		"score": sim.score.total(),
		"score_parts": sim.score.parts(),
		"best_mult": sim.score.best_mult,
	}
