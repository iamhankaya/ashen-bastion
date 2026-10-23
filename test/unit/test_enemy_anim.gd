extends GutTest
## EnemyAnim (D1-2): tür tabloları, sinüs LUT, slot fazları, mesafe tabanlı kare, pose_of.

var _data: GameData
var _anim: EnemyAnim


func before_each() -> void:
	_data = GameData.load_default()
	_anim = EnemyAnim.new()
	var paths: Array[String] = []
	for id in _data.enemy_ids:
		var def := _data.get_enemy(id)
		if not paths.has(def.sprite):
			paths.append(def.sprite)
	_anim.bind(_data, EnemyAtlas.new().build(paths))


func _t(id: StringName) -> int:
	return _data.enemy_ids.find(id)


func test_lut_is_a_256_entry_sine() -> void:
	assert_eq(EnemyAnim.LUT_SIZE, 256)
	assert_eq(EnemyAnim.lut_sin(0.0), 0.0)
	assert_almost_eq(EnemyAnim.lut_sin(0.25), 1.0, 1e-3)
	assert_almost_eq(EnemyAnim.lut_sin(0.5), 0.0, 0.03)
	assert_almost_eq(EnemyAnim.lut_sin(0.75), -1.0, 1e-3)
	for k in 50:
		var x := float(k) / 50.0
		assert_almost_eq(EnemyAnim.lut_sin(x), sin(TAU * x), 0.03)
	assert_almost_eq(EnemyAnim.lut_sin(1.25), 1.0, 1e-3, "faz sarılır")
	assert_almost_eq(EnemyAnim.lut_sin(-0.25), -1.0, 1e-3, "negatif faz sarılır")


func test_bind_reads_tables_for_every_type() -> void:
	assert_eq(_anim.kind_of(_t(&"curumus_piyade")), EnemyAnim.Kind.CRAWL)
	assert_eq(_anim.kind_of(_t(&"les_kargasi")), EnemyAnim.Kind.FLAP)
	assert_eq(_anim.kind_of(_t(&"sovalye_hayaleti")), EnemyAnim.Kind.FLOAT)
	assert_eq(_anim.kind_of(_t(&"kale_lordu")), EnemyAnim.Kind.STOMP)
	assert_eq(_anim.kind_of(_t(&"elit_piyade")), EnemyAnim.Kind.CRAWL)
	assert_almost_eq(_anim.knock_of(_t(&"curumus_piyade")), 10.0, 1e-4)
	assert_almost_eq(_anim.knock_of(_t(&"kale_lordu")), 0.0, 1e-4)
	assert_almost_eq(_anim.hover_of(_t(&"les_kargasi")), 36.0, 1e-4)
	assert_almost_eq(_anim.alpha_lo_of(_t(&"sovalye_hayaleti")), 0.9, 1e-4)
	assert_eq(_anim.special_of(_t(&"kale_lordu")), EnemyAnim.Special.LORD)
	assert_eq(_anim.special_of(_t(&"elit_karga")), EnemyAnim.Special.CHARGER)
	assert_eq(_anim.special_of(_t(&"curumus_piyade")), EnemyAnim.Special.NONE)
	assert_eq(_anim.kind_of(-1), EnemyAnim.Kind.NONE, "geçersiz tür güvenli")
	assert_eq(_anim.kind_of(99), EnemyAnim.Kind.NONE)


func test_bind_with_null_is_safe() -> void:
	var a := EnemyAnim.new()
	a.bind(null, null)
	assert_eq(a.kind_of(0), EnemyAnim.Kind.NONE)
	a.sync_slot(0, 1, Vector2.ZERO)
	assert_eq(a.last_anim_instances, 0)


func test_phases_spread_across_100_slots() -> void:
	var vals := PackedFloat32Array()
	for i in 100:
		_anim.sync_slot(i, 1, Vector2.ZERO)
		vals.append(_anim.phase0[i])
	var mean := 0.0
	for v in vals:
		mean += v
	mean /= vals.size()
	var sd := 0.0
	for v in vals:
		sd += (v - mean) * (v - mean)
	sd = sqrt(sd / vals.size())
	assert_gt(sd, 0.2, "fazlar yayılmış (σ > 0,2)")
	for v in vals:
		assert_true(v >= 0.0 and v < 1.0)


func test_slot_reuse_gets_a_new_phase_and_resets_walk() -> void:
	_anim.sync_slot(5, 1, Vector2(10, 10))
	var p1 := _anim.phase0[5]
	_anim.sync_slot(5, 1, Vector2(999, 999))
	assert_eq(_anim.phase0[5], p1, "aynı nesil: yeniden tohumlanmaz")
	assert_eq(_anim.last_pos[5], Vector2(10, 10), "son konum korunur")
	_anim.sync_slot(5, 2, Vector2(50, 60))
	assert_ne(_anim.phase0[5], p1, "yeni nesil yeni faz")
	assert_eq(_anim.last_pos[5], Vector2(50, 60))
	assert_eq(_anim.walk[5], _anim.phase0[5], "yürüme fazı hash'ten başlar")
	assert_eq(_anim.enrage_t0[5], -1.0)


func test_pose_of_identity_for_none_and_bounds_for_others() -> void:
	var p := EnemyAnim.pose_of(EnemyAnim.Kind.NONE, 1.0, 5.0, 0.1, 0.05, 3.0, 0.3)
	assert_eq(p, Vector4(0.0, 1.0, 1.0, 0.0))
	for kind in [EnemyAnim.Kind.CRAWL, EnemyAnim.Kind.FLAP, EnemyAnim.Kind.FLOAT, EnemyAnim.Kind.STOMP]:
		for k in 400:
			var t := float(k) * 0.037
			var ph := float(k % 17) / 17.0
			var v := EnemyAnim.pose_of(kind, 1.1, 5.0, deg_to_rad(5.0), 0.05, t, ph)
			assert_lte(absf(v.x), deg_to_rad(5.0) + 1e-4, "θ sınırı")
			assert_lte(absf(v.w), 5.0 + 1e-4, "bob sınırı")
			assert_between(v.y * v.z, 0.98, 1.02, "hacim korunur sx·sy≈1")
			assert_between(v.z, 0.949, 1.051, "squash ±%5")


func test_crawl_bob_is_never_negative_and_reaches_the_peak() -> void:
	var peak := 0.0
	for k in 600:
		var v := EnemyAnim.pose_of(EnemyAnim.Kind.CRAWL, 1.1, 5.0, 0.0, 0.0, float(k) / 60.0, 0.2)
		assert_gte(v.w, 0.0)
		peak = maxf(peak, v.w)
	assert_gt(peak, 4.8)


func test_pose_is_deterministic_and_phase_shifted() -> void:
	var a := EnemyAnim.pose_of(EnemyAnim.Kind.FLOAT, 0.7, 6.0, 0.04, 0.03, 12.34, 0.1)
	var b := EnemyAnim.pose_of(EnemyAnim.Kind.FLOAT, 0.7, 6.0, 0.04, 0.03, 12.34, 0.1)
	assert_eq(a, b)
	var c := EnemyAnim.pose_of(EnemyAnim.Kind.FLOAT, 0.7, 6.0, 0.04, 0.03, 12.34, 0.6)
	assert_ne(a, c, "başka faz başka poz")


func test_speed_multiplier_spans_plus_minus_15_percent() -> void:
	assert_almost_eq(EnemyAnim.speed_mult(0.0), 0.85, 1e-6)
	assert_almost_eq(EnemyAnim.speed_mult(0.5), 1.0, 1e-6)
	assert_almost_eq(EnemyAnim.speed_mult(1.0), 1.15, 1e-6)


func test_walk_frame_is_distance_based_and_ignores_stationary() -> void:
	_anim.sync_slot(3, 1, Vector2.ZERO)
	var w0 := _anim.walk[3]
	for k in 30:
		_anim.advance_walk(3, Vector2.ZERO, 72.0)
	assert_eq(_anim.walk[3], w0, "konumu değişmeyen düşmanın fazı ilerlemez")
	_anim.advance_walk(3, Vector2(36.0, 0.0), 72.0)
	_anim.advance_walk(3, Vector2(72.0, 0.0), 72.0)
	assert_almost_eq(fposmod(_anim.walk[3] - w0, 1.0), 0.0, 1e-4, "72 px = 1 çevrim")
	_anim.advance_walk(3, Vector2(72.0 + 36.0, 0.0), 72.0)
	assert_almost_eq(fposmod(_anim.walk[3] - w0, 1.0), 0.5, 1e-4)


func test_teleport_over_60px_is_clamped() -> void:
	_anim.sync_slot(4, 1, Vector2.ZERO)
	var w0 := _anim.walk[4]
	_anim.advance_walk(4, Vector2(5000.0, 0.0), 72.0)
	assert_almost_eq(_anim.walk[4] - w0, 60.0 / 72.0, 1e-4, "ışınlanma 60 px'e kenetlenir")
	assert_eq(_anim.last_pos[4], Vector2(5000.0, 0.0), "son konum yine güncellenir")


func test_walk_frame_index_wraps_for_n_frames() -> void:
	for n in [6, 7]:
		_anim.sync_slot(1, 10 + n, Vector2.ZERO)
		var seen := {}
		for k in 200:
			_anim.advance_walk(1, Vector2(float(k) * 5.0, 0.0), 72.0)
			var f := WalkCycle.frame_at(_anim.walk[1], n)
			assert_between(f, 0, n - 1)
			seen[f] = true
		assert_eq(seen.size(), n)


func test_flap_frame_sequence_is_ping_pong_at_12_per_second() -> void:
	# [0,1,2,1] @12 kare/sn: her eleman 1/12 sn
	var got: Array[int] = []
	for k in 8:
		got.append(EnemyAnim.flap_frame(3, float(k) / 12.0 + 0.001, 0.0))
	assert_eq(got, [0, 1, 2, 1, 0, 1, 2, 1] as Array[int])
	assert_eq(EnemyAnim.flap_frame(1, 5.0, 0.3), 0, "tek kare")
	assert_eq(EnemyAnim.flap_frame(2, 0.0, 0.0), 0)
	var four: Array[int] = []
	for k in 6:
		four.append(EnemyAnim.flap_frame(4, float(k) / 12.0 + 0.001, 0.0))
	assert_eq(four, [0, 1, 2, 3, 2, 1] as Array[int], "n kareli genel: uzunluk 2n−2")


func test_flap_slot_offset_desynchronizes() -> void:
	var diff := 0
	for k in 20:
		if EnemyAnim.flap_frame(3, 1.0, 0.0) != EnemyAnim.flap_frame(3, 1.0, float(k) / 20.0):
			diff += 1
	assert_gt(diff, 5)
