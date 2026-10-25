extends SceneTree
## Yoğunluk DPS tablosu (gate dışı, v2.0.2 D fazı): 10/50/200 kukla, "crowd" düzeni, DpsProbe ile. Karakter başına
## temel atış, her aktif sv5 ve her evrim (etkin sv5 + gerekli pasif + evrim). "Toplam" = temel saldırı + beceri birlikte.
##   godot --headless -s res://tools/balance/dps_density.gd -- [karakterler=gunslinger,zyfen] [saniye=20] [çıktı.md]
## Her evrimin altına evrim ÷ aktif sv5 oranı satırı yazılır (hedef 1,8-2,2).

const DENSITIES: Array[int] = [10, 50, 200]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var chars: PackedStringArray = (args[0] if args.size() > 0 else "gunslinger,zyfen").split(",")
	var secs: float = float(args[1]) if args.size() > 1 else DpsProbe.DEFAULT_SECONDS
	var data := GameData.load_default()
	var lines: PackedStringArray = ["| karakter | satır | 10 | 50 | 200 |", "|---|---|---|---|---|"]
	var table := {}  # "karakter|anahtar" -> [dps10, dps50, dps200]
	for c in chars:
		var cid := StringName(c)
		var start := data.get_character(cid).starting_skill
		_row(lines, table, cid, "base", "temel", {}, secs)
		for sk in data.skills_of_kind(SkillDef.KIND_ACTIVE):
			if sk.available_to(cid) and sk.id != start:
				_row(
					lines,
					table,
					cid,
					"active:%s" % sk.id,
					"aktif sv5: %s" % sk.id,
					{sk.id: sk.max_level},
					secs
				)
		for sk in data.skills_of_kind(SkillDef.KIND_EVOLUTION):
			if not sk.available_to(cid):
				continue
			var req: Dictionary = sk.requires
			var act := StringName(req["active"])
			var setup := {
				act: int(req["active_level"]),
				StringName(req["passive"]): int(req["passive_min_level"])
			}
			setup[sk.id] = 1
			_row(
				lines,
				table,
				cid,
				"evo:%s" % sk.id,
				"evrim: %s (%s sv5 + pasif)" % [sk.id, act],
				setup,
				secs
			)
			var ratio: PackedStringArray = []
			for i in DENSITIES.size():
				var a: float = table["%s|active:%s" % [cid, act]][i]
				ratio.append("%.2f" % (float(table["%s|evo:%s" % [cid, sk.id]][i]) / maxf(a, 1e-9)))
			lines.append("| %s | oran %s ÷ aktif sv5 | %s |" % [cid, sk.id, " | ".join(ratio)])
	var md := "\n".join(lines) + "\n"
	print(md)
	if args.size() > 2:
		var f := FileAccess.open(args[2], FileAccess.WRITE)
		f.store_string(md)
	quit()


func _row(
	lines: PackedStringArray,
	table: Dictionary,
	cid: StringName,
	key: String,
	label: String,
	setup: Dictionary,
	secs: float
) -> void:
	var vals: Array = []
	for n in DENSITIES:
		vals.append(DpsProbe.measure(cid, setup, &"crowd", n, secs)["dps"])
	table["%s|%s" % [cid, key]] = vals
	lines.append("| %s | %s | %.1f | %.1f | %.1f |" % [cid, label, vals[0], vals[1], vals[2]])
