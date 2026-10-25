class_name ZonePool
extends RefCounted
## Alan bölgeleri havuzu (v2.0.2 rüzgar: Hortum, Hava Cebi, Tufan). SoA, kompakt: canlılar 0..count-1, ölen son elemanla
## yer değiştirir (çıkarma için ters sırayla gezin). `gen` artan kimliktir: indeks kararsız olduğundan bölgeye kalıcı
## başvuru `index_of_gen` ile çözülür. Girdap bölge DEĞİLDİR (davranış içinde, KIND_RING yok).

const CAP := 64
## KIND_POCKET yalnız count < CAP - RESERVE iken doğar (Hava Cebi zinciri Tufan/Hortum'u dışarıda bırakamaz).
const RESERVE := 8
const KIND_TWISTER := 1
const KIND_POCKET := 2
const KIND_GIANT := 3

var count: int = 0
var gen: PackedInt32Array = PackedInt32Array()
var kind: PackedInt32Array = PackedInt32Array()
var pos: PackedVector2Array = PackedVector2Array()
var vel: PackedVector2Array = PackedVector2Array()
var target: PackedVector2Array = PackedVector2Array()
var radius: PackedFloat32Array = PackedFloat32Array()
var life: PackedFloat32Array = PackedFloat32Array()
var tick_every: PackedFloat32Array = PackedFloat32Array()
var tick_left: PackedFloat32Array = PackedFloat32Array()
var dmg: PackedFloat32Array = PackedFloat32Array()
var pull: PackedFloat32Array = PackedFloat32Array()
var push: PackedFloat32Array = PackedFloat32Array()
var fling: PackedFloat32Array = PackedFloat32Array()
var retarget_left: PackedFloat32Array = PackedFloat32Array()
## Hortum/Tufan hareketi (U3): hız px/sn, oyuncudan en fazla uzaklık, elit/Lord tik çarpanı (hash'e girmez: tohumdan türer).
var speed: PackedFloat32Array = PackedFloat32Array()
var max_dist: PackedFloat32Array = PackedFloat32Array()
var boss_mult: PackedFloat32Array = PackedFloat32Array()
## Yeniden hedefleme aralığı (sn); 0 = türe göre WindSystem.DEFAULT_RETARGET.
var retarget_every: PackedFloat32Array = PackedFloat32Array()

var _next_gen: int = 1


func _init() -> void:
	gen.resize(CAP)
	kind.resize(CAP)
	pos.resize(CAP)
	vel.resize(CAP)
	target.resize(CAP)
	radius.resize(CAP)
	life.resize(CAP)
	tick_every.resize(CAP)
	tick_left.resize(CAP)
	dmg.resize(CAP)
	pull.resize(CAP)
	push.resize(CAP)
	fling.resize(CAP)
	retarget_left.resize(CAP)
	speed.resize(CAP)
	max_dist.resize(CAP)
	boss_mult.resize(CAP)
	retarget_every.resize(CAP)


## o: radius, life, tick_every, dmg, pull, push, fling, retarget (sn, ilk bekleme), retarget_every (sn), speed, max_dist, boss_mult (=1), vel:Vector2,
## target:Vector2 (hepsi isteğe bağlı, yok = 0). İlk tik `tick_every` sonra. Dönen değer bölge indeksidir (çıkarma olana kadar geçerli).
## -1 = dolu ya da rezerv (KIND_POCKET count >= CAP - RESERVE iken). Sessiz değildir: çağıran
## `WindSystem.spawn_zone` `sim.fx.zone_dropped` sayacını artırır.
func spawn(k: int, p: Vector2, o: Dictionary = {}) -> int:
	var limit := CAP - RESERVE if k == KIND_POCKET else CAP
	if count >= limit:
		return -1
	var i := count
	count += 1
	gen[i] = _next_gen
	_next_gen += 1
	kind[i] = k
	pos[i] = p
	vel[i] = o.get("vel", Vector2.ZERO)
	target[i] = o.get("target", p)
	radius[i] = float(o.get("radius", 0.0))
	life[i] = float(o.get("life", 0.0))
	tick_every[i] = float(o.get("tick_every", 0.0))
	tick_left[i] = tick_every[i]
	dmg[i] = float(o.get("dmg", 0.0))
	pull[i] = float(o.get("pull", 0.0))
	push[i] = float(o.get("push", 0.0))
	fling[i] = float(o.get("fling", 0.0))
	retarget_left[i] = float(o.get("retarget", 0.0))
	speed[i] = float(o.get("speed", 0.0))
	max_dist[i] = float(o.get("max_dist", 0.0))
	boss_mult[i] = float(o.get("boss_mult", 1.0))
	retarget_every[i] = float(o.get("retarget_every", 0.0))
	return i


## Son bölgeyi i'ye taşıyıp havuzu küçültür. Ters sırayla gezen döngüde güvenlidir.
func remove(i: int) -> void:
	var last := count - 1
	if i < 0 or i > last:
		return
	if i != last:
		gen[i] = gen[last]
		kind[i] = kind[last]
		pos[i] = pos[last]
		vel[i] = vel[last]
		target[i] = target[last]
		radius[i] = radius[last]
		life[i] = life[last]
		tick_every[i] = tick_every[last]
		tick_left[i] = tick_left[last]
		dmg[i] = dmg[last]
		pull[i] = pull[last]
		push[i] = push[last]
		fling[i] = fling[last]
		retarget_left[i] = retarget_left[last]
		speed[i] = speed[last]
		max_dist[i] = max_dist[last]
		boss_mult[i] = boss_mult[last]
		retarget_every[i] = retarget_every[last]
	count = last


## `gen` kimlikli bölgenin güncel indeksi; yoksa (ömrü bitti) -1.
func index_of_gen(g: int) -> int:
	for i in count:
		if gen[i] == g:
			return i
	return -1


## state_hash için: count 0 => boş dizi. Bölge başına: gen, kind, q(pos.x), q(pos.y), q(life), q(radius),
## q(tick_left); q = 1/HASH_QUANT px nicemleme (GameSim ile aynı).
func hash_items() -> PackedInt64Array:
	var h := PackedInt64Array()
	for i in count:
		h.append(gen[i])
		h.append(kind[i])
		h.append(_q(pos[i].x))
		h.append(_q(pos[i].y))
		h.append(_q(life[i]))
		h.append(_q(radius[i]))
		h.append(_q(tick_left[i]))
	return h


static func _q(v: float) -> int:
	return roundi(v * GameSim.HASH_QUANT)
