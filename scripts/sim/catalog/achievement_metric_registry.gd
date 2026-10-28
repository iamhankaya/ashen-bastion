class_name AchievementMetricRegistry
extends RefCounted
## Başarım metrik tanım kaydı iskeleti (sözleşme-B): data/achievements/<stat>.json tanımlarını doğrular. Tracker/Store
## dönüşümü ve gerçek veri R8'dedir; `default()` şimdilik BOŞ kayıttır (mevcut data/achievements.json başka şemadadır).
## Metrik: {stat, group, tiers:[int], goal_text, icon_family, persist:{total, best},
##   source:{event, filter, value:"one"|"payload.<alan>"} + aggregate:"sum"|"max"|"count"  VEYA  reducer:"<sınıf>"}.
## Veriyle eklenebilir = mevcut SimEvents olayı + yerleşik toplam; yeni olay/durumlu koşul = reducer (kod).

const AGGREGATES: PackedStringArray = ["sum", "max", "count"]
const VALUE_RE := "^(one|payload\\.[a-z_][a-z0-9_]*)$"

var _metrics: Array = []  # stat sıralı ham girdiler (yinelenenler dahil; validate bildirir)


static func default() -> AchievementMetricRegistry:
	return from_dicts([])


static func from_dicts(metrics: Array) -> AchievementMetricRegistry:
	var r := AchievementMetricRegistry.new()
	for m in metrics:
		if m is Dictionary:
			r._metrics.append(m)
	r._metrics.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("stat", "")) < str(b.get("stat", ""))
	)
	return r


## "ACH_METRIC: <stat>: <neden>"; boş = geçerli. Sıra deterministiktir (stat sırası).
func validate() -> PackedStringArray:
	var out := PackedStringArray()
	var stats := {}
	var keys := {}  # persist anahtarı -> ilk sahibi stat
	var events := _event_names()
	var vre := RegEx.create_from_string(VALUE_RE)
	for m in _metrics:
		var stat := str(m.get("stat", ""))
		if stat == "":
			out.append("ACH_METRIC: (statsız): stat boş")
		elif seen_stats.has(stat):
			out.append("ACH_METRIC: %s: yinelenen stat" % stat)
		seen_stats[stat] = true
		_check_tiers(out, stat, m.get("tiers", null))
		_check_source(out, stat, m, events, vre)
		var persist: Variant = m.get("persist", {})
		if not (persist is Dictionary):
			continue
		for k in ["total", "best"]:
			var key := str((persist as Dictionary).get(k, ""))
			if key == "":
				continue
			if keys.has(key):
				out.append(
					(
						"ACH_METRIC: %s: persist anahtarı '%s' %s ile çakışıyor"
						% [stat, key, keys[key]]
					)
				)
			else:
				keys[key] = stat
	return out


func stats() -> PackedStringArray:
	var out := PackedStringArray()
	for m in _metrics:
		if not out.has(str(m.get("stat", ""))):
			out.append(str(m.get("stat", "")))
	return out


## Bilinmeyen stat => {}.
func metric(stat: String) -> Dictionary:
	for m in _metrics:
		if str(m.get("stat", "")) == stat:
			return m
	return {}


## Tüm metriklerin kademe toplamı ("53" sabiti testlerden bu türetmeye geçecek).
func total_tiers() -> int:
	var n := 0
	for m in _metrics:
		var t: Variant = m.get("tiers", [])
		n += (t as Array).size() if t is Array else 0
	return n


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


static func _check_source(
	out: PackedStringArray, stat: String, m: Dictionary, events: PackedStringArray, vre: RegEx
) -> void:
	var reducer := str(m.get("reducer", ""))
	if reducer != "":
		if m.has("source") or m.has("aggregate"):
			out.append("ACH_METRIC: %s: source/aggregate ile reducer birlikte olamaz" % stat)
		elif not _reducer_exists(reducer):
			out.append("ACH_METRIC: %s: reducer '%s' yok" % [stat, reducer])
		return
	if not (m.get("source", null) is Dictionary) or not m.has("aggregate"):
		out.append("ACH_METRIC: %s: source+aggregate ya da reducer gerekir" % stat)
		return
	var agg := str(m["aggregate"])
	if not AGGREGATES.has(agg):
		out.append("ACH_METRIC: %s: aggregate '%s' bilinmiyor" % [stat, agg])
	var src: Dictionary = m["source"]
	var ev := str(src.get("event", ""))
	if not events.has(ev):
		out.append("ACH_METRIC: %s: olay '%s' SimEvents'te yok" % [stat, ev])
	var value := str(src.get("value", ""))
	if vre.search(value) == null:
		out.append("ACH_METRIC: %s: value '%s' geçersiz" % [stat, value])


## SimEvents sabitlerinin değerleri (olay türleri).
static func _event_names() -> PackedStringArray:
	var out := PackedStringArray()
	for v in (SimEvents as GDScript).get_script_constant_map().values():
		if v is StringName or v is String:
			out.append(str(v))
	return out


## Zincir `extends` ile kökte AchievementReducer'a varan genel sınıf (kendisi de geçerli).
static func _reducer_exists(cls: String) -> bool:
	var parent := {}
	for e in ProjectSettings.get_global_class_list():
		parent[str(e["class"])] = str(e["base"])
	var cur := cls
	for _i in 16:
		if cur == "AchievementReducer":
			return true
		if not parent.has(cur):
			return false
		cur = parent[cur]
	return false
