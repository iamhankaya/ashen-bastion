class_name AchievementProgressView
extends RefCounted
## Başarım ilerlemesinin salt okuma görünümü (domain → store bağımlılığı tek yerde): kilit sorgusu ve bozuk-kayıt bayrağı.
## Null depo = bozuk görünüm (güvenli yön: hiçbir şey açık değil).

var corrupt: bool = true
var _store: AchievementStore = null


static func of_store(store: AchievementStore) -> AchievementProgressView:
	var v := AchievementProgressView.new()
	if store != null:
		v.corrupt = store.corrupt
		v._store = store
	return v


## Depo ya da görünüm (ya da null) kabul eder; çağıranlar tek biçime indirir.
static func of(source: Variant) -> AchievementProgressView:
	if source is AchievementProgressView:
		return source
	return of_store(source as AchievementStore)


func is_unlocked(achievement_id: StringName) -> bool:
	return not corrupt and _store != null and _store.is_unlocked(achievement_id)
