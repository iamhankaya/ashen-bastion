class_name StatMetricsValidator
extends DataValidator
## data/achievements/<stat>.json metrik kaydı doğrulayıcısı (R8; docs/data-schema.md `### Başarım metrik kaydı`).
## Şema kuralları `MetricSchema`'da; burada dosya adı=stat, JSON nesnesi olma ve aile statlarının metriği olması bakılır.


func validator_order() -> int:
	return 100


func validator_id() -> StringName:
	return &"stat_metrics"


func run(g: GameData, out: PackedStringArray, _complete: bool) -> void:
	var metrics: Array = []
	for e in g._raw_metrics:
		var ctx: String = str(e["file"])
		var d: Variant = e["data"]
		if e.get("failed", false) or d == null:
			continue  # bad_json load_errors'ta bildirildi
		if not (d is Dictionary):
			GameData._err(out, "metric_schema", ctx, "kayıt nesne olmalı")
			continue
		if ctx.get_file().get_basename() != str(d.get("stat", "")):
			GameData._err(out, "metric_schema", ctx, "dosya adı stat ile aynı olmalı")
		metrics.append(d)
	for line in MetricSchema.validate(metrics):
		out.append(_coded(line))
	if metrics.is_empty():
		return  # dizin yok/boş: metrik kaydı kullanılmıyor (eski veri kökleri)
	var known := {}
	for m: Dictionary in metrics:
		known[str(m.get("stat", ""))] = true
	for d in g.achievements:
		if not known.has(str(d.stat)):
			GameData._err(
				out,
				"metric_schema",
				"achievements.json",
				"aile '%s' için '%s' statının metriği yok" % [d.id, d.stat]
			)


## "ACH_METRIC: <stat>: <neden>" -> "[metric_schema] achievements/<stat>: <neden>".
static func _coded(line: String) -> String:
	var body := line.trim_prefix("ACH_METRIC: ")
	var cut := body.find(": ")
	return "[metric_schema] achievements/%s: %s" % [body.substr(0, cut), body.substr(cut + 2)]
