class_name UnlimitedKillsReducer
extends AchievementReducer
## "unlimited" buff'ı sırasındaki öldürmeler. Buff yenilemesi (sinyal `fresh` taşımaz) sayacı sıfırlamaz; yeni buff sıfırlar.


func on_event(ev: StringName, payload: Dictionary, state: Dictionary) -> void:
	match ev:
		&"buff_started":
			if payload["kind"] == AchievementTracker.UNLIMITED and not state["active"]:
				state["active"] = true
				state["value"] = 0
		&"buff_ended":
			if payload["kind"] == AchievementTracker.UNLIMITED:
				state["active"] = false
		&"enemy_killed":
			if state["active"]:
				state["value"] = int(state["value"]) + 1


func reset(state: Dictionary) -> void:
	state["active"] = false
	state["value"] = 0
