class_name PlayerAnim
extends RefCounted
## Oyuncu rig durum makinesi ve prosedürel katmanlar (saf: Node bilmez). Çıktı = aşağıdaki poz alanları;
## PlayerView bunları Rig düğümüne uygular. Değerler DESIGN §1.2 (P1–P13), süreler Motion'dan.
## Açılar radyan, uzunluklar dünya pikseli. Tek karakter: sabitler const (YAGNI), kare sayısı/adım verisi `configure`.
## Sim'e dokunmaz; zaman = çağıranın verdiği dt (PlayerView görünüm saati; duraklatmada dt = 0 gelir).

enum Mode { IDLE, WALK, DEAD }

const GOLD := Color("#E8A24A")
const BORDO := Color("#E0584F")
const WALK_ENTER := 8.0
const WALK_EXIT := 5.0
const MAX_SPEED := 300.0
const BREATH_PERIOD := 2.4
const BREATH_SY := 0.015
const BREATH_ARM := 1.5  # derece
const BOB_PX := 9.0
const BOB_HZ := 2.2
const SQUASH_CONTACT := Vector2(1.05, 0.93)
const SQUASH_AIR := Vector2(0.97, 1.04)
const CONTACT_TIME := 0.06
const LEAN_DEG := 6.0
const LEAN_FRAME_SCALE := 0.6
const LEAN_TAU := 0.04  # 120 ms'de %95
const WOBBLE_DEG := 2.0
const TURN_MIN := 0.25
const TURN_HYSTERESIS_PX := 8.0
const RECOIL_ARM_DEG := 8.0
const RECOIL_BACK_PX := 10.0
const RECOIL_LEN := 0.06
const RECOIL_BODY_DEG := 1.2
const RECOIL_BODY_PX := 2.0
const RECOIL_CAP := 1.25
const RECOIL_OVERSHOOT := 0.37
const RELOAD_ARM_DEG := 70.0
const RELOAD_SHAKE_DEG := 10.0
const RELOAD_SHAKE_HZ := 8.0
const RELOAD_OVERSHOOT_DEG := 6.0
const RELOAD_SY := 0.97
const HIT_KNOCK_PX := 8.0
const HIT_SQ := 0.10
const HIT_SPRING_HZ := 12.0
## <=3 Hz kuralı: iki beyaz parlama arası en az 1/3 sn (plan "150 ms" tek başına 6,7 Hz'e izin verirdi).
const HIT_FLASH_GAP := 0.34
const TINT_AMOUNT := 0.35
const SCARF_IDLE := 3.0
const SCARF_RUN := 6.5
const SCARF_HIT_MULT := 2.5
const SCARF_HIT_TIME := 0.3
const LEVEL_RING_PX := 180.0
const LEVEL_HALO := 0.3
const DEATH_FALL_DEG := 75.0
const DEATH_BOUNCE_DEG := 4.0
const DEATH_SINK_PX := 8.0
const DEATH_ARM_DEG := 100.0
const DEATH_ARM_TIME := 0.35
const DEATH_DESAT := 0.6
const DEATH_LIGHT_TIME := 0.6
const STAND_FADE := 0.08

var mode: int = Mode.IDLE
var lean: float = 0.0
var bob_px: float = 0.0
var sx: float = 1.0
var sy: float = 1.0
## Gövdenin işaretli yatay ölçeği: +1 sağa, −1 sola bakış; dönüşte |değer| 0,25'e iner.
var turn_x: float = 1.0
var frame_a: int = 0
var frame_b: int = 0
var frame_mix: float = 0.0
var walk_phase: float = 0.0
var hit: float = 0.0
var tint_amt: float = 0.0
var tint: Color = BORDO
var desat: float = 0.0
var scarf_amp: float = SCARF_IDLE
## Kol dönüşü (rad): geri tepme/doldurma/ölümün aim'e eklenen kısmı; + = namlu yukarı (dikey ayna PlayerView'da).
var arm_rot := PackedFloat32Array([0.0, 0.0])
var arm_back := PackedFloat32Array([0.0, 0.0])
var arm_len := PackedFloat32Array([1.0, 1.0])
## Hasar itmesi (px) ve yönü (saldırganın tersi, birim vektör).
var knock_px: float = 0.0
var knock_dir: Vector2 = Vector2.ZERO
## Rig'e uygulanan toplam dönüş (eğim + adım sallanması + geri tepme gövde karşılığı + ölüm devrilmesi).
var body_rot: float = 0.0
## Tabanca geri tepmesinden gövdenin arkaya kayması (px, yatay yön PlayerView'da).
var body_back_px: float = 0.0
var sink_px: float = 0.0
var fade: float = 1.0
## Parlama ışığı çarpanına eklenen pay: 0 normal, +0,3 seviye ön vurgusu, −1 ölümde söner.
var halo: float = 0.0
## Seviye halkası yarıçapı (px); −1 = yok.
var level_ring: float = -1.0
## Etki aurası: bit0 hasar, bit1 hız, bit2 sınırsız.
var aura_mask: int = 0
## Bakış değişiminin hedefinin gövdeye yatay uzaklığı (px). Bu eşiğin (8) altında bakış değişimi dönüş başlatmaz.
## Bilinmiyorsa (varsayılan çok büyük) her değişim kabul edilir.
var facing_margin_px: float = 1.0e9

var _frames: int = 0
var _stride: float = 136.0
var _t: float = 0.0
var _phase: float = 0.0
var _contact_left: float = 0.0
var _prev_h: float = 0.0
var _facing_seen: bool = false
var _facing_left: bool = false
var _turn_t: float = 1.0  # 0..1 ilerleme; 1 = bitti
var _turn_from: float = 1.0
var _turn_to: float = 1.0
var _rc_t := PackedFloat32Array([9.0, 9.0])
var _rc_amp := PackedFloat32Array([1.0, 1.0])
var _hit_t: float = 9.0
var _flash_gap: float = 9.0
var _tint_t: float = 9.0
var _lu_t: float = -1.0
var _stop_t: float = 9.0
var _won: bool = false
var _death_t: float = 0.0
var _fall_sign: float = 0.0


func _init() -> void:
	reset()


## CharacterDef.rig (walk dahil) ile yapılandırır; walk.frames > 0 ise kare modu.
func configure(rig: Dictionary) -> void:
	_frames = 0
	_stride = 136.0
	var w: Variant = rig.get("walk", null)
	if w is Dictionary:
		_frames = clampi(int(w.get("frames", 0)), 0, DataV11.WALK_MAX_FRAMES)
		if _frames < 2:
			_frames = 0
		var st := float(w.get("stride", 136.0))
		_stride = st if st >= 20.0 and st <= 600.0 else 136.0
	reset()


func reset() -> void:
	mode = Mode.IDLE
	lean = 0.0
	bob_px = 0.0
	sx = 1.0
	sy = 1.0
	turn_x = 1.0
	frame_a = _frames
	frame_b = _frames
	frame_mix = 0.0
	walk_phase = 0.0
	hit = 0.0
	tint_amt = 0.0
	tint = BORDO
	desat = 0.0
	scarf_amp = SCARF_IDLE
	arm_rot.fill(0.0)
	arm_back.fill(0.0)
	arm_len.fill(1.0)
	knock_px = 0.0
	knock_dir = Vector2.ZERO
	body_rot = 0.0
	body_back_px = 0.0
	sink_px = 0.0
	fade = 1.0
	halo = 0.0
	level_ring = -1.0
	aura_mask = 0
	facing_margin_px = 1.0e9
	_t = 0.0
	_phase = 0.0
	_contact_left = 0.0
	_prev_h = 0.0
	_facing_seen = false
	_facing_left = false
	_turn_t = 1.0
	_turn_from = 1.0
	_turn_to = 1.0
	_rc_t.fill(9.0)
	_rc_amp.fill(1.0)
	_hit_t = 9.0
	_flash_gap = 9.0
	_tint_t = 9.0
	_lu_t = -1.0
	_stop_t = 9.0
	_won = false
	_death_t = 0.0
	_fall_sign = 0.0


## reload_progress: -1 = doldurmuyor. dt <= 0 hiçbir şeyi ilerletmez (duraklatma).
func update(dt: float, vel: Vector2, facing_left: bool, reload_progress: float) -> void:
	if dt <= 0.0:
		return
	_t += dt
	if mode == Mode.DEAD:
		_update_dead(dt)
		return
	if _won:
		vel = Vector2.ZERO
	_update_mode(dt, vel)
	_update_facing(dt, facing_left)
	_update_walk(dt, vel)
	_update_layers(dt, vel, reload_progress)


func on_shot(gun: int) -> void:
	if mode == Mode.DEAD or gun < 0 or gun > 1:
		return
	# Yeni atış zamanlayıcıyı sıfırlar; genlik birikmez (tavan 1,25×).
	_rc_amp[gun] = minf(1.0 + 0.5 * maxf(_recoil_value(gun), 0.0), RECOIL_CAP)
	_rc_t[gun] = 0.0


## from_dir: oyuncudan hasarın geldiği yöne birim vektör (bilinmiyorsa ZERO).
func on_damaged(amount: float, from_dir: Vector2) -> void:
	if mode == Mode.DEAD or amount < 0.0:
		return
	if from_dir.length_squared() > 0.0001:
		knock_dir = -from_dir.normalized()
	elif knock_dir == Vector2.ZERO:
		knock_dir = Vector2.LEFT if turn_x > 0.0 else Vector2.RIGHT
	_hit_t = 0.0
	_tint_t = 0.0
	if _flash_gap >= HIT_FLASH_GAP:
		_flash_gap = 0.0
		hit = 1.0


func on_level_up() -> void:
	if mode == Mode.DEAD:
		return
	_lu_t = 0.0


func on_buffs(mask: int) -> void:
	aura_mask = mask


## from_dir: hasarın geldiği yön (devrilme tersine); ZERO ise bakışın tersine.
func on_died(from_dir: Vector2) -> void:
	if mode == Mode.DEAD:
		return
	mode = Mode.DEAD
	_death_t = 0.0
	if absf(from_dir.x) > 0.0001:
		_fall_sign = -signf(from_dir.x)
	elif knock_dir.x != 0.0 and _hit_t < 5.0:
		_fall_sign = signf(knock_dir.x)
	else:
		_fall_sign = 1.0 if _facing_left else -1.0
	_lu_t = -1.0
	level_ring = -1.0
	hit = 1.0
	_set_idle_outputs()
	_update_dead(0.0)


func on_won() -> void:
	if mode == Mode.DEAD:
		return
	_won = true
	mode = Mode.IDLE


func death_done() -> bool:
	return mode == Mode.DEAD and _death_t >= Motion.sec(Motion.DEATH_TOTAL) - 1e-6


# --- iç --------------------------------------------------------------------------------------


func _update_mode(dt: float, vel: Vector2) -> void:
	var speed := vel.length()
	var walking := mode == Mode.WALK
	if walking and speed < WALK_EXIT:
		walking = false
	elif not walking and speed >= WALK_ENTER:
		walking = true
	if walking and mode != Mode.WALK:
		_phase = 0.0
		_prev_h = 0.0
		_contact_left = 0.0
	if not walking and mode == Mode.WALK:
		_stop_t = 0.0
	mode = Mode.WALK if walking else Mode.IDLE
	_stop_t += dt


func _update_facing(dt: float, facing_left: bool) -> void:
	if not _facing_seen:
		_facing_seen = true
		_facing_left = facing_left
		turn_x = -1.0 if facing_left else 1.0
		_turn_to = turn_x
		_turn_from = turn_x
		return
	if facing_left != _facing_left and facing_margin_px >= TURN_HYSTERESIS_PX:
		_facing_left = facing_left
		_turn_from = turn_x
		_turn_to = -1.0 if facing_left else 1.0
		_turn_t = 0.0
	if _turn_t < 1.0:
		_turn_t = minf(1.0, _turn_t + dt / Motion.sec(Motion.TURN))
		var e := _ease_in_out_cubic(_turn_t)
		var old_sign := signf(_turn_from)
		var new_sign := signf(_turn_to)
		if old_sign == new_sign:
			turn_x = _turn_to
		elif e < 0.5:
			turn_x = old_sign * lerpf(1.0, TURN_MIN, e / 0.5)
		else:
			turn_x = new_sign * lerpf(TURN_MIN, 1.0, (e - 0.5) / 0.5)
		if _turn_t >= 1.0:
			turn_x = _turn_to


func _update_walk(dt: float, vel: Vector2) -> void:
	var speed := vel.length()
	var framed := _frames > 0
	if mode == Mode.WALK:
		if framed:
			var dist := speed * dt
			if dist <= 60.0:  # ışınlanma yok sayılır
				_phase = WalkCycle.advance(_phase, dist, _stride)
			frame_a = WalkCycle.frame_at(_phase, _frames)
			frame_b = frame_a
			frame_mix = 0.0
		else:
			_phase = fposmod(_phase + BOB_HZ * clampf(speed / MAX_SPEED, 0.5, 1.0) * dt, 1.0)
			frame_a = 0
			frame_b = 0
			frame_mix = 0.0
	elif framed:
		_stand_frames()
	walk_phase = _phase


## Durma: en yakın temas karesinden duruş hücresine 80 ms'de çapraz solma.
func _stand_frames() -> void:
	if _stop_t >= STAND_FADE - 1e-6:
		frame_a = _frames
		frame_b = _frames
		frame_mix = 0.0
		return
	frame_a = WalkCycle.nearest_contact(_phase, _frames)
	frame_b = _frames
	frame_mix = clampf(_stop_t / STAND_FADE, 0.0, 1.0)


func _update_layers(dt: float, vel: Vector2, reload_progress: float) -> void:
	var framed := _frames > 0
	var walking := mode == Mode.WALK
	var speed_f := clampf(vel.length() / MAX_SPEED, 0.0, 1.0)
	_update_body(dt, vel, walking, framed, speed_f)
	# geri tepme / doldurma / hasar / seviye üst üste biner
	for g in 2:
		if _rc_t[g] < 1.0:
			_rc_t[g] += dt
	_apply_recoil()
	_apply_reload(reload_progress)
	_update_hit(dt)
	_apply_tint(_update_level(dt))
	var run_w := speed_f if walking else 0.0
	var scarf := lerpf(SCARF_IDLE, SCARF_RUN, run_w)
	if _hit_t < SCARF_HIT_TIME:
		scarf *= lerpf(SCARF_HIT_MULT, 1.0, _hit_t / SCARF_HIT_TIME)
	scarf_amp = scarf


func _update_body(dt: float, vel: Vector2, walking: bool, framed: bool, speed_f: float) -> void:
	var lean_target := deg_to_rad(LEAN_DEG) * clampf(vel.x / MAX_SPEED, -1.0, 1.0)
	if framed:
		lean_target *= LEAN_FRAME_SCALE
	lean += (lean_target - lean) * (1.0 - exp(-dt / LEAN_TAU))
	var wobble := 0.0
	bob_px = 0.0
	sx = 1.0
	sy = 1.0
	if walking and not framed:
		var h := pow(absf(sin(TAU * _phase)), 0.8)
		bob_px = BOB_PX * h
		# temas: |sin| sıfıra inen an; 60 ms squash, havada geriye doğru gerilme
		if _prev_h > 0.15 and h <= 0.15:
			_contact_left = CONTACT_TIME
		_prev_h = h
		if _contact_left > 0.0:
			_contact_left = maxf(0.0, _contact_left - dt)
			sx = SQUASH_CONTACT.x
			sy = SQUASH_CONTACT.y
		else:
			sx = lerpf(1.0, SQUASH_AIR.x, h)
			sy = lerpf(1.0, SQUASH_AIR.y, h)
		wobble = deg_to_rad(WOBBLE_DEG) * sin(TAU * _phase) * speed_f
	elif not walking:
		var b := 0.5 - 0.5 * cos(TAU * _t / BREATH_PERIOD)
		sy = 1.0 + BREATH_SY * b
	body_rot = lean + wobble
	var s := sin(TAU * _t / BREATH_PERIOD)
	var arm_idle := 0.0 if walking else deg_to_rad(BREATH_ARM) * s
	arm_rot[0] = arm_idle
	arm_rot[1] = arm_idle


func _recoil_value(g: int) -> float:
	var t := _rc_t[g]
	var kick := Motion.sec(Motion.RECOIL_KICK)
	var back := Motion.sec(Motion.RECOIL_BACK)
	if t < 0.0 or t >= kick + back:
		return 0.0
	if t < kick:
		var u := t / kick
		return 1.0 - pow(1.0 - u, 3.0)  # cubic-out
	var q := (t - kick) / back
	# quad-out sönüm, ardından küçük (-1,5°) aşma
	return pow(1.0 - q, 2.0) - RECOIL_OVERSHOOT * sin(PI * q)


## Tepme katkılarını arm_rot/arm_back/arm_len ve gövdeye ekler (_update_body önce sıfırlar/temel değeri yazar).
func _apply_recoil() -> void:
	body_back_px = 0.0
	for g in 2:
		var v := _recoil_value(g) * _rc_amp[g]
		if v == 0.0:
			arm_back[g] = 0.0
			arm_len[g] = 1.0
			continue
		arm_rot[g] += deg_to_rad(RECOIL_ARM_DEG) * v
		arm_back[g] = RECOIL_BACK_PX * v
		arm_len[g] = 1.0 - RECOIL_LEN * v
		body_rot -= deg_to_rad(RECOIL_BODY_DEG) * 0.5 * v
		body_back_px += RECOIL_BODY_PX * 0.5 * v


func _apply_reload(p: float) -> void:
	if p < 0.0:
		return
	p = clampf(p, 0.0, 1.0)
	var down := deg_to_rad(RELOAD_ARM_DEG)
	var r := 0.0
	if p < 0.12:
		var u := p / 0.12
		r = -down * u * u  # quad-in
	elif p < 0.8:
		r = -down
		if p < 0.7:
			# süre ~ ilerleme × 1 sn (doldurma süresi 1 sn): 8 Hz titreme
			r += deg_to_rad(RELOAD_SHAKE_DEG) * sin(TAU * RELOAD_SHAKE_HZ * (p - 0.12))
	else:
		var s := (p - 0.8) / 0.2
		var over := deg_to_rad(RELOAD_OVERSHOOT_DEG)
		if s < 0.6:
			var e := 1.0 - pow(1.0 - s / 0.6, 3.0)  # cubic-out
			r = lerpf(-down, over, e)
		else:
			var e2 := (s - 0.6) / 0.4
			r = lerpf(over, 0.0, e2 * e2 * (3.0 - 2.0 * e2))
	for g in 2:
		arm_rot[g] = r
	if p >= 0.12 and p < 0.7:
		sy *= RELOAD_SY


func _update_hit(dt: float) -> void:
	_flash_gap += dt
	if _hit_t < 9.0:
		_hit_t += dt
	if _tint_t < 9.0:
		_tint_t += dt
	var flash := Motion.sec(Motion.HIT_FLASH)
	hit = 1.0 if _flash_gap < flash else 0.0
	# itme: 50 ms'de 8 px (cubic-out), ardından 12 Hz sönümlü yay (220 ms)
	var kt := Motion.sec(Motion.HIT_KNOCK)
	var spring := Motion.sec(Motion.HIT_SPRING)
	var k := 0.0
	if _hit_t < kt:
		var u := _hit_t / kt
		k = 1.0 - pow(1.0 - u, 3.0)
	elif _hit_t < kt + spring:
		var w := _hit_t - kt
		k = exp(-w / 0.06) * cos(TAU * HIT_SPRING_HZ * w) * (1.0 - w / spring)
	knock_px = HIT_KNOCK_PX * k
	sx *= 1.0 + HIT_SQ * k
	sy *= 1.0 - HIT_SQ * k


## Seviye atlama: ön vurgu (halo, altın ton) 180 ms tam, kalan sürede söner; halka 450 ms'de 0->180 px (cubic-out).
## Halka son değerinde bir kare daha kalır (450. ms'de 180 okunabilsin).
func _update_level(dt: float) -> float:
	if _lu_t < 0.0:
		level_ring = -1.0
		halo = 0.0
		return 0.0
	_lu_t += dt
	var pre := Motion.sec(Motion.LEVELUP_PREROLL)
	var ring := Motion.sec(Motion.LEVELUP_RING)
	if _lu_t >= ring + 1.0 / 60.0:
		_lu_t = -1.0
		level_ring = -1.0
		halo = 0.0
		return 0.0
	var g := 1.0 if _lu_t < pre else clampf(1.0 - (_lu_t - pre) / (ring - pre), 0.0, 1.0)
	halo = LEVEL_HALO * g
	level_ring = LEVEL_RING_PX * (1.0 - pow(1.0 - clampf(_lu_t / ring, 0.0, 1.0), 3.0))
	return g


## Hasar bordosu ile seviye altını arasında büyük olan kazanır.
func _apply_tint(gold_g: float) -> void:
	var flash := Motion.sec(Motion.HIT_FLASH)
	var ht := Motion.sec(Motion.HIT_TINT)
	var dmg := 0.0
	if _tint_t < flash:
		dmg = TINT_AMOUNT
	elif _tint_t < flash + ht:
		dmg = TINT_AMOUNT * (1.0 - (_tint_t - flash) / ht)
	var gold := 0.5 * gold_g
	if dmg >= gold:
		tint = BORDO
		tint_amt = dmg
	else:
		tint = GOLD
		tint_amt = gold


func _set_idle_outputs() -> void:
	bob_px = 0.0
	sx = 1.0
	sy = 1.0
	lean = 0.0
	scarf_amp = SCARF_IDLE
	arm_back.fill(0.0)
	arm_len.fill(1.0)
	knock_px = 0.0
	body_back_px = 0.0
	tint = BORDO
	tint_amt = 0.0
	halo = 0.0
	frame_a = _frames
	frame_b = _frames
	frame_mix = 0.0


func _update_dead(dt: float) -> void:
	_death_t = minf(_death_t + dt, Motion.sec(Motion.DEATH_TOTAL))
	var t := _death_t
	var freeze := Motion.sec(Motion.DEATH_FREEZE)
	var fall := Motion.sec(Motion.DEATH_FALL)
	var total := Motion.sec(Motion.DEATH_TOTAL)
	var fall_end := freeze + fall
	hit = 1.0 if t < freeze else 0.0
	var fall_deg := deg_to_rad(DEATH_FALL_DEG) * _fall_sign
	if t < freeze:
		body_rot = 0.0
		desat = 0.0
		sink_px = 0.0
	elif t < fall_end:
		var u := (t - freeze) / fall
		var e := u * u  # quad-in
		body_rot = fall_deg * e
		desat = DEATH_DESAT * e
		sink_px = DEATH_SINK_PX * e
	else:
		var q := clampf((t - fall_end) / 0.18, 0.0, 1.0)
		body_rot = fall_deg - _fall_sign * deg_to_rad(DEATH_BOUNCE_DEG) * sin(PI * q) * (1.0 - q)
		desat = DEATH_DESAT
		sink_px = DEATH_SINK_PX
	# kollar 350 ms'de sarkar
	var au := clampf((t - freeze) / DEATH_ARM_TIME, 0.0, 1.0)
	var arm_down := -deg_to_rad(DEATH_ARM_DEG) * (1.0 - pow(1.0 - au, 3.0))
	arm_rot[0] = arm_down
	arm_rot[1] = arm_down
	halo = -clampf(t / DEATH_LIGHT_TIME, 0.0, 1.0)
	fade = 1.0 if t < fall_end else clampf(1.0 - (t - fall_end) / (total - fall_end), 0.0, 1.0)


static func _ease_in_out_cubic(x: float) -> float:
	if x < 0.5:
		return 4.0 * x * x * x
	return 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0
