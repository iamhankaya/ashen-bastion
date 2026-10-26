extends SceneTree
## Hareketli portre öz-kontrolü (v2.0.3 A): Karakterler ekranı, hareket serbest / hareket azalt. Kullanım:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 540x1200 \
##     -s res://tools/capture/shots_portrait.gd -- <çıktı_dizini>

var out_dir := "/tmp/shots_portrait/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0].path_join("") if args.size() > 0 else out_dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var data := GameData.load_default()
	var st := root.get_node("Settings")
	for mode in ["hareket", "azalt"]:
		st.hareket_azalt = mode == "azalt"
		for id in ["gunslinger", "zyfen"]:
			var s := CharactersScreen.new()
			s.size = Vector2(1080, 2400)
			root.add_child(s)
			s.open(data, AchievementStore.new(), StringName(id))
			for i in 90:
				await process_frame
			await create_timer(1.2).timeout
			var vp := s.find_children("*", "PortraitPlayer", true, false)
			print(
				(
					"%s %s: oynatıcı=%d oynuyor=%s görünür=%s"
					% [mode, id, vp.size(), vp[0].is_playing(), vp[0].visible]
				)
			)
			root.get_viewport().get_texture().get_image().save_png(
				"%s%s_%s.png" % [out_dir, mode, id]
			)
			s.queue_free()
			await process_frame
	st.hareket_azalt = false
	quit()
