extends SceneTree
## v2.1 U4a ekran görüntüsü öz-kontrolü (koşu şeridi, KOŞU ekranı, duraklatma çipleri; çıktı commit'lenmez). Kullanım:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 1080x2400 \
##     -s res://tools/capture/shots_v21.gd -- <çıktı_dizini> [senaryo,senaryo]
## Senaryolar: menu, menu_quick_easy, menu_endless_hard, menu_2x, run, run_quick_easy, run_endless_hard, run_2x, pause.
## ÖNCE/SONRA: aynı betik iki kaynakta koşulur. `RunScreen` yoksa (taban commit) run_* senaryoları atlanır; menu*/pause
## senaryoları iki kaynakta da koşar, böylece ana sayfa (şerit yok -> var) ve duraklatma (çip yok -> var) kıyaslanır.
## Seçim Settings düğümüne bellek içi yazılır (diske kaydedilmez).

const RUN_SCREEN := "res://scripts/ui/run_screen.gd"

var out_dir := "/tmp/shots/"
var scenarios: PackedStringArray = [
	"menu",
	"menu_quick_easy",
	"menu_endless_hard",
	"menu_2x",
	"run",
	"run_quick_easy",
	"run_endless_hard",
	"run_2x",
	"pause"
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0].path_join("")
	if args.size() > 1:
		scenarios = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir + n + ".png")
	print("shot ", n, " ", img.get_width(), "x", img.get_height())


func _pick(mode: String, diff: String) -> void:
	var st := root.get_node_or_null("Settings")
	if st != null:
		st.set("run_mode", mode)
		st.set("run_diff", diff)


func _clear() -> void:
	for c in root.get_children():
		if c is Control:
			c.queue_free()


func _menu(scale: float) -> void:
	var m := MainMenu.new()
	root.add_child(m)
	m.set_font_scale(scale)
	m.visible = true


func _run_screen(scale: float) -> bool:
	if not ResourceLoader.exists(RUN_SCREEN):
		return false
	var s: Control = load(RUN_SCREEN).new()
	root.add_child(s)
	s.visible = true
	if scale > 1.0:
		s.set_font_scale(scale)
	return true


func _run() -> void:
	for sc in scenarios:
		_clear()
		await process_frame
		match sc:
			"menu":
				_pick("normal", "normal")
				_menu(1.0)
			"menu_quick_easy":
				_pick("quick", "easy")
				_menu(1.0)
			"menu_endless_hard":
				_pick("endless", "hard")
				_menu(1.0)
			"menu_2x":
				_pick("normal", "normal")
				_menu(2.0)
			"run":
				_pick("normal", "normal")
				if not _run_screen(1.0):
					continue
			"run_quick_easy":
				_pick("quick", "easy")
				if not _run_screen(1.0):
					continue
			"run_endless_hard":
				_pick("endless", "hard")
				if not _run_screen(1.0):
					continue
			"run_2x":
				_pick("endless", "easy")
				if not _run_screen(2.0):
					continue
			"pause":
				_pick("quick", "hard")
				var p := PauseScreen.new()
				root.add_child(p)
				p.open([] as Array[SkillState], [] as Array[SkillState], true, true)
			_:
				continue
		await _shot(sc)
	quit()
