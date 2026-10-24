class_name CharacterDef
extends RefCounted
## Karakter tanımı (data/characters/<id>.json). Şema: docs/data-schema.md

var id: StringName = &""
var display_name: String = ""
var max_hp: float = 100.0
var move_speed: float = 300.0
var mag_cap: int = 6
var reload_time: float = 1.0
var pickup_radius: float = 110.0
var collision_radius: float = 22.0
var starting_skill: StringName = &""
var attack_range: float = 700.0  # JSON anahtarı "range"
var rig: Dictionary = {}
## rig.walk (kareli yürüme): frames 0 ya da yok = prosedürel yedek. Şema: docs/data-schema.md
var walk: Dictionary = {"frames": 0}
## v2.0 (hepsi isteğe bağlı): vitrin metni, portre yolu, kilit başarımı (yok = açık), yer tutucu görsel işareti.
var blurb: String = ""
var portrait: String = ""
var unlock_achievement: StringName = &""
var placeholder: bool = false
## v2.0 düzeltme payı: `display_upper` büyük harfli ad (özel adlarda upper_tr noktalı İ üretir, F-029); boşsa upper_tr.
## `order` vitrin sırası (küçük önce, F-030); yoksa ORDER_DEFAULT (dosya adı sırasıyla sona).
const ORDER_DEFAULT := 1000
var display_upper: String = ""
var order: int = ORDER_DEFAULT


static func from_dict(d: Dictionary) -> CharacterDef:
	var c := CharacterDef.new()
	c.id = StringName(str(d.get("id", "")))
	c.display_name = str(d.get("name", ""))
	c.max_hp = float(d.get("max_hp", 100.0))
	c.move_speed = float(d.get("move_speed", 300.0))
	c.mag_cap = int(d.get("mag_cap", 6))
	c.reload_time = float(d.get("reload_time", 1.0))
	c.pickup_radius = float(d.get("pickup_radius", 110.0))
	c.collision_radius = float(d.get("collision_radius", 22.0))
	c.starting_skill = StringName(str(d.get("starting_skill", "")))
	c.attack_range = float(d.get("range", 700.0))
	var r: Variant = d.get("rig", {})
	c.rig = r if r is Dictionary else {}
	var w: Variant = c.rig.get("walk", null)
	if w is Dictionary:
		c.walk = w
	c.blurb = _s(d.get("blurb", ""))
	c.portrait = _s(d.get("portrait", ""))
	var u: Variant = d.get("unlock", null)
	if u is Dictionary:
		c.unlock_achievement = StringName(_s(u.get("achievement", "")))
	var ph: Variant = d.get("placeholder", false)
	c.placeholder = ph is bool and ph
	c.display_upper = _s(d.get("display_upper", ""))
	var o: Variant = d.get("order", ORDER_DEFAULT)
	c.order = int(o) if o is int or o is float else ORDER_DEFAULT
	return c


static func _s(v: Variant) -> String:
	return v if v is String else ""
