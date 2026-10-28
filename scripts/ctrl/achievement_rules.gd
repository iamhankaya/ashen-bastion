class_name AchievementRules
extends RefCounted
## v2.1 zorluğa bağlı başarım kuralı (K-C5). Veri run_profiles.json "achievements" bölümünden gelir; kural DÜZEYİ kademedir:
## tracker her kademe verme noktasında `allows`, her toplam sayaç artışında `counts_total` sorar (olay anında; sonradan geri alma yok).
## Tracker kurulurken enjekte edilir (V21Runs.achievement_rules + diff_of; constructor parametreleri).

var _lord_bound: PackedStringArray = PackedStringArray()
var _by_diff: Dictionary = {}


## `profiles` = RunProfiles.load_default()["profiles"]; boş sözlük = hiçbir kural yok (her şey serbest).
func _init(profiles: Dictionary = {}) -> void:
	var a: Dictionary = profiles.get("achievements", {})
	for id: Variant in a.get("lord_bound_tier_ids", []):
		_lord_bound.append(str(id))
	for diff in RunProfiles.DIFFS:
		if a.get(diff, null) is Dictionary:
			_by_diff[diff] = a[diff]


## "<aile>:<kademe sırası>" kimliği (1 tabanlı), örn. tier_id(&"endure", 4) = "endure:4".
static func tier_id(family: StringName, step: int) -> String:
	return "%s:%d" % [family, step]


## Bu kademe bu zorlukta açılabilir mi? Kolay'da Lord'a bağlı kademeler kapalıdır.
func allows(tier: String, diff: StringName) -> bool:
	var r: Dictionary = _by_diff.get(String(diff), {})
	return not (bool(r.get("block_lord_bound", false)) and _lord_bound.has(tier))


## Bu toplam sayaç (depo anahtarı: runs, play_secs, kills, wins, boss_kills, chars5) bu zorlukta artar mı?
func counts_total(key: StringName, diff: StringName) -> bool:
	var r: Dictionary = _by_diff.get(String(diff), {})
	if str(r.get("totals", "all")) == "all":
		return true
	return key == &"runs" or key == &"play_secs"
