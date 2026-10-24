extends SceneTree
## v1.1 D1 masaüstü mikro-ölçüm (zaman yalnız BİLGİDİR; gate'e giren değerler iş sayaçlarıdır):
## 300 düşmanla EnemyRenderer.refresh (hareket + gölge + kare seçimi), oyuncu PlayerAnim/PlayerView, FxRenderer ve hayalet.
## Kullanım: godot --headless -s res://tools/perf/anim_micro.gd [-- --json]
## Bütçe (plan G): düşman animasyonu @300 ≤ 0,4 ms/kare, kare seçimi ≤ 0,15, oyuncu ≤ 0,05, FxRenderer ≤ 0,15.

const FRAMES := 300
const ENEMY_MIX := [[&"curumus_piyade", 150], [&"les_kargasi", 100], [&"sovalye_hayaleti", 50]]


func _init() -> void:
	var sim := GameSim.new(20261023, &"gunslinger", {"end_mode": "lord", "start_time": 900.0})
	for m in ENEMY_MIX:
		sim.debug_fill(m[0], m[1], 450.0 + 40.0 * float(m[1] % 7))
	var er := EnemyRenderer.new()
	var shadows := EnemyShadowLayer.new()
	er.shadows = shadows
	root.add_child(er)
	root.add_child(shadows)
	er.bind(sim)
	var pv := PlayerView.new()
	root.add_child(pv)
	pv.bind(sim)
	var fx := FxRenderer.new()
	root.add_child(fx)
	fx.bind(sim, null)
	var ghosts := AshGhostRenderer.new()
	root.add_child(ghosts)
	ghosts.bind(sim, er)
	er.set_ghosts(ghosts)

	var enemy_us := 0.0
	var player_us := 0.0
	var fx_us := 0.0
	var ghost_us := 0.0
	var worst_enemy_us := 0.0
	for f in FRAMES:
		sim.time = float(f) / 60.0
		sim.player_pos += Vector2(5.0, 0.0)
		for k in 6:  # periyodik ölüm yükü: kare başına 6 hayalet olayı
			sim.bus.enemy_killed.emit(&"curumus_piyade", sim.player_pos + Vector2(200 + k * 30, 0))
		var a := Time.get_ticks_usec()
		er.refresh()
		var b := Time.get_ticks_usec()
		pv.update_view(1.0 / 60.0)
		var c := Time.get_ticks_usec()
		fx.update_fx(1.0 / 60.0)
		var d := Time.get_ticks_usec()
		ghosts.update_ghosts(1.0 / 60.0)
		var e := Time.get_ticks_usec()
		enemy_us += float(b - a)
		worst_enemy_us = maxf(worst_enemy_us, float(b - a))
		player_us += float(c - b)
		fx_us += float(d - c)
		ghost_us += float(e - d)
	var out := {
		"frames": FRAMES,
		"enemies": sim.enemies.count,
		"counters":
		{
			"last_anim_instances": er.last_anim_instances,
			"last_frame_selects": er.last_frame_selects,
			"last_shadow_instances": er.last_shadow_instances,
			"ghosts": ghosts.ghost_count(),
		},
		"info_ms_per_frame":
		{
			"enemy_refresh": snappedf(enemy_us / FRAMES / 1000.0, 0.001),
			"enemy_refresh_worst": snappedf(worst_enemy_us / 1000.0, 0.001),
			"player_view": snappedf(player_us / FRAMES / 1000.0, 0.001),
			"fx_update": snappedf(fx_us / FRAMES / 1000.0, 0.001),
			"ghost_update": snappedf(ghost_us / FRAMES / 1000.0, 0.001),
		},
	}
	print(JSON.stringify(out, "  "))
	quit()
