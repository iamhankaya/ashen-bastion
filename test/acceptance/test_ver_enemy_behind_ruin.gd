extends GutTest
## Doğrulama-2 (T20261023-80): F-ashen-bastion-020 (kod incelemesi #1). Sıradan yer düşmanı katı harabenin tam
## arkasında (oyuncu–düşman doğrultusu harabe merkezinden geçerken) takılıp yığılıyor mu? Ölçüm sim'de.

const HZ := 60
const SECONDS := 25
const REACH := 70.0
const CASES_PER_SEED := 14


## Katı engel `i` için oyuncu bir yanda, düşman tam karşı yanda; doğrultu engel merkezinden geçer.
func _scenario(seed_value: int, n_enemies: int) -> Dictionary:
	var sim := SimKit.make(seed_value, {"data_kind": "quiet", "log_events": false})
	SimKit.godmode(sim)
	var m := sim.map
	for cx in range(-3, 4):
		for cy in range(-3, 4):
			m.ensure(Vector2(cx * 1024.0, cy * 1024.0))
	var cases := 0
	var reached := 0
	var stuck := 0
	var worst_min := 0.0
	for i in m.count:
		if m.ob_solid[i] != 1 or cases >= CASES_PER_SEED:
			continue
		var c := m.ob_pos[i]
		if c.length() < 700.0 or c.length() > 2600.0:
			continue
		var dir := Vector2.from_angle(float(i) * 2.399)  # her engel için farklı yön
		var reach := m.ob_r[i] + 260.0
		var player := c + dir * reach
		var foe := c - dir * reach
		if m.resolve(player, 22.0).distance_to(player) > 0.5:
			continue  # başka harabeye gömülü başlangıç
		var enemies: Array[int] = []
		for k in n_enemies:
			var e := SimKit.add_enemy(
				sim, &"curumus_piyade", foe + Vector2(0, 30.0 * k - 15.0 * n_enemies)
			)
			sim.enemies.hp[EnemyPool.index_of(e)] = 1.0e9  # oyuncunun silahı ölçümü bozmasın
			enemies.append(e)
		sim.player_pos = player
		cases += 1
		var ok := false
		var first := -1
		var mark := Vector2.ZERO
		for s in HZ * SECONDS:
			sim.step(Vector2.ZERO)
			if s == HZ * (SECONDS - 5):
				mark = SimKit.enemy_pos(sim, enemies[0])
			var near := 0
			for e in enemies:
				if sim.enemies.is_alive(e) and SimKit.enemy_pos(sim, e).distance_to(player) < REACH:
					near += 1
			if near > 0 and first < 0:
				first = s
			if near == enemies.size():
				ok = true
				break
		if ok:
			reached += 1
		else:
			stuck += 1
			worst_min = maxf(worst_min, float(HZ * SECONDS))
		for e in enemies:
			if sim.enemies.is_alive(e):
				sim.enemies.alive[EnemyPool.index_of(e)] = 0
		var fin := SimKit.enemy_pos(sim, enemies[0])
		(
			gut
			. p(
				(
					"seed %d ob %d r=%.0f: first_contact=%.1fs all_reached=%s son_mesafe=%.0f son5sn_yer_degisim=%.1f"
					% [
						seed_value,
						i,
						m.ob_r[i],
						first / 60.0 if first >= 0 else -1.0,
						ok,
						fin.distance_to(player),
						fin.distance_to(mark)
					]
				)
			)
		)
	return {"cases": cases, "reached": reached, "stuck": stuck}


func test_f_ashen_bastion_020_single_ground_enemy_reaches_player_from_directly_behind_solid_ruin(
) -> void:
	var tot := {"cases": 0, "reached": 0, "stuck": 0}
	for s in [1, 2, 3]:
		var r := _scenario(s, 1)
		for k in tot:
			tot[k] += r[k]
	gut.p("TEK DÜŞMAN: %s" % str(tot))
	assert_gt(tot["cases"], 10)
	assert_eq(
		tot["stuck"],
		0,
		(
			"tek düşman harabe arkasından oyuncuya ulaşır (takılan: %d/%d)"
			% [tot["stuck"], tot["cases"]]
		)
	)


func test_f_ashen_bastion_020_enemy_group_reaches_player_from_directly_behind_solid_ruin() -> void:
	var tot := {"cases": 0, "reached": 0, "stuck": 0}
	for s in [1, 2, 3]:
		var r := _scenario(s, 8)
		for k in tot:
			tot[k] += r[k]
	gut.p("8'Lİ GRUP: %s" % str(tot))
	assert_gt(tot["cases"], 10)
	assert_eq(
		tot["stuck"],
		0,
		"grup harabe arkasından oyuncuya ulaşır (takılan: %d/%d)" % [tot["stuck"], tot["cases"]]
	)
