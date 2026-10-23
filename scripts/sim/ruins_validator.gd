class_name RuinsValidator
extends RefCounted


## ruins.json isteğe bağlıdır (yoksa harita boş). Varsa: dizi; her kayıt id (benzersiz), sprite (var), display_scale,
## foot [x,y] 0..1, footprint {w,h}, weight > 0, solid bool.
static func run(g: GameData, raw: Variant, out: PackedStringArray) -> void:
	if not (raw is Array):
		GameData._err(out, "bad_type", "ruins.json", "kök dizi olmalı")
		return
	var seen := {}
	for i in raw.size():
		var ctx := "ruins.json[%d]" % i
		var d: Variant = raw[i]
		if not (d is Dictionary):
			GameData._err(out, "not_object", ctx, "kayıt nesne olmalı")
			continue
		if not GameData._valid_id(d.get("id")):
			GameData._err(out, "missing_field", ctx, "geçerli 'id' yok")
		elif seen.has(d["id"]):
			GameData._err(out, "dup_id", ctx, "yinelenen id '%s'" % d["id"])
		else:
			seen[d["id"]] = true
		g._check_asset(out, ctx, d, "sprite")
		GameData._num(out, ctx, d, "display_scale", 0.1, 20)
		GameData._num(out, ctx, d, "weight", 0.01, 1000)
		GameData._pair(out, ctx, d, "foot", 0, 1)
		var fp: Variant = d.get("footprint")
		if not (fp is Dictionary):
			GameData._err(out, "missing_field", ctx, "'footprint' nesne olmalı")
		else:
			GameData._num(out, ctx + " footprint", fp, "w", 1, 2000)
			GameData._num(out, ctx + " footprint", fp, "h", 1, 2000)
		if typeof(d.get("solid")) != TYPE_BOOL:
			GameData._err(out, "bad_type", ctx, "'solid' bool olmalı")
