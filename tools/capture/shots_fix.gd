extends SceneTree
## Ara denetim düzeltmeleri (T20261023-97) önce/sonra öz-kontrolü (masaüstü render; çıktı commit'lenmez, küçültülmüşü docs'a girer):
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 1080x2400 \
##     -s res://tools/capture/shots_fix.gd -- <çıktı_dizini> [senaryo,senaryo]
## Senaryolar: shadow (gölge açık/kapalı + koyulaşma ölçümü), float, lord, arrow, scores, menu, glow, ring, debug.
## Yalnız eski ve yeni kodda ortak API'yi kullanır (aynı betik temel commit'te de koşar).

const NOTCH := Vector4(48.0, 130.0, 48.0, 80.0)

var out_dir := "/tmp/shots_fix/"
var scenarios: PackedStringArray = [
	"shadow", "float", "lord", "arrow", "scores", "menu", "glow", "ring", "debug"
]
var c: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0].path_join("")
	if args.size() > 1:
		scenarios = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func shot(n: String) -> void:
	var img := await grab()
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


func _still(id: StringName, off: Vector2) -> void:
	var sim: GameSim = c.sim
	var uid := sim.debug_spawn(id, sim.player_pos + off)
	if uid >= 0:
		sim.enemies.speed[EnemyPool.index_of(uid)] = 0.0
		sim.enemies.hp[EnemyPool.index_of(uid)] = 1.0e9


## Gölge pikselleri: gölge kapalı/açık görüntü farkında koyulaşma >= %5 olan piksellerin ortalama koyulaşması.
func _darkening(on: Image, off: Image) -> Dictionary:
	var sum := 0.0
	var n := 0
	for y in range(0, on.get_height(), 2):
		for x in range(0, on.get_width(), 2):
			var lo := on.get_pixel(x, y).get_luminance()
			var lf := off.get_pixel(x, y).get_luminance()
			if lf > 0.02 and lo < lf:
				var d := 1.0 - lo / lf
				if d >= 0.05:
					sum += d
					n += 1
	return {"mean": sum / float(maxi(n, 1)), "pixels": n}


func _run() -> void:
	await frames(5)
	for sc in scenarios:
		match sc:
			"shadow":
				await fresh()
				for id in [&"elit_piyade", &"elit_sovalye"]:
					_still(id, Vector2(-260, -60) if id == &"elit_piyade" else Vector2(260, -60))
				_still(&"kale_lordu", Vector2(0, -480))
				for k in 3:
					_still(&"curumus_piyade", Vector2(-180 + 180 * k, 260))
				advance(6)
				await frames(4)
				var on := await grab()
				on.save_png(out_dir + "shadow_on.png")
				var layer: CanvasItem = c.enemy_shadows
				layer.visible = false
				var pv: Node = c.player_view
				(pv.get("shadow") as CanvasItem).visible = false
				var off := await grab()
				off.save_png(out_dir + "shadow_off.png")
				var st := _darkening(on, off)
				print("shadow_darkening mean=%.3f pixels=%d" % [st["mean"], st["pixels"]])
			"float":
				await fresh()
				advance(5)
				var h: Hud = c.hud
				var at := Vector2(540, 1000)
				for t in ["SINIRSIZ ŞARJÖR", "HASAR ARTTI", "ATIŞ HIZI ARTTI"]:
					h.float_text.show_text(t, at)
				await frames(14)
				await shot("float")
			"lord":
				await fresh()
				var h: Hud = c.hud
				h.apply_safe_area(NOTCH)
				_still(&"kale_lordu", Vector2(0, -420))
				c.sim.debug_grant(&"seken_mermi", 1)
				advance(30)
				h.score_block._on_streak_changed(5, 1.0)
				h.score_block._on_score_changed(1500, 5, 1500)
				h.show_boss_band(&"kale_lordu")
				for id in [&"ofke_barutu", &"kizgin_namlu", &"sonsuz_tambur"]:
					c.sim.debug_spawn_pickup(id, c.sim.player_pos)
				c.sim.debug_collect_pickups()
				advance(10)
				await frames(4)
				await shot("lord_notch")
			"arrow":
				await fresh()
				var p: Vector2 = c.sim.player_pos
				c.sim.pickups.count = 0
				c.sim.debug_spawn_pickup(&"sonsuz_tambur", p + Vector2(-1500, 100))
				advance(2)
				await frames(6)
				await shot("arrow_left")
				c.hud.apply_safe_area(NOTCH)
				c.sim.pickups.count = 0
				c.sim.debug_spawn_pickup(&"sonsuz_tambur", p + Vector2(500, 2500))
				advance(2)
				await frames(6)
				await shot("arrow_notch_bottom")
			"scores":
				await fresh()
				var path := "user://shots_hs.json"
				DirAccess.remove_absolute(path)
				c.highscores = Highscores.new(path)
				c.go_menu()
				c.scores_screen.apply_safe_area(NOTCH)
				c.open_scores()
				await frames(30)
				await shot("scores_empty_notch")
				var t := 1_761_000_000
				for sco in [
					246350, 171900, 154200, 131775, 118420, 96050, 72310, 60000, 50000, 41000
				]:
					c.highscores.submit(
						{
							"score": sco,
							"time": 1200 - (246350 - sco) / 300,
							"won": sco > 150000,
							"level": 9,
							"unix": t
						}
					)
					t -= 86400
				c.scores_screen.apply_safe_area(Vector4.ZERO)
				c.scores_screen.show_scores(c.highscores.entries, -1)
				await frames(30)
				await shot("scores_filled")
			"menu":
				await fresh()
				c.go_menu()
				c.menu.set_settings(false, false)
				await frames(20)
				await shot("menu_off")
			"glow":
				await fresh()
				var sim: GameSim = c.sim
				var p2 := sim.player_pos
				var ids: Array = sim.data.pickup_ids
				for k in ids.size():
					sim.debug_spawn_pickup(
						ids[k], p2 + Vector2.from_angle(TAU * float(k) / 6.0 + 0.3) * 260.0
					)
				advance(40)
				await frames(10)
				await shot("glow")
			"ring":
				await fresh()
				c.set_process(false)
				advance(2)
				var pv2: Node = c.player_view
				c.sim.bus.level_up.emit(2)
				for k in 8:  # ~130 ms: ön vurgu (kartlar henüz yok)
					pv2.update_view(1.0 / 60.0)
				await frames(2)
				await shot("ring_pre")
				if pv2.has_method("on_level_chosen"):
					pv2.call("on_level_chosen")
				for k in 12:  # kart seçildikten ~200 ms
					pv2.update_view(1.0 / 60.0)
				await frames(2)
				await shot("ring_after_choice")
			"debug":
				await fresh()
				for id in [&"ofke_barutu", &"kizgin_namlu", &"sonsuz_tambur"]:
					c.sim.debug_spawn_pickup(id, c.sim.player_pos)
				c.sim.debug_collect_pickups()
				advance(120)
				await frames(6)
				await shot("debug_labels")
	quit()
