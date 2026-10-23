class_name SkillDef
extends RefCounted
## Beceri tanımı (data/skills/<id>.json). Şema: docs/data-schema.md

const KIND_ACTIVE := &"active"
const KIND_PASSIVE := &"passive"
const KIND_EVOLUTION := &"evolution"

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
	return s


## Seviye (1..max_level) verisi; aralık dışıysa boş sözlük.
func level_data(level: int) -> Dictionary:
	if level < 1 or level > levels.size():
		return {}
	return levels[level - 1]
