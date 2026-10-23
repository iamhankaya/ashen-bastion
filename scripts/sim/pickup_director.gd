class_name PickupDirector
extends RefCounted
## Eklenti doğuş zamanlaması, tür/konum seçimi (rng_pickup) ve ömür dolumu. Etki uygulamaz.
## İskelet (S2): _init ve alanlar gerçek; gövdeler D2-1'de dolar. `armed` iskelette hep false: v1 davranışı korunur
## (boşta Stub.todo kaydı oluşmaz). D2-1 `_init`te `armed = not cfg.is_empty()` yapar ve bu korumaları kaldırır.

## Bir sonraki doğuşun adım numarası (step_count'a göre).
var next_step: int = 0
var armed: bool = false

var _cfg: Dictionary = {}
var _rng: RandomNumberGenerator = null


## cfg = GameData.pickup_cfg ({spawn, kinds}; opts.pickups=false iken {}), rng = GameSim.rng_pickup.
func _init(cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_rng = rng


@warning_ignore_start("unused_parameter")


## Ömür dolumu + doğuş (GameSim._phase_spawn).
func step(sim: GameSim) -> void:
	if not armed:
		return
	Stub.todo(&"PickupDirector.step")


## debug_set_time: next_step geride kalmışsa step_count'a çekilir (birikmiş doğuş yok).
func skip_to(step_count: int) -> void:
	if not armed:
		return
	Stub.todo(&"PickupDirector.skip_to")


func progress_hash() -> int:
	if not armed:
		return next_step
	Stub.todo(&"PickupDirector.progress_hash")
	return next_step
