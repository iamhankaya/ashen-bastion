extends GutTest
## Kabul (v2.0.2 K, R): şerit manifesti ↔ rig verisi ve `palm` ↔ `cast_point` (plan Test stratejisi + AD-1 notu: "Manifest `palm`
## ile `cast_point` karşılaştırması gate testidir (K)"). Her kolsuz (`rig.armless`) karakter için çalışır; manifest
## art/source/<id>/strip_manifest.json (make_zyfen_strip.py çıktısı). Ayrıca gerçek rig ile RigFrames hücre düzeni ve CastAnim kare
## seçimi (iki `action_while_moving` değeriyle). Zyfen'in kare sayıları PINNED ile ayrıca sabitlenir.

const DT := 1.0 / 60.0
## id -> [toplam hücre, duruş, cast tabanı, gather tabanı]
const PINNED := {&"zyfen": [19, 8, 9, 15]}

var _rigs: Dictionary = {}


func before_all() -> void:
	var data := GameData.load_default()
	for id in data.character_ids:
		var c := data.get_character(id)
		if c.armless:
			_rigs[id] = c.rig.duplicate(true)


func _manifest(id: StringName) -> Dictionary:
	var path := "res://art/source/%s/strip_manifest.json" % id
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _anim(rig: Dictionary, awm: bool) -> CastAnim:
	var r := rig.duplicate(true)
	r["action_while_moving"] = awm
	var a := CastAnim.new()
	a.configure(r)
	return a


## Cast klibinin (fire_frame'den sona) 60 Hz adım sayısı + pay.
func _cast_steps(rig: Dictionary) -> int:
	var c: Dictionary = rig["cast"]
	var left := int(c["frames"]) - int(c["fire_frame"])
	return int(ceil(float(left) / float(c["fps"]) / DT)) + 2


func test_r0_there_is_an_armless_character() -> void:
	if V202Slice.require(self, "R"):
		return
	assert_false(_rigs.is_empty(), "en az bir kolsuz karakter (zyfen)")
	assert_true(_rigs.has(&"zyfen"), "zyfen kolsuz rig")


func test_r1_manifest_cell_layout_matches_the_rig() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var rig: Dictionary = _rigs[id]
		var m := _manifest(id)
		assert_false(m.is_empty(), "%s: strip_manifest.json okunur" % id)
		if m.is_empty():
			continue
		assert_eq(int(m["cells"]), RigFrames.total_cells(rig), "%s hücre sayısı" % id)
		assert_eq(
			int(m["walk"]["frames"]), int(rig["walk"]["frames"]), "%s yürüme kare sayısı" % id
		)
		assert_eq(int(m["cast"]["frames"]), int(rig["cast"]["frames"]), "%s cast kare sayısı" % id)
		assert_eq(
			int(m["gather"]["frames"]), int(rig["gather"]["frames"]), "%s gather kare sayısı" % id
		)
		assert_eq(int(m["idle"]["index"]), RigFrames.idle_index(rig), "%s duruş hücresi" % id)
		assert_eq(
			[int(m["cell"][0]), int(m["cell"][1])],
			[int(rig["walk"]["cell"][0]), int(rig["walk"]["cell"][1])],
			"%s hücre boyutu" % id
		)
		assert_eq(
			int(m["strip_width"]), int(m["cells"]) * int(m["cell"][0]), "%s şerit genişliği" % id
		)
		assert_almost_eq(
			float(m["stride"]), float(rig["walk"]["stride"]), 0.01, "%s adım uzunluğu" % id
		)
		assert_almost_eq(
			float(m["body_scale"]),
			float(m["idle"]["scale"]),
			0.0001,
			"%s gövde ölçeği = duruş ölçeği" % id
		)


func test_r2_manifest_records_the_palm_point() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var rig: Dictionary = _rigs[id]
		var m := _manifest(id)
		assert_true(
			m.has("palm"),
			(
				"%s: manifest `palm` (cast karesindeki avuç noktası) kaydetmeli — cast_point ile karşılaştırılır"
				% id
			)
		)
		if m.has("palm"):
			var pt: Variant = m["palm"].get("point", null) if m["palm"] is Dictionary else m["palm"]
			assert_true(pt is Array and (pt as Array).size() == 2, "%s palm [x, y]" % id)
			if pt is Array and (pt as Array).size() == 2:
				var cp: Array = rig["cast_point"]
				# Dönüşüm docs/data-schema.md "Manifest palm ↔ cast_point"; tolerans 0,03 (≈ 6 dünya px).
				assert_lte(
					absf(float(pt[0]) - float(cp[0])), 0.03, "%s |palm.x − cast_point.x|" % id
				)
				assert_lte(
					absf(float(pt[1]) - float(cp[1])), 0.03, "%s |palm.y − cast_point.y|" % id
				)


func test_r7_cast_point_is_in_range_in_front_and_not_below_the_waist() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var rig: Dictionary = _rigs[id]
		var cp: Array = rig["cast_point"]
		assert_between(float(cp[0]), -0.5, 0.5, "%s cast_point.x aralık" % id)
		assert_between(float(cp[1]), -0.5, 0.5, "%s cast_point.y aralık" % id)
		if str(rig.get("native_facing", "right")) == "right":
			assert_gt(float(cp[0]), 0.0, "%s native_facing sağ: cast noktası öne (x > 0)" % id)
		else:
			assert_lt(float(cp[0]), 0.0, "%s native_facing sol: cast noktası öne (x < 0)" % id)
		assert_lt(float(cp[1]), 0.1, "%s cast noktası bel altında değil (y < 0,1)" % id)


func test_r3_frame_indices_follow_walk_idle_cast_gather_order() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var rig: Dictionary = _rigs[id]
		var w := int(rig["walk"]["frames"])
		var c := int(rig["cast"]["frames"])
		var g := int(rig["gather"]["frames"])
		var wc := int(rig["walk_cast"]["frames"]) if rig.has("walk_cast") else 0
		assert_eq(RigFrames.total_cells(rig), w + 1 + c + g + wc, "%s toplam hücre" % id)
		assert_eq(RigFrames.idle_index(rig), w, "%s duruş hücresi" % id)
		assert_eq(RigFrames.cast_base(rig), w + 1, "%s cast tabanı" % id)
		assert_eq(RigFrames.gather_base(rig), w + 1 + c, "%s gather tabanı" % id)
		assert_eq(
			RigFrames.walk_cast_base(rig),
			w + 1 + c + g if wc > 0 else -1,
			"%s walk_cast tabanı" % id
		)
		if PINNED.has(id):
			var p: Array = PINNED[id]
			assert_eq(RigFrames.total_cells(rig), p[0], "%s sabit toplam" % id)
			assert_eq(RigFrames.idle_index(rig), p[1], "%s sabit duruş" % id)
			assert_eq(RigFrames.cast_base(rig), p[2], "%s sabit cast" % id)
			assert_eq(RigFrames.gather_base(rig), p[3], "%s sabit gather" % id)
			assert_eq(RigFrames.walk_cast_base(rig), -1, "%s walk_cast tanımlı değil" % id)
		var no_cast := rig.duplicate(true)
		no_cast.erase("cast")
		no_cast.erase("gather")
		no_cast.erase("walk_cast")
		assert_eq(RigFrames.total_cells(no_cast), w + 1, "%s cast/gather yoksa W + 1" % id)
		assert_eq(RigFrames.cast_base(no_cast), -1)
		assert_eq(RigFrames.gather_base(no_cast), -1)


func test_r4_default_mode_shows_cast_and_gather_only_while_standing() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var rig: Dictionary = _rigs[id]
		assert_false(
			bool(rig.get("action_while_moving", true)),
			"%s gerçek rig: action_while_moving false" % id
		)
		var a := _anim(rig, false)
		a.update(DT, false)
		assert_eq(a.frame(), -1, "%s etkin klip yok" % id)
		a.on_shot()
		assert_eq(
			a.frame(),
			RigFrames.cast_base(rig) + int(rig["cast"]["fire_frame"]),
			"%s cast klibi fire_frame'den" % id
		)
		for _k in _cast_steps(rig):
			a.update(DT, false)
		assert_eq(a.frame(), -1, "%s klip bitti" % id)
		var w := _anim(rig, false)
		w.update(DT, true)
		w.on_shot()
		assert_eq(w.frame(), -1, "%s yürürken atış cast karesi seçmez" % id)
		w.on_reload(1.3)
		assert_eq(w.frame(), -1, "%s yürürken doldurma gather karesi seçmez" % id)


func test_r5_gather_frames_follow_reload_progress_thresholds() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var rig: Dictionary = _rigs[id]
		var n := int(rig["gather"]["frames"])
		var a := _anim(rig, false)
		a.update(DT, false)
		a.on_reload(1.0)
		var base := RigFrames.gather_base(rig)
		assert_eq(a.frame(), base, "%s ilerleme 0 => k0" % id)
		# 4 karede sabit eşikler (CastAnim.GATHER_CUTS), diğer sayılarda eşit bölme.
		var at := {0.1: 0, 0.35: 1, 0.7: 2, 0.95: 3}
		if n != 4:
			at = {}
			for p in [0.1, 0.35, 0.7, 0.95]:
				at[p] = clampi(int(p * n), 0, n - 1)
		var t := 0.0
		var sorted_keys := at.keys()
		sorted_keys.sort()
		for p in sorted_keys:
			while t < float(p):
				a.update(DT, false)
				t += DT
			assert_eq(a.frame(), base + int(at[p]), "%s ilerleme %.2f" % [id, float(p)])
		a.on_reload_end()
		a.update(DT, false)
		assert_eq(a.frame(), -1, "%s doldurma bitti" % id)


func test_r6_action_while_moving_true_gives_priority_to_cast_over_walking() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var rig: Dictionary = _rigs[id]
		var a := _anim(rig, true)
		a.update(DT, true)
		a.on_shot()
		assert_eq(
			a.frame(),
			RigFrames.cast_base(rig) + int(rig["cast"]["fire_frame"]),
			"%s yürürken de cast" % id
		)
		assert_true(a.holds_walk(), "%s yürüme saati donar" % id)
		for _k in _cast_steps(rig):
			a.update(DT, true)
		assert_eq(a.frame(), -1, "%s klip bitince yürüme sürer" % id)
		assert_false(a.holds_walk())
