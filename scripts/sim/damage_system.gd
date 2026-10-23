class_name DamageSystem
extends RefCounted
## Hasar/zırh/ölüm/XP taşı, on_hit/on_kill. Hedef seçmez.

const ARMOR_MIN_FRACTION := 0.2


## Mermi hasarı: max(hasar - zırh, hasar * 0,2). Alan/patlama/parçacık zırhı yok sayar.
static func after_armor(raw: float, armor: float) -> float:
	Stub.todo(&"DamageSystem.after_armor")
	return 0.0


## kind: "bullet" | "explosion" | "contact" | "dot"
func damage_enemy(sim: GameSim, id: int, amount: float, kind: StringName) -> void:
	Stub.todo(&"DamageSystem.damage_enemy")


## Temas hasarı tick'i (0,6 sn; ilk tick hemen; tick başına en çok 4 temas). Oyuncuya verilen toplamı döndürür.
func contact_tick(sim: GameSim, dt: float) -> float:
	Stub.todo(&"DamageSystem.contact_tick")
	return 0.0
