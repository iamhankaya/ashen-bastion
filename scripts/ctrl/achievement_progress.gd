class_name AchievementProgress
extends RefCounted
## Koşu dışı ilerleme (ekran bunu kullanır; tracker bilmez). Saf: yalnız depo okur.


## totals/best/chars5'ten ilerleme; kaynağı olmayan (koşu-kapsamlı) stat için -1 ("TEK KOŞU").
static func of(def: AchievementDef, store: AchievementStore) -> int:
	if def == null or store == null:
		return -1
	match String(def.stat):
		"total_kills":
			return int(store.totals["kills"])
		"total_runs":
			return int(store.totals["runs"])
		"total_wins":
			return int(store.totals["wins"])
		"total_play_secs":
			return int(store.totals["play_secs"])
		"total_chars5":
			return store.chars5.size()
		"run_time":
			return int(store.best["time"])
		"run_level":
			return int(store.best["level"])
		"run_score":
			return int(store.best["score"])
	return -1
