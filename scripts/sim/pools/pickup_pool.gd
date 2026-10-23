class_name PickupPool
extends RefCounted
## Yerdeki eklentiler (SoA, kompakt 0..count-1, CAP 8). Etki uygulamaz. Süre sayaçları tam sayı ADIM'dır.

const CAP := 8

var count: int = 0
var pos: PackedVector2Array = PackedVector2Array()
## GameData.pickup_ids sırasına indeks.
var kind_idx: PackedInt32Array = PackedInt32Array()
var age_steps: PackedInt32Array = PackedInt32Array()
var left_steps: PackedInt32Array = PackedInt32Array()
## Monoton artan kimlik (görünüm fazı bundan türer); yuva yeniden kullanılsa da tekrar etmez.
var uid: PackedInt32Array = PackedInt32Array()

var _next_uid: int = 0


func _init() -> void:
	pos.resize(CAP)
	kind_idx.resize(CAP)
	age_steps.resize(CAP)
	left_steps.resize(CAP)
	uid.resize(CAP)


## Yeni eklenti ekler; havuz doluysa -1, değilse indeks. uid monoton artar.
func spawn(kind: int, p: Vector2, life_steps: int) -> int:
	if count >= CAP:
		return -1
	var i := count
	pos[i] = p
	kind_idx[i] = kind
	age_steps[i] = 0
	left_steps[i] = life_steps
	uid[i] = _next_uid
	_next_uid += 1
	count += 1
	return i


## Son elemanı yerine alır (GemPool kalıbı). Ters sırayla gezen döngüde güvenlidir.
func remove(i: int) -> void:
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		kind_idx[i] = kind_idx[last]
		age_steps[i] = age_steps[last]
		left_steps[i] = left_steps[last]
		uid[i] = uid[last]
	count = last


## age++ / left--; süresi dolanlar çıkarılır, kind_idx'leri expired_kinds'e yazılır (önce temizlenir).
func tick(expired_kinds: PackedInt32Array) -> void:
	expired_kinds.clear()
	if count == 0:
		return
	for i in count:
		age_steps[i] += 1
		left_steps[i] -= 1
		if left_steps[i] <= 0:
			expired_kinds.append(kind_idx[i])
	if expired_kinds.is_empty():
		return
	var i := count - 1
	while i >= 0:
		if left_steps[i] <= 0:
			remove(i)
		i -= 1
