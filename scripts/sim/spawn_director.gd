class_name SpawnDirector
extends RefCounted
## `waves` verisine göre doğurma, boss/lord, uzak düşmanı geri taşıma, spawn kaybı sayacı.

var waves: Dictionary = {}


func _init(p_waves: Dictionary = {}) -> void:
	waves = p_waves


func step(sim: GameSim) -> void:
	Stub.todo(&"SpawnDirector.step")


## start_time / debug_set_time atlamasında: at < t olan olaylar "yapıldı" işaretlenir.
func skip_to(t: float) -> void:
	Stub.todo(&"SpawnDirector.skip_to")
