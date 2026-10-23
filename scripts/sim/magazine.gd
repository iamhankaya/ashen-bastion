class_name Magazine
extends RefCounted
## Ortak şarjör ve doldurma durum makinesi. Kurallar: plan "Magazine (kesin kurallar)".

signal changed(count: int, cap: int)
signal reload_started(duration: float)
signal reload_finished

var count: int = 6
var cap: int = 6
var reloading: bool = false
var reload_left: float = 0.0
var reload_total: float = 0.0
## kiyamet_mermisi: doldurma döngüsü başına bir geri yazma; reload_finished'te false olur.
var refund_used: bool = false


func can_fire() -> bool:
	Stub.todo(&"Magazine.can_fire")
	return false


## {"ok": bool, "index": int (1..cap), "is_last": bool}
func consume() -> Dictionary:
	Stub.todo(&"Magazine.consume")
	return {"ok": false, "index": 0, "is_last": false}


func refund(n: int) -> void:
	Stub.todo(&"Magazine.refund")


func tick(dt: float, stats: StatBlock) -> void:
	Stub.todo(&"Magazine.tick")


func start_reload(stats: StatBlock) -> void:
	Stub.todo(&"Magazine.start_reload")


## StatBlock değişince sim çağırır.
func set_cap(new_cap: int) -> void:
	Stub.todo(&"Magazine.set_cap")


func reset_cycle_flags() -> void:
	Stub.todo(&"Magazine.reset_cycle_flags")
