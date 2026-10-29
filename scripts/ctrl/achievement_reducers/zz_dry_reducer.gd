class_name ZzDryReducer
extends AchievementReducer
## Kuru deneme reducer'ı (prova): her öldürmede değeri 1 artırır. Yalnız prova ağacında bulunur.


func on_event(ev: StringName, _payload: Dictionary, state: Dictionary) -> void:
	if ev == &"enemy_killed":
		state["value"] = int(state["value"]) + 1


func reset(state: Dictionary) -> void:
	state["value"] = 0
