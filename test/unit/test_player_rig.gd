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
		assert_almost_eq(m.x - sh.x, (0.98 - 0.11) * arm_len, 1e-3)


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
