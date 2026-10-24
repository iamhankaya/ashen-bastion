extends SceneTree
## Başlangıç DPS tablosu (gate dışı, v2.0.2 S2): ham temel atış + her evrim, karakter başına, DpsProbe ile.
##   godot --headless -s res://tools/balance/dps_table.gd -- [karakterler=gunslinger,zyfen] [saniye=20] [çıktı.md]
## Zyfen satırları davranışlar uygulanana dek (U1/U2/U3) yer tutucu gövdelerle ölçülür: 0 = henüz uygulanmadı;
## D fazı yeniden ölçer. Evrim satırı: etkin beceri seviye 5 + gerekli pasif + evrim kimliği.

const LAYOUTS: Array[StringName] = [&"ring", &"line", &"cluster"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var chars: PackedStringArray = (args[0] if args.size() > 0 else "gunslinger,zyfen").split(",")
	var secs: float = float(args[1]) if args.size() > 1 else DpsProbe.DEFAULT_SECONDS
	var data := GameData.load_default()
	var lines: PackedStringArray = [
		"| karakter | satır | halka | çizgi | küme |", "|---|---|---|---|---|"
	]
	for c in chars:
		var cid := StringName(c)
		lines.append(_row(cid, "ham temel (başlangıç becerisi sv1)", {}, secs))
		for sk in data.skills_of_kind(SkillDef.KIND_EVOLUTION):
			if not sk.available_to(cid):
				continue
			var req: Dictionary = sk.requires
			var setup := {StringName(req["active"]): int(req["active_level"])}
			setup[StringName(req["passive"])] = int(req["passive_min_level"])
			setup[sk.id] = 1
			lines.append(_row(cid, "evrim: %s" % sk.id, setup, secs))
	var md := "\n".join(lines) + "\n"
	print(md)
	if args.size() > 2:
		var f := FileAccess.open(args[2], FileAccess.WRITE)
		f.store_string(md)
	quit()


func _row(cid: StringName, label: String, setup: Dictionary, secs: float) -> String:
	var cells: PackedStringArray = []
	for lay in LAYOUTS:
		var r := DpsProbe.measure(cid, setup, lay, DpsProbe.DEFAULT_DUMMIES, secs)
		cells.append("%.1f" % r["dps"])
	return "| %s | %s | %s |" % [cid, label, " | ".join(cells)]
