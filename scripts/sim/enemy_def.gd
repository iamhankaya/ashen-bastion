class_name EnemyDef
extends RefCounted
## Düşman tanımı (data/enemies/<id>.json). Şema: docs/data-schema.md

var id: StringName = &""
var display_name: String = ""
var hp: float = 1.0
var speed: float = 0.0
var dmg: float = 0.0  # temas hasarı (taban)
var radius: float = 20.0
var armor: float = 0.0
var xp: int = 0
var ai: StringName = &"ground"
var scales_with_time: bool = true
var sprite: String = ""
var display_height: float = 100.0
var tint: Color = Color.WHITE
var charge: Dictionary = {}  # opsiyonel: every, duration, speed
var summon: Dictionary = {}  # opsiyonel: type, every, count, [enrage_*]
## Hareket/ölüm animasyonu (görünüm okur, sim kullanmaz). Yoksa {"kind": "none"}: hareket ve gölge yok.
var anim: Dictionary = {"kind": "none"}


static func from_dict(d: Dictionary) -> EnemyDef:
	var e := EnemyDef.new()
	e.id = StringName(str(d.get("id", "")))
	e.display_name = str(d.get("name", ""))
	e.hp = float(d.get("hp", 1.0))
	e.speed = float(d.get("speed", 0.0))
	e.dmg = float(d.get("dmg", 0.0))
	e.radius = float(d.get("radius", 20.0))
	e.armor = float(d.get("armor", 0.0))
	e.xp = int(d.get("xp", 0))
	e.ai = StringName(str(d.get("ai", "ground")))
	e.scales_with_time = bool(d.get("scales_with_time", true))
	e.sprite = str(d.get("sprite", ""))
	e.display_height = float(d.get("display_height", 100.0))
	var t: Variant = d.get("tint", "#ffffff")
	if t is String and Color.html_is_valid(t):
		e.tint = Color.html(t)
	var ch: Variant = d.get("charge", {})
	e.charge = ch if ch is Dictionary else {}
	var sm: Variant = d.get("summon", {})
	e.summon = sm if sm is Dictionary else {}
	var an: Variant = d.get("anim", null)
	if an is Dictionary:
		e.anim = an
	return e
