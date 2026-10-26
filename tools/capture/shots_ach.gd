extends SceneTree
## Başarım ekranı ekran görüntüsü öz-kontrolü (v2.0.3 C; masaüstü render, çıktı commit'lenmez). Kullanım:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 1080x2400 \
##     -s res://tools/capture/shots_ach.gd -- <çıktı_dizini>
## Çıktılar: ach_bos, ach_kismi, ach_satir_acik, ach_hepsi, ach_centik (güvenli alan payı), ach_gri (gri tonlama sınaması için kısmi).

const T0 := 1761270000

var out_dir := "/tmp/shots/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0].path_join("")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir + n + ".png")
	print("shot ", n, " ", img.get_width(), "x", img.get_height())


func _screen(store: AchievementStore, data: GameData) -> AchievementsScreen:
	for c in root.get_children():
		c.queue_free()
	var s := AchievementsScreen.new()
	root.add_child(s)
	s.visible = true
	s.open(data, store)
	return s


## Gerçekçi kısmi kayıt: her gruptan birkaç aile, bir tamam, bir kilitli.
func _partial(data: GameData) -> AchievementStore:
	var st := AchievementStore.new("user://shots_ach_never_saved.json")
	var steps := {
		&"endure": 3,
		&"untouched": 1,
		&"rampage": 2,
		&"reaper": 2,
		&"bossbane": 1,
		&"elite_trio": 1,
		&"ascendant": 1,
		&"quick_hands": 3,
		&"unbroken": 1,
		&"garrison": 1,
	}
	for id in steps:
		st.unlock_step(id, steps[id], T0)
	st.totals["kills"] = 1480
	st.totals["runs"] = 17
	st.totals["boss_kills"] = 4
	st.best["time"] = 780
	st.best["kills"] = 1320
	st.best["level"] = 14
	return st


func _run() -> void:
	var data := GameData.load_dir("res://data")
	var s := _screen(AchievementStore.new("user://shots_ach_never_saved.json"), data)
	await _shot("ach_bos")
	s = _screen(_partial(data), data)
	await _shot("ach_kismi")
	s.open_id = &"reaper"
	s._populate()
	await _shot("ach_satir_acik")
	var all := AchievementStore.new("user://shots_ach_never_saved.json")
	for d in data.achievements:
		all.unlock_step(d.id, AchievementStep.total(d), T0)
	s = _screen(all, data)
	await _shot("ach_hepsi")
	s = _screen(_partial(data), data)
	s.apply_safe_area(Vector4(0, 100, 0, 150))
	await _shot("ach_centik")
	quit()
