class_name Magazine
extends RefCounted
## Ortak şarjör ve doldurma durum makinesi. Kurallar: plan "Magazine (kesin kurallar)".

signal changed(count: int, cap: int)
signal reload_started(duration: float)
signal reload_finished

const MIN_RELOAD := 0.35

var count: int = 6
var cap: int = 6
var reloading: bool = false
var reload_left: float = 0.0
var reload_total: float = 0.0
## Karakter verisinden gelen temel doldurma süresi (sn).
var base_reload: float = 1.0
## kiyamet_mermisi: doldurma döngüsü başına bir geri yazma; reload_finished'te false olur.
var refund_used: bool = false
## Sınırsız şarjör (Sonsuz Tambur): sayaç düşmez, doldurma yok, ritim döngüsü (indeks 1..cap) sürer.
var unlimited: bool = false

var _loop_index: int = 1


func can_fire() -> bool:
	return count > 0 and not reloading


## {"ok": bool, "index": int (1..cap), "is_last": bool}
func consume() -> Dictionary:
	if not can_fire():
		return {"ok": false, "index": 0, "is_last": false}
	if unlimited:
		var idx := _loop_index if _loop_index <= cap else 1
		_loop_index = idx % cap + 1
		return {"ok": true, "index": idx, "is_last": idx == cap}
	var index := cap - count + 1
	count -= 1
	changed.emit(count, cap)
	return {"ok": true, "index": index, "is_last": count == 0}


## Doldurma sürerken yok sayılır.
func refund(n: int) -> void:
	if reloading or n <= 0 or unlimited:
		return
	count = mini(cap, count + n)
	changed.emit(count, cap)


## Boşalınca doldurma bir SONRAKİ adımın başında (tick) otomatik başlar.
func tick(dt: float, stats: StatBlock) -> void:
	if unlimited:
		return
	if reloading:
		reload_left -= dt
		if reload_left <= 0.0:
			reload_left = 0.0
			reloading = false
			count = cap
			refund_used = false
			changed.emit(count, cap)
			reload_finished.emit()
	elif count == 0:
		start_reload(stats)


func start_reload(stats: StatBlock) -> void:
	if reloading or unlimited:
		return
	reloading = true
	reload_total = maxf(MIN_RELOAD, base_reload * stats.reload_time_mult)
	reload_left = reload_total
	reload_started.emit(reload_total)
	changed.emit(count, cap)


## StatBlock değişince sim çağırır. Artış anında mermi olarak eklenir (doldurma sürüyorsa bitişte zaten dolar).
func set_cap(new_cap: int) -> void:
	if new_cap == cap:
		return
	if new_cap > cap:
		if not reloading:
			count += new_cap - cap
	else:
		count = mini(count, new_cap)
	cap = new_cap
	changed.emit(count, cap)


func reset_cycle_flags() -> void:
	refund_used = false


## Sınırsız modu açar/kapatır. Açılışta doldurma iptal edilir (count = cap, reload_finished yayınlanır) ve ritim
## döngüsü kaldığı yerden (cap − count + 1; doldururken 1) sürer; kapanışta count = cap, doldurma tetiklenmez.
func set_unlimited(on: bool) -> void:
	if on == unlimited:
		return
	unlimited = on
	if on:
		var was_reloading := reloading
		_loop_index = 1 if (was_reloading or count <= 0) else clampi(cap - count + 1, 1, cap)
		reloading = false
		reload_left = 0.0
		count = cap
		changed.emit(count, cap)
		if was_reloading:
			refund_used = false
			reload_finished.emit()
	else:
		count = cap
		changed.emit(count, cap)
