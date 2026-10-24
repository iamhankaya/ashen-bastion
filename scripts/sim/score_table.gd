class_name ScoreTable
extends RefCounted
## Skor tablosu (data/score.json). Şema: docs/data-schema.md. Durum tutmaz; ScoreKeeper bunu okur.
## Dosya yoksa varsayılanlar: puan yok, tek basamak (x1), pencere 180 adım.

const STEPS_PER_SEC := 60

## StringName(düşman id) -> int. Yalnız okuma; sonuca etki eden yerde yinelenmez.
var kill_points: Dictionary = {}
## (min_seri, çarpan), min_seri artan; ilk eleman (0, 1).
var tiers: Array[Vector2i] = [Vector2i(0, 1)]
var window_steps: int = 180
var evolution_bonus: int = 0
var survival_per_sec: int = 0
var lord_bonus: int = 0
var display_cap: int = 99999999


static func from_dict(d: Dictionary) -> ScoreTable:
	var t := ScoreTable.new()
	var kp: Variant = d.get("kill_points", {})
	if kp is Dictionary:
		for k in (kp as Dictionary).keys():
			t.kill_points[StringName(str(k))] = _i(kp[k], 0)
	var st: Variant = d.get("streak", {})
	if st is Dictionary:
		var w: Variant = st.get("window", 3.0)
		t.window_steps = roundi((float(w) if (w is int or w is float) else 3.0) * STEPS_PER_SEC)
		var tr: Variant = st.get("tiers", [])
		if tr is Array and not (tr as Array).is_empty():
			var parsed: Array[Vector2i] = []
			for row in tr:
				if row is Array and (row as Array).size() == 2:
					parsed.append(Vector2i(_i(row[0], 0), _i(row[1], 1)))
			if not parsed.is_empty():
				t.tiers = parsed
	t.evolution_bonus = _i(d.get("evolution_bonus", 0), 0)
	t.survival_per_sec = _i(d.get("survival_per_sec", 0), 0)
	t.lord_bonus = _i(d.get("lord_bonus", 0), 0)
	t.display_cap = _i(d.get("display_cap", 99999999), 99999999)
	return t


## Düşman başına öldürme puanı (kayıt yoksa 0).
func points(type_id: StringName) -> int:
	return int(kill_points.get(StringName(type_id), 0))


## Seri sayısına karşılık gelen çarpan (eşik dahil: >=).
func mult_for(streak: int) -> int:
	var m := 1
	for t in tiers:
		if streak >= t.x:
			m = t.y
	return m


## Bozuk (yanlış tipli) veri yüklemeyi çökertmez; doğrulayıcı hatayı bildirir.
static func _i(v: Variant, fallback: int) -> int:
	return int(v) if (v is int or v is float) else fallback
