class_name EnemyPool
extends RefCounted
## SoA düşman havuzu. enemy_id = (nesil << 16) | indeks. Nesil 16 bit (65536. yeniden kullanımda 0'a döner).
## Havuz sıkıştırılmaz; serbest-liste LIFO.

const CAP := 400
const GEN_SHIFT := 16
const INDEX_MASK := 0xFFFF

var count: int = 0
var pos: PackedVector2Array = PackedVector2Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var type_idx: PackedInt32Array = PackedInt32Array()
var flash: PackedFloat32Array = PackedFloat32Array()
var gen: PackedInt32Array = PackedInt32Array()
var alive: PackedByteArray = PackedByteArray()


func _init() -> void:
	pos.resize(CAP)
	hp.resize(CAP)
	type_idx.resize(CAP)
	flash.resize(CAP)
	gen.resize(CAP)
	alive.resize(CAP)


static func make_id(generation: int, index: int) -> int:
	return ((generation & 0xFFFF) << GEN_SHIFT) | (index & INDEX_MASK)


static func index_of(id: int) -> int:
	return id & INDEX_MASK


static func gen_of(id: int) -> int:
	return (id >> GEN_SHIFT) & 0xFFFF


## -1 = havuz dolu.
func spawn(
	type_id: StringName, p: Vector2, hp_mult: float, contact_mult: float, speed_mult: float
) -> int:
	Stub.todo(&"EnemyPool.spawn")
	return -1


func kill(id: int) -> void:
	Stub.todo(&"EnemyPool.kill")


## Nesil uyumsuzluğunda false.
func is_alive(id: int) -> bool:
	var i := index_of(id)
	return i < CAP and alive[i] == 1 and gen[i] == gen_of(id)


func radius_of(id: int) -> float:
	Stub.todo(&"EnemyPool.radius_of")
	return 0.0


## Canlı düşman kimlikleri, ARTAN id (sayısal) sırasıyla; query_circle ile aynı kural.
## Dikkat: nesil >= 0x8000 olan id int32'de negatiftir (bir slotun 32768 kez yeniden kullanımı; 20 dk'lık
## oyunda gerçekçi değil). "Eşitlikte en düşük indeks" kuralı id'ye değil index_of(id)'ye bakar.
func alive_ids() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in CAP:
		if alive[i] == 1:
			out.append(make_id(gen[i], i))
	out.sort()
	return out
