class_name AudioDirector
extends Node
## Crossfade ve bus yönetimi (MusicPlan kararını uygular). Sözleşmede boş iskelet (U2-8c).

var sim_bus: SimBus = null


func bind(bus: SimBus) -> void:
	sim_bus = bus
	Stub.todo(&"AudioDirector.bind")
