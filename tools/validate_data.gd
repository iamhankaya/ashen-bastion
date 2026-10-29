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
	# v2.1: run_profiles.json. Kökte run_modes/ varsa (R7 katalog biçimi) GameData.validate'in RunCatalogValidator eklentisi
	# zaten denetler; yoksa eski tek dosyalık biçim burada denetlenir. Asıl veri kökünde dosya ZORUNLU; başka kökte varsa denetlenir.
	var profile_path := root.path_join("run_profiles.json")
	var has_catalog := DirAccess.dir_exists_absolute(root.path_join(RunCatalog.MODES_DIR))
	if not has_catalog and (root == "res://data" or FileAccess.file_exists(profile_path)):
		errs.append_array(PackedStringArray(RunProfiles.load_file(profile_path)["errors"]))
	for e in errs:
		print("VERİ HATASI: ", e)
	print(
		(
			"veri: %d karakter, %d beceri, %d düşman, %d eklenti, %d skor kaydı, %d başarım, %d hata"
			% [
				g.character_ids.size(),
				g.skill_ids.size(),
				g.enemy_ids.size(),
				g.pickup_ids.size(),
				g.score_table.kill_points.size(),
				g.achievements.size(),
				errs.size()
			]
		)
	)
	quit(1 if errs.size() > 0 else 0)
