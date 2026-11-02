class_name AchievementProgress
extends RefCounted
## Koşu dışı ilerleme (ekran bunu kullanır; tracker bilmez). Saf: yalnız depo okur.


## totals/best/chars5'ten ilerleme; kaynağı olmayan stat (`run_elit_piyade`, `run_won`) için -1.
static func of(def: AchievementDef, store: AchievementStore) -> int:
	if def == null or store == null:
		return -1
	var s := String(def.stat)
	if s == "total_chars5":
		return store.chars5.size()
	if def.total_key != "":
		return int(store.totals.get(def.total_key, 0))
	if def.best_key != "":
		return int(store.best.get(def.best_key, 0))
	return -1
