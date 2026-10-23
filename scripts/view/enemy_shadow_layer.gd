class_name EnemyShadowLayer
extends MultiMeshInstance2D
## Düşman yer gölgesi (soft elips) MultiMesh'i. Mantık yok; EnemyRenderer aynı refresh() döngüsünde tamponu yazar.
## İskelet (S3): gövde D1-2'de dolar.

@warning_ignore_start("unused_parameter")


## buf: n örnek × (8 float dönüşüm + 4 renk).
func write(buf: PackedFloat32Array, n: int) -> void:
	Stub.todo(&"EnemyShadowLayer.write")
