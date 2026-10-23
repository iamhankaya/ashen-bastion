class_name Loadout
extends RefCounted
## 6 aktif + 6 pasif yuva, evrim koşulu, seviye atlama kartları.

const ACTIVE_SLOTS := 6
const PASSIVE_SLOTS := 6

var data: GameData = null
var _actives: Array[SkillState] = []
var _passives: Array[SkillState] = []


func _init(p_data: GameData = null) -> void:
	data = p_data


func actives() -> Array[SkillState]:
	return _actives


func passives() -> Array[SkillState]:
	return _passives


func level_of(skill_id: StringName) -> int:
	for s in _actives:
		if s.id == skill_id:
			return s.level
	for s in _passives:
		if s.id == skill_id:
			return s.level
	return 0


func add_or_upgrade(skill_id: StringName) -> void:
	Stub.todo(&"Loadout.add_or_upgrade")


## Evrim hazırsa evrim kimliği, değilse &"". Koşul: aktif max_level + eşleşen pasif seviye >= 1.
func evolution_ready() -> StringName:
	Stub.todo(&"Loadout.evolution_ready")
	return &""


## Ham aktifi yuvada yerinde değiştirir (evrim max_level 1; pasif kalır).
func apply_evolution(evo_id: StringName) -> void:
	Stub.todo(&"Loadout.apply_evolution")


## rng: sim buraya rng_choice verir. 1..3 kart; aday yoksa tek "heal".
func roll_choices(rng: RandomNumberGenerator) -> Array[Choice]:
	Stub.todo(&"Loadout.roll_choices")
	return []
