class_name MetricSchema
extends RefCounted
## data/achievements/<stat>.json metrik kaydının şema kuralları (sim katmanı; test_b9 yüzünden bu dosyalar başarım sınıf adlarını anmaz).
## Hem GameData doğrulayıcı eklentisi (`StatMetricsValidator`) hem de ctrl'deki kayıt sınıfı bunu kullanır.
## Metrik: {stat, order, icon_family, persist:{total, best}, [tiers, group, goal_text],
##   source:{event, filter:{<etiket alanı>:[değer]}, value:"one"|"payload.<alan>"} | {poll:"time"|"active_slots"} |
##   {finish:"always"|"won", value:"one"|"result.time"}  +  aggregate:"sum"|"max"|"count"  [+ result_max]
##   VEYA  reducer:"<sınıf>" + events:[olay] [+ poll:true] [+ finish:true]}.

## SimBus sinyali -> etiket alanı (StringName argüman) ve tamsayı alanları (sırayla). Tracker'ın dinlediği küme budur.
const EVENTS := {
	"enemy_killed": {"tag": "type_id", "ints": []},
	"level_up": {"tag": "", "ints": ["level"]},
	"score_changed": {"tag": "", "ints": ["score", "mult", "gain"]},
	"reload_started": {"tag": "", "ints": []},
	"streak_changed": {"tag": "", "ints": ["mult"]},
	"pickup_collected": {"tag": "kind_id", "ints": []},
	"player_damaged": {"tag": "", "ints": []},
	"evolution_gained": {"tag": "evo_id", "ints": []},
	"buff_started": {"tag": "kind", "ints": []},
	"buff_ended": {"tag": "kind", "ints": []},
	"bomb_hits": {"tag": "", "ints": ["hits"]},
}
const AGGREGATES: PackedStringArray = ["sum", "max", "count"]
const POLLS: PackedStringArray = ["time", "active_slots"]
const FINISH_WHEN: PackedStringArray = ["always", "won"]
const FINISH_VALUES: PackedStringArray = ["one", "result.time"]
const RESULT_KEYS: PackedStringArray = ["time", "level", "score"]
const VALUE_RE := "^(one|payload\\.[a-z_][a-z0-9_]*)$"
## Eklenti dizini; ikincisi yalnız kuru deneme testlerinin sahte reducer'ı içindir (üretimde dizin yoktur).
const REDUCER_DIRS: PackedStringArray = [
	"res://scripts/ctrl/achievement_reducers/", "res://test/helpers/reducer_fixtures/"
]
const DIR := "res://data/achievements"


## `dir` altındaki *.json dosyalarını dosya adı sırasıyla sözlük olarak okur; okunamayan/sözlük olmayan atlanır
## (GameData yolu hataları ayrıca bildirir). Dizin yoksa boş.
static func read_dir(dir: String = DIR) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var names: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f in names:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if parsed is Dictionary:
			out.append(parsed)
	return out


## "ACH_METRIC: <stat>: <neden>"; boş = geçerli. Sıra deterministiktir (stat sırası, sonra giriş sırası).
static func validate(metrics: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var seen_stats := {}
	var keys := {}  # persist anahtarı -> ilk sahibi stat
	var vre := RegEx.create_from_string(VALUE_RE)
	for m: Dictionary in metrics:
		var stat := str(m.get("stat", ""))
		if stat == "":
			out.append("ACH_METRIC: (statsız): stat boş")
		elif seen_stats.has(stat):
			out.append("ACH_METRIC: %s: yinelenen stat" % stat)
		seen_stats[stat] = true
		if m.has("tiers"):
			_check_tiers(out, stat, m["tiers"])
		_check_source(out, stat, m, vre)
		_check_result_max(out, stat, m)
		_check_persist(out, stat, m, keys)
	return out


static func _check_persist(
	out: PackedStringArray, stat: String, m: Dictionary, keys: Dictionary
) -> void:
	var persist: Variant = m.get("persist", {})
	if not (persist is Dictionary):
		return
	for k in ["total", "best"]:
		var raw: Variant = (persist as Dictionary).get(k, null)
		if not (raw is String) or raw == "":
			continue  # null/yok = bu metrik o değeri tutmaz
		var key: String = raw
		if keys.has(key):
			out.append(
				"ACH_METRIC: %s: persist anahtarı '%s' %s ile çakışıyor" % [stat, key, keys[key]]
			)
		else:
			keys[key] = stat


static func _check_tiers(out: PackedStringArray, stat: String, tiers: Variant) -> void:
	if not (tiers is Array) or (tiers as Array).is_empty():
		out.append("ACH_METRIC: %s: tiers boş" % stat)
		return
	var prev := 0
	for t in tiers:
		if not (t is int or t is float) or t != floorf(t) or int(t) <= prev:
			out.append("ACH_METRIC: %s: tiers artan olmalı (pozitif tamsayılar)" % stat)
			return
		prev = int(t)


static func _check_result_max(out: PackedStringArray, stat: String, m: Dictionary) -> void:
	if m.has("result_max") and not RESULT_KEYS.has(str(m["result_max"])):
		out.append("ACH_METRIC: %s: result_max '%s' bilinmiyor" % [stat, m["result_max"]])


static func _check_source(out: PackedStringArray, stat: String, m: Dictionary, vre: RegEx) -> void:
	var reducer := str(m.get("reducer", ""))
	if reducer != "":
		if m.has("source") or m.has("aggregate"):
			out.append("ACH_METRIC: %s: source/aggregate ile reducer birlikte olamaz" % stat)
		elif not reducer_exists(reducer):
			out.append("ACH_METRIC: %s: reducer '%s' yok" % [stat, reducer])
		else:
			_check_reducer_events(out, stat, m)
		return
	if not (m.get("source", null) is Dictionary) or not m.has("aggregate"):
		out.append("ACH_METRIC: %s: source+aggregate ya da reducer gerekir" % stat)
		return
	var agg := str(m["aggregate"])
	if not AGGREGATES.has(agg):
		out.append("ACH_METRIC: %s: aggregate '%s' bilinmiyor" % [stat, agg])
	var src: Dictionary = m["source"]
	if src.has("poll"):
		if not POLLS.has(str(src["poll"])):
			out.append("ACH_METRIC: %s: poll '%s' bilinmiyor" % [stat, src["poll"]])
	elif src.has("finish"):
		_check_finish(out, stat, src)
	else:
		_check_event(out, stat, src, vre)


static func _check_finish(out: PackedStringArray, stat: String, src: Dictionary) -> void:
	if not FINISH_WHEN.has(str(src["finish"])):
		out.append("ACH_METRIC: %s: finish '%s' bilinmiyor" % [stat, src["finish"]])
	if not FINISH_VALUES.has(str(src.get("value", ""))):
		out.append("ACH_METRIC: %s: value '%s' geçersiz" % [stat, src.get("value", "")])


static func _check_event(out: PackedStringArray, stat: String, src: Dictionary, vre: RegEx) -> void:
	var ev := str(src.get("event", ""))
	var known := EVENTS.has(ev)
	if not known:
		out.append("ACH_METRIC: %s: olay '%s' SimBus'ta yok" % [stat, ev])
	var value := str(src.get("value", ""))
	if vre.search(value) == null:
		out.append("ACH_METRIC: %s: value '%s' geçersiz" % [stat, value])
	elif known and value != "one" and not (EVENTS[ev]["ints"] as Array).has(value.substr(8)):
		out.append("ACH_METRIC: %s: value '%s' olay '%s' alanı değil" % [stat, value, ev])
	var flt: Variant = src.get("filter", {})
	if not (flt is Dictionary):
		out.append("ACH_METRIC: %s: filter sözlük olmalı" % stat)
	elif known:
		_check_filter(out, stat, ev, flt)


static func _check_filter(
	out: PackedStringArray, stat: String, ev: String, flt: Dictionary
) -> void:
	for k in flt:
		var ok: bool = (
			str(k) == EVENTS[ev]["tag"] and flt[k] is Array and not (flt[k] as Array).is_empty()
		)
		if ok:
			for v in flt[k]:
				ok = ok and v is String
		if not ok:
			out.append("ACH_METRIC: %s: filter '%s' olay '%s' için geçersiz" % [stat, k, ev])


static func _check_reducer_events(out: PackedStringArray, stat: String, m: Dictionary) -> void:
	var evs: Variant = m.get("events", [])
	if not (evs is Array):
		out.append("ACH_METRIC: %s: events dizi olmalı" % stat)
		return
	for e in evs:
		if not EVENTS.has(str(e)):
			out.append("ACH_METRIC: %s: olay '%s' SimBus'ta yok" % [stat, e])


## Genel sınıf `REDUCER_DIRS` altında (taban sınıfa uygunluğu tracker kurarken denetler).
static func reducer_exists(cls: String) -> bool:
	for e in ProjectSettings.get_global_class_list():
		if str(e["class"]) == cls:
			for d in REDUCER_DIRS:
				if str(e["path"]).begins_with(d):
					return true
			return false
	return false


## Genel sınıf adından betik yolu; yoksa "".
static func script_path(cls: String) -> String:
	for e in ProjectSettings.get_global_class_list():
		if str(e["class"]) == cls:
			return str(e["path"])
	return ""
