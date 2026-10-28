class_name RunCatalog
extends RefCounted
## Koşu modu / zorluk kataloğu iskeleti (sözleşme-B): mod, zorluk, bitiş türü ve varsayılanların tek kaynağı olacak.
## Bu aşamada tüketici YOK (RunProfiles/RunStrip/Settings/Highscores dönüşümü R7); `default()` bugünkü
## data/run_profiles.json'u sarar. Saf veri: store/ui/ctrl bilmez. Bilinmeyen kimlik => boş/null, hata YOK (push_error yok).
## Mod girdisi: {id, order, name, description, profile:{çarpanlar}, ending, icon_key, default?}.
## Zorluk girdisi: {id, order, name, description, values:{enemy_hp, enemy_dmg, spawn_density, xp, lord_hp}, default?}.

## Bitiş türü kapalı küme: yeni tür sim kodu gerektirir (kabul veriyle eklenmez).
const ENDING_KINDS: PackedStringArray = ["lord", "endless"]

var _modes: Array = []  # (order, id) sıralı ham girdiler (yinelenenler dahil; validate bildirir)
var _diffs: Array = []


static func default() -> RunCatalog:
	var raw: Dictionary = RunProfiles.load_default().get("profiles", {})
	var dflt: Dictionary = raw.get("default", {})
	var modes: Array = []
	var diffs: Array = []
	var i := 0
	for id in raw.get("modes", {}):
		var m: Dictionary = raw["modes"][id]
		i += 1
		(
			modes
			. append(
				{
					"id": id,
					"order": i,
					"name": String(id).capitalize(),
					"description": "",
					"profile": m,
					"ending": str(m.get("end_mode", "lord")),
					"icon_key": id,
					"default": id == str(dflt.get("mode", "")),
				}
			)
		)
	i = 0
	for id in raw.get("difficulties", {}):
		i += 1
		(
			diffs
			. append(
				{
					"id": id,
					"order": i,
					"name": String(id).capitalize(),
					"description": "",
					"values": raw["difficulties"][id],
					"default": id == str(dflt.get("diff", "")),
				}
			)
		)
	return from_dicts(modes, diffs)


static func from_dicts(modes: Array, difficulties: Array) -> RunCatalog:
	var c := RunCatalog.new()
	c._modes = _sorted(modes)
	c._diffs = _sorted(difficulties)
	return c


## Hata mesajları ("RUN_CATALOG: <id>: <neden>"); boş = geçerli. Sıra deterministiktir ((order, id) sırası).
func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if _modes.is_empty():
		out.append("RUN_CATALOG: modes: en az bir mod gerekir")
	if _diffs.is_empty():
		out.append("RUN_CATALOG: difficulties: en az bir zorluk gerekir")
	var seen := {}
	for m in _modes:
		var id := _id(m)
		_check_common(out, m, seen)
		if not (m.get("profile", null) is Dictionary):
			out.append("RUN_CATALOG: %s: profile sözlük olmalı" % id)
		var ending := str(m.get("ending", ""))
		if not ENDING_KINDS.has(ending):
			out.append("RUN_CATALOG: %s: bitiş türü '%s' bilinmiyor" % [id, ending])
	_check_defaults(out, _modes, "mod")
	seen = {}
	for d in _diffs:
		_check_common(out, d, seen)
		var v: Variant = d.get("values", null)
		if not (v is Dictionary) or (v as Dictionary).is_empty():
			out.append("RUN_CATALOG: %s: values boş" % _id(d))
	_check_defaults(out, _diffs, "zorluk")
	return out


func mode_ids() -> PackedStringArray:
	return _ids(_modes)


## Bilinmeyen kimlik => {}.
func mode(id: String) -> Dictionary:
	return _find(_modes, id)


func difficulty_ids() -> PackedStringArray:
	return _ids(_diffs)


func difficulty(id: String) -> Dictionary:
	return _find(_diffs, id)


## `default: true` olan; yoksa (order, id) sırasıyla ilki; katalog boşsa "".
func default_mode() -> String:
	return _default_of(_modes)


func default_difficulty() -> String:
	return _default_of(_diffs)


func ending_kinds() -> PackedStringArray:
	return ENDING_KINDS


## `RunProfile.make` birleşimi (run_profile.gd). Bilinmeyen mod/zorluk => null.
func build_profile(mode_id: String, difficulty_id: String) -> RunProfile:
	var m := mode(mode_id)
	var d := difficulty(difficulty_id)
	if m.is_empty() or d.is_empty():
		return null
	var profile: Dictionary = (m.get("profile", {}) as Dictionary).duplicate()
	profile["end_mode"] = str(m.get("ending", GameSim.END_MODE_LORD))
	var cfg := {"modes": {mode_id: profile}, "difficulties": {difficulty_id: d.get("values", {})}}
	return RunProfile.make(StringName(mode_id), StringName(difficulty_id), cfg)


static func _sorted(entries: Array) -> Array:
	var keyed: Array = []
	for i in entries.size():
		var e: Variant = entries[i]
		if e is Dictionary:
			keyed.append([int(e.get("order", 0)), str(e.get("id", "")), i, e])
	keyed.sort_custom(
		func(a: Array, b: Array) -> bool:
			if a[0] != b[0]:
				return a[0] < b[0]
			if a[1] != b[1]:
				return a[1] < b[1]
			return a[2] < b[2]
	)
	var out: Array = []
	for k in keyed:
		out.append(k[3])
	return out


static func _id(e: Dictionary) -> String:
	return str(e.get("id", ""))


static func _check_common(out: PackedStringArray, e: Dictionary, seen: Dictionary) -> void:
	var id := _id(e)
	if id == "":
		out.append("RUN_CATALOG: (kimliksiz): kimlik boş")
	elif seen.has(id):
		out.append("RUN_CATALOG: %s: yinelenen kimlik" % id)
	seen[id] = true
	if str(e.get("name", "")) == "":
		out.append("RUN_CATALOG: %s: ad boş" % id)


static func _check_defaults(out: PackedStringArray, entries: Array, what: String) -> void:
	var n := 0
	for e in entries:
		if bool(e.get("default", false)):
			n += 1
	if n > 1:
		out.append("RUN_CATALOG: %s: birden fazla varsayılan" % what)


static func _ids(entries: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for e in entries:
		if not out.has(_id(e)):
			out.append(_id(e))
	return out


static func _find(entries: Array, id: String) -> Dictionary:
	for e in entries:
		if _id(e) == id:
			return e
	return {}


static func _default_of(entries: Array) -> String:
	for e in entries:
		if bool(e.get("default", false)):
			return _id(e)
	return "" if entries.is_empty() else _id(entries[0])
