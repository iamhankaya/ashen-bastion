extends GutTest
## ResultTimeline: sayma/satır/damga/düğme zamanları (DESIGN §3.3).


func test_buttons_ready_at_rules() -> void:
	assert_almost_eq(ResultTimeline.buttons_ready_at(-1.0), 1.3, 1e-6)
	assert_almost_eq(ResultTimeline.buttons_ready_at(0.2), 0.8, 1e-6, "erken atlama: 0,8")
	assert_almost_eq(ResultTimeline.buttons_ready_at(0.5), 0.9, 1e-6, "skip_t + 0,4")
	assert_almost_eq(ResultTimeline.buttons_ready_at(1.0), 1.3, 1e-6, "üst sınır 1,3")
	assert_almost_eq(ResultTimeline.buttons_ready_at(5.0), 1.3, 1e-6)


func test_constants_come_from_motion() -> void:
	assert_almost_eq(ResultTimeline.count_sec(), 0.9, 1e-6)
	assert_almost_eq(ResultTimeline.stagger_sec(), 0.12, 1e-6)
	assert_almost_eq(ResultTimeline.stamp_at(), 1.25, 1e-6)
	assert_almost_eq(ResultTimeline.buttons_at(), 1.3, 1e-6)


func test_count_progress_is_cubic_out_and_clamped() -> void:
	assert_eq(ResultTimeline.count_progress(0.0), 0.0)
	assert_eq(ResultTimeline.count_progress(-1.0), 0.0)
	assert_almost_eq(ResultTimeline.count_progress(0.45), 1.0 - pow(0.5, 3.0), 1e-6)
	assert_eq(ResultTimeline.count_progress(0.9), 1.0)
	assert_eq(ResultTimeline.count_progress(9.0), 1.0)


func test_rows_start_at_300ms_with_120ms_stagger_and_count_400ms() -> void:
	assert_almost_eq(ResultTimeline.row_start(0), 0.3, 1e-6)
	assert_almost_eq(ResultTimeline.row_start(4), 0.78, 1e-6)
	assert_eq(ResultTimeline.row_progress(0, 0.29), 0.0)
	assert_gt(ResultTimeline.row_progress(0, 0.4), 0.0)
	assert_eq(ResultTimeline.row_progress(0, 0.7), 1.0)
	assert_eq(ResultTimeline.row_progress(2, 0.5), 0.0, "3. satır 0,54'te başlar")
	assert_eq(ResultTimeline.row_progress(4, 1.18), 1.0)
