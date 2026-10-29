class_name DataV202Rig
extends RefCounted
## v2.0.2 kolsuz rig doğrulaması (`rig.armless: true`). GameData `_validate_character` içinde rig'i buraya yönlendirir;
## kollu rig SchemaValidators.rig'e aynen gider. Kolsuzda `arm, arm_pivot, muzzle, shoulders, arm_scale` zorunlu
## değildir, verilirse yok sayılır (kopyada sahte geçerli değerlerle değiştirilip ortak doğrulama koşar).
## Hata kodları GameData'nın (yeni kod yok): missing_field, bad_type, out_of_range, unknown_key, asset_missing.
## Şerit dosyasının gerçek boyutu burada okunmaz; `GameData.strip_probes`a yazılır, denetimi `AssetCheck` yapar (R6b).
## Şema: docs/data-schema.md

const ARM_KEYS: PackedStringArray = ["arm", "arm_pivot", "muzzle", "shoulders", "arm_scale"]
const EXTRA_KEYS: PackedStringArray = [
	"armless", "cast_point", "action_while_moving", "cast", "gather", "walk_cast"
]
const CAST_KEYS: PackedStringArray = ["frames", "fire_frame", "fps"]
const GATHER_KEYS: PackedStringArray = ["frames"]
const CLIP_FRAMES_MIN := 2
const CLIP_FRAMES_MAX := 8
const FPS_MIN := 8
const FPS_MAX := 60
const CAST_POINT_MAX := 0.5
## Şerit en geniş doku sınırı (px): toplam hücre × hücre genişliği.
const STRIP_MAX_WIDTH := 8192


static func validate(g: GameData, out: PackedStringArray, ctx: String, r: Dictionary) -> void:
	if not PlayerRig.is_armless(r):
		SchemaValidators.new(g).rig(out, ctx, r)
		return
	var base := r.duplicate()
	for k in EXTRA_KEYS:
		base.erase(k)
	base["arm"] = "placeholder:armless"
	base["arm_pivot"] = [0.0, 0.0]
	base["muzzle"] = [0.0, 0.0]
	base["shoulders"] = [[0.0, 0.0], [0.0, 0.0]]
	base["arm_scale"] = 0.5
	SchemaValidators.new(g).rig(out, ctx, base)
	GameData._pair(out, ctx, r, "cast_point", -CAST_POINT_MAX, CAST_POINT_MAX)
	if r.has("action_while_moving") and not (r["action_while_moving"] is bool):
		GameData._err(out, "bad_type", ctx, "'action_while_moving' bool olmalı")
	var clips := 0
	for k in ["cast", "walk_cast"]:
		if r.has(k) and _validate_clip(out, ctx + " " + k, r[k], CAST_KEYS, true):
			clips += 1
	if r.has("gather") and _validate_clip(out, ctx + " gather", r["gather"], GATHER_KEYS, false):
		clips += 1
	if clips > 0:
		_validate_strip(g, out, ctx, r)


## true = blok geçerli (kare kümesi sayılır).
static func _validate_clip(
	out: PackedStringArray, ctx: String, v: Variant, keys: PackedStringArray, timed: bool
) -> bool:
	if not (v is Dictionary):
		GameData._err(out, "bad_type", ctx, "nesne olmalı")
		return false
	var d: Dictionary = v
	var n_err := out.size()
	GameData._unknown_keys(out, ctx, d, keys)
	var ok := GameData._num(out, ctx, d, "frames", CLIP_FRAMES_MIN, CLIP_FRAMES_MAX, true)
	if timed:
		var hi := int(d["frames"]) - 1 if ok else CLIP_FRAMES_MAX - 1
		GameData._num(out, ctx, d, "fire_frame", 0, hi, true)
		GameData._num(out, ctx, d, "fps", FPS_MIN, FPS_MAX, true)
	return out.size() == n_err


## cast/gather/walk_cast varsa walk.strip + walk.cell zorunlu; toplam hücre × genişlik sınırı; doku varsa boyut uyumu.
static func _validate_strip(
	g: GameData, out: PackedStringArray, ctx: String, r: Dictionary
) -> void:
	var w: Variant = r.get("walk")
	if (
		not (w is Dictionary)
		or not (w as Dictionary).has("strip")
		or not (w as Dictionary).has("cell")
	):
		GameData._err(
			out, "missing_field", ctx, "cast/gather/walk_cast için walk.strip ve walk.cell zorunlu"
		)
		return
	var wd: Dictionary = w
	g._check_asset(out, ctx + " walk", wd, "strip")
	var cell: Variant = wd["cell"]
	if not (cell is Array) or (cell as Array).size() != 2 or not GameData._is_int(cell[0]):
		return  # biçim hatası DataV11.validate_walk'ta bildirilir
	var cells := RigFrames.total_cells(r)
	if cells * int(cell[0]) > STRIP_MAX_WIDTH:
		GameData._err(
			out,
			"out_of_range",
			ctx + " walk",
			(
				"%d hücre × %d px = %d > %d"
				% [cells, int(cell[0]), cells * int(cell[0]), STRIP_MAX_WIDTH]
			)
		)
		return
	var path: Variant = wd["strip"]
	if path is String and g._asset_ok(path) and not (path as String).begins_with("placeholder:"):
		# Doku boyutu sim'de okunmaz (doku yüklemek sim dışı): AssetCheck.validate(g) bu kayıtları denetler.
		g.strip_probes.append(
			{"ctx": ctx + " walk", "path": path, "w": cells * int(cell[0]), "h": int(cell[1])}
		)
