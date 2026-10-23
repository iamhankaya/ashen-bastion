extends SceneTree
## D2 eklenti görünümü öz-kontrolü (masaüstü render; çıktı commit'lenmez). Kullanım:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 1080x2400 \
##     -s res://tools/capture/shots_pickups.gd -- <çıktı_dizini>
## Çıktılar: pickups_ground (yerdeki 6 eklenti + ekran dışı ok), pickups_hud (3 rozet + ∞ tambur + toast), pickups_bomb (fitil).

var out_dir := "/tmp/shots_pickups/"
var c: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0].path_join("")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir + n + ".png")
	print("shot ", n, " ", img.get_width(), "x", img.get_height())


func advance(n: int) -> void:
	for i in n:
		if c.sim.state != GameSim.State.RUNNING:
			break
		c.sim.step(Vector2.ZERO)
	c._after_step()


func fresh() -> void:
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


func _run() -> void:
	await frames(5)
	await fresh()
	var sim: GameSim = c.sim
	var p := sim.player_pos
	var ids: Array = sim.data.pickup_ids
	for k in ids.size():
		var a := TAU * float(k) / 6.0 + 0.3
		sim.debug_spawn_pickup(ids[k], p + Vector2.from_angle(a) * (260.0 + 40.0 * (k % 2)))
	advance(40)
	await frames(10)
	await shot("pickups_ground")
	# ekran dışı ok: yakındakileri toplayıp uzakta bir tane bırak
	sim.pickups.count = 0
	sim.debug_spawn_pickup(&"sonsuz_tambur", p + Vector2(-900, 1500))
	advance(2)
	await frames(6)
	await shot("pickups_arrow")
	# HUD: 3 rozet + ∞ + toast
	for id in [&"ofke_barutu", &"kizgin_namlu", &"sonsuz_tambur"]:
		sim.debug_spawn_pickup(id, sim.player_pos)
	sim.debug_collect_pickups()
	advance(200)
	await frames(10)
	await shot("pickups_hud")
	# bomba fitili
	sim.debug_spawn_pickup(&"kara_bomba", sim.player_pos + Vector2(40, 0))
	sim.debug_collect_pickups()
	sim.debug_fill(&"curumus_piyade", 20, 250.0)
	advance(24)
	await frames(4)
	await shot("pickups_bomb")
	quit()
