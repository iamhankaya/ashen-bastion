extends GutTest
## ShowcaseMotion (S3 gerçek, saf): nefes ve sürüklenme sınırları, periyot, geçiş süresi.


func test_scale_at_bounds_and_period() -> void:
	assert_almost_eq(ShowcaseMotion.scale_at(0.0), 1.0, 1e-9)
	assert_almost_eq(ShowcaseMotion.scale_at(1.2), 1.015, 1e-9, "yarı periyotta tepe")
	assert_almost_eq(ShowcaseMotion.scale_at(2.4), 1.0, 1e-9, "periyot sonu")
	for i in 241:
		var s := ShowcaseMotion.scale_at(i * 0.01)
		assert_gte(s, 1.0 - 1e-9)
		assert_lte(s, 1.015 + 1e-9)


func test_drift_at_bounds_and_period() -> void:
	assert_almost_eq(ShowcaseMotion.drift_at(0.0), 0.0, 1e-9)
	assert_almost_eq(ShowcaseMotion.drift_at(1.5), 8.0, 1e-9)
	assert_almost_eq(ShowcaseMotion.drift_at(4.5), -8.0, 1e-9)
	assert_almost_eq(ShowcaseMotion.drift_at(6.0), 0.0, 1e-9)
	for i in 601:
		assert_lte(absf(ShowcaseMotion.drift_at(i * 0.01)), 8.0 + 1e-9)


func test_functions_are_pure() -> void:
	assert_eq(ShowcaseMotion.scale_at(0.37), ShowcaseMotion.scale_at(0.37))
	assert_eq(ShowcaseMotion.drift_at(3.3), ShowcaseMotion.drift_at(3.3))


func test_crossfade_is_260_ms() -> void:
	assert_eq(ShowcaseMotion.CROSSFADE_SEC, 0.26)
