extends SceneTree
## v2.0.3 B ruh küreleri öz-kontrolü (masaüstü render; çıktı commit'lenmez). Kullanım:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 1080x2400 \
##     -s res://tools/capture/shots_orbs.gd -- <çıktı_dizini>
## Çıktılar: orbs_three (3 tip yan yana), orbs_crowd (300 küre), orbs_still (hareket azalt AÇIK). Kare başına refresh süresi basılır.

var out_dir := "/tmp/shots_orbs/"
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


func _run() -> void:
	await frames(5)
	c = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(c)
	await frames(3)
	c.start_run()
	await frames(2)
	var sim: GameSim = c.sim
	sim.max_hp = 1.0e9
	sim.hp = 1.0e9
	var p := sim.player_pos
	if OS.get_environment("NOATMO") != "":
		c.atmosphere.get_parent().visible = false
	sim.gems.drop(p + Vector2(-120, -200), 1)
	sim.gems.drop(p + Vector2(0, -200), 7)
	sim.gems.drop(p + Vector2(120, -200), 120)
	await frames(10)
	(c.gem_renderer.texture as Texture2D).get_image().save_png(out_dir + "atlas.png")
	await shot("orbs_three")
	for i in 280:
		sim.gems.drop(
			p + Vector2.from_angle(randf() * TAU) * randf_range(420.0, 900.0),
			[1, 1, 1, 7, 120][i % 5]
		)
	await frames(10)
	var t0 := Time.get_ticks_usec()
	for i in 120:
		c.gem_renderer.refresh()
	print("refresh us/kare (", sim.gems.count, " küre): ", (Time.get_ticks_usec() - t0) / 120)
	await shot("orbs_crowd")
	root.get_node("Settings").hareket_azalt = true
	await frames(10)
	await shot("orbs_still")
	root.get_node("Settings").hareket_azalt = false
	quit()
