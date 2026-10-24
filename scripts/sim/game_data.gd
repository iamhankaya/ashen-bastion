class_name GameData
extends RefCounted
## Veri yükleme + şema doğrulama (autoload DEĞİL). Şema: docs/data-schema.md
##
## Dosya başına kayıt: <kök>/characters/<id>.json, skills/<id>.json, enemies/<id>.json, waves.json
## validate() hata kodlu satırlar döndürür: "[kod] bağlam: açıklama". Boş dizi = geçerli.

const SKILL_KINDS: PackedStringArray = ["active", "passive", "evolution"]
const AI_KINDS: PackedStringArray = ["ground", "air", "ghost", "elite", "lord"]
const WAVE_KINDS: PackedStringArray = ["rate", "group", "burst", "boss"]
const SPAWNABLE_AI: PackedStringArray = ["ground", "air", "ghost"]
const PASSIVE_KEYS: PackedStringArray = [
	"bullet_dmg_mult",
	"fire_rate_mult",
	"reload_time_mult",
	"mag_add",
	"area_mult",
	"explosion_dmg_mult",
	"move_speed_mult",
	"max_hp_add",
	"regen",
	"pickup_mult",
	"range_mult",
	"wind_time_mult",
]
## Çarpan türü pasifler x saklar, etkin değer 1 + x. Diğerleri toplamdır.
const PASSIVE_ADDITIVE_KEYS: PackedStringArray = ["mag_add", "max_hp_add", "regen"]
const PASSIVE_BOUNDS := {
	"bullet_dmg_mult": [-0.9, 5.0],
	"fire_rate_mult": [-0.9, 5.0],
	"reload_time_mult": [-0.9, 0.0],
	"mag_add": [0.0, 20.0],
	"area_mult": [-0.9, 5.0],
	"explosion_dmg_mult": [-0.9, 5.0],
	"move_speed_mult": [-0.9, 5.0],
	"max_hp_add": [0.0, 1000.0],
	"regen": [0.0, 50.0],
	"pickup_mult": [-0.9, 5.0],
	"range_mult": [-0.9, 5.0],
	"wind_time_mult": [-0.9, 5.0],
}
## Aktif seviye anahtarları: değer seviyeyle azalmamalı / artmamalı.
const LEVEL_KEYS_NONDECREASING: PackedStringArray = [
	"damage",
	"count",
	"radius",
	"pellets",
	"chance",
	"bounces",
	"ex_damage",
	"ex_radius",
	"damage_mult",
	"pierce",
	"push",
]
const LEVEL_KEYS_NONINCREASING: PackedStringArray = ["cooldown", "interval", "every_n"]
## Bilinen anahtar kümeleri (yazım hatası = unknown_key). Aktif seviye satırları serbest sayısal anahtar alır.
const CHARACTER_KEYS: PackedStringArray = [
	"id",
	"name",
	"max_hp",
	"move_speed",
	"mag_cap",
	"reload_time",
	"pickup_radius",
	"collision_radius",
	"starting_skill",
	"range",
	"rig",
	"blurb",
	"portrait",
	"unlock",
	"placeholder",
	"display_upper",
	"order",
]
const RIG_KEYS: PackedStringArray = [
	"body",
	"arm",
	"display_height",
	"native_facing",
	"shoulders",
	"arm_pivot",
	"muzzle",
	"arm_scale",
	"sway",
	"walk",
]
const SWAY_KEYS: PackedStringArray = ["hem_from_y", "scarf_rect", "amp", "lag"]
const SKILL_KEYS: PackedStringArray = [
	"id",
	"kind",
	"name",
	"icon",
	"max_level",
	"tags",
	"behavior",
	"levels",
	"desc",
	"requires",
	"sfx",
]
const REQUIRES_KEYS: PackedStringArray = ["active", "active_level", "passive", "passive_min_level"]
const ENEMY_KEYS: PackedStringArray = [
	"id",
	"name",
	"hp",
	"speed",
	"dmg",
	"radius",
	"armor",
	"xp",
	"ai",
	"scales_with_time",
	"sprite",
	"display_height",
	"tint",
	"charge",
	"summon",
	"anim",
]
const CHARGE_KEYS: PackedStringArray = ["every", "duration", "speed"]
const SUMMON_KEYS: PackedStringArray = [
	"type",
	"every",
	"count",
	"enrage_hp_frac",
	"enrage_speed_mult",
	"enrage_every",
]
## Bilinen aktif seviye anahtarlarının sınırları [alt, üst].
const LEVEL_KEY_BOUNDS := {
	"cooldown": [0.05, 600.0],
	"interval": [0.05, 60.0],
	"every_n": [1.0, 100.0],
	"damage": [0.0, 100000.0],
	"count": [1.0, 100.0],
	"radius": [0.0, 2000.0],
	"pellets": [1.0, 100.0],
	"chance": [0.0, 1.0],
	"bounces": [0.0, 50.0],
	"ex_damage": [0.0, 100000.0],
	"ex_radius": [0.0, 2000.0],
	"damage_mult": [0.0, 20.0],
	"pierce": [0.0, 50.0],
	"push": [0.0, 2000.0],
}
const MAX_LEVEL_LIMIT := 8
const MAX_BURST_COUNT := 400
const DEFAULT_END_TIME := 1200.0
const PLACEHOLDER_PREFIX := "placeholder:"
const RHYTHM_TAG := "rhythm"
const MIN_RHYTHM_ACTIVES := 2
const ASSET_EXTENSIONS: PackedStringArray = ["", ".png", ".svg", ".webp"]

## validate() hata kodları (her biri için test/fixtures/data_bad_<kod>/ bulunur).
const ERROR_CODES: PackedStringArray = [
	"bad_json",
	"missing_file",
	"not_object",
	"missing_field",
	"bad_type",
	"out_of_range",
	"dup_id",
	"id_filename",
	"bad_kind",
	"levels_length",
	"levels_keys",
	"levels_monotonic",
	"passive_key",
	"behavior_missing",
	"behavior_base",
	"requires_unexpected",
	"requires_ref",
	"requires_kind",
	"requires_level",
	"dup_evolution",
	"bad_ai",
	"asset_missing",
	"unknown_enemy",
	"wave_range",
	"wave_kind",
	"wave_boss_time",
	"wave_enemy_ai",
	"wave_unknown_key",
	"no_character",
	"rhythm_count",
	"unknown_key",
	"pickup_weight",
	"score_tiers",
	# v2.0
	"unknown_stat",
	"ach_count",
	"tier_missing",
	"scope_mismatch",
	"atlas_cells",
	"unknown_ref",
]

var root_dir: String = ""
var asset_root: String = "res://assets/"
var load_errors: PackedStringArray = PackedStringArray()
var character_ids: Array[StringName] = []
var skill_ids: Array[StringName] = []
var enemy_ids: Array[StringName] = []
var waves: Dictionary = {}
## data/ruins.json (isteğe bağlı): harabe tanımları [{id, sprite, display_scale, foot, footprint{w,h}, weight, solid}].
var ruins: Array[Dictionary] = []
var pickup_cfg: Dictionary = {}  # v1.1 pickups.json ham sözlüğü {spawn, kinds}; dosya yoksa {}
var pickup_ids: Array[StringName] = []  # `kinds` DİZİ sırasında (PickupPool.kind_idx bu sıra)
var score_table: ScoreTable = ScoreTable.new()  # v1.1 score.json; dosya yoksa varsayılan tablo
var achievement_ids: Array[StringName] = []  # v2.0 achievements.json, dosya sırası
var achievements: Array[AchievementDef] = []  # achievement_ids ile aynı sırada

var _characters: Dictionary = {}  # StringName -> CharacterDef
var _skills: Dictionary = {}  # StringName -> SkillDef
var _enemies: Dictionary = {}  # StringName -> EnemyDef
# Ham kayıtlar: {"file": String, "data": Variant}; dizi sırası = dosya adı sırası
var _raw_characters: Array[Dictionary] = []
var _raw_skills: Array[Dictionary] = []
var _raw_enemies: Array[Dictionary] = []
var _raw_waves: Variant = null
var _waves_failed: bool = false
var _raw_ruins: Variant = null
var _ruins_failed: bool = false
var _pickups: Dictionary = {}  # StringName -> PickupDef
var _v11: Dictionary = {}  # DataV11 ham durumu (pickups/score + yükleme başarısızlık bayrakları)
var _v2: Dictionary = {}  # DataV2 ham durumu (achievements.json)
var _achievements: Dictionary = {}  # StringName -> AchievementDef

static var _default: GameData = null


## Önbellekli varsayılan veri (res://data).
static func load_default() -> GameData:
	if _default == null:
		_default = load_dir("res://data")
	return _default


static func clear_default_cache() -> void:
	_default = null


## Bir veri kökünü yükler. Okuma hataları load_errors'a ve validate() çıktısına girer.
static func load_dir(dir: String) -> GameData:
	var g := GameData.new()
	g.root_dir = dir
	g._load_all()
	return g


## Vitrin sırası: `order` artan, eşitlikte dosya adı sırası (kararlı). `order` yoksa sona düşer (F-030).
func _sort_character_ids() -> void:
	var idx := {}
	for i in character_ids.size():
		idx[character_ids[i]] = i
	character_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			var oa: int = (_characters[a] as CharacterDef).order
			var ob: int = (_characters[b] as CharacterDef).order
			return idx[a] < idx[b] if oa == ob else oa < ob
	)


func get_character(id: StringName) -> CharacterDef:
	return _characters.get(id)


func get_skill(id: StringName) -> SkillDef:
	return _skills.get(id)


func get_enemy(id: StringName) -> EnemyDef:
	return _enemies.get(id)


func get_pickup(id: StringName) -> PickupDef:
	return _pickups.get(id)


## null olabilir (bilinmeyen kimlik).
func get_achievement(id: StringName) -> AchievementDef:
	return _achievements.get(id)


func skills_of_kind(kind: StringName) -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for id in skill_ids:
		var s: SkillDef = _skills[id]
		if s.kind == kind:
			out.append(s)
	return out


## Şemayı doğrular. registry: id -> SkillBehavior'dan türeyen GDScript (boşsa SkillRegistry.BEHAVIORS).
## complete: içerik tamamlandı modu (slice 2): "ritim" etiketli aktif sayısı >= 2.
func validate(registry: Dictionary = {}, complete: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	out.append_array(load_errors)
	var reg: Dictionary = registry if not registry.is_empty() else _default_registry()
	_validate_skills(out, reg)
	_validate_enemies(out)
	_validate_characters(out)
	WavesValidator.run(self, out)
	DataV11.validate(self, out)
	DataV2.validate(self, out, complete)
	DataV202Pool.validate(self, out)
	if not _ruins_failed and _raw_ruins != null:
		RuinsValidator.run(self, _raw_ruins, out)
	if complete:
		_validate_complete(out)
	return out


# --- yükleme -------------------------------------------------------------------------------


func _load_all() -> void:
	_raw_characters = _read_dir("characters")
	_raw_skills = _read_dir("skills")
	_raw_enemies = _read_dir("enemies")
	var wp := root_dir.path_join("waves.json")
	if FileAccess.file_exists(wp):
		var r := _read_json(wp, "waves.json")
		_raw_waves = r.get("data")
		_waves_failed = r.get("failed", false)
	else:
		load_errors.append("[missing_file] waves.json: dosya yok")
	if _raw_waves is Dictionary:
		waves = _raw_waves
	var rp := root_dir.path_join("ruins.json")
	if FileAccess.file_exists(rp):
		var rr := _read_json(rp, "ruins.json")
		_raw_ruins = rr.get("data")
		_ruins_failed = rr.get("failed", false)
		if _raw_ruins is Array:
			for x in _raw_ruins:
				if x is Dictionary:
					ruins.append(x)
	DataV11.load_tables(self)
	DataV2.load_achievements(self, root_dir)
	for e in _raw_characters:
		var d: Variant = e["data"]
		if d is Dictionary and _valid_id(d.get("id")) and not _characters.has(StringName(d["id"])):
			var c := CharacterDef.from_dict(d)
			_characters[c.id] = c
			character_ids.append(c.id)
	_sort_character_ids()
	for e in _raw_skills:
		var d: Variant = e["data"]
		if d is Dictionary and _valid_id(d.get("id")) and not _skills.has(StringName(d["id"])):
			var s := SkillDef.from_dict(d)
			_skills[s.id] = s
			skill_ids.append(s.id)
	for e in _raw_enemies:
		var d: Variant = e["data"]
		if d is Dictionary and _valid_id(d.get("id")) and not _enemies.has(StringName(d["id"])):
			var en := EnemyDef.from_dict(d)
			_enemies[en.id] = en
			enemy_ids.append(en.id)


func _read_dir(sub: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var dir := root_dir.path_join(sub)
	if not DirAccess.dir_exists_absolute(dir):
		return res  # eksik dizin = boş (temiz checkout'ta boş dizinler git'te yoktur)
	var files := DirAccess.get_files_at(dir)
	var names: Array[String] = []
	for f in files:
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f in names:
		var rel := sub + "/" + f
		var r := _read_json(dir.path_join(f), rel)
		res.append({"file": rel, "data": r.get("data"), "failed": r.get("failed", false)})
	return res


func _read_json(path: String, rel: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		load_errors.append(
			"[bad_json] %s: JSON okunamadı (satır %d)" % [rel, json.get_error_line()]
		)
		return {"data": null}
	return {"data": json.data}


static func _valid_id(v: Variant) -> bool:
	return v is String and not (v as String).is_empty()


func _default_registry() -> Dictionary:
	# Statik başvuru döngü yaratacağından dinamik yüklenir (GameData <-> SkillBehavior <-> GameSim).
	var script: GDScript = load("res://scripts/sim/skills/skill_registry.gd")
	return script.get("BEHAVIORS")


# --- doğrulama yardımcıları ----------------------------------------------------------------


## Bilinmeyen anahtarları bildirir.
static func _unknown_keys(
	out: PackedStringArray, ctx: String, d: Dictionary, known: PackedStringArray
) -> void:
	for k in d.keys():
		if not known.has(str(k)):
			_err(out, "unknown_key", ctx, "bilinmeyen anahtar '%s'" % k)


static func _err(out: PackedStringArray, code: String, ctx: String, msg: String) -> void:
	out.append("[%s] %s: %s" % [code, ctx, msg])


static func _is_num(v: Variant) -> bool:
	return (v is int) or (v is float and is_finite(v))


static func _is_int(v: Variant) -> bool:
	return (v is int) or (v is float and is_finite(v) and v == floorf(v))


## Zorunlu sayısal alan: tür + aralık. Geçerliyse true.
static func _num(
	out: PackedStringArray,
	ctx: String,
	d: Dictionary,
	key: String,
	lo: float,
	hi: float,
	int_only: bool = false
) -> bool:
	if not d.has(key):
		_err(out, "missing_field", ctx, "'%s' yok" % key)
		return false
	var v: Variant = d[key]
	if not _is_num(v) or (int_only and not _is_int(v)):
		_err(out, "bad_type", ctx, "'%s' %s olmalı" % [key, "tamsayı" if int_only else "sayı"])
		return false
	if float(v) < lo or float(v) > hi:
		_err(out, "out_of_range", ctx, "'%s' = %s, aralık [%s, %s]" % [key, v, lo, hi])
		return false
	return true


static func _str(out: PackedStringArray, ctx: String, d: Dictionary, key: String) -> bool:
	if not d.has(key):
		_err(out, "missing_field", ctx, "'%s' yok" % key)
		return false
	if not (d[key] is String) or (d[key] as String).strip_edges().is_empty():
		_err(out, "bad_type", ctx, "'%s' boş olmayan metin olmalı" % key)
		return false
	return true


## [a, b] sayı çifti; geçerliyse true.
static func _pair(
	out: PackedStringArray, ctx: String, d: Dictionary, key: String, lo: float, hi: float
) -> bool:
	if not d.has(key):
		_err(out, "missing_field", ctx, "'%s' yok" % key)
		return false
	var v: Variant = d[key]
	if not (v is Array) or (v as Array).size() != 2:
		_err(out, "bad_type", ctx, "'%s' iki sayılı dizi olmalı" % key)
		return false
	for x in v:
		if not _is_num(x):
			_err(out, "bad_type", ctx, "'%s' sayılardan oluşmalı" % key)
			return false
		if float(x) < lo or float(x) > hi:
			_err(out, "out_of_range", ctx, "'%s' değeri %s, aralık [%s, %s]" % [key, x, lo, hi])
			return false
	return true


func _asset_ok(path: String) -> bool:
	if path.begins_with(PLACEHOLDER_PREFIX):
		return path.length() > PLACEHOLDER_PREFIX.length()
	if path.begins_with("res://"):
		return ResourceLoader.exists(path) or FileAccess.file_exists(path)
	for ext in ASSET_EXTENSIONS:
		var p := asset_root.path_join(path) + ext
		if FileAccess.file_exists(p):
			return true
	return false


func _check_asset(out: PackedStringArray, ctx: String, d: Dictionary, key: String) -> void:
	if not _str(out, ctx, d, key):
		return
	if not _asset_ok(d[key]):
		_err(
			out,
			"asset_missing",
			ctx,
			"'%s' = '%s' bulunamadı (placeholder: öneki kullan)" % [key, d[key]]
		)


## Kayıt listesini tarar; sözlük olanların id/dosya adı kurallarını denetler. Geçerli kayıtları döndürür.
func _screen(out: PackedStringArray, entries: Array[Dictionary]) -> Array[Dictionary]:
	var seen := {}
	var ok: Array[Dictionary] = []
	for e in entries:
		var file: String = e["file"]
		var d: Variant = e["data"]
		if e.get("failed", false):
			continue  # bad_json zaten load_errors'ta
		if not (d is Dictionary):
			_err(out, "not_object", file, "kök nesne olmalı")
			continue
		if not _str(out, file, d, "id"):
			continue
		var id: String = d["id"]
		if file.get_file().get_basename() != id:
			_err(out, "id_filename", file, "id '%s' dosya adıyla eşleşmeli" % id)
		if seen.has(id):
			_err(out, "dup_id", file, "id '%s' tekrarlanıyor (%s)" % [id, seen[id]])
			continue
		seen[id] = file
		ok.append(e)
	return ok


# --- beceriler -----------------------------------------------------------------------------


func _validate_skills(out: PackedStringArray, reg: Dictionary) -> void:
	var entries := _screen(out, _raw_skills)
	for e in entries:
		_validate_skill(out, e["file"], e["data"], reg)
	# çapraz referanslar: yalnız kendi alanları geçerli evrimler
	var evo_targets := {}
	for e in entries:
		var d: Dictionary = e["data"]
		if d.get("kind") == "evolution" and d.get("requires") is Dictionary:
			_validate_requires(out, e["file"], d)
			var act: Variant = (d["requires"] as Dictionary).get("active")
			if act is String:
				if evo_targets.has(act):
					_err(
						out,
						"dup_evolution",
						e["file"],
						"'%s' için ikinci evrim (%s)" % [act, evo_targets[act]]
					)
				else:
					evo_targets[act] = e["file"]


func _validate_skill(out: PackedStringArray, file: String, d: Dictionary, reg: Dictionary) -> void:
	_unknown_keys(out, file, d, SKILL_KEYS + DataV202Pool.KEYS)
	_str(out, file, d, "name")
	_check_asset(out, file, d, "icon")
	if not d.has("kind") or not (d["kind"] is String) or not SKILL_KINDS.has(d["kind"]):
		_err(out, "bad_kind", file, "'kind' active|passive|evolution olmalı")
		return
	var kind: String = d["kind"]
	var max_ok := _num(out, file, d, "max_level", 1, MAX_LEVEL_LIMIT, true)
	if kind == "evolution" and max_ok and int(d["max_level"]) != 1:
		_err(out, "out_of_range", file, "evrim 'max_level' 1 olmalı")
	_validate_tags(out, file, d)
	_validate_behavior(out, file, d, kind, reg)
	if kind != "evolution" and d.has("requires"):
		_err(out, "requires_unexpected", file, "'requires' yalnız evrimde olur")
	if kind == "evolution":
		if not d.has("requires"):
			_err(out, "missing_field", file, "evrimde 'requires' zorunlu")
		elif not (d["requires"] is Dictionary):
			_err(out, "bad_type", file, "'requires' nesne olmalı")
		else:
			_unknown_keys(out, file + " requires", d["requires"], REQUIRES_KEYS)
	var levels_ok := _validate_levels_shape(out, file, d, max_ok)
	if levels_ok:
		if kind == "passive":
			_validate_passive_levels(out, file, d["levels"])
		else:
			_validate_active_levels(out, file, d["levels"])
	_validate_desc(out, file, d, max_ok)


func _validate_tags(out: PackedStringArray, file: String, d: Dictionary) -> void:
	if not d.has("tags"):
		_err(out, "missing_field", file, "'tags' yok")
		return
	if not (d["tags"] is Array):
		_err(out, "bad_type", file, "'tags' dizi olmalı")
		return
	for t in d["tags"]:
		if not (t is String) or (t as String).is_empty():
			_err(out, "bad_type", file, "'tags' elemanları metin olmalı")
			return


func _validate_behavior(
	out: PackedStringArray, file: String, d: Dictionary, kind: String, reg: Dictionary
) -> void:
	var has_b: bool = d.has("behavior") and d["behavior"] is String and d["behavior"] != ""
	if kind == "passive":
		if has_b:
			_err(out, "bad_type", file, "pasifte 'behavior' olmaz")
		return
	if not has_b:
		_err(out, "missing_field", file, "'behavior' yok")
		return
	var key := StringName(d["behavior"])
	if not reg.has(key):
		_err(out, "behavior_missing", file, "'%s' SkillRegistry'de yok" % key)
		return
	if not _derives_from_behavior(reg[key]):
		_err(out, "behavior_base", file, "'%s' SkillBehavior'dan türemiyor" % key)


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
		_err(out, "missing_field", file, "'levels' yok")
		return false
	var lv: Variant = d["levels"]
	if not (lv is Array) or (lv as Array).is_empty():
		_err(out, "bad_type", file, "'levels' dolu dizi olmalı")
		return false
	if max_ok and (lv as Array).size() != int(d["max_level"]):
		_err(
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
			_err(out, "bad_type", file, "levels[%d] dolu nesne olmalı" % i)
			return false
		var keys: Array = (row as Dictionary).keys()
		keys.sort()
		for k in keys:
			if not _is_num(row[k]):
				_err(out, "bad_type", file, "levels[%d].%s sayı olmalı" % [i, k])
				return false
		if i == 0:
			first_keys = keys
		elif keys != first_keys:
			_err(
				out, "levels_keys", file, "levels[%d] anahtar kümesi levels[0] ile aynı olmalı" % i
			)
			return false
	return true


func _validate_passive_levels(out: PackedStringArray, file: String, levels: Array) -> void:
	for i in levels.size():
		for k in (levels[i] as Dictionary).keys():
			if not PASSIVE_KEYS.has(k):
				_err(out, "passive_key", file, "bilinmeyen pasif anahtarı '%s'" % k)
				return
	for k in (levels[0] as Dictionary).keys():
		var b: Array = PASSIVE_BOUNDS[k]
		var prev := 0.0
		for i in levels.size():
			var v := float(levels[i][k])
			if v < float(b[0]) or v > float(b[1]):
				_err(out, "out_of_range", file, "levels[%d].%s = %s, aralık %s" % [i, k, v, b])
				return
			if PASSIVE_ADDITIVE_KEYS.has(k) and k == "mag_add" and not _is_int(v):
				_err(out, "bad_type", file, "levels[%d].mag_add tamsayı olmalı" % i)
				return
			# toplam değerler sıfırdan uzaklaşmalı (|x| azalmaz)
			if absf(v) < absf(prev):
				_err(
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
			if LEVEL_KEY_BOUNDS.has(k):
				var b: Array = LEVEL_KEY_BOUNDS[k]
				var v := float(levels[i][k])
				if v < float(b[0]) or v > float(b[1]):
					_err(out, "out_of_range", file, "levels[%d].%s = %s, aralık %s" % [i, k, v, b])
					return
	for k in (levels[0] as Dictionary).keys():
		var dec: bool = LEVEL_KEYS_NONDECREASING.has(k)
		var inc: bool = LEVEL_KEYS_NONINCREASING.has(k)
		if not dec and not inc:
			continue
		for i in range(1, levels.size()):
			var a := float(levels[i - 1][k])
			var b := float(levels[i][k])
			if (dec and b < a) or (inc and b > a):
				_err(out, "levels_monotonic", file, "'%s' levels[%d] yönü bozuyor" % [k, i])
				break


func _validate_desc(out: PackedStringArray, file: String, d: Dictionary, max_ok: bool) -> void:
	if not d.has("desc"):
		_err(out, "missing_field", file, "'desc' yok")
		return
	var ds: Variant = d["desc"]
	if not (ds is Array):
		_err(out, "bad_type", file, "'desc' dizi olmalı")
		return
	if max_ok and (ds as Array).size() != int(d["max_level"]):
		_err(
			out,
			"levels_length",
			file,
			"desc %d eleman, max_level %d" % [(ds as Array).size(), int(d["max_level"])]
		)
		return
	for x in ds:
		if not (x is String) or (x as String).strip_edges().is_empty():
			_err(out, "bad_type", file, "'desc' elemanları boş olmayan metin olmalı")
			return


## Evrim 'requires' şekli ve referansları (tüm beceri kayıtları yüklendikten sonra).
func _validate_requires(out: PackedStringArray, file: String, d: Dictionary) -> void:
	var rq: Dictionary = d["requires"]
	var shape_ok := _str(out, file + " requires", rq, "active")
	shape_ok = _str(out, file + " requires", rq, "passive") and shape_ok
	shape_ok = (
		_num(out, file + " requires", rq, "active_level", 1, MAX_LEVEL_LIMIT, true) and shape_ok
	)
	shape_ok = (
		_num(out, file + " requires", rq, "passive_min_level", 1, MAX_LEVEL_LIMIT, true)
		and shape_ok
	)
	if not shape_ok:
		return
	var act: SkillDef = _skills.get(StringName(rq["active"]))
	var pas: SkillDef = _skills.get(StringName(rq["passive"]))
	if act == null:
		_err(out, "requires_ref", file, "requires.active '%s' yok" % rq["active"])
	elif act.kind != SkillDef.KIND_ACTIVE:
		_err(out, "requires_kind", file, "requires.active '%s' kind:active değil" % rq["active"])
	elif int(rq["active_level"]) != act.max_level:
		_err(
			out,
			"requires_level",
			file,
			"requires.active_level, '%s' max_level (%d) olmalı" % [act.id, act.max_level]
		)
	if pas == null:
		_err(out, "requires_ref", file, "requires.passive '%s' yok" % rq["passive"])
	elif pas.kind != SkillDef.KIND_PASSIVE:
		_err(out, "requires_kind", file, "requires.passive '%s' kind:passive değil" % rq["passive"])
	elif int(rq["passive_min_level"]) > pas.max_level:
		_err(
			out,
			"requires_level",
			file,
			"requires.passive_min_level, '%s' max_level (%d) üstünde" % [pas.id, pas.max_level]
		)


# --- düşmanlar -----------------------------------------------------------------------------


func _validate_enemies(out: PackedStringArray) -> void:
	for e in _screen(out, _raw_enemies):
		_validate_enemy(out, e["file"], e["data"])


func _validate_enemy(out: PackedStringArray, file: String, d: Dictionary) -> void:
	_unknown_keys(out, file, d, ENEMY_KEYS)
	_str(out, file, d, "name")
	_num(out, file, d, "hp", 1, 1000000)
	_num(out, file, d, "speed", 0, 2000)
	_num(out, file, d, "dmg", 0, 100000)
	_num(out, file, d, "radius", 1, 500)
	_num(out, file, d, "armor", 0, 1000)
	_num(out, file, d, "xp", 0, 100000, true)
	_num(out, file, d, "display_height", 1, 2000)
	if not d.has("ai") or not (d["ai"] is String) or not AI_KINDS.has(d["ai"]):
		_err(out, "bad_ai", file, "'ai' ground|air|ghost|elite|lord olmalı")
	if not d.has("scales_with_time"):
		_err(out, "missing_field", file, "'scales_with_time' yok")
	elif not (d["scales_with_time"] is bool):
		_err(out, "bad_type", file, "'scales_with_time' bool olmalı")
	_check_asset(out, file, d, "sprite")
	if not d.has("tint"):
		_err(out, "missing_field", file, "'tint' yok")
	elif not (d["tint"] is String) or not Color.html_is_valid(d["tint"]):
		_err(out, "bad_type", file, "'tint' #rrggbb metni olmalı")
	if d.has("charge"):
		if d["charge"] is Dictionary:
			_unknown_keys(out, file + " charge", d["charge"], CHARGE_KEYS)
			_num(out, file + " charge", d["charge"], "every", 0.1, 600)
			_num(out, file + " charge", d["charge"], "duration", 0.1, 60)
			_num(out, file + " charge", d["charge"], "speed", 1, 5000)
		else:
			_err(out, "bad_type", file, "'charge' nesne olmalı")
	DataV11.validate_enemy(self, out, file, d)
	if d.has("summon"):
		if d["summon"] is Dictionary:
			var sm: Dictionary = d["summon"]
			_unknown_keys(out, file + " summon", sm, SUMMON_KEYS)
			_num(out, file + " summon", sm, "every", 0.1, 600)
			_num(out, file + " summon", sm, "count", 1, 50, true)
			if _str(out, file + " summon", sm, "type") and not _raw_enemy_exists(sm["type"]):
				_err(out, "unknown_enemy", file, "summon.type '%s' yok" % sm["type"])
			if sm.has("enrage_hp_frac"):
				_num(out, file + " summon", sm, "enrage_hp_frac", 0.01, 0.99)
				_num(out, file + " summon", sm, "enrage_speed_mult", 1, 5)
				_num(out, file + " summon", sm, "enrage_every", 0.1, 600)
		else:
			_err(out, "bad_type", file, "'summon' nesne olmalı")


func _raw_enemy_exists(id: Variant) -> bool:
	return id is String and _enemies.has(StringName(id))


# --- karakterler ---------------------------------------------------------------------------


func _validate_characters(out: PackedStringArray) -> void:
	var entries := _screen(out, _raw_characters)
	if _characters.is_empty():
		_err(out, "no_character", "characters", "en az bir karakter gerekli")
	for e in entries:
		_validate_character(out, e["file"], e["data"])


func _validate_character(out: PackedStringArray, file: String, d: Dictionary) -> void:
	_unknown_keys(out, file, d, CHARACTER_KEYS)
	DataV2.validate_character(self, out, file, d)
	_str(out, file, d, "name")
	_num(out, file, d, "max_hp", 1, 10000)
	_num(out, file, d, "move_speed", 50, 1000)
	_num(out, file, d, "mag_cap", 1, 20, true)
	_num(out, file, d, "reload_time", 0.35, 5)
	_num(out, file, d, "pickup_radius", 0, 1000)
	_num(out, file, d, "collision_radius", 1, 200)
	_num(out, file, d, "range", 100, 2000)
	if _str(out, file, d, "starting_skill"):
		var sk: SkillDef = _skills.get(StringName(d["starting_skill"]))
		if sk == null:
			_err(out, "requires_ref", file, "starting_skill '%s' yok" % d["starting_skill"])
		elif sk.kind != SkillDef.KIND_ACTIVE:
			_err(
				out,
				"requires_kind",
				file,
				"starting_skill '%s' kind:active değil" % d["starting_skill"]
			)
	if not d.has("rig"):
		_err(out, "missing_field", file, "'rig' yok")
	elif not (d["rig"] is Dictionary):
		_err(out, "bad_type", file, "'rig' nesne olmalı")
	else:
		DataV202Rig.validate(self, out, file + " rig", d["rig"])


func _validate_rig(out: PackedStringArray, ctx: String, r: Dictionary) -> void:
	_unknown_keys(out, ctx, r, RIG_KEYS)
	_check_asset(out, ctx, r, "body")
	_check_asset(out, ctx, r, "arm")
	_num(out, ctx, r, "display_height", 1, 1000)
	_num(out, ctx, r, "arm_scale", 0.01, 5)
	if not r.has("native_facing"):
		_err(out, "missing_field", ctx, "'native_facing' yok")
	elif not (r["native_facing"] is String) or not ["left", "right"].has(r["native_facing"]):
		_err(out, "bad_type", ctx, "'native_facing' left|right olmalı")
	_pair(out, ctx, r, "arm_pivot", 0, 1)
	_pair(out, ctx, r, "muzzle", 0, 1)
	if not r.has("shoulders"):
		_err(out, "missing_field", ctx, "'shoulders' yok")
	elif not (r["shoulders"] is Array) or (r["shoulders"] as Array).size() != 2:
		_err(out, "bad_type", ctx, "'shoulders' iki [x,y] çifti olmalı")
	else:
		for i in 2:
			_pair(out, ctx, {"shoulders": r["shoulders"][i]}, "shoulders", 0, 1)
	DataV11.validate_walk(self, out, ctx, r)
	if not r.has("sway"):
		_err(out, "missing_field", ctx, "'sway' yok")
	elif not (r["sway"] is Dictionary):
		_err(out, "bad_type", ctx, "'sway' nesne olmalı")
	else:
		var s: Dictionary = r["sway"]
		_unknown_keys(out, ctx + " sway", s, SWAY_KEYS)
		_num(out, ctx + " sway", s, "hem_from_y", 0, 1)
		_num(out, ctx + " sway", s, "amp", 0, 100)
		_num(out, ctx + " sway", s, "lag", 0, 1)
		if not s.has("scarf_rect"):
			_err(out, "missing_field", ctx + " sway", "'scarf_rect' yok")
		else:
			var sr: Variant = s["scarf_rect"]
			var good: bool = sr is Array and (sr as Array).size() == 4
			if good:
				for x in sr:
					good = good and _is_num(x) and float(x) >= 0.0 and float(x) <= 1.0
			if not good:
				_err(out, "bad_type", ctx + " sway", "'scarf_rect' [x0,y0,x1,y1] (0..1) olmalı")
			elif float(sr[0]) >= float(sr[2]) or float(sr[1]) >= float(sr[3]):
				_err(out, "out_of_range", ctx + " sway", "'scarf_rect' x0<x1 ve y0<y1 olmalı")


# --- içerik tamamlandı ---------------------------------------------------------------------


func _validate_complete(out: PackedStringArray) -> void:
	DataV11.validate_complete(self, out)
	var n := 0
	for s in skills_of_kind(SkillDef.KIND_ACTIVE):
		if s.tags.has(RHYTHM_TAG):
			n += 1
	if n < MIN_RHYTHM_ACTIVES:
		_err(
			out,
			"rhythm_count",
			"skills",
			"'rhythm' etiketli aktif %d < %d" % [n, MIN_RHYTHM_ACTIVES]
		)
