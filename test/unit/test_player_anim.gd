extends GutTest
## PlayerAnim (D1-1): saf durum makinesi; eğriler, zamanlar, tavanlar ve <=3 Hz parlama kuralı (DESIGN §1.2 P1-P13).

const DT := 1.0 / 60.0
const RIG_PROC := {"walk": {"frames": 0, "stride": 136.0}}
const RIG_FRAMES := {"walk": {"frames": 6, "stride": 136.0}}


func _anim(rig: Dictionary = RIG_PROC) -> PlayerAnim:
	var a := PlayerAnim.new()
	a.configure(rig)
	return a


func _run(a: PlayerAnim, secs: float, vel: Vector2 = Vector2.ZERO, rp: float = -1.0) -> void:
	for i in roundi(secs / DT):
		a.update(DT, vel, false, rp)


func test_breath_keeps_body_and_arms_within_the_small_range() -> void:
	var a := _anim()
	var lo := 9.0
	var hi := 0.0
	var max_arm := 0.0
	for i in roundi(5.0 / DT):
		a.update(DT, Vector2.ZERO, false, -1.0)
		lo = minf(lo, a.sy)
		hi = maxf(hi, a.sy)
		max_arm = maxf(max_arm, absf(a.arm_rot[0]))
	assert_gte(lo, 1.0 - 1e-5)
	assert_lte(hi, 1.015 + 1e-5)
	assert_gt(hi, 1.012, "nefes tepe değerine ulaşır")
	assert_lte(rad_to_deg(max_arm), 1.5 + 0.01)
	assert_eq(a.mode, PlayerAnim.Mode.IDLE)
	assert_almost_eq(a.scarf_amp, 3.0, 0.01, "duruşta atkı 3 px")


func test_mode_hysteresis_idle_walk() -> void:
	var a := _anim()
	a.update(DT, Vector2(7.0, 0.0), false, -1.0)
	assert_eq(a.mode, PlayerAnim.Mode.IDLE, "8 px/sn altında yürümeye girmez")
	a.update(DT, Vector2(9.0, 0.0), false, -1.0)
	assert_eq(a.mode, PlayerAnim.Mode.WALK)
	a.update(DT, Vector2(6.0, 0.0), false, -1.0)
	assert_eq(a.mode, PlayerAnim.Mode.WALK, "5-8 arası histerezis: yürümede kalır")
	a.update(DT, Vector2(4.0, 0.0), false, -1.0)
	assert_eq(a.mode, PlayerAnim.Mode.IDLE)


func test_procedural_bob_peaks_at_nine_px_and_scales_with_speed() -> void:
	var a := _anim()
	var peak := 0.0
	for i in roundi(2.0 / DT):
		a.update(DT, Vector2(300.0, 0.0), false, -1.0)
		peak = maxf(peak, a.bob_px)
	assert_almost_eq(peak, 9.0, 0.35, "tepe bob 9 px")
	var f_full := _phase_rate(300.0)
	assert_almost_eq(f_full, 2.2, 0.05, "tam hızda 2,2 Hz")
	assert_almost_eq(_phase_rate(75.0), 1.1, 0.05, "hız/300 0,5'e kenetlenir: 1,1 Hz")
	assert_almost_eq(_phase_rate(600.0), 2.2, 0.05, "üst sınır 1")


func _phase_rate(speed: float) -> float:
	var a := _anim()
	a.update(DT, Vector2(speed, 0.0), false, -1.0)
	var p0 := a.walk_phase
	var total := 0.0
	var prev := p0
	for i in 60:
		a.update(DT, Vector2(speed, 0.0), false, -1.0)
		total += fposmod(a.walk_phase - prev, 1.0)
		prev = a.walk_phase
	return total


func test_frame_mode_has_no_bob_no_walk_squash_and_reduced_lean() -> void:
	var a := _anim(RIG_FRAMES)
	var peak := 0.0
	for i in roundi(1.0 / DT):
		a.update(DT, Vector2(300.0, 0.0), false, -1.0)
		peak = maxf(peak, a.bob_px)
		assert_almost_eq(a.sx, 1.0, 1e-4)
		assert_almost_eq(a.sy, 1.0, 1e-4)
	assert_eq(peak, 0.0, "kare modunda prosedürel bob 0")
	assert_almost_eq(rad_to_deg(a.lean), 3.6, 0.1, "kare modunda eğim %60")


func test_lean_reaches_six_degrees_and_ninety_percent_in_120ms() -> void:
	var a := _anim()
	_run(a, 0.12, Vector2(300.0, 0.0))
	assert_gte(rad_to_deg(a.lean), 0.9 * 6.0)
	_run(a, 0.5, Vector2(300.0, 0.0))
	assert_almost_eq(rad_to_deg(a.lean), 6.0, 0.05)
	_run(a, 0.5, Vector2(-300.0, 0.0))
	assert_almost_eq(rad_to_deg(a.lean), -6.0, 0.05, "yön işareti")
	_run(a, 0.5, Vector2(150.0, 0.0))
	assert_almost_eq(rad_to_deg(a.lean), 3.0, 0.05, "orantılı")


func test_turn_mirrors_at_midpoint_with_quarter_width() -> void:
	var a := _anim()
	_run(a, 0.1, Vector2.ZERO)
	assert_eq(a.turn_x, 1.0)
	var min_abs := 9.0
	var seen_neg := false
	for i in 80:
		a.update(0.001, Vector2.ZERO, true, -1.0)
		min_abs = minf(min_abs, absf(a.turn_x))
		seen_neg = seen_neg or a.turn_x < 0.0
	assert_true(seen_neg)
	assert_lte(min_abs, 0.3)
	assert_gte(min_abs, 0.2, "orta nokta |sx| ~0,25")
	for i in 20:
		a.update(DT, Vector2.ZERO, true, -1.0)
	assert_eq(a.turn_x, -1.0, "tamamlanınca sola bakıyor")


func test_turn_takes_70ms() -> void:
	var a := _anim()
	_run(a, 0.1)
	var t := 0
	a.update(DT, Vector2.ZERO, true, -1.0)
	while absf(a.turn_x + 1.0) > 1e-4 and t < 30:
		a.update(DT, Vector2.ZERO, true, -1.0)
		t += 1
	assert_lte(float(t) * DT, 0.07 + 2.0 * DT)
	assert_gte(float(t) * DT, 0.07 - 2.0 * DT)


func test_facing_margin_below_8px_does_not_turn() -> void:
	var a := _anim()
	_run(a, 0.1)
	a.facing_margin_px = 5.0
	_run(a, 0.2, Vector2.ZERO)
	a.update(DT, Vector2.ZERO, true, -1.0)
	_run(a, 0.2, Vector2.ZERO)
	assert_eq(a.turn_x, 1.0, "<8 px: dönüş yok")
	a.facing_margin_px = 20.0
	for i in 20:
		a.update(DT, Vector2.ZERO, true, -1.0)
	assert_eq(a.turn_x, -1.0)


func test_recoil_peaks_at_40ms_and_settles_by_150ms() -> void:
	var a := _anim()
	var ctl := _anim()
	_run(a, 0.1)
	_run(ctl, 0.1)
	a.on_shot(0)
	var peak := 0.0
	var peak_t := 0.0
	var t := 0.0
	var min_v := 0.0
	for i in 12:
		a.update(DT, Vector2.ZERO, false, -1.0)
		ctl.update(DT, Vector2.ZERO, false, -1.0)
		t += DT
		var d := a.arm_rot[0] - ctl.arm_rot[0]
		min_v = minf(min_v, d)
		if d > peak:
			peak = d
			peak_t = t
	assert_almost_eq(rad_to_deg(peak), 8.0, 0.6, "8° yukarı")
	assert_almost_eq(peak_t, 0.04, 0.02, "40 ms'de tepe")
	assert_lt(min_v, -deg_to_rad(0.5), "-1,5° aşma")
	assert_gt(min_v, -deg_to_rad(3.0))
	_run(a, 0.1)
	assert_almost_eq(a.arm_back[0], 0.0, 0.05)
	assert_almost_eq(a.arm_len[0], 1.0, 1e-3)
	assert_almost_eq(a.arm_back[1], 0.0, 1e-4, "ikinci tabanca bağımsız")


func test_recoil_back_and_len_at_peak_and_cap_125() -> void:
	var a := _anim()
	a.on_shot(0)
	for i in 2:
		a.update(DT, Vector2.ZERO, false, -1.0)
	assert_gt(a.arm_back[0], 5.0)
	assert_lt(a.arm_len[0], 0.97)
	var cap_back := 0.0
	var cap_len := 1.0
	for k in 12:  # ardışık atış: tavan 1,25
		a.on_shot(0)
		for i in 2:
			a.update(DT, Vector2.ZERO, false, -1.0)
		cap_back = maxf(cap_back, a.arm_back[0])
		cap_len = minf(cap_len, a.arm_len[0])
	assert_lte(cap_back, 10.0 * 1.25 + 0.01, "tepme 1,25× tavan")
	assert_gte(cap_len, 1.0 - 0.06 * 1.25 - 1e-3)


func test_reload_pose_timeline() -> void:
	var a := _anim()
	_run(a, 0.1)
	a.update(DT, Vector2.ZERO, false, 0.12)
	assert_almost_eq(rad_to_deg(a.arm_rot[0]), -70.0, 1.0, "%12'de kollar 70° aşağı")
	var max_dev := 0.0
	var sy_mid := 0.0
	for k in 40:
		var p := 0.12 + 0.58 * float(k) / 39.0
		a.update(DT, Vector2.ZERO, false, p)
		max_dev = maxf(max_dev, absf(rad_to_deg(a.arm_rot[0]) + 70.0))
		if k == 20:
			sy_mid = a.sy
	assert_lte(max_dev, 10.5, "titreme ±10°")
	assert_gt(max_dev, 4.0)
	assert_almost_eq(sy_mid, 0.97, 0.02, "doldururken gövde sy 0,97")
	var over := -99.0
	for k in 21:
		a.update(DT, Vector2.ZERO, false, 0.8 + 0.2 * float(k) / 20.0)
		over = maxf(over, rad_to_deg(a.arm_rot[0]))
	assert_almost_eq(over, 6.0, 0.5, "+6° aşma")
	a.update(DT, Vector2.ZERO, false, 1.0)
	assert_almost_eq(rad_to_deg(a.arm_rot[0]), 0.0, 1.0)


func test_damage_flash_tint_and_knock_timeline() -> void:
	var a := _anim()
	_run(a, 0.5)
	a.on_damaged(10.0, Vector2.LEFT)
	a.update(DT, Vector2.ZERO, false, -1.0)
	assert_eq(a.hit, 1.0, "0-90 ms beyaz parlama")
	var max_knock := 0.0
	var sx_at := 1.0
	var sy_at := 1.0
	var scarf_at_100ms := 0.0
	for i in 5:
		a.update(DT, Vector2.ZERO, false, -1.0)
		if a.knock_px > max_knock:
			max_knock = a.knock_px
			sx_at = a.sx
			sy_at = a.sy
		if i == 4:
			scarf_at_100ms = a.scarf_amp
	assert_gt(max_knock, 7.0, "~50 ms'de ~8 px geri")
	assert_lte(max_knock, 8.01)
	assert_gt(sx_at, 1.08)
	assert_lt(sy_at, 0.92)
	assert_eq(a.hit, 0.0, "90 ms sonra parlama biter")
	assert_gt(a.tint_amt, 0.0, "bordo ton sürer")
	assert_eq(a.tint, PlayerAnim.BORDO)
	assert_gt(scarf_at_100ms, 5.0, "atkı x2,5 sönümü")
	_run(a, 0.5)
	assert_almost_eq(a.tint_amt, 0.0, 1e-4)
	assert_almost_eq(a.knock_px, 0.0, 1e-3)
	assert_almost_eq(a.scarf_amp, 3.0, 0.05)
	assert_eq(a.knock_dir, Vector2.RIGHT, "saldırganın tersi")


func test_second_hit_within_100ms_does_not_restart_the_white_flash() -> void:
	var a := _anim()
	_run(a, 0.5)
	a.on_damaged(5.0, Vector2.LEFT)
	_run(a, 0.1)
	assert_eq(a.hit, 0.0)
	a.on_damaged(5.0, Vector2.LEFT)
	a.update(DT, Vector2.ZERO, false, -1.0)
	assert_eq(a.hit, 0.0, "100 ms arayla ikinci hasar: parlama yeniden başlamaz")
	assert_gt(a.tint_amt, 0.2, "ama ton yenilenir")


func test_flash_rate_never_exceeds_3_per_second() -> void:
	var a := _anim()
	var rises := 0
	var prev := 0.0
	var elapsed := 0.0
	# 100 olay, 0,6 sn aralıklı
	for k in 100:
		a.on_damaged(5.0, Vector2.LEFT)
		for i in roundi(0.6 / DT):
			a.update(DT, Vector2.ZERO, false, -1.0)
			if a.hit > 0.0 and prev == 0.0:
				rises += 1
			prev = a.hit
			elapsed += DT
	assert_lte(float(rises) / elapsed, 3.0)
	assert_eq(rises, 100, "0,6 sn aralıklı her hasar parlar")
	# ardışık yığın: her karede hasar
	var b := _anim()
	rises = 0
	prev = 0.0
	elapsed = 0.0
	for i in roundi(10.0 / DT):
		b.on_damaged(5.0, Vector2.LEFT)
		b.update(DT, Vector2.ZERO, false, -1.0)
		if b.hit > 0.0 and prev == 0.0:
			rises += 1
		prev = b.hit
		elapsed += DT
	assert_lte(float(rises) / elapsed, 3.0, "yığılmış olaylarda da <=3 Hz")


func test_death_timeline() -> void:
	var a := _anim()
	_run(a, 0.2)
	a.on_died(Vector2.RIGHT)  # hasar sağdan geldi -> sola devrilir
	assert_eq(a.mode, PlayerAnim.Mode.DEAD)
	_run(a, 0.1)
	assert_eq(a.hit, 1.0, "0-120 ms donma + beyaz parlama")
	assert_almost_eq(a.body_rot, 0.0, 0.01)
	_run(a, 0.62)  # t=0,72
	assert_almost_eq(rad_to_deg(a.body_rot), -75.0, 1.5, "720 ms'de -75° (hasarın tersi)")
	assert_almost_eq(a.desat, 0.6, 0.05)
	assert_gt(a.sink_px, 6.0)
	assert_false(a.death_done())
	_run(a, 0.2)
	assert_lte(absf(rad_to_deg(a.body_rot) + 75.0), 5.0, "±4° sekme")
	_run(a, 0.4)  # t=1,32
	assert_true(a.death_done())
	assert_almost_eq(a.fade, 0.0, 0.02)


func test_death_direction_opposite_of_damage_and_fallback_to_facing() -> void:
	var a := _anim()
	a.on_died(Vector2.LEFT)
	_run(a, 0.8)
	assert_gt(a.body_rot, 0.0, "soldan hasar: sağa (saat yönü) devrilir")
	var b := _anim()
	b.on_died(Vector2.ZERO)
	_run(b, 0.8)
	assert_lt(b.body_rot, 0.0, "yön yok + sağa bakış: sola (bakışın tersi)")
	var c := _anim()
	c.update(DT, Vector2.ZERO, true, -1.0)
	c.on_died(Vector2.ZERO)
	_run(c, 0.8)
	assert_gt(c.body_rot, 0.0)


func test_death_arms_hang_and_light_fades() -> void:
	var a := _anim()
	a.on_died(Vector2.LEFT)
	_run(a, 0.5)
	assert_lt(rad_to_deg(a.arm_rot[0]), -90.0, "kollar ~100° sarkar")
	_run(a, 0.2)
	assert_almost_eq(a.halo, -1.0, 0.05, "amber ışık 600 ms'de söner")


func test_dead_ignores_further_events_and_reset_restores() -> void:
	var a := _anim()
	a.on_died(Vector2.LEFT)
	a.on_damaged(5.0, Vector2.LEFT)
	a.on_shot(0)
	a.on_level_up()
	_run(a, 0.3, Vector2(300.0, 0.0))
	assert_eq(a.mode, PlayerAnim.Mode.DEAD)
	a.reset()
	assert_eq(a.mode, PlayerAnim.Mode.IDLE)
	assert_eq(a.fade, 1.0)
	assert_eq(a.body_rot, 0.0)
	assert_eq(a.level_ring, -1.0)
	assert_false(a.death_done())


func test_won_goes_idle_and_only_breathes() -> void:
	var a := _anim()
	_run(a, 0.2, Vector2(300.0, 0.0))
	a.on_won()
	_run(a, 0.5, Vector2(300.0, 0.0))
	assert_eq(a.mode, PlayerAnim.Mode.IDLE)
	assert_eq(a.bob_px, 0.0)
	assert_almost_eq(a.lean, 0.0, 1e-3)
	assert_eq(a.hit, 0.0)


func test_level_ring_grows_to_180_in_450ms_and_ends() -> void:
	var a := _anim()
	assert_eq(a.level_ring, -1.0)
	a.on_level_up()
	_run(a, 0.225)
	assert_gt(a.level_ring, 100.0, "cubic-out: yarıda >%55")
	assert_lt(a.level_ring, 180.0)
	_run(a, 0.225)
	assert_almost_eq(a.level_ring, 180.0, 4.0, "450. ms'de 180 px")
	_run(a, 0.1)
	assert_eq(a.level_ring, -1.0, "bitince yok")


func test_level_up_preroll_glow_then_clears() -> void:
	var a := _anim()
	a.on_level_up()
	_run(a, 0.1)
	assert_gt(a.halo, 0.2, "halo x1,3")
	assert_gt(a.tint_amt, 0.2)
	assert_eq(a.tint, PlayerAnim.GOLD)
	_run(a, 0.6)
	assert_almost_eq(a.halo, 0.0, 1e-3)
	assert_almost_eq(a.tint_amt, 0.0, 1e-3)


func test_aura_mask_roundtrip() -> void:
	var a := _anim()
	a.on_buffs(5)
	assert_eq(a.aura_mask, 5)
	a.on_buffs(0)
	assert_eq(a.aura_mask, 0)


func test_frame_mode_stop_crossfades_to_stand_within_80ms_and_start_is_frame_zero() -> void:
	var a := _anim(RIG_FRAMES)
	assert_eq(a.frame_a, 6, "duruş hücresi N")
	_run(a, 0.5, Vector2(300.0, 0.0))
	var seen := {}
	for i in 12:
		a.update(DT, Vector2(300.0, 0.0), false, -1.0)
		seen[a.frame_a] = true
		assert_lt(a.frame_a, 6)
	assert_gt(seen.size(), 2, "yürürken kareler ilerler")
	a.update(DT, Vector2.ZERO, false, -1.0)
	assert_gt(a.frame_mix, 0.0, "durmada çapraz solma")
	assert_eq(a.frame_b, 6)
	_run(a, 0.08)
	assert_eq(a.frame_a, 6, "<=80 ms'de duruş hücresi")
	assert_eq(a.frame_mix, 0.0)
	a.update(DT, Vector2(300.0, 0.0), false, -1.0)
	assert_eq(a.frame_a, 0, "harekete başlayınca kare 0")
	assert_eq(a.frame_mix, 0.0)


func test_frame_mode_walk_phase_is_distance_based() -> void:
	var a := _anim(RIG_FRAMES)
	a.update(DT, Vector2(136.0 * 60.0 / 6.0 * 1.02, 0.0), false, -1.0)  # ~1/6 çevrim = 1 kare
	assert_eq(a.frame_a, 1)
	a.configure(RIG_FRAMES)
	a.reset()
	for i in 60:
		a.update(DT, Vector2(136.0, 0.0), false, -1.0)  # 136 px/sn, 1 sn = 1 çevrim
	assert_almost_eq(minf(a.walk_phase, 1.0 - a.walk_phase), 0.0, 0.02)


func test_teleport_does_not_advance_walk_phase() -> void:
	var a := _anim(RIG_FRAMES)
	a.update(DT, Vector2(300.0, 0.0), false, -1.0)
	var before := a.walk_phase
	a.update(DT, Vector2(300000.0, 0.0), false, -1.0)  # 5000 px/kare
	assert_almost_eq(a.walk_phase, before, 1e-6)


func test_configure_reads_frame_count_and_clamps_garbage() -> void:
	var a := PlayerAnim.new()
	a.configure({})
	assert_eq(a.frame_a, 0, "walk yok: prosedürel yedek")
	a.configure({"walk": {"frames": 99, "stride": -5.0}})
	a.update(DT, Vector2(300.0, 0.0), false, -1.0)
	assert_true(is_finite(a.walk_phase))
	a.configure({"walk": "bozuk"})
	a.update(DT, Vector2(300.0, 0.0), false, -1.0)
	assert_eq(a.mode, PlayerAnim.Mode.WALK)


func test_zero_dt_changes_nothing() -> void:
	var a := _anim()
	a.on_damaged(5.0, Vector2.LEFT)
	a.update(0.0, Vector2.ZERO, false, -1.0)
	var k := a.knock_px
	a.update(0.0, Vector2.ZERO, false, -1.0)
	assert_eq(a.knock_px, k)


func test_reversing_mid_turn_continues_from_the_current_width() -> void:
	var a := _anim()
	_run(a, 0.1)
	for i in 3:
		a.update(0.01, Vector2.ZERO, true, -1.0)
	var mid := a.turn_x
	a.update(0.001, Vector2.ZERO, false, -1.0)  # geri çevir
	assert_lt(absf(a.turn_x - mid), 0.12, "genişlik sıçramaz")
