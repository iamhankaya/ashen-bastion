class_name AchievementMetricRegistry
extends RefCounted
## Başarım metrik tanım kaydı: data/achievements/<stat>.json kayıtları (R8). Şema kuralları sim tarafındaki `MetricSchema`'da
## (test_b9: scripts/sim bu sınıf adlarını anmaz; kayıt bu yüzden ctrl'de, F-ashen-bastion-121). Tracker bunun üzerinden çalışır.
## Metrik: {stat, order, icon_family, persist:{total, best}, [tiers, group, goal_text],
##   source:{event, filter, value} | {poll} | {finish, value} + aggregate  VEYA  reducer + events [+ poll] [+ finish]}.
## Veriyle eklenebilir = mevcut SimBus olayı/poll/finish + yerleşik toplam; durumlu koşul = `AchievementReducer` alt sınıf dosyası.

var _metrics: Array = []  # stat sıralı ham girdiler (yinelenenler dahil; validate bildirir)


## Gerçek veri: res://data/achievements/*.json.
static func default() -> AchievementMetricRegistry:
	return from_dicts(MetricSchema.read_dir())


static func from_dicts(metrics: Array) -> AchievementMetricRegistry:
	var r := AchievementMetricRegistry.new()
	for m in metrics:
		if m is Dictionary:
			r._metrics.append(m)
	var keyed: Array = []
	for i in r._metrics.size():
		keyed.append([str(r._metrics[i].get("stat", "")), i])
	keyed.sort()  # (stat, giriş sırası): yinelenenlerde de deterministik
	var sorted: Array = []
	for k in keyed:
		sorted.append(r._metrics[k[1]])
	r._metrics = sorted
	return r


## "ACH_METRIC: <stat>: <neden>"; boş = geçerli. Sıra deterministiktir (stat sırası).
func validate() -> PackedStringArray:
	return MetricSchema.validate(_metrics)


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
