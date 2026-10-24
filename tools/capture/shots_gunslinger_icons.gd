extends SceneTree
## Gunslinger/Zyfen ikon öz-kontrolü (v2.0.2 A2b; masaüstü render, çıktı commit'lenmez). Kullanım:
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 \
##     -s res://tools/capture/shots_gunslinger_icons.gd -- <çıktı_dizini>
## Çıktı: gs_levelup (aktif + pasif + evrim kartı), gs_hud, gs_pause; zy_levelup, zy_hud (Zyfen ikonları değişmedi).

var out_dir := "/tmp/shots_a2b/"
var c: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0].path_join("")
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


func fresh(character: String) -> void:
	if c != null:
		c.queue_free()
		await process_frame
	root.get_node("Settings").character_id = character
	c = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(c)
	await frames(3)
	c.start_run()
	await frames(2)
	c.sim.max_hp = 1.0e9
	c.sim.hp = 1.0e9
	c.set_process(false)


func _cards(ids: Array) -> Array:
	var out: Array = []
	for id: StringName in ids:
		out.append(c.sim.loadout.card_for(id, c.sim.loadout.level_of(id) + 1))
	return out


func _run() -> void:
	var sets := {
		"gs": [[&"cift_tabanca", &"keskin_nisan", &"sarapnel"], [&"saglam_yelek", &"barut_kesesi", &"miknatis"]],
		"zy": [[&"ruzgar_kesigi", &"girdap", &"tufan"], [&"saglam_yelek", &"agir_kursun", &"miknatis"]],
	}
	for key in ["gs", "zy"]:
		await fresh("gunslinger" if key == "gs" else "zyfen")
		var actives: Array = sets[key][0]
		var passives: Array = sets[key][1]
		var card_ids: Array = [actives[0], passives[0], actives[1]] if key == "zy" else [
			actives[0], passives[0], &"kiyamet_mermisi"
		]
		c.level_up.show_choices(_cards(card_ids), 7, c.sim.data, c.sim.character)
		await frames(40)
		await shot(key + "_levelup")
		c.level_up.visible = false
		for id: StringName in actives:
			c.sim.debug_grant(id, 2)
		for id: StringName in passives:
			c.sim.debug_grant(id, 3)
		if key == "gs":
			c.sim.debug_grant(&"kiyamet_mermisi")
		c._after_step()
		c._update_views(1.0 / 60.0)
		await frames(6)
		await shot(key + "_hud")
		c.pause_game()
		await frames(30)
		await shot(key + "_pause")
	quit()
