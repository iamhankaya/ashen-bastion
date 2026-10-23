class_name PickupSystem
extends RefCounted
## Eklenti toplama, süreli etkilerin uygulanması, bomba fitili/patlaması (GameSim'in v1.1 kancalarının gövdeleri).
## GameSim dosyası gdlint 1000 satır sınırına dayandığından kancalar buraya devredilir: GameSim._collect_pickups,
## _apply_buffs, _buffs_ended, _tick_bombs, bomb_blast birer satırla bu sınıfı çağırır. Sahibi D2-1.
## İskelet (S2): boşta (eklenti/bomba/etki yok) no-op; iş olduğunda Stub.todo kaydı oluşturur. debug_spawn gerçek.

@warning_ignore_start("unused_parameter")


## Oyuncu ≤ collect_radius ise eklentiyi toplar (artan indeks): pickup_collected, etki, havuzdan çıkarma.
static func collect(sim: GameSim) -> void:
	if sim.pickups.count == 0:
		return
	Stub.todo(&"PickupSystem.collect")


## Biten süreli etkiler (BuffManager.Kind): buff_end olayı/sinyali, ardından apply_buffs.
static func buffs_ended(sim: GameSim, ended: PackedInt32Array) -> void:
	Stub.todo(&"PickupSystem.buffs_ended")


## BuffManager çarpanlarını StatBlock.set_buffs'a ve Magazine.set_unlimited'a yansıtır.
static func apply_buffs(sim: GameSim) -> void:
	Stub.todo(&"PickupSystem.apply_buffs")


## Fitili biten bombaları patlatır (GameSim.bomb_blast); WON/LOST sonrası step no-op olduğundan patlamaz.
static func tick_bombs(sim: GameSim) -> void:
	if sim.bombs.count == 0:
		return
	Stub.todo(&"PickupSystem.tick_bombs")


## Alan hasarı: normal düşmana dmg, elit/Lord için max(elite_min, elite_frac × maks. can); zırhı yok sayar.
## Vurulan sayıyı döndürür.
static func blast(
	sim: GameSim, pos: Vector2, radius: float, dmg: float, elite_frac: float, elite_min: float
) -> int:
	Stub.todo(&"PickupSystem.blast")
	return 0


## GameSim.debug_spawn_pickup gövdesi: türü pickups.json ömrüyle yere koyar; indeks ya da -1 (bilinmeyen tür/dolu).
static func debug_spawn(sim: GameSim, kind_id: StringName, pos: Vector2) -> int:
	var kind := sim.data.pickup_ids.find(kind_id)
	if kind < 0:
		return -1
	var life := 25.0
	var sp: Variant = sim.data.pickup_cfg.get("spawn", {})
	if sp is Dictionary:
		life = float((sp as Dictionary).get("life", life))
	var i := sim.pickups.spawn(kind, pos, roundi(life * 60.0))
	if i >= 0:
		sim.log_event(SimEvents.PICKUP_SPAWN, {"kind_id": kind_id, "pos": pos})
		sim.bus.pickup_spawned.emit(kind_id, pos)
	return i
