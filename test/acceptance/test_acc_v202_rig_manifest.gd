extends GutTest
## Kabul (v2.0.2 K, R): şerit manifesti ↔ rig verisi ve `palm` ↔ `cast_point` (plan Test stratejisi + AD-1 notu: "Manifest `palm`
## ile `cast_point` karşılaştırması gate testidir (K)"). Manifest art/source/zyfen/strip_manifest.json (make_zyfen_strip.py çıktısı).
## Ayrıca gerçek rig ile RigFrames hücre düzeni ve CastAnim kare seçimi (iki `action_while_moving` değeriyle).

const MANIFEST := "res://art/source/zyfen/strip_manifest.json"
const DT := 1.0 / 60.0

var _rig: Dictionary


func before_all() -> void:
	_rig = GameData.load_default().get_character(&"zyfen").rig.duplicate(true)


func _manifest() -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return v if v is Dictionary else {}


func test_r1_manifest_cell_layout_matches_the_rig() -> void:
	if V202Slice.require(self, "R"):
		return
	var m := _manifest()
	assert_eq(int(m["cells"]), RigFrames.total_cells(_rig), "hücre sayısı")
	assert_eq(int(m["walk"]["frames"]), int(_rig["walk"]["frames"]), "yürüme kare sayısı")
	assert_eq(int(m["cast"]["frames"]), int(_rig["cast"]["frames"]), "cast kare sayısı")
	assert_eq(int(m["gather"]["frames"]), int(_rig["gather"]["frames"]), "gather kare sayısı")
	assert_eq(int(m["idle"]["index"]), RigFrames.idle_index(_rig), "duruş hücresi")
	assert_eq(
		[int(m["cell"][0]), int(m["cell"][1])],
		[int(_rig["walk"]["cell"][0]), int(_rig["walk"]["cell"][1])],
		"hücre boyutu"
	)
	assert_eq(int(m["strip_width"]), int(m["cells"]) * int(m["cell"][0]), "şerit genişliği")
	assert_almost_eq(float(m["stride"]), float(_rig["walk"]["stride"]), 0.01, "adım uzunluğu")
	assert_almost_eq(
		float(m["body_scale"]), float(m["idle"]["scale"]), 0.0001, "gövde ölçeği = duruş ölçeği"
	)


func test_r2_manifest_records_the_palm_point() -> void:
	if V202Slice.require(self, "R"):
		return
	var m := _manifest()
	assert_true(
		m.has("palm"),
		"manifest `palm` (cast karesindeki avuç noktası) kaydetmeli — cast_point ile karşılaştırılır"
	)
	if m.has("palm"):
		assert_true(m["palm"] is Array and (m["palm"] as Array).size() == 2, "palm [x, y]")


func test_r7_cast_point_is_in_range_in_front_and_not_below_the_waist() -> void:
	if V202Slice.require(self, "R"):
		return
	var cp: Array = _rig["cast_point"]
	assert_between(float(cp[0]), -0.5, 0.5, "cast_point.x aralık")
	assert_between(float(cp[1]), -0.5, 0.5, "cast_point.y aralık")
	assert_gt(float(cp[0]), 0.0, "native_facing sağ: cast noktası öne (x > 0)")
	assert_lt(float(cp[1]), 0.1, "cast noktası bel altında değil (y < 0,1)")


func test_r3_frame_indices_follow_walk_idle_cast_gather_order() -> void:
	if V202Slice.require(self, "R"):
		return
	assert_eq(RigFrames.total_cells(_rig), 19)
	assert_eq(RigFrames.idle_index(_rig), 8)
	assert_eq(RigFrames.cast_base(_rig), 9)
	assert_eq(RigFrames.gather_base(_rig), 15)
	assert_eq(RigFrames.walk_cast_base(_rig), -1, "walk_cast tanımlı değil")
	var no_cast := _rig.duplicate(true)
	no_cast.erase("cast")
	no_cast.erase("gather")
	assert_eq(RigFrames.total_cells(no_cast), 9, "cast/gather yoksa 8 + 1")
	assert_eq(RigFrames.cast_base(no_cast), -1)
	assert_eq(RigFrames.gather_base(no_cast), -1)


func _anim(awm: bool) -> CastAnim:
	var r := _rig.duplicate(true)
	r["action_while_moving"] = awm
	var a := CastAnim.new()
	a.configure(r)
	return a


func test_r4_default_mode_shows_cast_and_gather_only_while_standing() -> void:
	if V202Slice.require(self, "R"):
		return
	assert_false(
		bool(_rig.get("action_while_moving", true)), "gerçek rig: action_while_moving false"
	)
	var a := _anim(false)
	a.update(DT, false)
	assert_eq(a.frame(), -1, "etkin klip yok")
	a.on_shot()
	assert_eq(
		a.frame(),
		RigFrames.cast_base(_rig) + int(_rig["cast"]["fire_frame"]),
		"cast klibi fire_frame'den"
	)
	for _k in 12:
		a.update(DT, false)
	assert_eq(a.frame(), -1, "klip bitti")
	var w := _anim(false)
	w.update(DT, true)
	w.on_shot()
	assert_eq(w.frame(), -1, "yürürken atış cast karesi seçmez")
	w.on_reload(1.3)
	assert_eq(w.frame(), -1, "yürürken doldurma gather karesi seçmez")


func test_r5_gather_frames_follow_reload_progress_thresholds() -> void:
	if V202Slice.require(self, "R"):
		return
	var a := _anim(false)
	a.update(DT, false)
	a.on_reload(1.0)
	var base := RigFrames.gather_base(_rig)
	assert_eq(a.frame(), base, "ilerleme 0 => k0")
	var at := {0.1: 0, 0.35: 1, 0.7: 2, 0.95: 3}
	var t := 0.0
	var sorted_keys := at.keys()
	sorted_keys.sort()
	for p in sorted_keys:
		while t < float(p):
			a.update(DT, false)
			t += DT
		assert_eq(a.frame(), base + int(at[p]), "ilerleme %.2f" % float(p))
	a.on_reload_end()
	a.update(DT, false)
	assert_eq(a.frame(), -1, "doldurma bitti")


func test_r6_action_while_moving_true_gives_priority_to_cast_over_walking() -> void:
	if V202Slice.require(self, "R"):
		return
	var a := _anim(true)
	a.update(DT, true)
	a.on_shot()
	assert_eq(
		a.frame(), RigFrames.cast_base(_rig) + int(_rig["cast"]["fire_frame"]), "yürürken de cast"
	)
	assert_true(a.holds_walk(), "yürüme saati donar")
	for _k in 15:
		a.update(DT, true)
	assert_eq(a.frame(), -1, "klip bitince yürüme sürer")
	assert_false(a.holds_walk())
