extends GutTest
## HitStop: vuruş donması isteği (tavan 0,15 sn) ve kare sayacı.


func test_idle_never_freezes() -> void:
	var h := HitStop.new()
	assert_false(h.tick(1.0 / 60.0))
	assert_eq(h.left, 0.0)


func test_request_freezes_for_the_requested_time() -> void:
	var h := HitStop.new()
	h.request(0.06)  # bomba
	var frozen := 0
	while h.tick(1.0 / 60.0):
		frozen += 1
		assert_lt(frozen, 100)
	assert_eq(frozen, 4, "0,06 sn @60 Hz = 4 kare (kısmi kare dahil)")
	assert_false(h.tick(1.0 / 60.0))


func test_request_is_capped_at_015() -> void:
	var h := HitStop.new()
	h.request(5.0)
	assert_eq(h.left, HitStop.MAX_SEC)
	h.request(0.15)
	assert_eq(h.left, 0.15)


func test_requests_take_the_maximum_and_never_stack() -> void:
	var h := HitStop.new()
	h.request(0.08)
	h.request(0.06)
	assert_eq(h.left, 0.08, "kısa istek uzunu kısaltmaz")
	h.request(0.15)
	assert_eq(h.left, 0.15)
	h.request(0.15)
	assert_eq(h.left, 0.15, "yığılmaz")


func test_remaining_time_decreases_with_each_frozen_tick() -> void:
	var h := HitStop.new()
	h.request(0.15)
	assert_true(h.tick(0.05))
	assert_almost_eq(h.left, 0.10, 1e-6)
	assert_true(h.tick(0.20), "son kare de donuk")
	assert_eq(h.left, 0.0)
	assert_false(h.tick(0.016))


func test_negative_dt_does_not_extend_the_freeze() -> void:
	var h := HitStop.new()
	h.request(0.06)
	assert_true(h.tick(-1.0))
	assert_almost_eq(h.left, 0.06, 1e-6)


func test_negative_request_is_harmless() -> void:
	var h := HitStop.new()
	h.request(-1.0)
	assert_eq(h.left, 0.0)
	assert_false(h.tick(0.016))


func test_plan_request_values_fit_under_the_cap() -> void:
	for ms in [Motion.HITSTOP_BOMB, Motion.HITSTOP_LORD_RAGE, Motion.HITSTOP_LORD_DEATH]:
		assert_lte(Motion.sec(ms), HitStop.MAX_SEC)
	assert_eq(Motion.sec(Motion.HITSTOP_LORD_DEATH), HitStop.MAX_SEC)
