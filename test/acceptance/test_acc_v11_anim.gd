extends GutTest
## Kabul (v1.1 D1/D4): oyuncu animasyonu - PlayerAnim saf durum makinesi (A1-A10), WalkCycle (A11), kare modu geçişleri (A12).
## Dilimler: D1 (prosedürel), D4 (kareli yürüme). A11 (WalkCycle) S3'ten beri gerçek: dilimsiz koşar.
## Açılar RADYAN kabul edilir (lean, arm_rot, body_rot: Godot rotation); px alanlar dünya pikseli (DESIGN §1.2 P1-P13).
## Ölçüm: PlayerAnim.update(dt, vel, facing_left, reload_progress) sabit dt ile sürülür; gerçek zaman yok.

const DT := 1.0 / 240.0
const FAST := 300.0

var _rig_base: Dictionary = {}


func before_all() -> void:
	_rig_base = GameData.load_default().get_character(&"gunslinger").rig.duplicate(true)


func _rig(frames: int = 0) -> Dictionary:
	var rig := _rig_base.duplicate(true)
	var w: Dictionary = rig.get("walk", {})
	w["frames"] = frames
	w["stride"] = 136.0
	if frames > 0:
		w["cell"] = [177, 320]
		w["shoulder_dev"] = []
	rig["walk"] = w
	return rig


func _anim(frames: int = 0) -> PlayerAnim:
	var a := PlayerAnim.new()
	a.configure(_rig(frames))
	a.reset()
	return a


## secs süre boyunca dt adımlarla sürer; on_step(t_since_start) varsa her adımdan sonra çağrılır.
func _run(
	a: PlayerAnim,
	secs: float,
	vel: Vector2 = Vector2.ZERO,
	facing_left: bool = false,
	reload: float = -1.0,
	on_step: Callable = Callable()
) -> float:
	var t := 0.0
	var n := int(round(secs / DT))
	for i in n:
		a.update(DT, vel, facing_left, reload)
		t += DT
		if on_step.is_valid():
			on_step.call(t)
	return t


## Yükselen kenar sayısı (eşik geçişi) / saniye.
func _rate(samples: Array[float], thresh: float, secs: float) -> float:
	var n := 0
	for i in range(1, samples.size()):
		if samples[i - 1] < thresh and samples[i] >= thresh:
			n += 1
	return float(n) / secs


# --- A1: nefes, mod histerezisi ------------------------------------------------------------------------------


func test_a1_idle_breath_stays_within_sy_1_000_to_1_015_arms_1_5_degrees() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 1.2)
	var st := {"lo": 10.0, "hi": 0.0, "arm": 0.0, "scarf": -100.0, "prev": 1.0, "rising": true}
	var maxima: Array[float] = []
	_run(
		a,
		4.8,
		Vector2.ZERO,
		false,
		-1.0,
		func(t: float) -> void:
			st["lo"] = minf(st["lo"], a.sy)
			st["hi"] = maxf(st["hi"], a.sy)
			st["arm"] = maxf(st["arm"], maxf(absf(a.arm_rot[0]), absf(a.arm_rot[1])))
			st["scarf"] = maxf(st["scarf"], a.scarf_amp)
			if a.sy < st["prev"] and st["rising"]:
				maxima.append(t)
			st["rising"] = a.sy >= st["prev"]
			st["prev"] = a.sy
	)
	assert_gte(st["lo"], 1.0 - 0.001, "sy alt sınır 1,000")
	assert_lte(st["hi"], 1.015 + 0.001, "sy üst sınır 1,015")
	assert_gte(st["hi"], 1.012, "nefes gerçekten var (tepe >= 1,012)")
	assert_lte(st["arm"], deg_to_rad(1.5) + 0.002, "kol +-1,5 derece")
	assert_gt(st["arm"], deg_to_rad(1.0), "kol nefesi var")
	assert_almost_eq(st["scarf"], 3.0, 0.3, "duruşta atkı 3 px")
	assert_gte(maxima.size(), 2)
	if maxima.size() >= 2:
		assert_almost_eq(maxima[1] - maxima[0], 2.4, 0.15, "nefes periyodu 2,4 sn")
	assert_eq(a.mode, PlayerAnim.Mode.IDLE)


func test_a1_mode_switches_to_walk_at_8_and_back_below_5_px_per_sec() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.3, Vector2(7.9, 0))
	assert_eq(a.mode, PlayerAnim.Mode.IDLE, "7,9 px/sn: yürümeye geçmez")
	_run(a, 0.3, Vector2(8.0, 0))
	assert_eq(a.mode, PlayerAnim.Mode.WALK, "8 px/sn: yürüme")
	_run(a, 0.3, Vector2(6.0, 0))
	assert_eq(a.mode, PlayerAnim.Mode.WALK, "6 px/sn: histerezis, yürüme sürer")
	_run(a, 0.3, Vector2(4.9, 0))
	assert_eq(a.mode, PlayerAnim.Mode.IDLE, "4,9 px/sn: duruş")
	_run(a, 0.3, Vector2(6.0, 0))
	assert_eq(a.mode, PlayerAnim.Mode.IDLE, "duruştan 6 px/sn: geri geçmez")


# --- A2: bob -------------------------------------------------------------------------------------------------


func _bob_series(a: PlayerAnim, speed: float, secs: float) -> Array[float]:
	var out: Array[float] = []
	_run(a, 1.0, Vector2(speed, 0))
	_run(
		a, secs, Vector2(speed, 0), false, -1.0, func(_t: float) -> void: out.append(absf(a.bob_px))
	)
	return out


func test_a2_procedural_bob_peaks_at_9_px() -> void:
	if V11Slice.require(self, "D1"):
		return
	var s := _bob_series(_anim(), FAST, 3.0)
	assert_almost_eq(s.max(), 9.0, 0.6, "tepe bob 9 px")


func test_a2_bob_frequency_scales_with_speed_between_half_and_full() -> void:
	if V11Slice.require(self, "D1"):
		return
	var secs := 4.0
	var base_series := _bob_series(_anim(), FAST, secs)
	var base := _rate(base_series, 4.5, secs)
	assert_gt(base, 1.5, "ölçülebilir bob hızı")
	assert_true(
		absf(base - 2.2) < 0.2 or absf(base - 4.4) < 0.4,
		"300 px/sn: 2,2 Hz (ya da |sin| ile 4,4 tepe/sn): %.2f" % base
	)
	var half := _rate(_bob_series(_anim(), 150.0, secs), 4.5, secs)
	assert_almost_eq(half / base, 0.5, 0.06, "150 px/sn: frekans yarıya iner")
	var low := _rate(_bob_series(_anim(), 30.0, secs), 4.5, secs)
	assert_almost_eq(low / base, 0.5, 0.06, "çok yavaş: alt sınır 0,5")
	var fast := _rate(_bob_series(_anim(), 600.0, secs), 4.5, secs)
	assert_almost_eq(fast / base, 1.0, 0.06, "300 üstü: üst sınır 1")


func test_a2_frame_mode_has_no_procedural_bob_or_walk_squash() -> void:
	if V11Slice.require(self, "D1") or V11Slice.require(self, "D4"):
		return
	var a := _anim(6)
	var st := {"bob": 0.0, "dev": 0.0}
	_run(a, 1.0, Vector2(FAST, 0))
	_run(
		a,
		2.0,
		Vector2(FAST, 0),
		false,
		-1.0,
		func(_t: float) -> void:
			st["bob"] = maxf(st["bob"], absf(a.bob_px))
			st["dev"] = maxf(st["dev"], maxf(absf(a.sx - 1.0), absf(a.sy - 1.0)))
	)
	assert_lt(st["bob"], 0.01, "kare modunda bob = 0")
	assert_lt(st["dev"], 0.02, "kare modunda yürüme squash'ı 0")


# --- A3: eğim ------------------------------------------------------------------------------------------------


func _mean_lean(a: PlayerAnim, vx: float, warm: float, secs: float) -> float:
	_run(a, warm, Vector2(vx, 0))
	var acc := [0.0, 0]
	_run(
		a,
		secs,
		Vector2(vx, 0),
		false,
		-1.0,
		func(_t: float) -> void:
			acc[0] += a.lean
			acc[1] += 1
	)
	return acc[0] / float(acc[1])


func test_a3_lean_is_6_degrees_at_full_speed_signed_and_clamped() -> void:
	if V11Slice.require(self, "D1"):
		return
	assert_almost_eq(
		rad_to_deg(_mean_lean(_anim(), FAST, 0.6, 2.0)), 6.0, 0.7, "300 px/sn: 6 derece"
	)
	assert_almost_eq(rad_to_deg(_mean_lean(_anim(), -FAST, 0.6, 2.0)), -6.0, 0.7, "sola: -6 derece")
	assert_almost_eq(
		rad_to_deg(_mean_lean(_anim(), 150.0, 0.6, 2.0)), 3.0, 0.7, "yarı hız: 3 derece"
	)
	assert_almost_eq(rad_to_deg(_mean_lean(_anim(), 700.0, 0.6, 2.0)), 6.0, 0.7, "tavan 6 derece")


func test_a3_lean_reaches_90_percent_by_120_ms() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	var target := _mean_lean(_anim(), FAST, 0.6, 2.0)
	var acc := [0.0, 0]
	_run(
		a,
		0.16,
		Vector2(FAST, 0),
		false,
		-1.0,
		func(t: float) -> void:
			if t >= 0.08:
				acc[0] += a.lean
				acc[1] += 1
	)
	var near_120: float = acc[0] / float(maxi(acc[1], 1))
	assert_gte(
		near_120 / target,
		0.85,
		"120 ms civarında hedefin >= %%85-90'ı (%.3f / %.3f)" % [near_120, target]
	)


func test_a3_frame_mode_lean_is_3_6_degrees() -> void:
	if V11Slice.require(self, "D1") or V11Slice.require(self, "D4"):
		return
	assert_almost_eq(
		rad_to_deg(_mean_lean(_anim(6), FAST, 0.6, 2.0)), 3.6, 0.5, "kare modu: %60 = 3,6 derece"
	)


# --- A4: dönüş -----------------------------------------------------------------------------------------------


func test_a4_turn_takes_70_ms_and_squeezes_to_0_25() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 1.0, Vector2.ZERO, false)
	assert_almost_eq(absf(a.turn_x), 1.0, 0.001, "dönüşten önce |sx| = 1")
	var st := {"min": 10.0, "turning": 0.0}
	_run(
		a,
		0.2,
		Vector2.ZERO,
		true,
		-1.0,
		func(_t: float) -> void:
			st["min"] = minf(st["min"], absf(a.turn_x))
			if absf(a.turn_x) < 0.999:
				st["turning"] += DT
	)
	assert_almost_eq(st["min"], 0.25, 0.06, "orta noktada |sx| = 0,25")
	assert_almost_eq(st["turning"], 0.07, 0.015, "dönüş süresi 70 ms")
	assert_almost_eq(absf(a.turn_x), 1.0, 0.001, "dönüş sonunda |sx| = 1")


func test_a4_no_turn_without_a_facing_change() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	var st := {"min": 10.0}
	_run(
		a,
		1.0,
		Vector2(FAST, 0),
		false,
		-1.0,
		func(_t: float) -> void: st["min"] = minf(st["min"], absf(a.turn_x))
	)
	assert_almost_eq(st["min"], 1.0, 0.001, "bakış değişmedi: dönüş yok")


# --- A5: geri tepme ------------------------------------------------------------------------------------------


func _peak_after_shot(gun: int, secs: float) -> Dictionary:
	var a := _anim()
	_run(a, 1.0)
	var ctrl := _anim()
	_run(ctrl, 1.0)
	a.on_shot(gun)
	var out := {
		"rot": 0.0,
		"rot_t": 0.0,
		"back": 0.0,
		"len": 1.0,
		"other_dev": 0.0,
		"end_rot": 0.0,
		"end_back": 0.0,
		"end_len": 1.0
	}
	var t := 0.0
	for i in int(round(secs / DT)):
		a.update(DT, Vector2.ZERO, false, -1.0)
		ctrl.update(DT, Vector2.ZERO, false, -1.0)
		t += DT
		var d := absf(a.arm_rot[gun] - ctrl.arm_rot[gun])
		if d > out["rot"]:
			out["rot"] = d
			out["rot_t"] = t
		out["back"] = maxf(out["back"], absf(a.arm_back[gun] - ctrl.arm_back[gun]))
		out["len"] = minf(out["len"], a.arm_len[gun])
		var o := 1 - gun
		out["other_dev"] = maxf(
			out["other_dev"],
			maxf(absf(a.arm_rot[o] - ctrl.arm_rot[o]), absf(a.arm_back[o] - ctrl.arm_back[o]))
		)
		out["end_rot"] = absf(a.arm_rot[gun] - ctrl.arm_rot[gun])
		out["end_back"] = absf(a.arm_back[gun] - ctrl.arm_back[gun])
		out["end_len"] = a.arm_len[gun]
	return out


func test_a5_recoil_peaks_at_40_ms_8_degrees_10_px_94_percent_and_recovers_in_110_ms() -> void:
	if V11Slice.require(self, "D1"):
		return
	for gun in [0, 1]:
		var r := _peak_after_shot(gun, 0.4)
		assert_almost_eq(rad_to_deg(r["rot"]), 8.0, 1.2, "tabanca %d: kol 8 derece" % gun)
		assert_between(float(r["rot_t"]), 0.03, 0.05, "tabanca %d: tepe ~40 ms" % gun)
		assert_almost_eq(float(r["back"]), 10.0, 1.2, "omuzdan 10 px geri")
		assert_almost_eq(float(r["len"]), 0.94, 0.015, "kol boyu %94")
		assert_lt(rad_to_deg(r["end_rot"]), 0.5, "150 ms sonra toparlanmış")
		assert_lt(float(r["end_back"]), 0.5)
		assert_almost_eq(float(r["end_len"]), 1.0, 0.01)
		assert_lt(float(r["other_dev"]), 1e-4, "iki tabanca bağımsız: diğeri etkilenmez")


func test_a5_recoil_recovery_is_done_by_150_ms_after_start() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 1.0)
	var ctrl := _anim()
	_run(ctrl, 1.0)
	a.on_shot(0)
	_run(a, 0.16)
	_run(ctrl, 0.16)
	assert_lt(absf(a.arm_back[0] - ctrl.arm_back[0]), 0.6, "40 + 110 ms içinde geri tepme bitti")


func test_a5_rapid_fire_is_capped_at_1_25x_and_restarts_the_timer() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 1.0)
	var ctrl := _anim()
	_run(ctrl, 1.0)
	var rot_peak := 0.0
	var back_peak := 0.0
	for k in 8:
		a.on_shot(0)
		for i in int(round(0.02 / DT)):
			a.update(DT, Vector2.ZERO, false, -1.0)
			ctrl.update(DT, Vector2.ZERO, false, -1.0)
			rot_peak = maxf(rot_peak, absf(a.arm_rot[0] - ctrl.arm_rot[0]))
			back_peak = maxf(back_peak, absf(a.arm_back[0] - ctrl.arm_back[0]))
	assert_lte(rad_to_deg(rot_peak), 8.0 * 1.25 + 0.4, "ardışık atış: kol tavanı 1,25x")
	assert_lte(back_peak, 10.0 * 1.25 + 0.4, "geri tepme tavanı 1,25x")
	assert_gt(back_peak, 10.0 * 0.9, "tepki sürüyor")


# --- A6: doldurma --------------------------------------------------------------------------------------------


func test_a6_reload_phase_one_pulls_both_arms_down_to_70_degrees() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.5)
	_run(a, 0.4, Vector2.ZERO, false, 0.12)
	for g in [0, 1]:
		assert_almost_eq(rad_to_deg(absf(a.arm_rot[g])), 70.0, 4.0, "%%12: kol %d 70 derece" % g)


func test_a6_reload_phase_two_trembles_8_hz_plus_minus_10_degrees_body_sy_097() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.5)
	_run(a, 0.3, Vector2.ZERO, false, 0.4)
	var vals: Array[float] = []
	var sy_acc := [0.0, 0]
	_run(
		a,
		1.0,
		Vector2.ZERO,
		false,
		0.4,
		func(_t: float) -> void:
			vals.append(rad_to_deg(a.arm_rot[0]))
			sy_acc[0] += a.sy
			sy_acc[1] += 1
	)
	var mean := 0.0
	for v in vals:
		mean += v
	mean /= vals.size()
	var lo := 1000.0
	var hi := -1000.0
	var crossings := 0
	for i in vals.size():
		lo = minf(lo, vals[i])
		hi = maxf(hi, vals[i])
		if i > 0 and (vals[i - 1] - mean) * (vals[i] - mean) < 0.0:
			crossings += 1
	assert_almost_eq((hi - lo) * 0.5, 10.0, 2.0, "titreme genliği +-10 derece")
	assert_almost_eq(float(crossings) / 2.0, 8.0, 1.2, "titreme 8 Hz (%d geçiş/sn)" % crossings)
	assert_almost_eq(sy_acc[0] / float(sy_acc[1]), 0.97, 0.015, "gövde sy 0,97")


func test_a6_reload_phase_three_overshoots_about_6_degrees_then_settles() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.5)
	_run(a, 0.3, Vector2.ZERO, false, 0.4)
	var down_sign := signf(a.arm_rot[0])
	assert_ne(down_sign, 0.0)
	var over := 0.0  # aim'in ötesine geçen en büyük sapma (derece)
	var p := 0.8
	while p <= 1.0:
		a.update(DT * 6.0, Vector2.ZERO, false, p)
		over = maxf(over, -rad_to_deg(a.arm_rot[0]) * down_sign)
		p += 0.002
	_run(a, 0.4)
	assert_almost_eq(over, 6.0, 2.5, "%%80-100: +6 derece aşma")
	assert_lt(rad_to_deg(absf(a.arm_rot[0])), 1.6, "doldurma bitince kol aim'de (nefes payı)")


# --- A7-A10: hasar, ölüm, seviye, yanıp sönme ------------------------------------------------------------------


func _after_damage(secs: float, from_dir: Vector2 = Vector2.RIGHT) -> PlayerAnim:
	var a := _anim()
	_run(a, 0.5)
	a.on_damaged(10.0, from_dir)
	_run(a, secs)
	return a


func test_a7_damage_flash_lasts_90_ms_then_burgundy_tint_fades_by_200_ms() -> void:
	if V11Slice.require(self, "D1"):
		return
	var early := _after_damage(0.01)
	assert_gte(early.hit, 0.85, "10 ms: beyaz parlama")
	var mid := _after_damage(0.09)
	assert_gte(mid.tint_amt, 0.3, "90 ms: bordo ton başladı/sürüyor")
	assert_almost_eq(mid.tint_amt, 0.35, 0.08, "ton %35")
	var late := _after_damage(0.12)
	assert_lt(late.hit, 0.05, "120 ms: parlama bitti")
	var gone := _after_damage(0.32)
	assert_lt(gone.tint_amt, 0.03, "90 + 200 ms sonra ton söner")
	assert_lt(gone.hit, 0.01)


func test_a7_damage_knock_8_px_at_50_ms_with_10_percent_squash_then_spring_settles() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.5)
	a.on_damaged(10.0, Vector2.RIGHT)
	var knock_peak := 0.0
	var knock_t := 0.0
	var sx_at_50 := 1.0
	var sy_at_50 := 1.0
	var t := 0.0
	for i in int(round(0.4 / DT)):
		a.update(DT, Vector2.ZERO, false, -1.0)
		t += DT
		if absf(a.knock_px) > knock_peak:
			knock_peak = absf(a.knock_px)
			knock_t = t
		if absf(t - 0.05) < DT * 0.5:
			sx_at_50 = a.sx
			sy_at_50 = a.sy
	assert_almost_eq(knock_peak, 8.0, 1.5, "8 px geri")
	assert_between(knock_t, 0.035, 0.07, "tepe ~50 ms")
	assert_almost_eq(sx_at_50, 1.10, 0.03, "50 ms: sx 1,10")
	assert_almost_eq(sy_at_50, 0.90, 0.03, "50 ms: sy 0,90")
	assert_lt(absf(a.knock_px), 0.3, "yay (220 ms) sonrası durulur")
	assert_lt(absf(a.sx - 1.0), 0.03)


func test_a7_second_hit_within_100_ms_refreshes_tint_but_not_the_white_flash() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.5)
	a.on_damaged(10.0, Vector2.RIGHT)
	_run(a, 0.1)
	a.on_damaged(10.0, Vector2.RIGHT)
	_run(a, 0.02)
	assert_lt(a.hit, 0.05, "100 ms arayla ikinci hasar: beyaz parlama yeniden başlamaz")
	assert_gte(a.tint_amt, 0.25, "ton yenilenir")


func test_a7_white_flash_can_fire_again_after_the_cooldown() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.5)
	a.on_damaged(10.0, Vector2.RIGHT)
	_run(a, 0.8)
	a.on_damaged(10.0, Vector2.RIGHT)
	_run(a, 0.01)
	assert_gte(a.hit, 0.85, "0,8 sn sonraki hasar yeniden parlar")


func test_a8_death_freezes_120_ms_falls_to_minus_75_in_720_ms_and_ends_at_1300_ms() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.5)
	a.on_died(Vector2.RIGHT)
	assert_eq(a.mode, PlayerAnim.Mode.DEAD, "ölüm: DEAD kipi")
	_run(a, 0.11)
	assert_lt(rad_to_deg(absf(a.body_rot)), 1.5, "0-120 ms: vuruş donması (devrilme başlamadı)")
	_run(a, 0.61)  # 0,72 sn
	var right_fall := a.body_rot
	assert_almost_eq(rad_to_deg(absf(right_fall)), 75.0, 6.0, "720 ms: 75 derece devrilme")
	assert_almost_eq(a.desat, 0.6, 0.06, "desat 0,6")
	assert_gt(a.sink_px, 4.0, "~8 px gömülme")
	assert_false(a.death_done(), "720 ms: bitmedi")
	_run(a, 0.5)
	assert_false(a.death_done(), "1,22 sn: bitmedi")
	_run(a, 0.1)
	assert_true(a.death_done(), "1,3 sn: ölüm animasyonu bitti")
	var b := _anim()
	_run(b, 0.5)
	b.on_died(Vector2.LEFT)
	_run(b, 0.72)
	assert_lt(
		right_fall * b.body_rot, 0.0, "devrilme yönü hasarın tersine: ters yönler zıt işaretli"
	)


func test_a8_won_player_idles_and_keeps_breathing() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.5, Vector2(FAST, 0))
	a.on_won()
	_run(a, 1.0)
	assert_eq(a.mode, PlayerAnim.Mode.IDLE, "kazanınca IDLE")
	assert_lt(rad_to_deg(absf(a.body_rot)), 0.5, "devrilme yok")
	assert_lt(a.desat, 0.01)
	assert_false(a.death_done())


func test_a9_level_ring_grows_0_to_180_px_in_450_ms_then_disappears() -> void:
	if V11Slice.require(self, "D1"):
		return
	var a := _anim()
	_run(a, 0.3)
	assert_eq(a.level_ring, -1.0, "halka yokken -1")
	a.on_level_up()
	var series: Array[float] = []
	_run(a, 0.45, Vector2.ZERO, false, -1.0, func(_t: float) -> void: series.append(a.level_ring))
	assert_almost_eq(series.max(), 180.0, 12.0, "450 ms'de 180 px")
	var mid := series[int(series.size() * 0.5)]
	assert_between(mid, 135.0, 172.0, "cubic-out: yarıda >= %75'i")
	var dips := 0
	for i in range(1, series.size()):
		if series[i] >= 0.0 and series[i - 1] >= 0.0 and series[i] + 0.01 < series[i - 1]:
			dips += 1
	assert_eq(dips, 0, "halka büyür (azalma yok)")
	_run(a, 0.1)
	assert_eq(a.level_ring, -1.0, "bitince -1")


func _flash_edges_per_second(events_at: Array[float], total: float) -> float:
	var a := _anim()
	_run(a, 0.3)
	var edges: Array[float] = []
	var prev := 0.0
	var t := 0.0
	var k := 0
	for i in int(round(total / DT)):
		while k < events_at.size() and events_at[k] <= t:
			a.on_damaged(5.0, Vector2.RIGHT)
			k += 1
		a.update(DT, Vector2.ZERO, false, -1.0)
		t += DT
		if prev < 0.5 and a.hit >= 0.5:
			edges.append(t)
		prev = a.hit
	var worst := 0
	for i in edges.size():
		var n := 0
		for j in range(i, edges.size()):
			if edges[j] - edges[i] < 1.0:
				n += 1
		worst = maxi(worst, n)
	return float(worst)


func test_a10_hundred_hits_600_ms_apart_flash_at_most_3_times_per_second() -> void:
	if V11Slice.require(self, "D1"):
		return
	var ev: Array[float] = []
	for k in 100:
		ev.append(0.6 * k)
	assert_lte(_flash_edges_per_second(ev, 20.0), 3.0, "0,6 sn aralıklı hasar: <= 3/sn")


func test_a10_pile_up_of_hits_every_20_ms_flashes_at_most_3_times_per_second() -> void:
	if V11Slice.require(self, "D1"):
		return
	var ev: Array[float] = []
	for k in 150:
		ev.append(0.02 * k)
	assert_lte(
		_flash_edges_per_second(ev, 4.0), 3.0, "ardışık hasar yığını: parlama geçişi <= 3/sn"
	)


func test_a10_hits_every_150_ms_also_respect_the_3_hz_rule() -> void:
	if V11Slice.require(self, "D1"):
		return
	var ev: Array[float] = []
	for k in 40:
		ev.append(0.15 * k)
	assert_lte(_flash_edges_per_second(ev, 6.0), 3.0, "150 ms aralık: <= 3/sn")


## 0..1 çember üzerinde en kısa uzaklık (0,99999 ile 0,0 aynı faz).
func _circ(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, 1.0 - d)


# --- A11: WalkCycle (gerçek) ---------------------------------------------------------------------------------


func test_a11_foot_shift_per_frame_is_stride_over_n() -> void:
	assert_almost_eq(WalkCycle.foot_shift_per_frame(136.0, 6), 22.667, 0.01, "136 / 6")
	assert_almost_eq(WalkCycle.foot_shift_per_frame(136.0, 7), 136.0 / 7.0, 0.001)
	assert_almost_eq(WalkCycle.foot_shift_per_frame(136.0, 6), ExpectedTablesV11.FOOT_SHIFT_6, 1e-4)
	assert_eq(WalkCycle.foot_shift_per_frame(136.0, 0), 0.0)


func test_a11_phase_advances_by_one_per_stride_and_wraps() -> void:
	assert_almost_eq(WalkCycle.advance(0.25, 136.0, 136.0), 0.25, 1e-5, "136 px = tam çevrim")
	assert_almost_eq(WalkCycle.advance(0.0, 68.0, 136.0), 0.5, 1e-5)
	assert_almost_eq(_circ(WalkCycle.advance(0.9, 13.6, 136.0), 0.0), 0.0, 1e-4, "sarma")
	var ph := 0.0
	for i in 10:
		ph = WalkCycle.advance(ph, 13.6, 136.0)
	assert_almost_eq(_circ(ph, 0.0), 0.0, 1e-4, "10 x 13,6 px = 1 çevrim")
	assert_gte(WalkCycle.advance(0.5, -10.0, 136.0), 0.0, "geri adım negatif faz üretmez")
	assert_lt(WalkCycle.advance(0.5, -10.0, 136.0), 1.0)


func test_a11_frame_at_boundaries_for_six_and_seven_frames() -> void:
	for n in [6, 7]:
		assert_eq(WalkCycle.frame_at(0.0, n), 0)
		assert_eq(WalkCycle.frame_at(0.9999, n), n - 1)
		assert_eq(WalkCycle.frame_at(1.0, n), 0, "1,0 = 0 (sarma)")
		for k in n:
			assert_eq(
				WalkCycle.frame_at((float(k) + 0.001) / float(n), n), k, "N=%d kare %d" % [n, k]
			)
			assert_eq(WalkCycle.frame_at((float(k) + 0.999) / float(n), n), k)
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 6000:
		counts[WalkCycle.frame_at(float(i) / 6000.0, 6)] += 1
	assert_eq(counts, [1000, 1000, 1000, 1000, 1000, 1000], "kareler eşit sürede")
	assert_eq(WalkCycle.nearest_contact(0.1, 6), 0)
	assert_eq(WalkCycle.nearest_contact(0.5, 6), 3)
	assert_eq(WalkCycle.nearest_contact(0.9, 6), 0)


func test_a11_one_second_at_full_speed_steps_about_13_frames() -> void:
	var ph := 0.0
	var last := 0
	var changes := 0
	for i in 600:
		ph = WalkCycle.advance(ph, 300.0 / 600.0, 136.0)
		var f := WalkCycle.frame_at(ph, 6)
		if f != last:
			changes += 1
			last = f
	assert_between(changes, 12, 14, "300 px/sn: ~13 kare/sn")


# --- A12: kare modunda duruş geçişi ----------------------------------------------------------------------------


func test_a12_stop_crossfades_to_standing_cell_within_80_ms() -> void:
	if V11Slice.require(self, "D1") or V11Slice.require(self, "D4"):
		return
	var n := 6
	var a := _anim(n)
	_run(a, 0.6, Vector2(FAST, 0))
	_run(a, 0.001, Vector2.ZERO)
	var contact := a.frame_a
	assert_true(
		contact == 0 or contact == n / 2,
		"durma: en yakın temas karesi (0/%d): %d" % [n / 2, contact]
	)
	_run(a, 0.09, Vector2.ZERO)
	var eff := a.frame_b if a.frame_mix >= 0.5 else a.frame_a
	assert_eq(eff, n, "80 ms içinde duruş hücresi (indeks N)")
	assert_true(a.frame_mix <= 0.01 or a.frame_mix >= 0.99, "çapraz solma bitti")


func test_a12_starting_to_walk_snaps_to_frame_zero_without_blend() -> void:
	if V11Slice.require(self, "D1") or V11Slice.require(self, "D4"):
		return
	var a := _anim(6)
	_run(a, 0.5, Vector2.ZERO)
	a.update(DT, Vector2(FAST, 0), false, -1.0)
	assert_eq(a.frame_a, 0, "harekete başlayınca kare 0")
	assert_almost_eq(a.frame_mix, 0.0, 1e-4, "doğrudan geçiş (karışım yok)")


func test_a12_walking_frame_rate_follows_distance_not_time() -> void:
	if V11Slice.require(self, "D1") or V11Slice.require(self, "D4"):
		return
	var counts := {}
	for speed in [150.0, 300.0]:
		var a := _anim(6)
		_run(a, 0.3, Vector2(speed, 0))
		var st := {"last": a.frame_a, "changes": 0}
		_run(
			a,
			2.0,
			Vector2(speed, 0),
			false,
			-1.0,
			func(_t: float) -> void:
				if a.frame_a != st["last"]:
					st["changes"] += 1
					st["last"] = a.frame_a
		)
		counts[speed] = float(st["changes"]) / 2.0
	assert_between(counts[300.0], 12.0, 14.5, "tam hız ~13 kare/sn")
	assert_almost_eq(
		counts[150.0] / counts[300.0], 0.5, 0.1, "yarı hız: yarı kare hızı (mesafe tabanlı)"
	)


# --- A24: kare yok/var kipleri -------------------------------------------------------------------------------

const STRIP_DIR := "user://v11_strip_tests"


## N+1 hücreli renkli sentetik yürüme şeridi yazar; yolunu döndürür.
func _strip(n: int) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STRIP_DIR))
	var cw := 64
	var ch := 96
	var img := Image.create_empty(cw * (n + 1), ch, false, Image.FORMAT_RGBA8)
	for c in n + 1:
		img.fill_rect(
			Rect2i(c * cw + 8, 8, cw - 16, ch - 8),
			Color.from_hsv(float(c) / float(n + 1), 0.8, 0.9)
		)
	var path := "%s/strip_%d.png" % [STRIP_DIR, n]
	img.save_png(ProjectSettings.globalize_path(path))
	return path


func _view_run(frames: int) -> Dictionary:
	# Taze GameData: sim.character.rig değişikliği paylaşılan önbelleğe sızmaz.
	var sim := SimKit.make(3, {"data_kind": "real", "pickups": false, "log_events": false})
	SimKit.godmode(sim)
	var w: Dictionary = sim.character.rig["walk"]
	w["frames"] = frames
	if frames > 0:
		w["strip"] = _strip(frames)
		w["cell"] = [64, 96]
		w["shoulder_dev"] = []
	var v := PlayerView.new()
	add_child_autofree(v)
	v.bind(sim)
	for i in 180:
		sim.step(Vector2.RIGHT)
		v.update_view(1.0 / 60.0)
	for i in 60:
		sim.step(Vector2.ZERO)
		v.update_view(1.0 / 60.0)
	return {"sim": sim, "view": v}


func after_all() -> void:
	var abs_dir := ProjectSettings.globalize_path(STRIP_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)


func test_a24_frames_zero_runs_procedural_fallback_without_errors() -> void:
	if V11Slice.require(self, "D1"):
		return
	var r := _view_run(0)
	assert_gt(r["sim"].player_pos.x, 100.0, "oyuncu yürüdü")
	assert_not_null(r["view"].body)
	var a := _anim(0)
	var st := {"bob": 0.0}
	_run(
		a,
		2.0,
		Vector2(FAST, 0),
		false,
		-1.0,
		func(_t: float) -> void: st["bob"] = maxf(st["bob"], absf(a.bob_px))
	)
	assert_gt(st["bob"], 5.0, "kare yok: prosedürel bob çalışır")
	assert_eq(a.frame_b, 0, "kare seçimi kullanılmaz")
	assert_almost_eq(a.frame_mix, 0.0, 1e-4)


func test_a24_synthetic_six_and_seven_frame_strips_cycle_all_cells() -> void:
	if V11Slice.require(self, "D1") or V11Slice.require(self, "D4"):
		return
	for n in [6, 7]:
		var a := _anim(n)
		var seen := {}
		_run(a, 0.2, Vector2(FAST, 0))
		_run(a, 2.5, Vector2(FAST, 0), false, -1.0, func(_t: float) -> void: seen[a.frame_a] = true)
		assert_eq(
			seen.size(), n, "N=%d: yürürken %d kare de görünür (%s)" % [n, n, str(seen.keys())]
		)
		for k in seen:
			assert_between(
				int(k), 0, n - 1, "yürüme karesi 0..N-1 (duruş hücresi N yürürken seçilmez)"
			)
		var step := WalkCycle.foot_shift_per_frame(136.0, n)
		assert_almost_eq(step, 136.0 / float(n), 1e-4)


func test_a24_view_runs_with_synthetic_six_and_seven_frame_strips() -> void:
	if V11Slice.require(self, "D1") or V11Slice.require(self, "D4"):
		return
	for n in [6, 7]:
		var r := _view_run(n)
		assert_gt(r["sim"].player_pos.x, 100.0, "N=%d: oyuncu yürüdü, görünüm hatasız" % n)
		assert_not_null(r["view"].body)
