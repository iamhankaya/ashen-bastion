extends GutTest
## Yer düşmanı katı harabeyi dolanır (F-ashen-bastion-020): arkada takılmaz, kararlı tarafa döner, titremez.


func _solid_setup() -> Dictionary:
	var sim := SimKit.make(1, {"data_kind": "quiet", "log_events": false})
	SimKit.godmode(sim)
	var m := sim.map
	for cx in range(-3, 4):
		for cy in range(-3, 4):
			m.ensure(Vector2(cx * 1024.0, cy * 1024.0))
	for i in m.count:
		var c := m.ob_pos[i]
		if m.ob_solid[i] == 1 and c.length() > 900.0 and c.length() < 2500.0:
			var dir := Vector2.RIGHT
			var player := c + dir * (m.ob_r[i] + 260.0)
			if m.resolve(player, 22.0).distance_to(player) < 0.5:
				return {"sim": sim, "c": c, "r": m.ob_r[i], "player": player, "dir": dir}
	return {}


func test_ground_enemy_circles_solid_ruin_to_reach_player() -> void:
	var s := _solid_setup()
	assert_false(s.is_empty())
	var sim: GameSim = s["sim"]
	var foe: Vector2 = s["c"] - s["dir"] * (s["r"] + 260.0)
	var id := SimKit.add_enemy(sim, &"curumus_piyade", foe)
	sim.enemies.hp[EnemyPool.index_of(id)] = 1.0e9
	sim.player_pos = s["player"]
	var reached := false
	for _k in 60 * 25:
		sim.step(Vector2.ZERO)
		if SimKit.enemy_pos(sim, id).distance_to(s["player"]) < 70.0:
			reached = true
			break
	assert_true(reached, "düşman harabeyi dolanıp oyuncuya ulaşır")


func test_detour_side_is_stable_no_jitter() -> void:
	var s := _solid_setup()
	var sim: GameSim = s["sim"]
	var foe: Vector2 = s["c"] - s["dir"] * (s["r"] + 260.0)
	var id := SimKit.add_enemy(sim, &"curumus_piyade", foe)
	var i := EnemyPool.index_of(id)
	sim.enemies.hp[i] = 1.0e9
	sim.player_pos = s["player"]
	var flips := 0
	var last_side := 0.0
	for _k in 60 * 25:
		sim.step(Vector2.ZERO)
		var side: float = sim.enemies.ai_aux[i]
		if side != 0.0 and last_side != 0.0 and side != last_side:
			flips += 1
		if side != 0.0:
			last_side = side
	assert_eq(flips, 0, "dolanma tarafı değişmez")
	assert_ne(last_side, 0.0, "dolanma moduna girildi")


func test_detour_does_not_affect_free_walk() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "log_events": false})
	sim.player_pos = Vector2.ZERO
	var id := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(0, -300.0))
	var i := EnemyPool.index_of(id)
	for _k in 30:
		sim.step(Vector2.ZERO)
	assert_almost_eq(SimKit.enemy_pos(sim, id).x, 0.0, 0.01, "engelsiz: düz yürür")
	assert_eq(sim.enemies.ai_timer[i], 0.0)
