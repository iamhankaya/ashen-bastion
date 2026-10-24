extends GutTest
## WalkCycle: mesafe tabanlı faz ve kare seçimi (saf). N=6 ve N=7 (veri güdümlü kare sayısı).


func test_advance_one_stride_returns_to_the_same_phase() -> void:
	assert_almost_eq(WalkCycle.advance(0.0, 136.0, 136.0), 0.0, 1e-6, "136 px'te faz +1 (sarılır)")
	assert_almost_eq(WalkCycle.advance(0.25, 136.0, 136.0), 0.25, 1e-6)
	assert_almost_eq(WalkCycle.advance(0.0, 34.0, 136.0), 0.25, 1e-6)
	assert_almost_eq(WalkCycle.advance(0.9, 27.2, 136.0), 0.1, 1e-5, "0..1'e sarılır")


func test_advance_accumulates_across_frames() -> void:
	var p := 0.0
	for i in 136:
		p = WalkCycle.advance(p, 1.0, 136.0)
	assert_almost_eq(minf(p, 1.0 - p), 0.0, 1e-4, "bir tam döngü: faz 0'a (ya da 1'e) döner")
	p = 0.0
	for i in 68:
		p = WalkCycle.advance(p, 1.0, 136.0)
	assert_almost_eq(p, 0.5, 1e-4)


func test_advance_is_robust_to_bad_input() -> void:
	assert_eq(WalkCycle.advance(0.3, 50.0, 0.0), 0.3, "stride 0: faz değişmez")
	assert_eq(WalkCycle.advance(0.3, 50.0, -10.0), 0.3)
	assert_almost_eq(WalkCycle.advance(0.3, -34.0, 136.0), 0.05, 1e-5, "geri hareket sarar")
	assert_almost_eq(WalkCycle.advance(1.0, 0.0, 136.0), 0.0, 1e-6)
	assert_almost_eq(WalkCycle.advance(-0.25, 0.0, 136.0), 0.75, 1e-6)


func test_frame_at_boundaries_for_six_and_seven_frames() -> void:
	for n in [6, 7]:
		assert_eq(WalkCycle.frame_at(0.0, n), 0)
		assert_eq(WalkCycle.frame_at(0.9999, n), n - 1, "N=%d son kare" % n)
		assert_eq(WalkCycle.frame_at(1.0, n), 0, "faz 1.0 = döngü başı")
		for k in n:
			assert_eq(
				WalkCycle.frame_at((k + 0.5) / float(n), n), k, "N=%d kare %d ortası" % [n, k]
			)
			assert_eq(WalkCycle.frame_at(float(k) / float(n), n), k, "N=%d kare %d başı" % [n, k])


func test_frame_at_handles_degenerate_frame_counts() -> void:
	assert_eq(WalkCycle.frame_at(0.5, 0), 0)
	assert_eq(WalkCycle.frame_at(0.5, -3), 0)
	assert_eq(WalkCycle.frame_at(0.5, 1), 0)
	assert_eq(WalkCycle.frame_at(-0.25, 4), 3, "negatif faz sarılır")


func test_nearest_contact_snaps_to_frame_zero_or_the_opposite_contact() -> void:
	assert_eq(WalkCycle.nearest_contact(0.0, 6), 0)
	assert_eq(WalkCycle.nearest_contact(0.2, 6), 0)
	assert_eq(WalkCycle.nearest_contact(0.3, 6), 3)
	assert_eq(WalkCycle.nearest_contact(0.5, 6), 3)
	assert_eq(WalkCycle.nearest_contact(0.7, 6), 3)
	assert_eq(WalkCycle.nearest_contact(0.8, 6), 0)
	assert_eq(WalkCycle.nearest_contact(0.99, 6), 0)
	assert_eq(WalkCycle.nearest_contact(0.5, 7), 3, "tek N: frames/2 aşağı yuvarlanır")
	assert_eq(WalkCycle.nearest_contact(0.5, 0), 0)


func test_foot_shift_per_frame_is_stride_over_n() -> void:
	assert_almost_eq(WalkCycle.foot_shift_per_frame(136.0, 6), 22.67, 0.01)
	assert_almost_eq(WalkCycle.foot_shift_per_frame(136.0, 7), 19.43, 0.01)
	assert_eq(WalkCycle.foot_shift_per_frame(136.0, 0), 0.0)


func test_full_speed_frame_rate_matches_the_plan() -> void:
	# 300 px/sn, stride 136, N=6: ~13 kare/sn (plan: oyuncu).
	var frames_per_sec := 300.0 / WalkCycle.foot_shift_per_frame(136.0, 6)
	assert_almost_eq(frames_per_sec, 13.2, 0.1)
