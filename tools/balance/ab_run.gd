extends SceneTree
## A/B denge verisi (gate dışı). Kullanım:
##   godot --headless -s res://tools/balance/ab_run.gd -- <politika> <ilk_tohum> <tohum_sayısı> <on|off> [çıktı.json] [godmode]
## politika: idle | kite | greedy | greedy_pickup. on = eklentili, off = `"pickups": false`.
## Her koşu `AbRunner.run` özetidir (hayatta kalma süresi, seviye, öldürme, skor, ölüm nedeni, eklenti/buff sayaçları).
## Denge AYARI yapmaz; yalnız veri üretir. Toplama/tablolar: `python3 tools/balance/ab_report.py`.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var policy := StringName(args[0] if args.size() > 0 else "kite")
	var first := int(args[1]) if args.size() > 1 else 1
	var n := int(args[2]) if args.size() > 2 else 1
	var with_pickups := (args[3] if args.size() > 3 else "on") == "on"
	var out_path: String = args[4] if args.size() > 4 else ""
	var god := (args[5] if args.size() > 5 else "") == "godmode"
	var rows: Array = []
	for k in n:
		var row: Dictionary = (
			AbRunner
			. run(
				{
					"seed": first + k,
					"policy": policy,
					"pickups": with_pickups,
					"godmode": god,
					"check_every": 60 if god else 0,
				}
			)
		)
		row.erase("state_hash")
		rows.append(row)
		print(JSON.stringify(row))
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(rows))
	quit()
