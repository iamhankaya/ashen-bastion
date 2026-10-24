class_name ShowcaseMotion
extends RefCounted
## Vitrin hareketi (saf, sim/RNG yok): portre nefesi, yatay sürüklenme, geçiş süresi. Tasarım §4 (D3).

const BREATH_SEC := 2.4
const BREATH_MAX := 0.015
const DRIFT_SEC := 6.0
const DRIFT_PX := 8.0
## Portre çapraz solması (kart şeridi odak değişimi; "260 ms geçiş" budur).
const CROSSFADE_SEC := 0.26


## 1.0 .. 1.0 + BREATH_MAX; t = 0'da 1.0 (sinüs, BREATH_SEC periyot).
static func scale_at(t: float) -> float:
	return 1.0 + BREATH_MAX * 0.5 * (1.0 - cos(TAU * t / BREATH_SEC))


## -DRIFT_PX .. +DRIFT_PX; t = 0'da 0 (sinüs, DRIFT_SEC periyot).
static func drift_at(t: float) -> float:
	return DRIFT_PX * sin(TAU * t / DRIFT_SEC)
