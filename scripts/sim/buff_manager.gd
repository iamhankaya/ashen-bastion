class_name BuffManager
extends RefCounted
## Üç süreli etki (hasar, atış hızı, sınırsız şarjör): kalan adım, yenileme, bitiş. Stat hesaplamaz.
## Süreler tam sayı ADIM'dır (roundi(sn × 60)).

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


## true = yeni etki, false = yenileme (süre tazelenir, yığılmaz; çarpan güncellenir).
func start(kind: int, duration_steps: int, m: float = 1.0) -> bool:
	duration_steps = maxi(duration_steps, 1)
	var fresh := left_steps[kind] <= 0
	left_steps[kind] = duration_steps
	total_steps[kind] = duration_steps
	mult[kind] = m
	return fresh


func active(kind: int) -> bool:
	return left_steps[kind] > 0


## left/total, 0..1.
func ratio(kind: int) -> float:
	if total_steps[kind] <= 0:
		return 0.0
	return clampf(float(left_steps[kind]) / float(total_steps[kind]), 0.0, 1.0)


## Bitenlerin Kind'ı ended'e yazılır (önce temizlenir).
func tick(ended: PackedInt32Array) -> void:
	ended.clear()
	for k in COUNT:
		if left_steps[k] > 0:
			left_steps[k] -= 1
			if left_steps[k] == 0:
				ended.append(k)


func damage_mult() -> float:
	return mult[Kind.DAMAGE] if left_steps[Kind.DAMAGE] > 0 else 1.0


func fire_rate_mult() -> float:
	return mult[Kind.FIRE_RATE] if left_steps[Kind.FIRE_RATE] > 0 else 1.0


func unlimited() -> bool:
	return left_steps[Kind.UNLIMITED] > 0
