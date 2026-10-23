class_name EnemyAnim
extends RefCounted
## Düşman hareket tabloları: tür başına `anim` verisi, 256'lık sinüs LUT, slot başına faz/son konum ve iş sayaçları.
## Çizmez; EnemyRenderer pozu okur. Zaman = sim.time (görünüm saati değil): duraklatma/seviye atlama/oyun sonunda
## düşmanlar kendiliğinden donar. Sim'e dokunmaz (havuz alanları salt okunur).

const LUT_SIZE := 256
const CAP := EnemyPool.CAP
## Kare modunda tek adımda en çok bu kadar piksel yürüme fazına yazılır (ışınlanma/geri dönüşüm sıçratmaz).
const MAX_STEP_PX := 60.0
const FLAP_FPS := 12.0
const KIND_NAMES: PackedStringArray = ["none", "crawl", "flap", "float", "stomp"]

enum Kind { NONE, CRAWL, FLAP, FLOAT, STOMP }
## Elit/Lord özel durumları (≤6 örnek): şarj hazırlığı (elit karga) ve Lord çağırma/öfke.
enum Special { NONE, CHARGER, LORD }

static var _lut := PackedFloat32Array()

var last_anim_instances: int = 0
var last_frame_selects: int = 0

# Tür tabloları (type_idx sırası = data.enemy_ids).
var kind_t := PackedInt32Array()
var hz_t := PackedFloat32Array()
var bob_t := PackedFloat32Array()
var rot_t := PackedFloat32Array()  # rad
var sq_t := PackedFloat32Array()
var lean_t := PackedFloat32Array()  # rad
var hover_t := PackedFloat32Array()
var knock_t := PackedFloat32Array()
var hit_sq_t := PackedFloat32Array()
var hit_rot_t := PackedFloat32Array()  # rad
var cycle_t := PackedFloat32Array()
var alpha_lo_t := PackedFloat32Array()
var alpha_hi_t := PackedFloat32Array()
var frames_t := PackedInt32Array()
var special_t := PackedInt32Array()

# Slot başına durum (CAP).
var phase0 := PackedFloat32Array()
var walk := PackedFloat32Array()
var last_pos := PackedVector2Array()
var gen_seen := PackedInt32Array()
var enrage_t0 := PackedFloat32Array()
var step_seen := PackedInt32Array()


func _init() -> void:
	phase0.resize(CAP)
	walk.resize(CAP)
	last_pos.resize(CAP)
	gen_seen.resize(CAP)
	gen_seen.fill(-1)
	enrage_t0.resize(CAP)
	enrage_t0.fill(-1.0)
	step_seen.resize(CAP)
	_ensure_lut()


static func _ensure_lut() -> void:
	if _lut.size() == LUT_SIZE:
		return
	_lut.resize(LUT_SIZE)
	for k in LUT_SIZE:
		_lut[k] = sin(TAU * float(k) / float(LUT_SIZE))


## sin(2π·x) LUT'tan (x: tur sayısı, her değer sarılır); 256 giriş, hata < %2,5.
static func lut_sin(x: float) -> float:
	_ensure_lut()
	return _lut[int(fposmod(x, 1.0) * LUT_SIZE) & (LUT_SIZE - 1)]


## Slot başına hız çarpanı: phase0'dan ±%15.
static func speed_mult(p0: float) -> float:
	return 0.85 + 0.30 * p0


func bind(data: GameData, atlas: EnemyAtlas) -> void:
	for arr in [
		kind_t, frames_t, special_t
	]:
		arr.clear()
	for arr in [
		hz_t,
		bob_t,
		rot_t,
		sq_t,
		lean_t,
		hover_t,
		knock_t,
		hit_sq_t,
		hit_rot_t,
		cycle_t,
		alpha_lo_t,
		alpha_hi_t
	]:
		arr.clear()
	gen_seen.fill(-1)
	last_anim_instances = 0
	last_frame_selects = 0
	if data == null:
		return
	for type_id in data.enemy_ids:
		var def: EnemyDef = data.get_enemy(type_id)
		var a: Dictionary = def.anim if def != null else {}
		var kind := maxi(KIND_NAMES.find(str(a.get("kind", "none"))), 0)
		kind_t.append(kind)
		hz_t.append(float(a.get("hz", 0.0)))
		bob_t.append(float(a.get("bob", 0.0)))
		rot_t.append(deg_to_rad(float(a.get("rot", 0.0))))
		sq_t.append(float(a.get("sq", 0.0)))
		lean_t.append(deg_to_rad(float(a.get("lean", 0.0))))
		hover_t.append(float(a.get("hover", 0.0)))
		knock_t.append(float(a.get("knock", 0.0)))
		hit_sq_t.append(float(a.get("hit_sq", 0.0)))
		hit_rot_t.append(deg_to_rad(float(a.get("hit_rot", 0.0))))
		cycle_t.append(float(a.get("cycle", 72.0)))
		var al: Variant = a.get("alpha", [1.0, 1.0])
		var lo := 1.0
		var hi := 1.0
		if al is Array and al.size() >= 2:
			lo = float(al[0])
			hi = float(al[1])
		alpha_lo_t.append(lo)
		alpha_hi_t.append(hi)
		var fr := 1
		if atlas != null and def != null:
			fr = int((atlas.cells.get(def.sprite, {}) as Dictionary).get("frames", 1))
		frames_t.append(fr)
		var sp := Special.NONE
		if def != null:
			if not def.summon.is_empty():
				sp = Special.LORD
			elif not def.charge.is_empty():
				sp = Special.CHARGER
		special_t.append(sp)


func kind_of(t: int) -> int:
	return kind_t[t] if t >= 0 and t < kind_t.size() else Kind.NONE


func knock_of(t: int) -> float:
	return knock_t[t] if t >= 0 and t < knock_t.size() else 0.0


func hover_of(t: int) -> float:
	return hover_t[t] if t >= 0 and t < hover_t.size() else 0.0


func alpha_lo_of(t: int) -> float:
	return alpha_lo_t[t] if t >= 0 and t < alpha_lo_t.size() else 1.0


func special_of(t: int) -> int:
	return special_t[t] if t >= 0 and t < special_t.size() else Special.NONE


## gen değiştiyse phase0/walk/last_pos ilklenir (slot yeniden kullanımı yeni faz alır).
func sync_slot(i: int, gen: int, pos: Vector2) -> void:
	if i < 0 or i >= CAP or gen_seen[i] == gen:
		return
	gen_seen[i] = gen
	var p0 := float((gen * 2654435761 + i * 40503) & 0xFFFF) / 65536.0
	phase0[i] = p0
	walk[i] = p0
	last_pos[i] = pos
	enrage_t0[i] = -1.0
	step_seen[i] = 0


## Mesafe tabanlı yürüme fazı: walk += min(|Δpos|, 60) / cycle. Konumu değişmeyen düşman ilerlemez.
func advance_walk(i: int, pos: Vector2, cycle: float) -> void:
	var d := minf(pos.distance_to(last_pos[i]), MAX_STEP_PX)
	last_pos[i] = pos
	if d > 0.0 and cycle > 0.0:
		walk[i] += d / cycle


## Karga: [0,1,..,n−1,..,1] ping-pong, 12 kare/sn; slot ofseti p0 (n=3: [0,1,2,1]).
static func flap_frame(frames: int, t: float, p0: float) -> int:
	if frames <= 1:
		return 0
	var len_ := 2 * frames - 2
	var k := (int(t * FLAP_FPS + p0 * float(len_))) % len_
	return k if k < frames else len_ - k


## (theta, sx, sy, bob_px) — ayak noktası etrafında; öteleme (0, −bob). Ham poz: vuruş/lean/özel durum renderer'da biner.
static func pose_of(
	kind: int, hz: float, bob: float, rot_rad: float, sq: float, t: float, phase0_: float
) -> Vector4:
	if kind == Kind.NONE:
		return Vector4(0.0, 1.0, 1.0, 0.0)
	var f := hz * speed_mult(phase0_) * t + phase0_
	var s1 := lut_sin(f)
	var theta := 0.0
	var bob_px := 0.0
	var sy := 1.0
	match kind:
		Kind.CRAWL:
			# topallama: 0,6·sin φ + 0,4·sin 2φ; bob |sin|; adımda squash, havada gerilme
			theta = rot_rad * (0.6 * s1 + 0.4 * lut_sin(2.0 * f))
			var u := absf(lut_sin(f))
			bob_px = bob * u
			sy = 1.0 + sq * (2.0 * u - 1.0)
		Kind.FLAP:
			theta = rot_rad * 0.5 * lut_sin(f * 0.5 + 0.25)
			bob_px = bob * s1
			sy = 1.0 + sq * s1
		Kind.FLOAT:
			theta = rot_rad * lut_sin(f * 0.6)
			bob_px = bob * s1
			sy = 1.0 + sq * lut_sin(f * 1.2857)  # 0,9 Hz "ağır adım" / 0,7 Hz süzülme
		Kind.STOMP:
			theta = rot_rad * s1
			var u2 := absf(lut_sin(f))
			bob_px = bob * u2
			sy = 1.0 + sq * (2.0 * u2 - 1.0)
	return Vector4(theta, 1.0 / sy, sy, bob_px)
