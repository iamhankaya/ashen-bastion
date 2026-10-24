class_name BombPool
extends RefCounted
## Toplanmış bombalar (SoA, CAP 4). Hasar vermez; fitil tam sayı ADIM sayacıdır.

const CAP := 4

var count: int = 0
var pos: PackedVector2Array = PackedVector2Array()
var fuse_steps: PackedInt32Array = PackedInt32Array()
var fuse_total: PackedInt32Array = PackedInt32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
## GameData.pickup_ids sırasına indeks (patlama parametreleri türünden okunur).
var kind_idx: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	pos.resize(CAP)
	fuse_steps.resize(CAP)
	fuse_total.resize(CAP)
	radius.resize(CAP)
	kind_idx.resize(CAP)


func is_full() -> bool:
	return count >= CAP


## Bomba kurar; havuz doluysa -1, değilse indeks.
func plant(p: Vector2, fuse: int, r: float, kind: int) -> int:
	if count >= CAP:
		return -1
	var i := count
	pos[i] = p
	fuse_steps[i] = fuse
	fuse_total[i] = fuse
	radius[i] = r
	kind_idx[i] = kind
	count += 1
	return i


## fuse_steps--; <= 0 olanların indeksleri artan sırayla ready'ye yazılır (önce temizlenir).
func tick(ready: PackedInt32Array) -> void:
	ready.clear()
	for i in count:
		fuse_steps[i] -= 1
		if fuse_steps[i] <= 0:
			ready.append(i)


## Son elemanı yerine alır. Ters sırayla gezen döngüde güvenlidir.
func remove(i: int) -> void:
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		fuse_steps[i] = fuse_steps[last]
		fuse_total[i] = fuse_total[last]
		radius[i] = radius[last]
		kind_idx[i] = kind_idx[last]
	count = last
