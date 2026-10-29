class_name SchemaValidators
extends RefCounted
## GameData şema doğrulayıcıları: beceri, düşman, karakter, rig (docs/data-schema.md). Hata mesajı ve SIRASI
## game_data.gd'deki eski `_validate_*` gövdeleriyle aynıdır (test_acc_rf_data_errors baz).

var g: GameData


func _init(p_data: GameData) -> void:
	g = p_data


## Beceri şeması, sonra evrim çapraz referansları (CrossRefValidator).
func skills(out: PackedStringArray, reg: Dictionary) -> void:
	var entries := g._screen(out, g._raw_skills)
	for e in entries:
		_validate_skill(out, e["file"], e["data"], reg)
	CrossRefValidator.new(g).evolutions(out, entries)


func _validate_skill(out: PackedStringArray, file: String, d: Dictionary, reg: Dictionary) -> void:
	GameData._unknown_keys(out, file, d, GameData.SKILL_KEYS + DataV202Pool.KEYS)
	GameData._str(out, file, d, "name")
	g._check_asset(out, file, d, "icon")
	if not d.has("kind") or not (d["kind"] is String) or not GameData.SKILL_KINDS.has(d["kind"]):
		GameData._err(out, "bad_kind", file, "'kind' active|passive|evolution olmalı")
		return
	var kind: String = d["kind"]
	var max_ok := GameData._num(out, file, d, "max_level", 1, GameData.MAX_LEVEL_LIMIT, true)
	if kind == "evolution" and max_ok and int(d["max_level"]) != 1:
		GameData._err(out, "out_of_range", file, "evrim 'max_level' 1 olmalı")
	_validate_tags(out, file, d)
	_validate_behavior(out, file, d, kind, reg)
	if kind != "evolution" and d.has("requires"):
		GameData._err(out, "requires_unexpected", file, "'requires' yalnız evrimde olur")
	if kind == "evolution":
		if not d.has("requires"):
			GameData._err(out, "missing_field", file, "evrimde 'requires' zorunlu")
		elif not (d["requires"] is Dictionary):
			GameData._err(out, "bad_type", file, "'requires' nesne olmalı")
		else:
			GameData._unknown_keys(out, file + " requires", d["requires"], GameData.REQUIRES_KEYS)
	var levels_ok := _validate_levels_shape(out, file, d, max_ok)
	if levels_ok:
		if kind == "passive":
			_validate_passive_levels(out, file, d["levels"])
		else:
			_validate_active_levels(out, file, d["levels"])
	_validate_desc(out, file, d, max_ok)


func _validate_tags(out: PackedStringArray, file: String, d: Dictionary) -> void:
	if not d.has("tags"):
		GameData._err(out, "missing_field", file, "'tags' yok")
		return
	if not (d["tags"] is Array):
		GameData._err(out, "bad_type", file, "'tags' dizi olmalı")
		return
	for t in d["tags"]:
		if not (t is String) or (t as String).is_empty():
			GameData._err(out, "bad_type", file, "'tags' elemanları metin olmalı")
			return


func _validate_behavior(
	out: PackedStringArray, file: String, d: Dictionary, kind: String, reg: Dictionary
) -> void:
	var has_b: bool = d.has("behavior") and d["behavior"] is String and d["behavior"] != ""
	if kind == "passive":
		if has_b:
			GameData._err(out, "bad_type", file, "pasifte 'behavior' olmaz")
		return
	if not has_b:
		GameData._err(out, "missing_field", file, "'behavior' yok")
		return
	var key := StringName(d["behavior"])
	if not reg.has(key):
		GameData._err(out, "behavior_missing", file, "'%s' SkillRegistry'de yok" % key)
		return
	if not _derives_from_behavior(reg[key]):
		GameData._err(out, "behavior_base", file, "'%s' SkillBehavior'dan türemiyor" % key)


static func _derives_from_behavior(script: Variant) -> bool:
	var s: Script = script if script is Script else null
	while s != null:
		if s == SkillBehavior:
			return true
		s = s.get_base_script()
	return false


## levels dizisi var mı, uzunluğu max_level mi, elemanlar sözlük mü, anahtar kümeleri aynı mı.
func _validate_levels_shape(
	out: PackedStringArray, file: String, d: Dictionary, max_ok: bool
) -> bool:
	if not d.has("levels"):
		GameData._err(out, "missing_field", file, "'levels' yok")
		return false
	var lv: Variant = d["levels"]
	if not (lv is Array) or (lv as Array).is_empty():
		GameData._err(out, "bad_type", file, "'levels' dolu dizi olmalı")
		return false
	if max_ok and (lv as Array).size() != int(d["max_level"]):
		GameData._err(
			out,
			"levels_length",
			file,
			"levels %d eleman, max_level %d" % [(lv as Array).size(), int(d["max_level"])]
		)
		return false
	var first_keys: Array = []
	for i in (lv as Array).size():
		var row: Variant = lv[i]
		if not (row is Dictionary) or (row as Dictionary).is_empty():
			GameData._err(out, "bad_type", file, "levels[%d] dolu nesne olmalı" % i)
			return false
		var keys: Array = (row as Dictionary).keys()
		keys.sort()
		for k in keys:
			if not (GameData._is_num(row[k]) or SkillDef.is_text_level_key(k, row[k])):
				GameData._err(out, "bad_type", file, "levels[%d].%s sayı olmalı" % [i, k])
				return false
		if i == 0:
			first_keys = keys
		elif keys != first_keys:
			GameData._err(
				out, "levels_keys", file, "levels[%d] anahtar kümesi levels[0] ile aynı olmalı" % i
			)
			return false
	return true


func _validate_passive_levels(out: PackedStringArray, file: String, levels: Array) -> void:
	for i in levels.size():
		for k in (levels[i] as Dictionary).keys():
			if not GameData.PASSIVE_KEYS.has(k):
				GameData._err(out, "passive_key", file, "bilinmeyen pasif anahtarı '%s'" % k)
				return
	for k in (levels[0] as Dictionary).keys():
		var b: Array = GameData.PASSIVE_BOUNDS[k]
		var prev := 0.0
		for i in levels.size():
			var v := float(levels[i][k])
			if v < float(b[0]) or v > float(b[1]):
				GameData._err(
					out, "out_of_range", file, "levels[%d].%s = %s, aralık %s" % [i, k, v, b]
				)
				return
			if GameData.PASSIVE_ADDITIVE_KEYS.has(k) and k == "mag_add" and not GameData._is_int(v):
				GameData._err(out, "bad_type", file, "levels[%d].mag_add tamsayı olmalı" % i)
				return
			# toplam değerler sıfırdan uzaklaşmalı (|x| azalmaz)
			if absf(v) < absf(prev):
				GameData._err(
					out,
					"levels_monotonic",
					file,
					"pasif '%s' seviyeyle azalıyor (toplam değer olmalı)" % k
				)
				return
			prev = v


func _validate_active_levels(out: PackedStringArray, file: String, levels: Array) -> void:
	for i in levels.size():
		for k in (levels[i] as Dictionary).keys():
			if GameData.LEVEL_KEY_BOUNDS.has(k):
				var b: Array = GameData.LEVEL_KEY_BOUNDS[k]
				var v := float(levels[i][k])
				if v < float(b[0]) or v > float(b[1]):
					GameData._err(
						out, "out_of_range", file, "levels[%d].%s = %s, aralık %s" % [i, k, v, b]
					)
					return
	for k in (levels[0] as Dictionary).keys():
		var dec: bool = GameData.LEVEL_KEYS_NONDECREASING.has(k)
		var inc: bool = GameData.LEVEL_KEYS_NONINCREASING.has(k)
		if not dec and not inc:
			continue
		for i in range(1, levels.size()):
			var a := float(levels[i - 1][k])
			var b := float(levels[i][k])
			if (dec and b < a) or (inc and b > a):
				GameData._err(
					out, "levels_monotonic", file, "'%s' levels[%d] yönü bozuyor" % [k, i]
				)
				break


func _validate_desc(out: PackedStringArray, file: String, d: Dictionary, max_ok: bool) -> void:
	if not d.has("desc"):
		GameData._err(out, "missing_field", file, "'desc' yok")
		return
	var ds: Variant = d["desc"]
	if not (ds is Array):
		GameData._err(out, "bad_type", file, "'desc' dizi olmalı")
		return
	if max_ok and (ds as Array).size() != int(d["max_level"]):
		GameData._err(
			out,
			"levels_length",
			file,
			"desc %d eleman, max_level %d" % [(ds as Array).size(), int(d["max_level"])]
		)
		return
	for x in ds:
		if not (x is String) or (x as String).strip_edges().is_empty():
			GameData._err(out, "bad_type", file, "'desc' elemanları boş olmayan metin olmalı")
			return


# --- düşmanlar -----------------------------------------------------------------------------


func enemies(out: PackedStringArray) -> void:
	for e in g._screen(out, g._raw_enemies):
		_validate_enemy(out, e["file"], e["data"])


func _validate_enemy(out: PackedStringArray, file: String, d: Dictionary) -> void:
	GameData._unknown_keys(out, file, d, GameData.ENEMY_KEYS)
	GameData._str(out, file, d, "name")
	GameData._num(out, file, d, "hp", 1, 1000000)
	GameData._num(out, file, d, "speed", 0, 2000)
	GameData._num(out, file, d, "dmg", 0, 100000)
	GameData._num(out, file, d, "radius", 1, 500)
	GameData._num(out, file, d, "armor", 0, 1000)
	GameData._num(out, file, d, "xp", 0, 100000, true)
	GameData._num(out, file, d, "display_height", 1, 2000)
	if not d.has("ai") or not (d["ai"] is String) or not GameData.AI_KINDS.has(d["ai"]):
		GameData._err(out, "bad_ai", file, "'ai' ground|air|ghost|elite|lord olmalı")
	if not d.has("scales_with_time"):
		GameData._err(out, "missing_field", file, "'scales_with_time' yok")
	elif not (d["scales_with_time"] is bool):
		GameData._err(out, "bad_type", file, "'scales_with_time' bool olmalı")
	g._check_asset(out, file, d, "sprite")
	if not d.has("tint"):
		GameData._err(out, "missing_field", file, "'tint' yok")
	elif not (d["tint"] is String) or not Color.html_is_valid(d["tint"]):
		GameData._err(out, "bad_type", file, "'tint' #rrggbb metni olmalı")
	if d.has("charge"):
		if d["charge"] is Dictionary:
			GameData._unknown_keys(out, file + " charge", d["charge"], GameData.CHARGE_KEYS)
			GameData._num(out, file + " charge", d["charge"], "every", 0.1, 600)
			GameData._num(out, file + " charge", d["charge"], "duration", 0.1, 60)
			GameData._num(out, file + " charge", d["charge"], "speed", 1, 5000)
		else:
			GameData._err(out, "bad_type", file, "'charge' nesne olmalı")
	DataV11.validate_enemy(g, out, file, d)
	if d.has("summon"):
		if d["summon"] is Dictionary:
			var sm: Dictionary = d["summon"]
			GameData._unknown_keys(out, file + " summon", sm, GameData.SUMMON_KEYS)
			GameData._num(out, file + " summon", sm, "every", 0.1, 600)
			GameData._num(out, file + " summon", sm, "count", 1, 50, true)
			if (
				GameData._str(out, file + " summon", sm, "type")
				and not g._raw_enemy_exists(sm["type"])
			):
				GameData._err(out, "unknown_enemy", file, "summon.type '%s' yok" % sm["type"])
			if sm.has("enrage_hp_frac"):
				GameData._num(out, file + " summon", sm, "enrage_hp_frac", 0.01, 0.99)
				GameData._num(out, file + " summon", sm, "enrage_speed_mult", 1, 5)
				GameData._num(out, file + " summon", sm, "enrage_every", 0.1, 600)
		else:
			GameData._err(out, "bad_type", file, "'summon' nesne olmalı")


# --- karakterler ---------------------------------------------------------------------------


func characters(out: PackedStringArray) -> void:
	var entries := g._screen(out, g._raw_characters)
	if g._characters.is_empty():
		GameData._err(out, "no_character", "characters", "en az bir karakter gerekli")
	for e in entries:
		_validate_character(out, e["file"], e["data"])


func _validate_character(out: PackedStringArray, file: String, d: Dictionary) -> void:
	GameData._unknown_keys(out, file, d, GameData.CHARACTER_KEYS)
	DataV2.validate_character(g, out, file, d)
	GameData._str(out, file, d, "name")
	GameData._num(out, file, d, "max_hp", 1, 10000)
	GameData._num(out, file, d, "move_speed", 50, 1000)
	GameData._num(out, file, d, "mag_cap", 1, 20, true)
	GameData._num(out, file, d, "reload_time", 0.35, 5)
	GameData._num(out, file, d, "pickup_radius", 0, 1000)
	GameData._num(out, file, d, "collision_radius", 1, 200)
	GameData._num(out, file, d, "range", 100, 2000)
	if GameData._str(out, file, d, "starting_skill"):
		var sk: SkillDef = g._skills.get(StringName(d["starting_skill"]))
		if sk == null:
			GameData._err(
				out, "requires_ref", file, "starting_skill '%s' yok" % d["starting_skill"]
			)
		elif sk.kind != SkillDef.KIND_ACTIVE:
			GameData._err(
				out,
				"requires_kind",
				file,
				"starting_skill '%s' kind:active değil" % d["starting_skill"]
			)
	if not d.has("rig"):
		GameData._err(out, "missing_field", file, "'rig' yok")
	elif not (d["rig"] is Dictionary):
		GameData._err(out, "bad_type", file, "'rig' nesne olmalı")
	else:
		DataV202Rig.validate(g, out, file + " rig", d["rig"])


func rig(out: PackedStringArray, ctx: String, r: Dictionary) -> void:
	GameData._unknown_keys(out, ctx, r, GameData.RIG_KEYS)
	g._check_asset(out, ctx, r, "body")
	g._check_asset(out, ctx, r, "arm")
	GameData._num(out, ctx, r, "display_height", 1, 1000)
	GameData._num(out, ctx, r, "arm_scale", 0.01, 5)
	if not r.has("native_facing"):
		GameData._err(out, "missing_field", ctx, "'native_facing' yok")
	elif not (r["native_facing"] is String) or not ["left", "right"].has(r["native_facing"]):
		GameData._err(out, "bad_type", ctx, "'native_facing' left|right olmalı")
	GameData._pair(out, ctx, r, "arm_pivot", 0, 1)
	GameData._pair(out, ctx, r, "muzzle", 0, 1)
	if not r.has("shoulders"):
		GameData._err(out, "missing_field", ctx, "'shoulders' yok")
	elif not (r["shoulders"] is Array) or (r["shoulders"] as Array).size() != 2:
		GameData._err(out, "bad_type", ctx, "'shoulders' iki [x,y] çifti olmalı")
	else:
		for i in 2:
			GameData._pair(out, ctx, {"shoulders": r["shoulders"][i]}, "shoulders", 0, 1)
	DataV11.validate_walk(g, out, ctx, r)
	if not r.has("sway"):
		GameData._err(out, "missing_field", ctx, "'sway' yok")
	elif not (r["sway"] is Dictionary):
		GameData._err(out, "bad_type", ctx, "'sway' nesne olmalı")
	else:
		var s: Dictionary = r["sway"]
		GameData._unknown_keys(out, ctx + " sway", s, GameData.SWAY_KEYS)
		GameData._num(out, ctx + " sway", s, "hem_from_y", 0, 1)
		GameData._num(out, ctx + " sway", s, "amp", 0, 100)
		GameData._num(out, ctx + " sway", s, "lag", 0, 1)
		if not s.has("scarf_rect"):
			GameData._err(out, "missing_field", ctx + " sway", "'scarf_rect' yok")
		else:
			var sr: Variant = s["scarf_rect"]
			var good: bool = sr is Array and (sr as Array).size() == 4
			if good:
				for x in sr:
					good = good and GameData._is_num(x) and float(x) >= 0.0 and float(x) <= 1.0
			if not good:
				GameData._err(
					out, "bad_type", ctx + " sway", "'scarf_rect' [x0,y0,x1,y1] (0..1) olmalı"
				)
			elif float(sr[0]) >= float(sr[2]) or float(sr[1]) >= float(sr[3]):
				GameData._err(
					out, "out_of_range", ctx + " sway", "'scarf_rect' x0<x1 ve y0<y1 olmalı"
				)
