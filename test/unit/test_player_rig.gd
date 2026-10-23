extends GutTest
## PlayerRig.muzzle_world karakter verisiyle sayısal.

var rig: Dictionary


func before_each() -> void:
	rig = GameData.load_default().get_character(&"gunslinger").rig


func test_muzzle_is_ahead_of_shoulder_along_aim() -> void:
	for gun in 2:
		var sh := PlayerRig.shoulder_world(gun, Vector2.ZERO, false, rig)
		var m := PlayerRig.muzzle_world(gun, Vector2.ZERO, 0.0, false, rig)
		assert_gt(m.x, sh.x)
		var arm_len: float = float(rig["arm_scale"]) * float(rig["display_height"])
		var pv: Array = rig["arm_pivot"]
		var mz: Array = rig["muzzle"]
		assert_almost_eq(m.x - sh.x, (float(mz[0]) - float(pv[0])) * arm_len, 1e-3)


func test_muzzle_offset_translates_with_player() -> void:
	var a := PlayerRig.muzzle_world(0, Vector2.ZERO, 0.7, false, rig)
	var b := PlayerRig.muzzle_world(0, Vector2(100, -50), 0.7, false, rig)
	assert_almost_eq((b - a).x, 100.0, 1e-4)
	assert_almost_eq((b - a).y, -50.0, 1e-4)


func test_facing_left_mirrors_shoulder() -> void:
	var r := PlayerRig.shoulder_world(0, Vector2.ZERO, false, rig)
	var l := PlayerRig.shoulder_world(0, Vector2.ZERO, true, rig)
	assert_almost_eq(l.x, -r.x, 1e-4)
	assert_almost_eq(l.y, r.y, 1e-4)


func test_aiming_left_flips_arm_vertically() -> void:
	var up := PlayerRig.muzzle_world(0, Vector2.ZERO, 0.0, false, rig)
	var left := PlayerRig.muzzle_world(0, Vector2.ZERO, PI, false, rig)
	var sh := PlayerRig.shoulder_world(0, Vector2.ZERO, false, rig)
	# sağa bakan kolun namlusu omuzun x'inin sağında, sola bakanın solunda; dikey ofset işareti çevrilir
	assert_gt(up.x - sh.x, 0.0)
	assert_lt(left.x - sh.x, 0.0)
	assert_almost_eq(left.y - sh.y, (up.y - sh.y) * 1.0, 1e-3)


func test_missing_rig_uses_defaults_without_error() -> void:
	var m := PlayerRig.muzzle_world(1, Vector2(10, 10), 1.0, false, {})
	assert_true(is_finite(m.x) and is_finite(m.y))


# --- shoulder_world_f (D4-2): kare başına omuz sapması ---------------------------------------


func _walk_rig(dev: Variant) -> Dictionary:
	var r: Dictionary = rig.duplicate(true)
	r["walk"] = {"frames": 2, "stride": 136, "strip": "x", "cell": [10, 10], "shoulder_dev": dev}
	return r


func test_shoulder_world_f_without_walk_data_equals_shoulder_world() -> void:
	for facing in [false, true]:
		var a := PlayerRig.shoulder_world(0, Vector2(5, 9), facing, rig)
		assert_eq(PlayerRig.shoulder_world_f(0, Vector2(5, 9), facing, rig, 3), a)


func test_shoulder_world_f_adds_the_frame_deviation_in_display_height_fractions() -> void:
	var r := _walk_rig([[0.02, -0.01], [0.0, 0.03], [0.0, 0.0]])
	var h := float(r["display_height"])
	var base := PlayerRig.shoulder_world(0, Vector2.ZERO, false, rig)
	var f0 := PlayerRig.shoulder_world_f(0, Vector2.ZERO, false, r, 0)
	assert_almost_eq(f0.x - base.x, 0.02 * h, 1e-4)
	assert_almost_eq(f0.y - base.y, -0.01 * h, 1e-4)
	var f1 := PlayerRig.shoulder_world_f(0, Vector2.ZERO, false, r, 1)
	assert_almost_eq(f1.y - base.y, 0.03 * h, 1e-4)


func test_shoulder_world_f_mirrors_dx_when_facing_left() -> void:
	var r := _walk_rig([[0.02, 0.0], [0.0, 0.0], [0.0, 0.0]])
	var h := float(r["display_height"])
	var base := PlayerRig.shoulder_world(0, Vector2.ZERO, true, rig)
	var f0 := PlayerRig.shoulder_world_f(0, Vector2.ZERO, true, r, 0)
	assert_almost_eq(f0.x - base.x, -0.02 * h, 1e-4)


func test_shoulder_world_is_the_stand_frame_and_ignores_deviation() -> void:
	var r := _walk_rig([[0.02, -0.01], [0.0, 0.03], [0.0, 0.0]])
	assert_eq(
		PlayerRig.shoulder_world(1, Vector2(3, 4), false, r),
		PlayerRig.shoulder_world_f(1, Vector2(3, 4), false, r, 2),
		"frame = N (duruş)"
	)
	assert_eq(
		PlayerRig.shoulder_world(1, Vector2(3, 4), false, r),
		PlayerRig.shoulder_world(1, Vector2(3, 4), false, rig),
		"sim omzu sapma verisinden etkilenmez"
	)


func test_shoulder_world_f_ignores_bad_deviation_tables() -> void:
	var base := PlayerRig.shoulder_world(0, Vector2.ZERO, false, rig)
	for dev in [[], [[0.1, 0.1]], "bozuk"]:
		var r := _walk_rig(dev)
		assert_eq(PlayerRig.shoulder_world_f(0, Vector2.ZERO, false, r, 0), base)
	var r2 := _walk_rig([[0.1, 0.1], [0.1, 0.1], [0.1, 0.1]])
	assert_eq(PlayerRig.shoulder_world_f(0, Vector2.ZERO, false, r2, 7), base, "aralık dışı kare")
	assert_eq(PlayerRig.shoulder_world_f(0, Vector2.ZERO, false, r2, -1), base)
