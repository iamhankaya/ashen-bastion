extends SceneTree
## v2.1 U4b ekran görüntüsü öz-kontrolü (sonuç çipleri/Kolay notu, skor sekmeleri, kilometre taşı bandı; commit'lenmez). Kullanım:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --rendering-driver opengl3 --resolution 1080x2400 \
##     -s res://tools/capture/shots_v21_b.gd -- <çıktı_dizini> [senaryo,senaryo]
## Senaryolar: result_lost, result_quick_win, result_endless_win, result_easy, scores, scores_empty, band.
## ÖNCE/SONRA: aynı betik iki kaynakta koşulur; taban commit'te v2.1 alanları yoksa result_* eski düzeni gösterir.

var out_dir := "/tmp/shots/"
var scenarios: PackedStringArray = [
	"result_lost",
	"result_quick_win",
	"result_endless_win",
	"result_easy",
	"scores",
	"scores_empty",
	"band"
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


func _result(won: bool, stats: Dictionary) -> void:
	var r := ResultScreen.new()
	root.add_child(r)
	var rec := {"rank": 3, "is_record": false, "previous_best": 900}
	r.show_result(won, stats, [] as Array[Dictionary], "", rec)
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
			"scores":
				var s := HighscoreScreen.new()
				root.add_child(s)
				s.show_scores(_entries(10), -1, &"normal", &"hard")
			"scores_empty":
				var e := HighscoreScreen.new()
				root.add_child(e)
				e.show_scores([] as Array[Dictionary], -1, &"endless", &"hard")
			"band":
				var b := MilestoneBand.new()
				root.add_child(b)
				b.show_band(300.0, true)
			_:
				continue
		await _shot(sc)
	quit()
