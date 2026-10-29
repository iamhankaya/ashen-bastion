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
	"portrait_video",
	"unlock",
	"placeholder",
	"display_upper",
	"order",
	"sfx",
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
const _VALIDATORS_DIR := "res://scripts/sim/validators/"
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
	# v2.0.3
	"steps_invalid",
	"legacy_unknown",
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
## Son validate() çağrısında toplanan rig şerit boyut denetimleri: {ctx, path, w, h}. Doku okumayı AssetCheck (validate katmanı) yapar.
var strip_probes: Array[Dictionary] = []
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


## `extends DataValidator` eklentilerini bulur (yalnız `dir` altındaki doğrudan alt sınıflar), `(order, id, yol)`
## sırasıyla döndürür. Sıra sınıf listesi sırasından bağımsızdır; hata sırası deterministiktir.
static func _discover_validators(dir: String = _VALIDATORS_DIR) -> Array[DataValidator]:
	var rows: Array = []
	for c in ProjectSettings.get_global_class_list():
		var path := str(c["path"])
		if str(c["base"]) == "DataValidator" and path.begins_with(dir):
			var scr := load(path) as GDScript
			if scr == null:
				push_error("DataValidator yüklenemedi: %s" % path)
				continue
			var v: DataValidator = scr.new()
			rows.append([v.validator_order(), str(v.validator_id()), path, v])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a.slice(0, 3) < b.slice(0, 3))
	var found: Array[DataValidator] = []
	for r in rows:
		found.append(r[3])
	return found


## Bir veri kökünü yükler. Okuma hataları load_errors'a ve validate() çıktısına girer.
static func load_dir(dir: String) -> GameData:
	var g := GameData.new()
	g.root_dir = dir
	CatalogLoader.load_all(g)
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
	strip_probes.clear()
	out.append_array(load_errors)
	var reg: Dictionary = registry if not registry.is_empty() else _default_registry()
	var sv := SchemaValidators.new(self)
	sv.skills(out, reg)
	sv.enemies(out)
	sv.characters(out)
	WavesValidator.run(self, out)
	DataV11.validate(self, out)
	DataV2.validate(self, out, complete)
	DataV202Pool.validate(self, out)
	if not _ruins_failed and _raw_ruins != null:
		RuinsValidator.run(self, _raw_ruins, out)
	if complete:
		CrossRefValidator.new(self).complete(out)
	for v in _discover_validators():
		v.run(self, out, complete)
	return out


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


func _raw_enemy_exists(id: Variant) -> bool:
	return id is String and _enemies.has(StringName(id))
