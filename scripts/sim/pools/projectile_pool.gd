class_name ProjectilePool
extends RefCounted
## SoA mermi havuzu (kompakt: canlılar 0..count-1, ölen son elemanla yer değiştirir; çıkarma için
## ters sırayla gezin). Mermi başına vurulan düşman kümesi (HIT_SLOTS halka tampon).

const CAP := 600
const HIT_SLOTS := 12

# flags (bit maskesi)
const FLAG_EXPLODES := 1  # isabette
const FLAG_EXPLODE_ON_EXPIRE := 2  # dinamit
const FLAG_EXPLODE_ON_BOUNCE := 4  # zincirleme_patlama
const FLAG_RICOCHET := 8
const FLAG_RADIAL := 16  # yalnız görsel
const FLAG_LOB := 32  # yay atış (dinamit): düşmana çarpmaz, ömrü bitince patlar
const FLAG_SHRAPNEL := 64  # şarapnel parçası: öldürdüğü düşman yeniden şarapnel saçmaz

const DEFAULT_LIFE := 1.2

var count: int = 0
var pos: PackedVector2Array = PackedVector2Array()
var vel: PackedVector2Array = PackedVector2Array()
var dmg: PackedFloat32Array = PackedFloat32Array()
var life: PackedFloat32Array = PackedFloat32Array()
var flags: PackedInt32Array = PackedInt32Array()
var pierce: PackedInt32Array = PackedInt32Array()
var bounces: PackedInt32Array = PackedInt32Array()
var ex_radius: PackedFloat32Array = PackedFloat32Array()
var ex_dmg: PackedFloat32Array = PackedFloat32Array()
var push: PackedFloat32Array = PackedFloat32Array()
var gun: PackedInt32Array = PackedInt32Array()
var hit_n: PackedInt32Array = PackedInt32Array()  # toplam işaretleme sayısı (halka tampon yazım sayacı)
var hit_ids: PackedInt32Array = PackedInt32Array()  # CAP * HIT_SLOTS


func _init() -> void:
	pos.resize(CAP)
	vel.resize(CAP)
	dmg.resize(CAP)
	life.resize(CAP)
	flags.resize(CAP)
	pierce.resize(CAP)
	bounces.resize(CAP)
	ex_radius.resize(CAP)
	ex_dmg.resize(CAP)
	push.resize(CAP)
	gun.resize(CAP)
	hit_n.resize(CAP)
	hit_ids.resize(CAP * HIT_SLOTS)


## o: pierce:int, bounces:int, life:float (=1.2), flags:int, ex_radius, ex_dmg, push:float, gun:int
## Dönen değer mermi indeksidir (çıkarma olana kadar geçerli). -1 = havuz dolu.
func spawn(p: Vector2, v: Vector2, damage: float, o: Dictionary = {}) -> int:
	if count >= CAP:
		return -1
	var i := count
	count += 1
	pos[i] = p
	vel[i] = v
	dmg[i] = damage
	life[i] = float(o.get("life", DEFAULT_LIFE))
	flags[i] = int(o.get("flags", 0))
	pierce[i] = int(o.get("pierce", 0))
	bounces[i] = int(o.get("bounces", 0))
	ex_radius[i] = float(o.get("ex_radius", 0.0))
	ex_dmg[i] = float(o.get("ex_dmg", 0.0))
	push[i] = float(o.get("push", 0.0))
	gun[i] = int(o.get("gun", 0))
	hit_n[i] = 0
	return i


## Son mermiyi i'ye taşıyıp havuzu küçültür. Ters sırayla gezen döngüde güvenlidir.
func remove(i: int) -> void:
	var last := count - 1
	if i < 0 or i > last:
		return
	if i != last:
		pos[i] = pos[last]
		vel[i] = vel[last]
		dmg[i] = dmg[last]
		life[i] = life[last]
		flags[i] = flags[last]
		pierce[i] = pierce[last]
		bounces[i] = bounces[last]
		ex_radius[i] = ex_radius[last]
		ex_dmg[i] = ex_dmg[last]
		push[i] = push[last]
		gun[i] = gun[last]
		hit_n[i] = hit_n[last]
		for k in HIT_SLOTS:
			hit_ids[i * HIT_SLOTS + k] = hit_ids[last * HIT_SLOTS + k]
	count = last


func has_hit(pid: int, enemy_id: int) -> bool:
	var n := mini(hit_n[pid], HIT_SLOTS)
	for k in n:
		if hit_ids[pid * HIT_SLOTS + k] == enemy_id:
			return true
	return false


## Halka tampon: 12'den fazla düşmana vuran (delici) mermide en eski kayıt unutulur.
func mark_hit(pid: int, enemy_id: int) -> void:
	hit_ids[pid * HIT_SLOTS + (hit_n[pid] % HIT_SLOTS)] = enemy_id
	hit_n[pid] += 1
