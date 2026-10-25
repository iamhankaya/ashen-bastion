extends SceneTree
## Altın hash üretici (gate dışı): godot --headless -s res://tools/golden/golden_run.gd -- --stage <anahtar>
##   [--characters gunslinger,zyfen] [--seeds 11,23] [--steps 7200] [--zyfen-u3-grants] [--write]
## --zyfen-u3-grants: koşuya GoldenKit.ZYFEN_U3_GRANTS (Tufan'lı Zyfen yükü) verilir (aşama `zyfen_u3`).
## --write yoksa JSON'u yazdırır; varsa test/fixtures/golden_hashes.json içindeki o aşama anahtarını günceller.

const DEFAULT_CHARS := "gunslinger"


func _init() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var stage: String = args.get("stage", "")
	if stage == "":
		push_error("--stage <anahtar> gerekli")
		quit(2)
		return
	var chars: PackedStringArray = str(args.get("characters", DEFAULT_CHARS)).split(",")
	var steps := int(args.get("steps", GoldenKit.STEPS))
	var seed_list: Array[int] = []
	if args.has("seeds"):
		for s in str(args["seeds"]).split(","):
			seed_list.append(int(s))
	else:
		seed_list = GoldenKit.seeds()
	var out := {}
	for c in chars:
		var per_seed := {}
		for s in seed_list:
			var grants: Dictionary = (
				GoldenKit.ZYFEN_U3_GRANTS if args.has("zyfen-u3-grants") else {}
			)
			per_seed[str(s)] = GoldenKit.run(s, StringName(c), steps, grants)
			print("golden %s %s seed=%d -> %s" % [stage, c, s, per_seed[str(s)]])
		out[c] = per_seed
	if args.has("write"):
		_write(stage, out)
	else:
		print(JSON.stringify({stage: out}, "  ", true))
	quit(0)


func _write(stage: String, entry: Dictionary) -> void:
	var doc := GoldenKit.load_fixture()
	if not doc.has("stages"):
		doc = {"version": 1, "stages": {}}
	doc["stages"][stage] = entry
	var f := FileAccess.open(GoldenKit.FIXTURE, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", true) + "\n")
	f.close()


static func _parse(argv: PackedStringArray) -> Dictionary:
	var res := {}
	var i := 0
	while i < argv.size():
		var a := argv[i]
		if a.begins_with("--"):
			var key := a.substr(2)
			if i + 1 < argv.size() and not argv[i + 1].begins_with("--"):
				res[key] = argv[i + 1]
				i += 1
			else:
				res[key] = true
		i += 1
	return res
