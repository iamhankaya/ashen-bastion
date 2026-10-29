class_name SimInvariants
extends RefCounted
## GameSim.check_invariants gövdesi (R9a çıkarımı). Mesaj metinleri ve sırası DEĞİŞMEZ (karakterizasyon bazı).


## Boşsa sağlam. Denetler: hp<=max_hp, NaN/inf yok, havuz CAP'leri, xp aralığı, canlı kimlik/nesil uyumu,
## time monoton, şarjör 0..cap, yuva sayısı, taş XP korunumu.
static func check(sim: GameSim) -> PackedStringArray:
	var out := PackedStringArray()
	var enemies := sim.enemies
	var magazine := sim.magazine
	var gems := sim.gems
	if sim.hp > sim.max_hp:
		out.append("hp > max_hp")
	if not (is_finite(sim.hp) and is_finite(sim.max_hp) and is_finite(sim.time)):
		out.append("hp/max_hp/time sonlu değil")
	if not (is_finite(sim.player_pos.x) and is_finite(sim.player_pos.y)):
		out.append("player_pos sonlu değil")
	if enemies.count > EnemyPool.CAP:
		out.append("enemies.count > CAP")
	if sim.projectiles.count > ProjectilePool.CAP:
		out.append("projectiles.count > CAP")
	if gems.count > GemPool.CAP:
		out.append("gems.count > CAP")
	if sim.xp < 0:
		out.append("xp < 0")
	if sim.state != GameSim.State.LEVEL_UP and sim.xp >= sim.xp_to_next:
		out.append("xp >= xp_to_next (LEVEL_UP dışında)")
	for id in enemies.alive_ids():
		var i := EnemyPool.index_of(id)
		if not enemies.is_alive(id):
			out.append("canlı kimlik nesil uyumsuz: %d" % id)
		elif not (
			is_finite(enemies.pos[i].x) and is_finite(enemies.pos[i].y) and is_finite(enemies.hp[i])
		):
			out.append("düşman %d konum/hp sonlu değil" % i)
	if sim._time_regressed:
		out.append("time geriye gitti")
	if magazine.count < 0 or magazine.count > magazine.cap:
		out.append("magazine.count aralık dışı")
	if (
		sim.loadout.actives().size() > Loadout.ACTIVE_SLOTS
		or sim.loadout.passives().size() > Loadout.PASSIVE_SLOTS
	):
		out.append("yuva sayısı sınırı aşıldı")
	if gems.dropped_total - gems.collected_total != gems.total_value():
		out.append("taş XP korunumu bozuldu")
	V11State.check(sim, out)
	return out
