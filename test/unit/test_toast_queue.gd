extends GutTest
## ToastQueue (S3 gerçek, saf): ≤1 görünür, bekleyen ≤3, taşan overflow, toplam 2,5 sn, 150 ms boşluk, dt=0 durur.

const P := ToastQueue.Phase
const EPS := 1e-6


func test_starts_idle_and_empty() -> void:
	var q := ToastQueue.new()
	assert_eq(q.phase(), P.IDLE)
	assert_eq(q.current(), &"")
	assert_eq(q.offset_alpha(), Vector2.ZERO)
	assert_eq(q.overflow, 0)


func test_push_when_idle_shows_immediately() -> void:
	var q := ToastQueue.new()
	assert_true(q.push(&"ilk_kan"))
	assert_eq(q.phase(), P.IN)
	assert_eq(q.current(), &"ilk_kan")
	assert_eq(q.offset_alpha(), Vector2(24.0, 0.0))


func test_total_visible_time_is_2_5_seconds() -> void:
	var q := ToastQueue.new()
	q.push(&"a")
	q.tick(0.22 - 0.001)
	assert_eq(q.phase(), P.IN)
	q.tick(0.002)
	assert_eq(q.phase(), P.HOLD)
	q.tick(2.1)
	assert_eq(q.phase(), P.OUT)
	assert_eq(q.current(), &"a", "çıkışta hâlâ görünür")
	q.tick(0.18 - 0.001)
	assert_eq(q.current(), &"a")
	q.tick(0.002)
	assert_eq(q.current(), &"", "2,5 sn sonra görünmez")
	assert_eq(q.phase(), P.GAP)


func test_gap_is_150_ms_then_idle() -> void:
	var q := ToastQueue.new()
	q.push(&"a")
	q.tick(2.5 + 0.0001)
	assert_eq(q.phase(), P.GAP)
	q.tick(0.15 - 0.001)
	assert_eq(q.phase(), P.GAP)
	q.tick(0.002)
	assert_eq(q.phase(), P.IDLE)


func test_second_toast_starts_after_the_gap_not_before() -> void:
	var q := ToastQueue.new()
	q.push(&"a")
	q.push(&"b")
	assert_eq(q.current(), &"a", "aynı anda tek görünür")
	q.tick(2.5 + 0.1)
	assert_eq(q.current(), &"", "boşlukta kimse görünmez")
	q.tick(0.06)
	assert_eq(q.current(), &"b")
	assert_eq(q.phase(), P.IN)


func test_waiting_queue_caps_at_three_and_overflow_counts() -> void:
	var q := ToastQueue.new()
	assert_true(q.push(&"a"))  # görünür
	assert_true(q.push(&"b"))
	assert_true(q.push(&"c"))
	assert_true(q.push(&"d"))  # bekleyen 3
	assert_false(q.push(&"e"))
	assert_false(q.push(&"f"))
	assert_eq(q.overflow, 2)
	assert_eq(q.waiting_count(), 3)
	var shown: Array[StringName] = []
	for i in 400:
		q.tick(0.05)
		if q.current() != &"" and (shown.is_empty() or shown[-1] != q.current()):
			shown.append(q.current())
	assert_eq(shown, [&"a", &"b", &"c", &"d"] as Array[StringName], "taşanlar hiç gösterilmez")


func test_tick_zero_freezes_everything() -> void:
	var q := ToastQueue.new()
	q.push(&"a")
	q.tick(0.1)
	var oa := q.offset_alpha()
	for i in 100:
		q.tick(0.0)
	assert_eq(q.phase(), P.IN)
	assert_eq(q.offset_alpha(), oa)


func test_one_big_tick_crosses_several_phases() -> void:
	var q := ToastQueue.new()
	q.push(&"a")
	q.push(&"b")
	q.tick(2.5 + 0.15 + 0.05)  # a biter, boşluk geçer, b girişte 50 ms
	assert_eq(q.current(), &"b")
	assert_eq(q.phase(), P.IN)
	assert_almost_eq(q.offset_alpha().y, 1.0 - pow(1.0 - 0.05 / 0.22, 3.0), 1e-4)


func test_offset_alpha_curve() -> void:
	var q := ToastQueue.new()
	q.push(&"a")
	var prev := q.offset_alpha()
	for i in 22:
		q.tick(0.01)
		var cur := q.offset_alpha()
		if q.phase() == P.IN:
			assert_lte(cur.x, prev.x + EPS, "kayma azalır")
			assert_gte(cur.y, prev.y - EPS, "alfa artar")
		prev = cur
	q.tick(0.001)
	assert_eq(q.phase(), P.HOLD)
	assert_eq(q.offset_alpha(), Vector2(0.0, 1.0))
	q.tick(2.1)
	assert_eq(q.phase(), P.OUT)
	q.tick(0.09)
	assert_almost_eq(q.offset_alpha().y, 0.5, 0.01)
	assert_eq(q.offset_alpha().x, 0.0)


func test_clear_resets() -> void:
	var q := ToastQueue.new()
	for id in [&"a", &"b", &"c", &"d", &"e", &"f"]:
		q.push(id)
	q.clear()
	assert_eq(q.phase(), P.IDLE)
	assert_eq(q.current(), &"")
	assert_eq(q.waiting_count(), 0)
	assert_eq(q.overflow, 0)
	assert_true(q.push(&"x"))


func test_push_during_gap_waits_for_gap_end() -> void:
	var q := ToastQueue.new()
	q.push(&"a")
	q.tick(2.5 + 0.05)
	assert_eq(q.phase(), P.GAP)
	assert_true(q.push(&"b"))
	assert_eq(q.current(), &"")
	q.tick(0.11)
	assert_eq(q.current(), &"b")
