extends SceneTree
## Zyfen öz-kontrolü (v2.0.2 U2; masaüstü render, çıktı commit'lenmez). Kullanım:
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 \
##     -s res://tools/capture/shots_zyfen.gd -- <çıktı_dizini> [senaryo,senaryo]
## Senaryolar: chars (karakter seçim ekranı, Zyfen odakta), idle, walk (yürürken atış), cast (dururken atış kareleri),
##   gather (rüzgar toplama kareleri), flip (sola bakış). Her senaryo gösterilen şerit hücresini adına yazar.

var out_dir := "/tmp/shots_zyfen/"
var scenarios: PackedStringArray = ["chars", "idle", "walk", "cast", "gather", "flip"]
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


func advance(n: int, move: Vector2 = Vector2.ZERO) -> void:
	for i in n:
		if c.sim.state != GameSim.State.RUNNING:
			break
		c.sim.step(move)
	c._after_step()


## Sim'i ve görünümü eşzamanlı 1/60 sn ilerletir (denetleyicinin kendi döngüsü kapatılır: yürüme/dokunma karışmasın).
func tick(n: int, move: Vector2 = Vector2.ZERO) -> void:
	for i in n:
		if c.sim.state == GameSim.State.RUNNING:
			c.sim.step(move)
		c._update_views(1.0 / 60.0)


func fresh() -> void:
	if c != null:
		c.queue_free()
		await process_frame
	root.get_node("Settings").character_id = "zyfen"
	c = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(c)
	await frames(3)
	c.start_run()
	await frames(2)
	c.sim.max_hp = 1.0e9
	c.sim.hp = 1.0e9
	c.set_process(false)


func _enemies(side: float, n: int = 6) -> void:
	for k in n:
		var id: int = c.sim.debug_spawn(
			&"curumus_piyade",
			c.sim.player_pos + Vector2(side * (260.0 + 70.0 * k), -24.0 + 18.0 * (k % 3))
		)
		c.sim.enemies.speed[EnemyPool.index_of(id)] = 0.0


func _cell() -> String:
	return "c%02d" % c.player_view.anim.frame_a


func _run() -> void:
	for sc in scenarios:
		match sc:
			"chars":
				await fresh()
				c.go_menu()
				await frames(2)
				c.open_characters()
				await frames(30)
				c.v2.characters.screen.set_focus_id(&"zyfen")
				await frames(40)
				await shot("zy_chars")
			"idle":
				await fresh()
				tick(5)
				await shot("zy_idle_" + _cell())
			"walk":
				await fresh()
				_enemies(1.0)
				for i in 8:
					tick(6, Vector2(1.0, 0.0))
					await shot("zy_walk_%d_%s" % [i, _cell()])
			"cast":
				await fresh()
				_enemies(1.0)
				for i in 10:
					tick(2)
					await shot("zy_cast_%d_%s" % [i, _cell()])
			"gather":
				await fresh()
				_enemies(1.0)
				c.sim.magazine.count = 0
				c.sim.magazine.reloading = true
				c.sim.magazine.reload_total = 1.3
				c.sim.magazine.reload_left = 1.3
				for i in 8:
					tick(10)
					await shot("zy_gather_%d_%s" % [i, _cell()])
			"flip":
				await fresh()
				_enemies(-1.0)
				tick(2)
				await shot("zy_flip_turn_" + _cell())
				tick(14)
				await shot("zy_flip_" + _cell())
	quit()
