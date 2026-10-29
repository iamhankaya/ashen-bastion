class_name CleanSecsReducer
extends AchievementReducer
## Hasar almadan geçen en uzun süre (sn): poll'da sim.time'a yükselir, ilk hasarda (player_damaged) donar.


func on_event(ev: StringName, _payload: Dictionary, state: Dictionary) -> void:
	if ev == &"player_damaged":
		state["damaged"] = true


func poll(sim: GameSim, state: Dictionary) -> void:
	var secs := int(sim.time)
	if not state.get("damaged", false) and secs > int(state["value"]):
		state["value"] = secs


func reset(state: Dictionary) -> void:
	state["damaged"] = false
	state["value"] = 0
