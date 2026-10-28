class_name SimSignalBinder
extends RefCounted
## GameController sim olay bağlantıları (R4): (sinyal, Callable) tablosu bir yerde; bağlama ve çözme aynı tablodan.
## Hedefler controller metotları KALIR (sinyal üçlüsü karakterizasyonu: hedef türü + metot adı değişmez).
## Yeni sim bağlanmadan önce `release()` eskinin bağlantılarını çözer; bağlama sırası tablo sırasıdır.

var _pairs: Array
var _sim: GameSim = null


func _init(pairs: Array) -> void:
	_pairs = pairs


func release() -> void:
	if _sim != null:
		for p in _pairs:
			if _sim.bus.is_connected(p[0], p[1]):
				_sim.bus.disconnect(p[0], p[1])
	_sim = null


## sim null olabilir (menüye dönüş): hiçbir şey bağlanmaz.
func attach(new_sim: GameSim) -> void:
	_sim = new_sim
	if new_sim == null:
		return
	for p in _pairs:
		new_sim.bus.connect(p[0], p[1])
