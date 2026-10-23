extends SceneTree
## Ekran görüntüsü öz-kontrolü (masaüstü render; commit'lenmez çıktı). Kullanım:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 1080x2400 \
##     -s res://tools/capture/shots.gd -- <çıktı_dizini> [senaryo,senaryo]
## Senaryolar: menu, game, crowd, boss, lord, levelup, pause, win, lose, contrast

var out_dir := "/tmp/shots/"
var scenarios: PackedStringArray = ["menu", "game", "crowd"]
var c: Node


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


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Sim'i `n` adım (kare beklemeden) ilerletir; seviye atlamada ilk kartı seçer.
func advance(n: int, move: Vector2 = Vector2.ZERO) -> void:
	var sim: GameSim = c.sim
	for i in n:
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			sim.hp = sim.max_hp
		if sim.state != GameSim.State.RUNNING:
			break
		sim.step(move)


func fresh(opts: Dictionary = {}) -> void:
	if c != null:
		c.queue_free()
		await process_frame
	c = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(c)
	await frames(3)
	if opts.get("lord", false):
		c.start_run()
	else:
		c.start_run()
	await frames(2)
	c.sim.max_hp = 1.0e9
	c.sim.hp = 1.0e9


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
				await frames(3)
				await shot("lord")
			"levelup":
				await fresh()
				c.sim.debug_add_xp(30)
				advance(5)
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
			"contrast":
				await fresh()
				for t in [&"curumus_piyade", &"les_kargasi", &"sovalye_hayaleti"]:
					c.sim.debug_fill(t, 6, 200.0)
				advance(2)
				await frames(3)
				await shot("contrast")
	quit()
