class_name DamageSystem
extends RefCounted
## Hasar/zırh/ölüm/XP taşı, on_hit/on_kill. Hedef seçmez.

const ARMOR_MIN_FRACTION := 0.2
const CONTACT_INTERVAL := 0.6
const MAX_CONTACTS_PER_TICK := 4
## Temas aramasında en büyük düşman yarıçapı payı (hash hücreleri bir kare eskidir).
const CONTACT_QUERY_PAD := 90.0

## Kalan temas bekleme süresi; temas yoksa 0'da hazır bekler.
var contact_timer: float = 0.0

var _scratch: PackedInt32Array = PackedInt32Array()


## Mermi hasarı: max(hasar - zırh, hasar * 0,2). Alan/patlama/parçacık zırhı yok sayar.
static func after_armor(raw: float, armor: float) -> float:
	return maxf(raw - armor, raw * ARMOR_MIN_FRACTION)


## kind: "bullet" | "explosion" | "contact" | "dot"
func damage_enemy(sim: GameSim, id: int, amount: float, kind: StringName) -> void:
	if not sim.enemies.is_alive(id):
		return
	var i := EnemyPool.index_of(id)
	var net := after_armor(amount, sim.enemies.armor[i]) if kind == &"bullet" else amount
	sim.enemies.hp[i] -= net
	sim.enemies.flash[i] = 1.0
	sim.log_event(
		SimEvents.DAMAGE, {"target": id, "amount": net, "raw": amount, "kind": kind, "source": &""}
	)
	if sim.enemies.hp[i] <= 0.0:
		_kill(sim, id, i)


func _kill(sim: GameSim, id: int, i: int) -> void:
	var p := sim.enemies.pos[i]
	var type_id := sim.enemies.type_id_of(i)
	var xp_value := sim.enemies.def_of(i).xp
	sim.enemies.kill(id)
	sim.kills += 1
	sim.log_event(SimEvents.KILL, {"enemy_id": id, "enemy_type": type_id, "pos": p})
	if xp_value > 0:
		sim.gems.drop(p, xp_value)
		sim.log_event(SimEvents.GEM_DROPPED, {"value": xp_value})
	sim.bus.enemy_killed.emit(type_id, p)
	for st in sim.loadout.actives():
		if st.behavior != null:
			st.behavior.on_kill(id, p)


## Temas hasarı tick'i (0,6 sn; ilk tick hemen; tick başına en çok 4 temas). Oyuncuya verilen toplamı döndürür.
func contact_tick(sim: GameSim, dt: float) -> float:
	contact_timer = maxf(0.0, contact_timer - dt)
	if contact_timer > 0.0:
		return 0.0
	var pr := sim.character.collision_radius if sim.character != null else 22.0
	sim.grid.query_circle(sim.player_pos, pr + CONTACT_QUERY_PAD, _scratch)
	var total := 0.0
	var touching := 0
	for id in _scratch:
		if not sim.enemies.is_alive(id):
			continue
		var i := EnemyPool.index_of(id)
		sim.w_collision_tests += 1
		var reach := pr + sim.enemies.radius[i]
		if sim.enemies.pos[i].distance_squared_to(sim.player_pos) <= reach * reach:
			total += sim.enemies.contact[i]
			touching += 1
			if touching >= MAX_CONTACTS_PER_TICK:
				break
	if touching > 0:
		contact_timer = CONTACT_INTERVAL
		sim.hp -= total
		sim.log_event(
			SimEvents.DAMAGE,
			{"target": -1, "amount": total, "raw": total, "kind": &"contact", "source": &""}
		)
		sim.bus.player_damaged.emit(total, sim.hp)
	return total
