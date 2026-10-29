class_name EliteKindsReducer
extends AchievementReducer
## Koşuda öldürülen farklı elit türü sayısı (aynı tür tekrarı kümeyi büyütmez).


func on_event(ev: StringName, payload: Dictionary, state: Dictionary) -> void:
	if ev != &"enemy_killed":
		return
	var mask: int = AchievementTracker.ELITE_MASKS.get(payload["type_id"], 0)
	var seen: int = state["mask"]
	if mask != 0 and seen & mask == 0:
		seen |= mask
		state["mask"] = seen
		state["value"] = AchievementTracker.POPCOUNT3[seen]


func reset(state: Dictionary) -> void:
	state["mask"] = 0
	state["value"] = 0
