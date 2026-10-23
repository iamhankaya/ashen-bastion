extends GutTest
## ScreenDelay: tek tetikli gecikme (ölüm 1,3 / kazanma 1,8 / seviye ön vurgusu 0,18 sn).

const S := PauseLogic.Screen


func test_starts_inactive() -> void:
	var d := ScreenDelay.new()
	assert_false(d.active)
	assert_false(d.tick(10.0), "aktif değilken tick tetiklemez")
	assert_false(d.skip(), "aktif değilken skip no-op")


func test_tick_fires_once_when_the_time_is_up() -> void:
	var d := ScreenDelay.new()
	d.start(S.RESULT, 1.3)
	assert_true(d.active)
	assert_eq(d.target, S.RESULT)
	assert_almost_eq(d.left, 1.3, 1e-6)
	var fired := 0
	var frames := 0
	while d.active and frames < 1000:
		frames += 1
		if d.tick(1.0 / 60.0):
			fired += 1
	assert_eq(fired, 1, "tam bir kez")
	assert_between(frames, 78, 79, "1,3 sn @60 Hz = 78 kare (kayan nokta payı 1)")
	assert_false(d.active)
	assert_false(d.tick(1.0), "ikinci tetik yok")
	assert_eq(d.left, 0.0)


func test_tick_exact_boundary_fires() -> void:
	var d := ScreenDelay.new()
	d.start(S.RESULT, 0.5)
	assert_false(d.tick(0.25))
	assert_true(d.tick(0.25), "left == 0 tetikler")


func test_skip_fires_immediately_and_only_once() -> void:
	var d := ScreenDelay.new()
	d.start(S.RESULT, 1.8)
	assert_true(d.skip())
	assert_false(d.active)
	assert_false(d.skip(), "ikinci skip no-op")
	assert_false(d.tick(5.0), "skip sonrası süre bitimi ikinci kez tetiklemez")


func test_tick_then_skip_does_not_double_fire() -> void:
	var d := ScreenDelay.new()
	d.start(S.RESULT, 0.1)
	assert_true(d.tick(0.2))
	assert_false(d.skip())


func test_start_while_active_is_ignored_so_the_timer_cannot_be_restarted() -> void:
	var d := ScreenDelay.new()
	d.start(S.RESULT, 1.0)
	d.tick(0.6)
	d.start(S.LEVEL_UP, 5.0)
	assert_eq(d.target, S.RESULT)
	assert_almost_eq(d.left, 0.4, 1e-6, "süre sıfırlanmaz")


func test_can_start_again_after_it_fired() -> void:
	var d := ScreenDelay.new()
	d.start(S.RESULT, 0.1)
	d.skip()
	d.start(S.LEVEL_UP, PauseLogic.LEVEL_UP_PREROLL)
	assert_true(d.active)
	assert_eq(d.target, S.LEVEL_UP)
	assert_almost_eq(d.left, 0.18, 1e-6)


func test_negative_or_zero_duration_fires_on_the_next_tick() -> void:
	var d := ScreenDelay.new()
	d.start(S.RESULT, -3.0)
	assert_eq(d.left, 0.0)
	assert_true(d.tick(0.0))
