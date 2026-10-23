class_name ResultTimeline
extends RefCounted
## Sonuç ekranı zaman çizelgesi (saf yardımcı): sayma 0,9 sn, satır aralığı 0,12 sn, damga 1,25 sn, düğme 1,3 sn.
## Süreler Motion'dadır (DESIGN §5.3). Dokunma (skip) görünümü hemen bitirir; düğmeler yine de kısa bir kilitle açılır.

const ROW_START := 0.3
const ROW_COUNT := 0.4
const SKIP_LOCK := 0.4
const MIN_BUTTONS_AFTER_SKIP := 0.8


static func count_sec() -> float:
	return Motion.sec(Motion.RESULT_COUNT)


static func stagger_sec() -> float:
	return Motion.sec(Motion.RESULT_ROW_STAGGER)


static func stamp_at() -> float:
	return Motion.sec(Motion.RESULT_STAMP_AT)


static func buttons_at() -> float:
	return Motion.sec(Motion.RESULT_BUTTONS)


## Düğmelerin hazır olduğu an (sn). skip_t < 0 = atlanmadı (1,3); atlandıysa min(1,3, max(0,8, skip_t + 0,4)).
static func buttons_ready_at(skip_t: float) -> float:
	if skip_t < 0.0:
		return buttons_at()
	return minf(buttons_at(), maxf(MIN_BUTTONS_AFTER_SKIP, skip_t + SKIP_LOCK))


## Skor sayacı ilerlemesi 0..1 (cubic-out, 900 ms).
static func count_progress(t: float) -> float:
	return cubic_out(t / count_sec())


## i. döküm satırının giriş ilerlemesi 0..1: 300 ms'den başlar, 120 ms arayla, her değer 400 ms sayar.
static func row_progress(i: int, t: float) -> float:
	return cubic_out((t - row_start(i)) / ROW_COUNT)


static func row_start(i: int) -> float:
	return ROW_START + float(i) * stagger_sec()


static func cubic_out(k: float) -> float:
	var c := clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)
