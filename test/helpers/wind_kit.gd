class_name WindKit
extends RefCounted
## U3 birim testleri için rüzgar yardımcıları: tek beceri verilmiş izole Zyfen sim'i, sabit (ölümsüz/çok canlı) kukla düşman,
## ızgara yenileme ve bölge adımı. Sim içi özel fazları doğrudan çağırır (tek aşama, hatasız tekrarlanabilir).

const TOUGH_HP := 1.0e7
const EMBED_SLACK := 12.0


## Zyfen sim'i; temel silah susturulur (tabanca beklemesi çok büyük), yalnız `skill_id` verilir. Düşman doğuşu yok.
static func make(skill_id: StringName = &"", level: int = 1, seed_value: int = 1) -> GameSim:
	var sim := SimKit.make(seed_value, {"character": &"zyfen", "log_events": false})
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	if skill_id != &"":
		sim.debug_grant(skill_id, level)
	SimKit.godmode(sim)  # beceri verildikten SONRA: debug_grant azami canı yeniden hesaplar
	return sim


## Sabit (hp çok yüksek) kukla düşman; id döner. `type_id` varsayılan curumus_piyade (yer, zırhsız).
static func dummy(sim: GameSim, pos: Vector2, type_id: StringName = &"curumus_piyade") -> int:
	var id := sim.debug_spawn(type_id, pos)
	sim.enemies.hp[EnemyPool.index_of(id)] = TOUGH_HP
	return id


static func hp_of(sim: GameSim, id: int) -> float:
	return sim.enemies.hp[EnemyPool.index_of(id)]


static func pos_of(sim: GameSim, id: int) -> Vector2:
	return sim.enemies.pos[EnemyPool.index_of(id)]


## Izgarayı güncel düşman konumlarından kurar.
static func rebuild(sim: GameSim) -> void:
	sim._phase_rebuild_hash()


## Izgara + bölge adımı (n kez); sim'in başka fazları işlemez.
static func zone_steps(sim: GameSim, n: int) -> void:
	for _k in n:
		rebuild(sim)
		sim.wind.step(sim)


## Izgara + beceri tick'i (n kez) ve ardından bölge adımı: `_phase_skills` ile aynı sıra, tabanca/hareket yok.
static func skill_steps(sim: GameSim, n: int) -> void:
	for _k in n:
		rebuild(sim)
		sim._phase_skills()


static func behavior_of(sim: GameSim, skill_id: StringName) -> SkillBehavior:
	return sim.loadout.state_of(skill_id).behavior


## Havuzdaki mermi sayısı belirli bayrakla.
static func projectiles_with(sim: GameSim, flag: int) -> int:
	var n := 0
	for i in sim.projectiles.count:
		if sim.projectiles.flags[i] & flag:
			n += 1
	return n


## Perf/fuzz senaryosu: Zyfen, `grants` (beceri -> seviye) ve sürekli ~`enemies` canlı düşman (her adım halkadan tamamlanır),
## ölümsüz, seviye atlama kapalı. `steps` adım koşar; adım başına ortalama iş sayaçlarını, en çok bölge sayısını ve
## bölge bulunan adım sayısını döndürür. Sayaçlar deterministiktir (aynı tohum aynı değer); süre (ms) yalnız bilgidir.
static func stress(
	seed_value: int, grants: Dictionary, steps: int, enemies: int = 300
) -> Dictionary:
	var sim := SimKit.make(
		seed_value,
		{"character": &"zyfen", "data_kind": "real", "start_time": 900.0, "log_events": false}
	)
	for k in grants:
		sim.debug_grant(StringName(k), int(grants[k]))
	SimKit.godmode(sim)
	sim.xp_to_next = 1000000000
	var t0 := Time.get_ticks_usec()
	var zone_steps_n := 0
	var zone_max := 0
	var violations := PackedStringArray()
	for i in steps:
		var need := enemies - sim.enemies.count
		if need > 0:
			sim.debug_fill(&"curumus_piyade", need, 450.0)
		sim.step(Vector2.ZERO)
		zone_max = maxi(zone_max, sim.zones.count)
		if sim.zones.count > 0:
			zone_steps_n += 1
		if i % 60 == 0:
			violations.append_array(zone_violations(sim))
	var avg := {}
	for k in GameSim.WORK_KEYS:
		avg[k] = float(sim.work[k]) / float(steps)
	return {
		"sim": sim,
		"avg": avg,
		"ms": float(Time.get_ticks_usec() - t0) / 1000.0,
		"zone_steps": zone_steps_n,
		"zone_max": zone_max,
		"violations": violations,
	}


## Bölge ve düşman değişmezleri: sonlu değerler, CAP, yer düşmanı katı daireye gömülmez. Gömülme eşiği EnemyAI çözümünün
## (0,8 yarıçap) üstüne EMBED_SLACK px pay taşır: doğuş harabe içine düşebilir (rüzgârsız Gunslinger'da 30 px ölçüldü) ve bir
## sonraki AI adımında çözülür; çekme/savurma ise adım başına en çok birkaç px gömer. Bu yüzden gömülme yalnız bir bölgenin
## erişimindeki (yarıçap + fling + pay) yer düşmanlarında denetlenir. Boş dizi = temiz.
static func zone_violations(sim: GameSim) -> PackedStringArray:
	var out := PackedStringArray()
	var z := sim.zones
	if z.count > ZonePool.CAP:
		out.append("zones.count > CAP")
	for i in z.count:
		if not (is_finite(z.pos[i].x) and is_finite(z.pos[i].y) and is_finite(z.life[i])):
			out.append("bölge %d sonlu değil" % i)
		if z.radius[i] < 0.0 or z.tick_every[i] < 0.0:
			out.append("bölge %d negatif yarıçap/tik" % i)
	for id in sim.enemies.alive_ids():
		var e := EnemyPool.index_of(id)
		var p := sim.enemies.pos[e]
		if not (is_finite(p.x) and is_finite(p.y)):
			out.append("düşman %d konumu sonlu değil" % e)
			continue
		if sim.enemies.def_of(e).ai != &"ground" or not _in_reach(z, p):
			continue
		var er := sim.enemies.radius[e] * 0.8
		for c in sim.map.obstacles_near(p):
			if p.distance_to(Vector2(c.x, c.y)) < c.z + er - EMBED_SLACK:
				out.append("düşman %d katı harabeye gömülü" % e)
				break
	return out


static func _in_reach(z: ZonePool, p: Vector2) -> bool:
	for i in z.count:
		if z.pos[i].distance_to(p) <= z.radius[i] + z.fling[i] + 80.0:
			return true
	return false
