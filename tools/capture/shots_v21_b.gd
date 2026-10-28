extends SceneTree
## v2.1 U4b ekran görüntüsü öz-kontrolü (sonuç çipleri/Kolay notu, skor sekmeleri, kilometre taşı bandı; commit'lenmez). Kullanım:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 1080x2400 \
##     -s res://tools/capture/shots_v21_b.gd -- <çıktı_dizini> [senaryo,senaryo]
## Senaryolar: result_lost, result_quick_win, result_endless_win, result_easy, result_2x, result_combos5_easy,
## result_combos5_chip, result_combos5_notch, scores, scores_2x, scores_empty, band, band_2x, band_no_hint.
## ÖNCE/SONRA: aynı betik iki kaynakta koşulur; taban commit'te v2.1 alanları yoksa result_* eski düzeni gösterir.

var out_dir := "/tmp/shots/"
var scenarios: PackedStringArray = [
	"result_lost",
	"result_quick_win",
	"result_endless_win",
	"result_easy",
	"result_2x",
	"result_combos5_easy",
	"result_combos5_chip",
	"result_combos5_notch",
	"scores",
	"scores_2x",
	"scores_empty",
	"band",
	"band_2x",
	"band_no_hint"
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
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir + n + ".png")
	print("shot ", n, " ", img.get_width(), "x", img.get_height())


func _clear() -> void:
	for c in root.get_children():
		if c is Control:
			c.queue_free()


func _stats(mode: String, diff: String, extra: Dictionary = {}) -> Dictionary:
	var parts := {
		"kills": 120000, "streak": 40000, "evolution": 0, "survival": 66000, "lord": 20350
	}
	var d := {
		"time": 1668.0,
		"level": 24,
		"kills": 2410,
		"score": 246350,
		"best_mult": 5,
		"evolutions": [],
		"mode": mode,
		"diff": diff,
		"score_parts": parts,
	}
	d.merge(extra, true)
	return d


## Taban commit'te olmayan `set_font_scale`/`apply_safe_area` çağrıları `has_method` ile atlanır (önce/sonra aynı betik).
func _scale(n: Node, f: float) -> void:
	if f > 1.0 and n.has_method(&"set_font_scale"):
		n.call(&"set_font_scale", f)


func _combos(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in n:
		out.append(
			{"id": &"zincirleme_patlama", "name": "Kıyamet Mermisi", "pair": "A + B", "icon": ""}
		)
	return out


func _result(
	won: bool,
	stats: Dictionary,
	f: float = 1.0,
	combos: int = 0,
	chip: bool = false,
	notch := false
) -> void:
	var r := ResultScreen.new()
	root.add_child(r)
	if chip:
		r.set_new_achievements(["AİLE II", "AİLE III"] as Array[String])
	if notch:
		r.apply_safe_area(Vector4(0.0, 60.0, 0.0, 40.0))
	var rec := {"rank": 3, "is_record": false, "previous_best": 900}
	r.show_result(won, stats, _combos(combos), "", rec)
	_scale(r, f)
	r.finish_count()


func _entries(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in n:
		out.append(
			{
				"score": 246350 - i * 9000,
				"time": 1200 - i * 60,
				"won": i % 2 == 0,
				"level": 20,
				"unix": 1_700_000_000 + i * 86400
			}
		)
	return out


func _run() -> void:
	for sc in scenarios:
		_clear()
		await process_frame
		match sc:
			"result_lost":
				_result(false, _stats("normal", "hard"))
			"result_quick_win":
				_result(true, _stats("quick", "normal"))
			"result_endless_win":
				_result(true, _stats("endless", "hard", {"lords_killed": 2, "milestone_t": 1200.0}))
			"result_easy":
				_result(false, _stats("normal", "easy"))
			"result_2x":
				_result(
					true,
					_stats("endless", "hard", {"lords_killed": 2, "milestone_t": 1200.0}),
					2.0,
					2
				)
			"result_combos5_easy":
				_result(true, _stats("normal", "easy"), 1.0, 5)
			"result_combos5_chip":
				_result(true, _stats("endless", "easy", {"lords_killed": 3}), 1.0, 5, true)
			"result_combos5_notch":
				_result(true, _stats("normal", "easy"), 1.0, 5, false, true)
			"scores", "scores_2x":
				var s := HighscoreScreen.new()
				root.add_child(s)
				s.show_scores(_entries(10), -1, &"normal", &"hard")
				_scale(s, 2.0 if sc == "scores_2x" else 1.0)
			"scores_empty":
				var e := HighscoreScreen.new()
				root.add_child(e)
				e.show_scores([] as Array[Dictionary], -1, &"endless", &"hard")
			"band", "band_2x", "band_no_hint":
				var b := MilestoneBand.new()
				root.add_child(b)
				b.show_band(0.0 if sc == "band_no_hint" else 300.0, true)
				_scale(b, 2.0 if sc == "band_2x" else 1.0)
			_:
				continue
		await _shot(sc)
	quit()
