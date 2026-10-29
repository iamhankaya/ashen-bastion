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
	if AchievementDef.TOTAL_KEY.has(s):
		return int(store.totals[AchievementDef.TOTAL_KEY[s]])
	if AchievementDef.BEST_KEY.has(s):
		return int(store.best[AchievementDef.BEST_KEY[s]])
	return -1
