extends GutTest
## BuffManager: tam sayı adım sayaçları, yenileme (yığılmaz), bitiş, bağımsız etkiler.

const D := BuffManager.Kind.DAMAGE
const F := BuffManager.Kind.FIRE_RATE
const U := BuffManager.Kind.UNLIMITED


func test_idle_manager_reports_neutral_values() -> void:
	var m := BuffManager.new()
	assert_false(m.active(D))
	assert_eq(m.damage_mult(), 1.0)
	assert_eq(m.fire_rate_mult(), 1.0)
	assert_false(m.unlimited())
	assert_eq(m.ratio(D), 0.0)


func test_start_is_new_then_refresh_resets_duration_without_stacking() -> void:
	var m := BuffManager.new()
	assert_true(m.start(D, 720, 1.5))
	var ended := PackedInt32Array()
	for _s in 300:
		m.tick(ended)
	assert_eq(m.left_steps[D], 420)
	assert_false(m.start(D, 720, 1.5), "yenileme: false")
	assert_eq(m.left_steps[D], 720, "süre tazelenir (17 sn değil)")
	assert_eq(m.damage_mult(), 1.5, "çarpan yığılmaz")


func test_buff_ends_after_exact_steps_and_reports_kind_once() -> void:
	var m := BuffManager.new()
	m.start(F, 720, 1.4)
	var ended := PackedInt32Array()
	var ended_at := -1
	for s in 800:
		m.tick(ended)
		if not ended.is_empty():
			assert_eq(ended, PackedInt32Array([F]))
			assert_eq(ended_at, -1, "tek bitiş")
			ended_at = s + 1
	assert_eq(ended_at, 720)
	assert_eq(m.fire_rate_mult(), 1.0)
	assert_false(m.active(F))


func test_kinds_are_independent_counters() -> void:
	var m := BuffManager.new()
	m.start(D, 100, 1.5)
	m.start(F, 200, 1.4)
	var ended := PackedInt32Array()
	for _s in 100:
		m.tick(ended)
	assert_eq(ended, PackedInt32Array([D]))
	assert_eq(m.damage_mult(), 1.0)
	assert_almost_eq(m.fire_rate_mult(), 1.4, 0.0001)
	assert_almost_eq(m.ratio(F), 0.5, 0.0001)
	assert_true(m.any_active())


func test_ratio_goes_from_one_to_zero() -> void:
	var m := BuffManager.new()
	m.start(U, 600)
	assert_eq(m.ratio(U), 1.0)
	var ended := PackedInt32Array()
	for _s in 150:
		m.tick(ended)
	assert_almost_eq(m.ratio(U), 0.75, 0.0001)
	assert_true(m.unlimited())
