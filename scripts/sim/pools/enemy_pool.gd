class_name EnemyPool
extends RefCounted
## SoA düşman havuzu. enemy_id = (nesil << 16) | indeks. Nesil 16 bit (65536. yeniden kullanımda 0'a döner).
## Havuz sıkıştırılmaz; serbest-liste LIFO (en düşük boş indeks önce). Canlı taramak için `alive[i] == 1`.

const CAP := 400
const GEN_SHIFT := 16
const INDEX_MASK := 0xFFFF

var count: int = 0
var pos: PackedVector2Array = PackedVector2Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var type_idx: PackedInt32Array = PackedInt32Array()
var flash: PackedFloat32Array = PackedFloat32Array()
var gen: PackedInt32Array = PackedInt32Array()
var alive: PackedByteArray = PackedByteArray()
## Düşman başına sabitler (spawn anında türden ve çarpanlardan).
var speed: PackedFloat32Array = PackedFloat32Array()
var contact: PackedFloat32Array = PackedFloat32Array()
var armor: PackedFloat32Array = PackedFloat32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
var max_hp: PackedFloat32Array = PackedFloat32Array()
## Yapay zekâ durumu (elit karga şarjı, Lord çağırması): geri sayım, yardımcı değer, kilitli yön.
var ai_timer: PackedFloat32Array = PackedFloat32Array()
var ai_aux: PackedFloat32Array = PackedFloat32Array()
var ai_dir: PackedVector2Array = PackedVector2Array()

## Tür başına yapay zekâ sınıfı (sıcak yolda def aramasını önler): 0 düz, 1 yer (engelden kayar), 2 özel (şarj/çağırma).
const KIND_PLAIN := 0
const KIND_GROUND := 1
const KIND_SPECIAL := 2
var type_kind: PackedByteArray = PackedByteArray()
var _type_ids: Array[StringName] = []
var _defs: Array[EnemyDef] = []
var _free: PackedInt32Array = PackedInt32Array()


func _init(data: GameData = null) -> void:
	pos.resize(CAP)
	hp.resize(CAP)
	type_idx.resize(CAP)
	flash.resize(CAP)
	gen.resize(CAP)
	alive.resize(CAP)
	speed.resize(CAP)
	contact.resize(CAP)
	armor.resize(CAP)
	radius.resize(CAP)
	max_hp.resize(CAP)
	ai_timer.resize(CAP)
	ai_aux.resize(CAP)
	ai_dir.resize(CAP)
	_free.resize(CAP)
	for k in CAP:
		_free[k] = CAP - 1 - k  # en düşük indeks yığının tepesinde
	if data != null:
		bind(data)


## Tür tablosunu bağlar. type_idx, `data.enemy_ids` içindeki sıradır.
func bind(data: GameData) -> void:
	_type_ids.clear()
	_defs.clear()
	type_kind.clear()
	for id in data.enemy_ids:
		var def := data.get_enemy(id)
		_type_ids.append(id)
		_defs.append(def)
		var k := KIND_PLAIN
		if def.ai == &"ground":
			k = KIND_GROUND
		elif not def.charge.is_empty() or not def.summon.is_empty():
			k = KIND_SPECIAL
		type_kind.append(k)


static func make_id(generation: int, index: int) -> int:
	return ((generation & 0xFFFF) << GEN_SHIFT) | (index & INDEX_MASK)


static func index_of(id: int) -> int:
	return id & INDEX_MASK


static func gen_of(id: int) -> int:
	return (id >> GEN_SHIFT) & 0xFFFF


## -1 = havuz dolu ya da bilinmeyen tür.
func spawn(
	type_id: StringName, p: Vector2, hp_mult: float, contact_mult: float, speed_mult: float
) -> int:
	var t := _type_ids.find(type_id)
	if t < 0 or _free.is_empty():
		return -1
	var def := _defs[t]
	var i: int = _free[_free.size() - 1]
	_free.resize(_free.size() - 1)
	alive[i] = 1
	pos[i] = p
	type_idx[i] = t
	max_hp[i] = def.hp * hp_mult
	hp[i] = max_hp[i]
	flash[i] = 0.0
	speed[i] = def.speed * speed_mult
	contact[i] = def.dmg * contact_mult
	armor[i] = def.armor
	radius[i] = def.radius
	ai_aux[i] = 0.0
	ai_dir[i] = Vector2.ZERO
	if not def.charge.is_empty():
		ai_timer[i] = float(def.charge.get("every", 4.0))
	elif not def.summon.is_empty():
		ai_timer[i] = float(def.summon.get("every", 8.0)) * 0.4  # Lord geldikten kısa süre sonra ilk çağırma
	else:
		ai_timer[i] = 0.0
	count += 1
	return make_id(gen[i], i)


func kill(id: int) -> void:
	if not is_alive(id):
		return
	var i := index_of(id)
	alive[i] = 0
	gen[i] = (gen[i] + 1) & 0xFFFF
	_free.append(i)
	count -= 1


## Nesil uyumsuzluğunda false.
func is_alive(id: int) -> bool:
	var i := index_of(id)
	return i < CAP and alive[i] == 1 and gen[i] == gen_of(id)


func radius_of(id: int) -> float:
	return radius[index_of(id)] if is_alive(id) else 0.0


func def_of(i: int) -> EnemyDef:
	return _defs[type_idx[i]]


func type_id_of(i: int) -> StringName:
	return _type_ids[type_idx[i]]


## Elit/boss mu (hedefleme önceliği).
func is_elite(i: int) -> bool:
	var ai: StringName = _defs[type_idx[i]].ai
	return ai == &"elite" or ai == &"lord"


## Canlı düşman kimlikleri, ARTAN id (sayısal) sırasıyla; query_circle ile aynı kural.
## Dikkat: nesil >= 0x8000 olan id int32'de negatiftir (bir slotun 32768 kez yeniden kullanımı; 20 dk'lık
## oyunda gerçekçi değil). "Eşitlikte en düşük indeks" kuralı id'ye değil index_of(id)'ye bakar.
func alive_ids() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in CAP:
		if alive[i] == 1:
			out.append(make_id(gen[i], i))
	out.sort()
	return out
