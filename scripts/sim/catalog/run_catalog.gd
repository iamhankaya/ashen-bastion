class_name RunCatalog
extends RefCounted
## Koşu modu / zorluk kataloğu (R7): mod, zorluk, bitiş türü ve varsayılanların tek kaynağı. Veri `data/run_modes/<id>.json` ve
## `data/difficulties/<id>.json` dosyalarından gelir (`load_dir`); tüketiciler (RunProfiles, RunStrip, Settings, Highscores,
## AchievementRules) `default()` üzerinden okur. Saf veri: store/ui/ctrl bilmez. Bilinmeyen kimlik => boş/null, hata YOK.
## Mod girdisi: {id, order, name, label, description, profile:{çarpanlar}, ending, icon_key, default?}.
## Zorluk girdisi: {id, order, name, label, description, spoken, shields, values:{enemy_hp, enemy_dmg, spawn_density, xp, lord_hp},
## achievements:{block_lord_bound, totals}, default?}. Alan kuralları: docs/data-schema.md `### Mod kataloğu (R7)`.

## Bitiş türü kapalı küme: yeni tür sim kodu gerektirir (kabul veriyle eklenmez).
const ENDING_KINDS: PackedStringArray = ["lord", "endless"]

const MODES_DIR := "run_modes"
const DIFFS_DIR := "difficulties"

static var _default: RunCatalog = null

var load_errors: PackedStringArray = PackedStringArray()  # okuma hataları; validate() çıktısının başına girer
var _modes: Array = []  # (order, id) sıralı ham girdiler (yinelenenler dahil; validate bildirir)
var _diffs: Array = []


## `res://data` kataloğu (ilk çağrıda yüklenir, paylaşılır, salt okunur).
static func default() -> RunCatalog:
	if _default == null:
		_default = load_dir("res://data")
	return _default


## Testler için: sonraki `default()` diskten yeniden okur.
static func reset_default_cache() -> void:
	_default = null


## `<kök>/run_modes/*.json` ve `<kök>/difficulties/*.json` (dosya adı = kimlik). Eksik dizin = boş katalog.
static func load_dir(root: String) -> RunCatalog:
	var errs := PackedStringArray()
	var c := from_dicts(
		_read_entries(root.path_join(MODES_DIR), MODES_DIR, errs),
		_read_entries(root.path_join(DIFFS_DIR), DIFFS_DIR, errs)
	)
	c.load_errors = errs
	return c


static func from_dicts(modes: Array, difficulties: Array) -> RunCatalog:
	var c := RunCatalog.new()
	c._modes = _sorted(modes)
	c._diffs = _sorted(difficulties)
	return c


## Hata mesajları ("RUN_CATALOG: <id>: <neden>"); boş = geçerli. Sıra deterministiktir ((order, id) sırası).
func validate() -> PackedStringArray:
	var out := PackedStringArray(load_errors)
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


## `RunProfiles` doğrulayıcısının beklediği ham biçim: {default, modes:{id: profil+end_mode}, difficulties:{id: değerler},
## achievements:{<zorluk>: kural}}. `extra_achievements` (run_profiles.json "achievements") ile birleşir.
func to_profiles_dict(extra_achievements: Dictionary = {}) -> Dictionary:
	var modes := {}
	for m in _modes:
		var p := _dict(m, "profile")
		p["end_mode"] = str(m.get("ending", ""))
		modes[_id(m)] = p
	var diffs := {}
	var ach := extra_achievements.duplicate(true)
	for d in _diffs:
		diffs[_id(d)] = _dict(d, "values")
		if d.get("achievements", null) is Dictionary:
			ach[_id(d)] = _dict(d, "achievements")
	return {
		"default": {"mode": default_mode(), "diff": default_difficulty()},
		"modes": modes,
		"difficulties": diffs,
		"achievements": ach,
	}


static func _dict(e: Dictionary, key: String) -> Dictionary:
	var v: Variant = e.get(key, null)
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


static func _read_entries(dir: String, label: String, errs: PackedStringArray) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var names: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f in names:
		var rel := "%s/%s" % [label, f]
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(dir.path_join(f))) != OK:
			errs.append("RUN_CATALOG: %s: JSON ayrıştırılamadı" % rel)
		elif not (json.data is Dictionary):
			errs.append("RUN_CATALOG: %s: kök nesne olmalı" % rel)
		else:
			if str((json.data as Dictionary).get("id", "")) != f.trim_suffix(".json"):
				errs.append("RUN_CATALOG: %s: kimlik dosya adıyla aynı olmalı" % rel)
			out.append(json.data)
	return out


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
