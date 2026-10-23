class_name ResultTimeline
extends RefCounted
## Sonuç ekranı zaman çizelgesi (saf yardımcı): sayma 0,9 sn, satır aralığı 0,12 sn, damga 1,25 sn, düğme 1,3 sn.
## Süreler Motion'dadır. İskelet (S3): gövde D3-4'te dolar.

@warning_ignore_start("unused_parameter")


## Düğmelerin hazır olduğu an (sn). skip_t < 0 = atlanmadı (1,3); atlandıysa min(1,3, max(0,8, skip_t + 0,4)).
static func buttons_ready_at(skip_t: float) -> float:
	Stub.todo(&"ResultTimeline.buttons_ready_at")
	return 0.0
