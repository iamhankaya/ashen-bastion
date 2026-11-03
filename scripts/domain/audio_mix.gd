class_name AudioMix
extends RefCounted
## Kullanıcı ses yüzdesi -> dB eşlemesi (saf, statik). Algısal eğri: linear_to_db((p/100)^2); %0 = kanal sessiz.
## Kanalın nihai dB'si = kullanıcı seviyesi + AudioDirector'ın anlık payı (duraklatma/duck); tek hesap burada.

const MIN_PCT := 0
const MAX_PCT := 100
const STEP := 5
const SILENT_DB := -80.0


static func clamp_pct(p: float) -> int:
	if is_nan(p):
		return MAX_PCT
	return clampi(int(roundf(p)), MIN_PCT, MAX_PCT)


## 100 -> 0 dB, 0 -> SILENT_DB (kanal ayrıca susturulur), arası monoton artan.
static func pct_to_db(pct: int) -> float:
	var p := clampi(pct, MIN_PCT, MAX_PCT)
	if p <= 0:
		return SILENT_DB
	var lin := float(p) / float(MAX_PCT)
	return linear_to_db(lin * lin)


## Kanal dB'si: kullanıcı seviyesi + `extra_db` (duraklatma/duck). %0'da susturulur (SILENT_DB).
static func bus_db(pct: int, extra_db: float = 0.0) -> float:
	if pct <= 0:
		return SILENT_DB
	return pct_to_db(pct) + extra_db
