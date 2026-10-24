class_name DataV202Pool
extends RefCounted
## v2.0.2 beceri havuzu doğrulaması: `pool` ("common" ya da karakter kimliği) ve `variants` (ortak becerilerde
## karakter başına {name, icon, desc}). GameData `SKILL_KEYS + KEYS` ile anahtarları, `validate` ile kuralları çağırır
## (game_data.gd satır tavanı). Hata kodları GameData'nın (yeni kod yok): unknown_ref, bad_type, unknown_key,
## requires_ref, out_of_range, asset_missing. Şema: docs/data-schema.md

const KEYS: PackedStringArray = ["pool", "variants"]
const VARIANT_KEYS: PackedStringArray = ["name", "icon", "desc"]
const NAME_MAX := 18


static func validate(g: GameData, out: PackedStringArray) -> void:
	var raw_pools := {}
	for e in g._raw_skills:
		if e["data"] is Dictionary and GameData._valid_id(e["data"].get("id")):
			raw_pools[str(e["data"]["id"])] = _pool_of(e["data"])
	for e in g._raw_skills:
		if e["data"] is Dictionary:
			_validate_skill(g, out, e["file"], e["data"], raw_pools)
	for e in g._raw_characters:
		if e["data"] is Dictionary:
			_validate_starting_skill(out, e["file"], e["data"], raw_pools)


static func _pool_of(d: Dictionary) -> String:
	var p: Variant = d.get("pool", "common")
	return p if p is String else ""


static func _validate_skill(
	g: GameData, out: PackedStringArray, file: String, d: Dictionary, pools: Dictionary
) -> void:
	var pool_ok := true
	if d.has("pool"):
		var p: Variant = d["pool"]
		if not (p is String) or (p as String).is_empty():
			GameData._err(out, "bad_type", file, "'pool' boş olmayan metin olmalı")
			pool_ok = false
		elif p != "common" and not g._characters.has(StringName(p)):
			GameData._err(out, "unknown_ref", file, "pool '%s' bilinen karakter değil" % p)
			pool_ok = false
	if d.has("variants") and pool_ok:
		_validate_variants(g, out, file, d, _pool_of(d) == "common")
	if d.get("kind") == "evolution" and d.get("requires") is Dictionary and pool_ok:
		var act: Variant = (d["requires"] as Dictionary).get("active")
		if act is String and pools.has(act) and pools[act] != _pool_of(d):
			GameData._err(
				out,
				"requires_ref",
				file,
				(
					"evrim havuzu '%s', requires.active '%s' havuzu '%s'"
					% [_pool_of(d), act, pools[act]]
				)
			)


static func _validate_variants(
	g: GameData, out: PackedStringArray, file: String, d: Dictionary, common: bool
) -> void:
	var v: Variant = d["variants"]
	if not (v is Dictionary):
		GameData._err(out, "bad_type", file, "'variants' nesne olmalı")
		return
	if not common:
		GameData._err(out, "unknown_key", file, "'variants' yalnız ortak (common) havuzda olur")
		return
	for ck in (v as Dictionary).keys():
		var ctx := "%s variants.%s" % [file, ck]
		if not g._characters.has(StringName(str(ck))):
			GameData._err(out, "unknown_ref", ctx, "'%s' bilinen karakter değil" % ck)
			continue
		var vd: Variant = v[ck]
		if not (vd is Dictionary):
			GameData._err(out, "bad_type", ctx, "variant nesne olmalı")
			continue
		_validate_variant(g, out, ctx, vd, d)


static func _validate_variant(
	g: GameData, out: PackedStringArray, ctx: String, vd: Dictionary, skill: Dictionary
) -> void:
	GameData._unknown_keys(out, ctx, vd, VARIANT_KEYS)
	if vd.has("name"):
		if not GameData._str(out, ctx, vd, "name"):
			pass
		elif (vd["name"] as String).length() > NAME_MAX:
			GameData._err(out, "out_of_range", ctx, "'name' en çok %d karakter" % NAME_MAX)
	if vd.has("icon"):
		g._check_asset(out, ctx, vd, "icon")
	if not vd.has("desc"):
		return
	var ds: Variant = vd["desc"]
	if not (ds is Array):
		GameData._err(out, "bad_type", ctx, "'desc' dizi olmalı")
		return
	var max_level: Variant = skill.get("max_level")
	if GameData._is_int(max_level) and (ds as Array).size() != int(max_level):
		GameData._err(
			out,
			"out_of_range",
			ctx,
			"'desc' %d eleman, max_level %d" % [(ds as Array).size(), int(max_level)]
		)
		return
	for x in ds:
		if not (x is String) or (x as String).strip_edges().is_empty():
			GameData._err(out, "bad_type", ctx, "'desc' elemanları boş olmayan metin olmalı")
			return


## Karakterin başlangıç becerisi kendi havuzundan ya da ortaktan olmalı.
static func _validate_starting_skill(
	out: PackedStringArray, file: String, d: Dictionary, pools: Dictionary
) -> void:
	var sk: Variant = d.get("starting_skill")
	if not (sk is String) or not pools.has(sk) or not (d.get("id") is String):
		return  # eksik/bilinmeyen: GameData kendi hatasını verir
	if pools[sk] != "common" and pools[sk] != d["id"]:
		GameData._err(
			out,
			"requires_ref",
			file,
			"starting_skill '%s' havuzu '%s' (karakter '%s')" % [sk, pools[sk], d["id"]]
		)
