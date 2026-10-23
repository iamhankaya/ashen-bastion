class_name BuffManager
extends RefCounted
## Üç süreli etki (hasar, atış hızı, sınırsız şarjör): kalan adım, yenileme, bitiş. Stat hesaplamaz.
## Süreler tam sayı ADIM'dır (roundi(sn × 60)). İskelet (S2): alanlar, kind_of/name_of ve any_active gerçek;
## geri kalanı D2-1'de dolar.

enum Kind { DAMAGE, FIRE_RATE, UNLIMITED }

const COUNT := 3
const NAMES: Array[StringName] = [&"damage", &"fire_rate", &"unlimited"]

var left_steps: PackedInt32Array = PackedInt32Array()
var total_steps: PackedInt32Array = PackedInt32Array()
var mult: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	left_steps.resize(COUNT)
	total_steps.resize(COUNT)
	mult.resize(COUNT)
	mult.fill(1.0)


@warning_ignore_start("unused_parameter")


## "damage"|"fire_rate"|"unlimited" -> Kind; yoksa -1.
static func kind_of(name: String) -> int:
	return NAMES.find(StringName(name))


static func name_of(kind: int) -> StringName:
	return NAMES[kind] if kind >= 0 and kind < COUNT else &""


## Herhangi bir etki sürüyor mu (sim bunu D2 gövdelerine boşta girmemek için sorar).
func any_active() -> bool:
	for k in COUNT:
		if left_steps[k] > 0:
			return true
	return false


## true = yeni etki, false = yenileme (süre tazelenir, yığılmaz).
func start(kind: int, duration_steps: int, m: float = 1.0) -> bool:
	Stub.todo(&"BuffManager.start")
	return false


func active(kind: int) -> bool:
	Stub.todo(&"BuffManager.active")
	return false


## left/total, 0..1.
func ratio(kind: int) -> float:
	Stub.todo(&"BuffManager.ratio")
	return 0.0


## Bitenlerin Kind'ı ended'e yazılır (önce temizlenir).
func tick(ended: PackedInt32Array) -> void:
	ended.clear()
	if not any_active():
		return
	Stub.todo(&"BuffManager.tick")


func damage_mult() -> float:
	Stub.todo(&"BuffManager.damage_mult")
	return 1.0


func fire_rate_mult() -> float:
	Stub.todo(&"BuffManager.fire_rate_mult")
	return 1.0


func unlimited() -> bool:
	Stub.todo(&"BuffManager.unlimited")
	return false
