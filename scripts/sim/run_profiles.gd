class_name RunProfiles
extends RefCounted
## data/run_profiles.json okuyucusu ve alan bazlı doğrulayıcısı (v2.1; tek kaynak). GameData'dan bağımsızdır:
## GameData.validate ve data_bad_* fixture setleri bunu görmez. Dosya yoksa HATA (yerleşik varsayılan yok).
## Hata satırı GameData ile aynı biçim: "[kod] bağlam: açıklama". Kurallar: docs/data-schema.md "run_profiles.json".

const PATH := "res://data/run_profiles.json"
const VERSION := 1
const MODES: PackedStringArray = ["quick", "normal", "endless"]
const DIFFS: PackedStringArray = ["easy", "normal", "hard"]
const END_MODES: PackedStringArray = ["lord", "endless"]
const TOTALS_RULES: PackedStringArray = ["runs_playsecs_only", "all"]
const ERROR_CODES: PackedStringArray = [
	"profile_file_missing",
	"profile_range",
	"profile_type",
	"profile_missing_key",
	"profile_unknown_key",
	"profile_default",
	"profile_cross",
]
const TOP_KEYS: PackedStringArray = ["v", "default", "modes", "difficulties", "achievements"]
## Her modda zorunlu sayı alanları: ad -> [alt, üst] (sınırlar dahil).
const MODE_FIELDS := {
	"time_scale": [0.25, 4.0],
	"xp_mult": [1.0, 5.0],
	"lord_hp_mult": [0.1, 5.0],
	"rate_mult": [0.25, 4.0],
}
## Yalnız end_mode=endless için zorunlu, diğer modlarda yasak.
const ENDLESS_FIELDS := {
	"lord_repeat_sec": [60.0, 1800.0],
	"lord_repeat_hp_mult": [1.0, 5.0],
	"lord_hp_cap_mult": [1.0, 20.0],
	"enrage_after_sec": [1200.0, 7200.0],
	"enrage_dmg_per_min": [0.0, 1.0],
}
const DIFF_FIELDS := {
	"enemy_hp": [0.1, 5.0],
	"enemy_dmg": [0.1, 5.0],
	"spawn_density": [0.1, 5.0],
	"xp": [1.0, 5.0],
	"lord_hp": [0.1, 5.0],
}
const ACH_DIFF_KEYS: PackedStringArray = ["block_lord_bound", "totals"]
## Kademe kimliği: "<aile>:<1 tabanlı kademe sırası>" (örn. "endure:4").
const TIER_ID_RE := "^[a-z0-9_]+:[1-9][0-9]*$"
const FILE_CTX := "run_profiles.json"


## {"profiles": Dictionary (doğrulanmış ham veri; hata varsa {}), "errors": Array}.
static func load_default() -> Dictionary:
	return load_file(PATH)


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"profiles": {}, "errors": ["[profile_file_missing] %s: dosya yok" % path]}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"profiles": {}, "errors": ["[profile_type] %s: JSON ayrıştırılamadı" % path]}
	var errs := validate(json.data)
	return {"profiles": json.data if errs.is_empty() else {}, "errors": Array(errs)}


## Ham veriyi doğrular (saf; dosyaya dokunmaz). Boş dönüş = geçerli.
static func validate(raw: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not (raw is Dictionary):
		_err(out, "profile_type", FILE_CTX, "kök nesne olmalı")
		return out
	var d: Dictionary = raw
	for k in d.keys():
		if not TOP_KEYS.has(str(k)):
			_err(out, "profile_unknown_key", FILE_CTX, "bilinmeyen anahtar '%s'" % k)
	if not d.has("v"):
		_err(out, "profile_missing_key", FILE_CTX, "'v' yok")
	elif not _is_num(d["v"]):
		_err(out, "profile_type", FILE_CTX, "'v' sayı olmalı")
	elif float(d["v"]) != float(VERSION):
		_err(out, "profile_range", FILE_CTX, "'v' = %d olmalı" % VERSION)
	var modes := _object(out, d, "modes")
	var diffs := _object(out, d, "difficulties")
	_names(out, "modes", modes, MODES)
	_names(out, "difficulties", diffs, DIFFS)
	for name in MODES:
		if modes.has(name):
			_mode(out, name, modes[name])
	for name in DIFFS:
		if diffs.has(name):
			_diff(out, name, diffs[name])
	_default(out, d, modes, diffs)
	_achievements(out, d, diffs)
	return out


## Doğrulanmış `profiles` içinden varsayılan seçim: {"mode": StringName, "diff": StringName}.
static func default_selection(profiles: Dictionary) -> Dictionary:
	var def: Dictionary = profiles.get("default", {})
	return {
		"mode": StringName(str(def.get("mode", "normal"))),
		"diff": StringName(str(def.get("diff", "normal")))
	}


static func _mode(out: PackedStringArray, name: String, raw: Variant) -> void:
	var ctx := "modes.%s" % name
	if not (raw is Dictionary):
		_err(out, "profile_type", ctx, "nesne olmalı")
		return
	var m: Dictionary = raw
	for k in m.keys():
		if not (MODE_FIELDS.has(k) or ENDLESS_FIELDS.has(k) or k == "end_mode"):
			_err(out, "profile_unknown_key", ctx, "bilinmeyen anahtar '%s'" % k)
	for k in MODE_FIELDS:
		_number(out, ctx, m, k, MODE_FIELDS[k], "profile_missing_key")
	var endless := false
	if not m.has("end_mode"):
		_err(out, "profile_missing_key", ctx, "'end_mode' yok")
	elif not (m["end_mode"] is String):
		_err(out, "profile_type", ctx, "'end_mode' dizge olmalı")
	elif not END_MODES.has(m["end_mode"]):
		_err(out, "profile_cross", ctx, "'end_mode' lord|endless olmalı")
	else:
		endless = m["end_mode"] == "endless"
	for k in ENDLESS_FIELDS:
		if endless:
			_number(out, ctx, m, k, ENDLESS_FIELDS[k], "profile_cross")
		elif m.has(k):
			_err(out, "profile_cross", ctx, "'%s' yalnız end_mode=endless için" % k)


static func _diff(out: PackedStringArray, name: String, raw: Variant) -> void:
	var ctx := "difficulties.%s" % name
	if not (raw is Dictionary):
		_err(out, "profile_type", ctx, "nesne olmalı")
		return
	var m: Dictionary = raw
	for k in m.keys():
		if not DIFF_FIELDS.has(k):
			_err(out, "profile_unknown_key", ctx, "bilinmeyen anahtar '%s'" % k)
	for k in DIFF_FIELDS:
		_number(out, ctx, m, k, DIFF_FIELDS[k], "profile_missing_key")


static func _default(
	out: PackedStringArray, d: Dictionary, modes: Dictionary, diffs: Dictionary
) -> void:
	if not d.has("default"):
		_err(out, "profile_missing_key", FILE_CTX, "'default' yok")
		return
	if not (d["default"] is Dictionary):
		_err(out, "profile_type", "default", "nesne olmalı")
		return
	var def: Dictionary = d["default"]
	for k in def.keys():
		if k != "mode" and k != "diff":
			_err(out, "profile_unknown_key", "default", "bilinmeyen anahtar '%s'" % k)
	for pair in [["mode", modes], ["diff", diffs]]:
		var key: String = pair[0]
		var table: Dictionary = pair[1]
		if not def.has(key):
			_err(out, "profile_missing_key", "default", "'%s' yok" % key)
		elif not (def[key] is String):
			_err(out, "profile_type", "default", "'%s' dizge olmalı" % key)
		elif not table.has(def[key]):
			_err(out, "profile_default", "default", "'%s' = '%s' tanımlı değil" % [key, def[key]])


static func _achievements(out: PackedStringArray, d: Dictionary, diffs: Dictionary) -> void:
	if not d.has("achievements"):
		_err(out, "profile_missing_key", FILE_CTX, "'achievements' yok")
		return
	if not (d["achievements"] is Dictionary):
		_err(out, "profile_type", "achievements", "nesne olmalı")
		return
	var a: Dictionary = d["achievements"]
	for k in a.keys():
		if k != "lord_bound_tier_ids" and not DIFFS.has(str(k)):
			_err(out, "profile_unknown_key", "achievements", "bilinmeyen anahtar '%s'" % k)
	_tier_ids(out, a)
	for name in diffs.keys():
		if not a.has(name):
			_err(out, "profile_cross", "achievements", "zorluk '%s' için kural yok" % name)
	for name in DIFFS:
		if not a.has(name):
			continue
		var ctx := "achievements.%s" % name
		if not (a[name] is Dictionary):
			_err(out, "profile_type", ctx, "nesne olmalı")
			continue
		var r: Dictionary = a[name]
		for k in r.keys():
			if not ACH_DIFF_KEYS.has(str(k)):
				_err(out, "profile_unknown_key", ctx, "bilinmeyen anahtar '%s'" % k)
		if not r.has("block_lord_bound"):
			_err(out, "profile_missing_key", ctx, "'block_lord_bound' yok")
		elif not (r["block_lord_bound"] is bool):
			_err(out, "profile_type", ctx, "'block_lord_bound' bool olmalı")
		if not r.has("totals"):
			_err(out, "profile_missing_key", ctx, "'totals' yok")
		elif not (r["totals"] is String):
			_err(out, "profile_type", ctx, "'totals' dizge olmalı")
		elif not TOTALS_RULES.has(r["totals"]):
			_err(out, "profile_range", ctx, "'totals' runs_playsecs_only|all olmalı")


static func _tier_ids(out: PackedStringArray, a: Dictionary) -> void:
	if not a.has("lord_bound_tier_ids"):
		_err(out, "profile_missing_key", "achievements", "'lord_bound_tier_ids' yok")
		return
	if not (a["lord_bound_tier_ids"] is Array):
		_err(out, "profile_type", "achievements", "'lord_bound_tier_ids' dizi olmalı")
		return
	var rx := RegEx.create_from_string(TIER_ID_RE)
	for id: Variant in a["lord_bound_tier_ids"]:
		if not (id is String):
			_err(out, "profile_type", "achievements", "kademe kimliği dizge olmalı")
		elif rx.search(id) == null:
			_err(
				out,
				"profile_range",
				"achievements",
				"kademe kimliği '<aile>:<n>' olmalı: '%s'" % id
			)


## Sözlükte `key`'in nesne olmasını ister; değilse hata + boş sözlük.
static func _object(out: PackedStringArray, d: Dictionary, key: String) -> Dictionary:
	if not d.has(key):
		_err(out, "profile_missing_key", FILE_CTX, "'%s' yok" % key)
		return {}
	if not (d[key] is Dictionary):
		_err(out, "profile_type", FILE_CTX, "'%s' nesne olmalı" % key)
		return {}
	return d[key]


## Beklenen adların hepsi var, başkası yok.
static func _names(
	out: PackedStringArray, ctx: String, table: Dictionary, expected: PackedStringArray
) -> void:
	for name in expected:
		if not table.has(name):
			_err(out, "profile_missing_key", ctx, "'%s' yok" % name)
	for k in table.keys():
		if not expected.has(str(k)):
			_err(out, "profile_unknown_key", ctx, "bilinmeyen ad '%s'" % k)


## Sayı alanı: eksik -> `missing_code`; sayı değil -> profile_type; aralık dışı/NaN -> profile_range.
static func _number(
	out: PackedStringArray,
	ctx: String,
	d: Dictionary,
	key: String,
	bounds: Array,
	missing_code: String
) -> void:
	if not d.has(key):
		_err(out, missing_code, ctx, "'%s' yok" % key)
		return
	var v: Variant = d[key]
	if not _is_num(v):
		_err(out, "profile_type", ctx, "'%s' sayı olmalı" % key)
		return
	var f := float(v)
	if f < float(bounds[0]) or f > float(bounds[1]):
		_err(out, "profile_range", ctx, "'%s' [%s, %s] içinde olmalı" % [key, bounds[0], bounds[1]])


static func _is_num(v: Variant) -> bool:
	return (v is int) or (v is float and is_finite(v))


static func _err(out: PackedStringArray, code: String, ctx: String, msg: String) -> void:
	out.append("[%s] %s: %s" % [code, ctx, msg])
