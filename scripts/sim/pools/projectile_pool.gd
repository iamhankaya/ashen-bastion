class_name ProjectilePool
extends RefCounted
## SoA mermi havuzu. Mermi başına vurulan düşman kümesi (HIT_SLOTS halka tampon).

const CAP := 600
const HIT_SLOTS := 12

# flags (bit maskesi)
const FLAG_EXPLODES := 1  # isabette
const FLAG_EXPLODE_ON_EXPIRE := 2  # dinamit
const FLAG_EXPLODE_ON_BOUNCE := 4  # zincirleme_patlama
const FLAG_RICOCHET := 8
const FLAG_RADIAL := 16  # yalnız görsel

var count: int = 0
var pos: PackedVector2Array = PackedVector2Array()
var vel: PackedVector2Array = PackedVector2Array()
var dmg: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	pos.resize(CAP)
	vel.resize(CAP)
	dmg.resize(CAP)


## o: pierce:int, bounces:int, life:float (=1.2), flags:int, ex_radius, ex_dmg, push:float, gun:int
## -1 = havuz dolu.
func spawn(p: Vector2, v: Vector2, damage: float, o: Dictionary = {}) -> int:
	Stub.todo(&"ProjectilePool.spawn")
	return -1


func has_hit(pid: int, enemy_id: int) -> bool:
	Stub.todo(&"ProjectilePool.has_hit")
	return false


func mark_hit(pid: int, enemy_id: int) -> void:
	Stub.todo(&"ProjectilePool.mark_hit")
