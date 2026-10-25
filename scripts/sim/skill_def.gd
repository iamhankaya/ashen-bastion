class_name SkillDef
extends RefCounted
## Beceri tanımı (data/skills/<id>.json). Şema: docs/data-schema.md

const KIND_ACTIVE := &"active"
const KIND_PASSIVE := &"passive"
const KIND_EVOLUTION := &"evolution"
## Havuz: ortak (her karakter) ya da bir karakter kimliği (yalnız o karakter).
const POOL_COMMON := &"common"

var id: StringName = &""
var kind: StringName = &""
var display_name: String = ""
var icon: String = ""
var max_level: int = 1
var tags: PackedStringArray = PackedStringArray()
var behavior: StringName = &""
var levels: Array[Dictionary] = []
var desc: PackedStringArray = PackedStringArray()
var requires: Dictionary = {}  # yalnız evrim: active, active_level, passive, passive_min_level
var sfx: StringName = &""  # yalnız evrim, isteğe bağlı: evrim sesi kimliği (boş: AudioDirector varsayılanı)
## v2.0.2: `pool` "common" (varsayılan) ya da karakter kimliği; `variants` yalnız ortak becerilerde karakter başına
## {name, icon, desc} (hepsi isteğe bağlı). Şema: docs/data-schema.md
var pool: StringName = POOL_COMMON
## v2.0.2 A4: aktif/evrim becerinin ateşlenme/doğuş sesi kimliği (isteğe bağlı; `evolution sfx` evrim anı sesidir).
var cast_sfx: StringName = &""
var variants: Dictionary = {}


static func from_dict(d: Dictionary) -> SkillDef:
	var s := SkillDef.new()
	s.id = StringName(str(d.get("id", "")))
	s.kind = StringName(str(d.get("kind", "")))
	s.display_name = str(d.get("name", ""))
	s.icon = str(d.get("icon", ""))
	s.max_level = int(d.get("max_level", 1))
	var t: Variant = d.get("tags", [])
	if t is Array:
		for x in t:
			s.tags.append(str(x))
	s.behavior = StringName(str(d.get("behavior", "")))
	var lv: Variant = d.get("levels", [])
	if lv is Array:
		for x in lv:
			if x is Dictionary:
				s.levels.append(x)
	var ds: Variant = d.get("desc", [])
	if ds is Array:
		for x in ds:
			s.desc.append(str(x))
	var rq: Variant = d.get("requires", {})
	s.requires = rq if rq is Dictionary else {}
	s.sfx = StringName(str(d.get("sfx", "")))
	s.pool = StringName(str(d.get("pool", "common")))
	s.cast_sfx = StringName(str(d.get("cast_sfx", "")))
	var vr: Variant = d.get("variants", {})
	s.variants = vr if vr is Dictionary else {}
	return s


## Seviye bloklarında metin değer alan anahtarlar (v2.0.2 `target_mode: "cluster"`); diğerleri sayıdır.
static func is_text_level_key(key: String, value: Variant) -> bool:
	return key == "target_mode" and value is String


## Seviye (1..max_level) verisi; aralık dışıysa boş sözlük.
func level_data(level: int) -> Dictionary:
	if level < 1 or level > levels.size():
		return {}
	return levels[level - 1]


## Karakter bu beceriyi görebilir mi. Boş kimlik = filtresiz (eski davranış); ortak havuz herkese açık.
func available_to(character_id: StringName) -> bool:
	return character_id == &"" or pool == POOL_COMMON or pool == character_id


## Karaktere göre görünen ad (variant adı yoksa display_name).
func name_for(character_id: StringName) -> String:
	var v := _variant(character_id)
	var n: Variant = v.get("name", "")
	return n if n is String and n != "" else display_name


func icon_for(character_id: StringName) -> String:
	var v := _variant(character_id)
	var i: Variant = v.get("icon", "")
	return i if i is String and i != "" else icon


## `level` 1..max_level; aralık dışı ya da açıklama yoksa "". Variant `desc` verilmişse o kullanılır.
func desc_for(character_id: StringName, level: int) -> String:
	if level < 1 or level > max_level:
		return ""
	var v := _variant(character_id)
	var d: Variant = v.get("desc", null)
	if d is Array and level - 1 < (d as Array).size():
		return str(d[level - 1])
	return desc[level - 1] if level - 1 < desc.size() else ""


func _variant(character_id: StringName) -> Dictionary:
	var v: Variant = variants.get(String(character_id), null)
	return v if v is Dictionary else {}
