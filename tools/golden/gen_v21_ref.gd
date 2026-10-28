extends SceneTree
## v2.1 K-C10 (b) referans karma üretici (gate dışı). DEĞİŞMEMİŞ kodda koşar:
##   godot --headless -s res://tools/golden/gen_v21_ref.gd -- [--write] [--base <karma>]
## --write yoksa JSON'u yazdırır; varsa test/fixtures/golden_v20_ref/ref.json'a yazar. --base: kaydın çıkarıldığı commit (bilgi).
## CI: .github/workflows/golden_ref.yml bu aracı ana dalın kodunda koşar ve ref.json'u artifact olarak verir.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var cases := {}
	for c: Array in V21RefKit.LATE_CASES:
		var key := V21RefKit.case_key(int(c[0]), float(c[1]), int(c[2]))
		cases[key] = V21RefKit.run_late(int(c[0]), float(c[1]), int(c[2]))
		print("ref %s -> %s" % [key, cases[key]])
	var base := ""
	var bi := args.find("--base")
	if bi >= 0 and bi + 1 < args.size():
		base = args[bi + 1]
	var doc := {"version": 1, "base": base, "late": cases}
	var text := JSON.stringify(doc, "  ", true) + "\n"
	if args.has("--write"):
		var f := FileAccess.open(V21RefKit.FIXTURE, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	else:
		print(text)
	quit(0)
