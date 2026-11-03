class_name AchievementProgress
extends RefCounted
## Koşu dışı ilerleme (ekran bunu kullanır; tracker bilmez). Saf: yalnız depo okur.


## totals/best/chars5'ten ilerleme; kaynağı olmayan stat (`run_elit_piyade`, `run_won`) için -1.
static func of(def: AchievementDef, store: AchievementStore) -> int:
	if def == null or store == null:
		return -1
	return store.progress_of(def)
