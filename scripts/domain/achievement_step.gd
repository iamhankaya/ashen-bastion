class_name AchievementStep
extends RefCounted
## Kademe aritmetiği (v2.0.3). Saf: tanım + değer; depo ve ekran bilmez. Eşikler `AchievementDef.thresholds()`.

const ROMAN: PackedStringArray = ["", "I", "II", "III", "IV", "V"]


## Kademe sayısı (v2.0 kaydı = 1, eşiksiz = 0).
static func total(def: AchievementDef) -> int:
	return def.thresholds().size() if def != null else 0


## `value`ın geçtiği kademe sayısı (0..total).
static func reached(def: AchievementDef, value: int) -> int:
	var n := 0
	if def == null:
		return n
	for t in def.thresholds():
		if value >= t:
			n += 1
	return n


## `done` kademe tamamsa sıradaki eşik; ailede kalan yoksa 0.
static func next_target(def: AchievementDef, done: int) -> int:
	var th := def.thresholds()
	return th[done] if done >= 0 and done < th.size() else 0


## 1..5 -> "I".."V"; aralık dışı "".
static func roman(n: int) -> String:
	return ROMAN[n] if n >= 0 and n < ROMAN.size() else ""
