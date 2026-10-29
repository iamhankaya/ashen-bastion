class_name CharsFiveReducer
extends AchievementReducer
## 5 dakikayı geçen koşularda oynanan farklı karakter sayısı (depodaki `chars5` kümesi). Zorluk kuralı toplamı saymıyorsa eklenmez.

const MIN_SECS := 300


func finish(result: Dictionary, state: Dictionary) -> int:
	if int(result["time"]) < MIN_SECS or not result["counts_chars5"]:
		return -1
	var store: AchievementStore = state["store"]
	store.note_char5(state["char_id"])
	return store.chars5.size()


func value(state: Dictionary) -> int:
	var store: AchievementStore = state.get("store")
	return store.chars5.size() if store != null else 0
