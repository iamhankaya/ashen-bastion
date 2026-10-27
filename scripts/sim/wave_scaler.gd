class_name WaveScaler
extends RefCounted
## Hızlı mod: waves sözlüğünün DERİN kopyasında zaman alanlarını `time_scale` ile ölçekler (kaynak sözlük değişmez).
## Ölçeklenenler: end_time, rate/group `from`/`to`, group `every`, burst/boss `at`, boss `warn`.
## Ölçeklenmeyenler: `rate` değerleri (K-C9; Hızlı'da toplam öldürme ≈ yarı), `group` boyutu, burst `count`.
## Ölçeklenmiş sözlük WavesValidator.validate_dict'ten geçer (`warn <= at`, Lord `at = end_time`).


static func scale(waves: Dictionary, time_scale: float) -> Dictionary:
	var out: Dictionary = waves.duplicate(true)
	if is_equal_approx(time_scale, 1.0):
		return out
	if out.has("end_time"):
		out["end_time"] = float(out["end_time"]) * time_scale
	var rows: Variant = out.get("rows", [])
	if not (rows is Array):
		return out
	for row: Variant in rows:
		if not (row is Dictionary):
			continue
		var r: Dictionary = row
		for key in ["from", "to", "at", "warn"]:
			if r.has(key):
				r[key] = float(r[key]) * time_scale
		if r.has("every") and r["every"] is Array:
			var ev: Array = r["every"]
			for i in ev.size():
				ev[i] = float(ev[i]) * time_scale
	return out
