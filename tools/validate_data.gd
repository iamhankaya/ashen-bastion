extends SceneTree
## Veri doğrulama: godot --headless -s res://tools/validate_data.gd [-- <veri_kökü>]
## tools/slice.txt = 2 ise içerik-tamamlandı kuralları da denetlenir. Hata varsa çıkış 1.


func _init() -> void:
	var root := "res://data"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		root = args[0]
	var complete := FileAccess.get_file_as_string("res://tools/slice.txt").strip_edges() == "2"
	var g := GameData.load_dir(root)
	var errs := g.validate({}, complete)
	for e in errs:
		print("VERİ HATASI: ", e)
	print(
		(
			"veri: %d karakter, %d beceri, %d düşman, %d eklenti, %d skor kaydı, %d hata"
			% [
				g.character_ids.size(),
				g.skill_ids.size(),
				g.enemy_ids.size(),
				g.pickup_ids.size(),
				g.score_table.kill_points.size(),
				errs.size()
			]
		)
	)
	quit(1 if errs.size() > 0 else 0)
