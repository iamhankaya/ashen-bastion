class_name HitStop
extends RefCounted
## Vuruş donması (saf). Donarken sim ADIMLANMAZ ve zaman birikimi (_accum) artmaz: sim adım sayısı etkilenmez,
## determinizm bozulmaz. İstekler: bomba 0,06; Lord öfkesi 0,08; Lord ölümü 0,15 sn (tavan MAX_SEC).

const MAX_SEC := 0.15

var left: float = 0.0


## max(mevcut, min(sn, MAX_SEC)).
func request(sec: float) -> void:
	left = maxf(left, minf(sec, MAX_SEC))


## true = bu karede donuk (sim adımlanmaz). Her çağrı kalan süreden dt düşer.
func tick(dt: float) -> bool:
	if left <= 0.0:
		return false
	left = maxf(0.0, left - maxf(dt, 0.0))
	return true
