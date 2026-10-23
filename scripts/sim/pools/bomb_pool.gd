class_name BombPool
extends RefCounted
## Toplanmış bombalar (SoA, CAP 4). Hasar vermez; fitil tam sayı ADIM sayacıdır.
## İskelet (S2): alanlar ve is_full gerçek; plant/tick/remove D2-1'de dolar.

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


@warning_ignore_start("unused_parameter")


func is_full() -> bool:
	return count >= CAP


## Bomba kurar; havuz doluysa -1, değilse indeks.
func plant(p: Vector2, fuse: int, r: float, kind: int) -> int:
	Stub.todo(&"BombPool.plant")
	return -1


## fuse_steps--; <= 0 olanların indeksleri artan sırayla ready'ye yazılır (önce temizlenir).
func tick(ready: PackedInt32Array) -> void:
	ready.clear()
	if count == 0:
		return
	Stub.todo(&"BombPool.tick")


func remove(i: int) -> void:
	Stub.todo(&"BombPool.remove")
