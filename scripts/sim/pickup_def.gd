class_name PickupDef
extends RefCounted
## Eklenti tanımı (data/pickups.json `kinds[i]`). Şema: docs/data-schema.md

var id: StringName = &""
var display_name: String = ""
var rarity: StringName = &"common"  # common|uncommon|rare
var weight: float = 0.0
var effect: StringName = &"heal"  # heal|magnet|buff|bomb
var amount: float = 0.0  # heal
var buff: StringName = &""  # buff: damage|fire_rate|unlimited
var mult: float = 1.0  # buff çarpanı (unlimited'ta kullanılmaz)
var duration: float = 0.0  # buff süresi (sn)
var radius: float = 0.0  # bomb
var fuse: float = 0.0  # bomb (sn)
var dmg: float = 0.0  # bomb: normal düşmana sabit hasar
var elite_frac: float = 0.0  # bomb: elit/Lord için azami can oranı
var elite_min: float = 0.0  # bomb: elit/Lord için alt sınır
var toast: String = ""
var icon: String = ""


static func from_dict(d: Dictionary) -> PickupDef:
	var p := PickupDef.new()
	p.id = StringName(_s(d.get("id", "")))
	p.display_name = _s(d.get("name", ""))
	p.rarity = StringName(_s(d.get("rarity", "common")))
	p.weight = _f(d.get("weight", 0.0))
	p.effect = StringName(_s(d.get("effect", "heal")))
	p.amount = _f(d.get("amount", 0.0))
	p.buff = StringName(_s(d.get("buff", "")))
	p.mult = _f(d.get("mult", 1.0))
	p.duration = _f(d.get("duration", 0.0))
	p.radius = _f(d.get("radius", 0.0))
	p.fuse = _f(d.get("fuse", 0.0))
	p.dmg = _f(d.get("dmg", 0.0))
	p.elite_frac = _f(d.get("elite_frac", 0.0))
	p.elite_min = _f(d.get("elite_min", 0.0))
	p.toast = _s(d.get("toast", ""))
	p.icon = _s(d.get("icon", ""))
	return p


## Bozuk (yanlış tipli) veri yüklemeyi çökertmez; doğrulayıcı hatayı bildirir.
static func _f(v: Variant) -> float:
	return float(v) if (v is int or v is float) else 0.0


static func _s(v: Variant) -> String:
	return v if v is String else ""
