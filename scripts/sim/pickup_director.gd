class_name PickupDirector
extends RefCounted
## Eklenti doğuş zamanlaması, tür/konum seçimi (rng_pickup) ve ömür dolumu. Etki uygulamaz.
## `armed` = yapılandırma var (opts.pickups=false ya da pickups.json yok ⇒ boş ⇒ doğuş yok, rng_pickup'a dokunulmaz).
## Tüm zamanlar tam sayı ADIM'dır (roundi(sn × 60)); aralıklar step_count'a göredir.

## Bir sonraki doğuşun adım numarası (step_count'a göre).
var next_step: int = 0
var armed: bool = false

var _cfg: Dictionary = {}
var _rng: RandomNumberGenerator = null
var _first := Vector2.ZERO
var _interval := Vector2.ZERO
var _dist := Vector2.ZERO
var _clearance := 40.0
var _life_steps := 1500
var _max_alive := 2
var _weights: PackedFloat32Array = PackedFloat32Array()
var _weight_total := 0.0
var _expired: PackedInt32Array = PackedInt32Array()


## cfg = GameData.pickup_cfg ({spawn, kinds}; opts.pickups=false iken {}), rng = GameSim.rng_pickup.
func _init(cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_rng = rng
	var sp: Variant = cfg.get("spawn", null)
	var kinds: Variant = cfg.get("kinds", null)
	if not (sp is Dictionary and kinds is Array and not (kinds as Array).is_empty()):
		return
	var spawn: Dictionary = sp
	_first = _pair(spawn.get("first"), Vector2(30.0, 45.0))
	_interval = _pair(spawn.get("interval"), Vector2(45.0, 60.0))
	_dist = _pair(spawn.get("dist"), Vector2(450.0, 700.0))
	_clearance = float(spawn.get("clearance", 40.0))
	_life_steps = roundi(float(spawn.get("life", 25.0)) * 60.0)
	_max_alive = int(spawn.get("max_alive", 2))
	for k in kinds:
		var w := float((k as Dictionary).get("weight", 0.0)) if k is Dictionary else 0.0
		_weights.append(maxf(0.0, w))
		_weight_total += maxf(0.0, w)
	if _weight_total <= 0.0:
		return
	armed = true
	next_step = _draw_steps(_first)


## Ömür dolumu + doğuş (GameSim._phase_spawn).
func step(sim: GameSim) -> void:
	if not armed:
		return
	sim.pickups.tick(_expired)
	for kind in _expired:
		var kind_id := sim.data.pickup_ids[kind]
		sim.log_event(SimEvents.PICKUP_EXPIRE, {"kind_id": kind_id})
		sim.bus.pickup_expired.emit(kind_id)
	if sim.step_count < next_step:
		return
	next_step = sim.step_count + _draw_steps(_interval)
	if sim.pickups.count >= _max_alive:
		return  # dolu: tür/konum çekilmez
	var kind := _pick_kind()
	var angle := _rng.randf() * TAU
	var dist := _rng.randf_range(_dist.x, _dist.y)
	var p := sim.map.resolve(sim.player_pos + Vector2.from_angle(angle) * dist, _clearance)
	var i := sim.pickups.spawn(kind, p, _life_steps)
	if i < 0:
		return
	var kind_id := sim.data.pickup_ids[kind]
	sim.log_event(SimEvents.PICKUP_SPAWN, {"kind_id": kind_id, "pos": p})
	sim.bus.pickup_spawned.emit(kind_id, p)


## debug_set_time: next_step geride kalmışsa step_count'a çekilir (birikmiş doğuş yok).
func skip_to(step_count: int) -> void:
	if armed and next_step < step_count:
		next_step = step_count


func progress_hash() -> int:
	return next_step


## Ağırlıklı seçim: kinds dizi sırası, kümülatif ağırlık, tek randf.
func _pick_kind() -> int:
	var r := _rng.randf() * _weight_total
	var acc := 0.0
	for k in _weights.size():
		acc += _weights[k]
		if r < acc:
			return k
	return _weights.size() - 1


func _draw_steps(range_sec: Vector2) -> int:
	return roundi(_rng.randf_range(range_sec.x, range_sec.y) * 60.0)


static func _pair(v: Variant, fallback: Vector2) -> Vector2:
	if v is Array and (v as Array).size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback
