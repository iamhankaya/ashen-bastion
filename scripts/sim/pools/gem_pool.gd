class_name GemPool
extends RefCounted
## XP taşı havuzu (kompakt: 0..count-1). CAP doluyken yeni taş en yakın mevcut taşa katılır (toplam değer korunur).

const CAP := 300

var count: int = 0
var pos: PackedVector2Array = PackedVector2Array()
var value: PackedInt32Array = PackedInt32Array()
## 1 = oyuncuya doğru çekiliyor (toplama yarıçapına girmiş taş çekilmeye devam eder).
var pulled: PackedByteArray = PackedByteArray()
## XP korunumu: dropped_total - collected_total == total_value() (check_invariants).
var dropped_total: int = 0
var collected_total: int = 0


func _init() -> void:
	pos.resize(CAP)
	value.resize(CAP)
	pulled.resize(CAP)


func drop(p: Vector2, v: int) -> void:
	dropped_total += v
	if count < CAP:
		pos[count] = p
		value[count] = v
		pulled[count] = 0
		count += 1
		return
	# Havuz dolu: en yakın taşa birleştir (O(CAP), yalnız doluyken ve düşüşte).
	var best := 0
	var best_d := INF
	for i in count:
		var d := pos[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	value[best] += v


## Taşı toplar (değeri döndürür), son taşı yerine alır. Ters sırayla gezen döngüde güvenlidir.
func collect(i: int) -> int:
	var v := value[i]
	collected_total += v
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		value[i] = value[last]
		pulled[i] = pulled[last]
	count = last
	return v


## Havuzdaki canlı taşların toplam XP değeri (ilk `count` indeks).
func total_value() -> int:
	var t := 0
	for i in count:
		t += value[i]
	return t
