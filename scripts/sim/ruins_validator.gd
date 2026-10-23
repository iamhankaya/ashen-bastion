class_name RuinsValidator
extends RefCounted

const MAX_CIRCLES := 32
const MAX_BOUND := 400.0


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
		_collision(out, ctx, d)


## `collision` (isteğe bağlı, yalnız katı): foot'a göre dünya px daireleri [{x, y, r}]. Sarmalayan çember
## `MAX_BOUND`'u aşamaz (katı harabe chunk kenarından bu kadar içeride durur, chunk 1024 px).
static func _collision(out: PackedStringArray, ctx: String, d: Dictionary) -> void:
	if not d.has("collision"):
		return
	var raw: Variant = d["collision"]
	if d.get("solid") != true:
		GameData._err(out, "unexpected", ctx, "'collision' yalnız katı (solid) harabede olur")
		return
	if not (raw is Array) or (raw as Array).is_empty() or (raw as Array).size() > MAX_CIRCLES:
		GameData._err(out, "bad_type", ctx, "'collision' 1..%d daireli dizi olmalı" % MAX_CIRCLES)
		return
	for k in (raw as Array).size():
		var c: Variant = raw[k]
		var cctx := "%s collision[%d]" % [ctx, k]
		if not (c is Dictionary):
			GameData._err(out, "bad_type", cctx, "daire nesne olmalı")
			return
		var ok := GameData._num(out, cctx, c, "x", -1000, 1000)
		ok = GameData._num(out, cctx, c, "y", -1000, 1000) and ok
		ok = GameData._num(out, cctx, c, "r", 4, 200) and ok
		if not ok:
			return
	var b := MapSim.bounds_of_def(d)
	if b.z > MAX_BOUND:
		GameData._err(
			out,
			"out_of_range",
			ctx,
			"collision sarmalayan çember %.0f px > %.0f" % [b.z, MAX_BOUND]
		)
