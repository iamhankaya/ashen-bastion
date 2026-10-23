class_name GemPool
extends RefCounted
## XP taşı havuzu. CAP aşılırsa en yakın iki taş birleşir (toplam değer korunur).

const CAP := 300

var count: int = 0
var pos: PackedVector2Array = PackedVector2Array()
var value: PackedInt32Array = PackedInt32Array()
## XP korunumu: dropped_total - collected_total == total_value() (check_invariants).
var dropped_total: int = 0
var collected_total: int = 0


func _init() -> void:
	pos.resize(CAP)
	value.resize(CAP)


func drop(p: Vector2, v: int) -> void:
	Stub.todo(&"GemPool.drop")


## Havuzdaki canlı taşların toplam XP değeri (ilk `count` indeks).
func total_value() -> int:
	var t := 0
	for i in count:
		t += value[i]
	return t
