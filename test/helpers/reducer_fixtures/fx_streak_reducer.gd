class_name FxStreakReducer
extends AchievementReducer
## Kuru deneme eklentisi (R8): hasar almadan üst üste öldürme serisinin en büyüğü. Yalnız bu yeni dosya + bir metrik JSON'u eklenir.


func on_event(ev: StringName, _payload: Dictionary, state: Dictionary) -> void:
	if ev == &"player_damaged":
		state["run"] = 0
	elif ev == &"enemy_killed":
		state["run"] = int(state["run"]) + 1
		state["value"] = maxi(int(state["value"]), int(state["run"]))


func reset(state: Dictionary) -> void:
	state["run"] = 0
	state["value"] = 0
