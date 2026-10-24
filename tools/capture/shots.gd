extends SceneTree
## Ekran görüntüsü öz-kontrolü (masaüstü render; commit'lenmez çıktı). Kullanım:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 1080x2400 \
##     -s res://tools/capture/shots.gd -- <çıktı_dizini> [senaryo,senaryo]
## Senaryolar: menu, game, crowd, boss, lord, levelup, pause, win, lose, contrast, ruins, stress,
##   names (i içeren beceri adları kartta), winc3 / winc0 (kombolu/kombosuz sonuç), ruinwalk (çarpışma daireleri + yürüyüş)

var out_dir := "/tmp/shots/"
var scenarios: PackedStringArray = ["menu", "game", "crowd"]
var c: Node


## Çarpışma dairelerini ve oyuncu dairesini dünya üstüne çizer (yalnız ekran görüntüsü öz-kontrolü).
class CollisionOverlay:
	extends Node2D
	var map: MapSim
	var sim: GameSim

	func _draw() -> void:
		for o in map.obstacles_near(sim.player_pos):
			draw_arc(Vector2(o.x, o.y), o.z, 0.0, TAU, 32, Color(1, 0.85, 0, 0.9), 3.0)
		draw_arc(
			sim.player_pos, sim.character.collision_radius, 0.0, TAU, 24, Color(0.2, 1, 0.4, 1), 3.0
		)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0].path_join("")
	if args.size() > 1:
		scenarios = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir + n + ".png")
	print("shot ", n, " ", img.get_width(), "x", img.get_height())


## Haritadaki en büyük katı harabenin sarmalayan çember merkezi.
func _big_ruin(m: MapSim) -> Vector2:
	var best := -1
	for i in m.count:
		if m.ob_solid[i] == 1 and m.ob_pos[i].x > 900.0 and (best < 0 or m.ob_r[i] > m.ob_r[best]):
			best = i
	return m.ob_pos[best] if best >= 0 else Vector2(1800, 0)


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Sim'i `n` adım (kare beklemeden) ilerletir; seviye atlamada ilk kartı seçer.
func advance(n: int, move: Vector2 = Vector2.ZERO, auto_choose: bool = true) -> void:
	var sim: GameSim = c.sim
	for i in n:
		if auto_choose and sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			sim.max_hp = 1.0e9
			sim.hp = 1.0e9
		if sim.state != GameSim.State.RUNNING:
			break
		sim.step(move)
	c._after_step()


func fresh(opts: Dictionary = {}) -> void:
	if c != null:
		c.queue_free()
		await process_frame
	c = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(c)
	await frames(3)
	c.start_run()
	await frames(2)
	c.sim.max_hp = 1.0e9
	c.sim.hp = 1.0e9


## Öz-kontrol için yerel skor listesini geçici dosyada kurar (gerçek kullanıcı dosyasına dokunmaz).
func _fresh_scores(filled: bool) -> void:
	var path := "user://shots_hs.json"
	DirAccess.remove_absolute(path)
	c.highscores = Highscores.new(path)
	if filled:
		var t := 1_761_000_000
		for sc in [246350, 171900, 154200, 131775, 118420, 96050, 72310]:
			c.highscores.submit(
				{
					"score": sc,
					"time": 1200 - (246350 - sc) / 300,
					"won": sc > 150000,
					"level": 9,
					"unix": t
				}
			)
			t -= 86400


func _run() -> void:
	c = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(c)
	await frames(5)
	for sc in scenarios:
		match sc:
			"menu":
				await shot("menu")
			"game":
				await fresh()
				advance(300, Vector2(0.6, 0.3))
				await frames(3)
				await shot("game")
			"crowd":
				await fresh()
				c.sim.debug_set_time(900.0)
				for t in [&"curumus_piyade", &"les_kargasi", &"sovalye_hayaleti"]:
					c.sim.debug_fill(t, 90, 380.0)
				for sk in [
					&"yelpaze_atis", &"dinamit", &"seken_mermi", &"son_mermi_patlar", &"sarapnel"
				]:
					c.sim.debug_grant(sk, 3)
				c.sim.max_hp = 1.0e9
				c.sim.hp = 1.0e9
				advance(240, Vector2(0.4, 0.4))
				await frames(3)
				await shot("crowd")
			"boss":
				await fresh()
				c.sim.debug_spawn(&"elit_piyade", c.sim.player_pos + Vector2(250, -200))
				c.sim.debug_spawn(&"elit_sovalye", c.sim.player_pos + Vector2(-300, 150))
				c.sim.debug_spawn(&"elit_karga", c.sim.player_pos + Vector2(0, 350))
				advance(30)
				await frames(3)
				await shot("boss")
			"lord":
				await fresh()
				c.sim.debug_spawn(&"kale_lordu", c.sim.player_pos + Vector2(0, -420))
				advance(60)
				c.hud.show_boss_band(&"kale_lordu")
				await frames(3)
				await shot("lord")
			"ruins":
				await fresh()
				c.sim.map.ensure(Vector2(1800, 0))
				var target := _big_ruin(c.sim.map)
				c.sim.player_pos = target + Vector2(0, 380)
				c.sim.debug_fill(&"curumus_piyade", 25, 520.0)
				c.sim.debug_grant(&"son_mermi_patlar", 4)
				c.sim.debug_grant(&"dinamit", 3)
				c.sim.max_hp = 1.0e9
				c.sim.hp = 1.0e9
				advance(150)
				await frames(3)
				await shot("ruins")
			"ruinwalk":
				await fresh()
				var m: MapSim = c.sim.map
				m.ensure(Vector2(1800, 0))
				var tgt := _big_ruin(m)
				c.sim.player_pos = m.resolve(tgt + Vector2(0, 420), 22.0)
				var ov := CollisionOverlay.new()
				ov.map = m
				ov.sim = c.sim
				ov.z_index = 50
				c.world.add_child(ov)
				for k in 160:  # üstüne doğru yürü, sonra eğik bas (kayma)
					var d: Vector2 = (tgt - c.sim.player_pos).normalized()
					c.sim.step(d if k < 110 else d.rotated(deg_to_rad(40.0)))
					ov.queue_redraw()
				c._after_step()
				await frames(3)
				await shot("ruinwalk")
			"names":
				await fresh()
				var ids := [&"barut_kesesi", &"son_mermi_patlar", &"kiyamet_mermisi"]
				var chs: Array = []
				for id in ids:
					var ch := Choice.new()
					ch.kind = Choice.KIND_NEW
					ch.skill_id = id
					ch.to_level = 1
					ch.title = c.sim.data.get_skill(id).display_name
					ch.desc = "Açıklama"
					chs.append(ch)
				var heal := Choice.new()
				heal.kind = Choice.KIND_HEAL
				heal.title = "Şifa"
				chs.append(heal)
				c.level_up.show_choices(chs, 7, c.sim.data)
				await frames(40)
				await shot("names")
			"winc3", "winc0":
				await fresh()
				var evos: Array = []
				if sc == "winc3":
					evos = [&"kiyamet_mermisi", &"mermi_firtinasi", &"son_mermi_patlar"]
				var rows := UiKit.combo_rows(evos, c.sim.data)
				c.ui.visible = true
				c.result_screen.show_result(
					sc == "winc3",
					{"time": 1290.0, "level": 31, "kills": 4210, "evolutions": evos},
					rows
				)
				c.result_screen.finish_count()
				await frames(30)
				await shot(sc)
			"d3hud":
				await fresh()
				advance(120, Vector2(0.6, 0.3))
				for i in 12:
					c.sim.score.on_kill(&"curumus_piyade", c.sim.step_count)
				c.sim.score.on_kill(&"elit_karga", c.sim.step_count)
				c.sim.bus.score_changed.emit(c.sim.score.total(), c.sim.score.mult, 1500)
				await frames(6)
				await shot("d3hud")
			"d3menu":
				c.go_menu()
				await frames(20)
				await shot("d3menu")
			"d3scores", "d3scores_empty":
				await fresh()
				_fresh_scores(sc == "d3scores")
				c.go_menu()
				c.open_scores()
				await frames(30)
				await shot(sc)
			"d3result", "d3result_top10", "d3result_lost":
				await fresh()
				_fresh_scores(sc != "d3result")
				advance(240)
				for i in 30:
					c.sim.score.on_kill(&"elit_piyade", c.sim.step_count)
				if sc == "d3result":
					c.sim.score.on_lord()
					c.sim.score.on_evolution()
				c.sim.hp = 0.0
				advance(10)
				c.flush_delay()
				await frames(90)
				c.result_screen.finish_count()
				await frames(10)
				await shot(sc)
			"chars", "chars_b", "chars_lock":
				await _chars(sc)
			"levelup_b":
				root.get_node("Settings").character_id = "barutcu"
				await fresh()
				c.sim.debug_add_xp(30)
				advance(5, Vector2.ZERO, false)
				await frames(40)
				await shot(sc)
				root.get_node("Settings").character_id = ""
			"levelup":
				await fresh()
				c.sim.debug_add_xp(30)
				advance(5, Vector2.ZERO, false)
				await frames(40)
				await shot("levelup")
			"pause":
				await fresh()
				advance(120)
				c.pause_game()
				await frames(10)
				await shot("pause")
			"win", "lose":
				await fresh()
				advance(60)
				if sc == "win":
					c.sim.end_mode = GameSim.END_MODE_TIMER
					c.sim.end_time = 1.0
				else:
					c.sim.hp = 0.0
				c.sim.max_hp = 100.0
				advance(120)
				await frames(30)
				await shot(sc)
			"stress":
				c.start_stress()
				if OS.get_environment("NOATMO") != "":
					c.atmosphere.visible = false
				if OS.get_environment("NOENEMY") != "":
					c.enemy_renderer.visible = false
				var t0 := Time.get_ticks_msec()
				while (
					c._stress != null
					and not c._stress.is_done()
					and Time.get_ticks_msec() - t0 < 100000
				):
					await process_frame
				await frames(3)
				await shot("stress")
				print("PERF ", FileAccess.get_file_as_string("user://perf.json"))
			"d1_walk", "d1_hit", "d1_die", "d1_ash", "d1_crowd":
				await _d1(sc)
			"contrast":
				await fresh()
				for t in [&"curumus_piyade", &"les_kargasi", &"sovalye_hayaleti"]:
					c.sim.debug_fill(t, 6, 200.0)
				advance(2)
				await frames(3)
				await shot("contrast")
	quit()


## v2.0 K2 öz-kontrolü: vitrin (gunslinger odak / barutcu odak / kilitli simülasyonu). Kayıt dosyasına yazmaz.
func _chars(sc: String) -> void:
	await fresh()
	c.go_menu()
	await frames(2)
	c.open_characters()
	await frames(30)
	var scr: CharactersScreen = c.v2.characters.screen
	if sc == "chars_b":
		scr.set_focus_id(&"barutcu")
		await frames(40)
	elif sc == "chars_lock":
		var d := GameData.load_default()
		d.get_character(&"barutcu").unlock_achievement = &"ilk_kan"
		scr.open(d, null, &"gunslinger")
		scr.set_focus_id(&"barutcu")
		await frames(40)
		d.get_character(&"barutcu").unlock_achievement = &""
	await shot(sc)


## v1.1 D1 görünüm öz-kontrolü: yürüme/vuruş/ölüm/kül/kalabalık gölgesi. Görünüm süresi `_update_views` ile ilerler.
func _d1(sc: String) -> void:
	await fresh()
	var sim: GameSim = c.sim
	sim.debug_set_time(900.0)
	sim.debug_fill(&"curumus_piyade", 30, 330.0)
	sim.debug_fill(&"les_kargasi", 10, 420.0)
	sim.debug_fill(&"sovalye_hayaleti", 6, 470.0)
	sim.debug_spawn(&"elit_piyade", sim.player_pos + Vector2(300, -250))
	match sc:
		"d1_walk":
			for k in 40:
				sim.step(Vector2(1.0, 0.0))
				c._update_views(1.0 / 60.0)
				await process_frame
			await shot(sc)
		"d1_hit":
			advance(20)
			sim.bus.player_damaged.emit(10.0, 90.0)
			for k in 4:
				c._update_views(1.0 / 60.0)
			await shot(sc)
		"d1_die":
			advance(20)
			sim.bus.player_damaged.emit(10.0, 90.0)
			sim.bus.run_ended.emit(false, {})
			for k in 40:
				c._update_views(1.0 / 60.0)
			await shot(sc)
		"d1_ash":
			advance(10)
			var ids := sim.alive_ids()
			for k in mini(ids.size(), 14):
				var i := EnemyPool.index_of(ids[k])
				sim.bus.enemy_killed.emit(sim.enemies.type_id_of(i), sim.enemies.pos[i])
			for k in 9:
				c._update_views(1.0 / 60.0)
			await shot(sc)
		"d1_crowd":
			sim.debug_fill(&"curumus_piyade", 200, 360.0)
			advance(30)
			await frames(3)
			await shot(sc)
