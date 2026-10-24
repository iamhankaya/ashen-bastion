extends GutTest
## U2: CastAnim kare seçimi (saf). Şerit düzeni: yürüme 0..7, duruş 8, cast 9..14, gather 15..18, walk_cast 19..23.

const DT := 1.0 / 60.0


func _rig(awm: bool = false, walk_cast: bool = false) -> Dictionary:
	var r := {
		"walk": {"frames": 8},
		"cast": {"frames": 6, "fire_frame": 3, "fps": 24},
		"gather": {"frames": 4},
		"action_while_moving": awm,
	}
	if walk_cast:
		r["walk_cast"] = {"frames": 5, "fire_frame": 2, "fps": 20}
	return r


func _anim(awm: bool = false, walk_cast: bool = false) -> CastAnim:
	var a := CastAnim.new()
	a.configure(_rig(awm, walk_cast))
	return a


func _tick(a: CastAnim, seconds: float, walking: bool) -> void:
	for i in int(round(seconds / DT)):
		a.update(DT, walking)


func test_no_override_by_default() -> void:
	assert_eq(_anim().frame(), -1)


func test_shot_while_idle_starts_at_fire_frame_and_ends() -> void:
	var a := _anim()
	a.update(DT, false)
	a.on_shot()
	assert_eq(a.frame(), 9 + 3, "cast klibi fire_frame'den başlar")
	_tick(a, 0.07, false)
	assert_eq(a.frame(), 9 + 4)
	_tick(a, 0.2, false)
	assert_eq(a.frame(), -1, "klip bitti: yürüme/duruş")


func test_shot_while_walking_is_ignored_without_walk_cast() -> void:
	var a := _anim(false, false)
	a.update(DT, true)
	a.on_shot()
	assert_eq(a.frame(), -1, "action_while_moving=false: yürürken cast karesi seçilmez")
	assert_false(a.holds_walk())


func test_shot_while_walking_uses_walk_cast_when_defined() -> void:
	var a := _anim(false, true)
	a.update(DT, true)
	a.on_shot()
	assert_eq(a.frame(), 19 + 2, "walk_cast fire_frame'den")
	assert_true(a.holds_walk(), "yürüme saati klip boyunca donar")
	_tick(a, 0.3, true)
	assert_eq(a.frame(), -1)
	assert_false(a.holds_walk(), "klip bitti: yürüme kaldığı yerden sürer")


func test_action_while_moving_true_plays_cast_while_walking() -> void:
	var a := _anim(true, false)
	a.update(DT, true)
	a.on_shot()
	assert_eq(a.frame(), 12)
	assert_true(a.holds_walk())
	a.update(DT, false)  # hareket durdu: klip tamamlanır
	assert_eq(a.frame(), 12)


func test_cast_started_idle_is_hidden_if_walking_starts_when_flag_false() -> void:
	var a := _anim(false)
	a.update(DT, false)
	a.on_shot()
	a.update(DT, true)
	assert_eq(a.frame(), -1, "false iken yürürken cast karesi gösterilmez")


func test_gather_maps_reload_progress_to_frames() -> void:
	var a := _anim()
	a.update(DT, false)
	a.on_reload(1.3)
	assert_eq(a.frame(), 15)
	var got := {}
	for i in int(1.3 / DT):
		a.update(DT, false)
		got[a.frame()] = true
	assert_eq(got.keys().size() >= 4, true)
	assert_true(got.has(15) and got.has(16) and got.has(17) and got.has(18))
	a.on_reload_end()
	assert_eq(a.frame(), -1)


func test_gather_thresholds_for_four_frames() -> void:
	assert_eq(CastAnim.gather_index(0.0, 4), 0)
	assert_eq(CastAnim.gather_index(0.19, 4), 0)
	assert_eq(CastAnim.gather_index(0.2, 4), 1)
	assert_eq(CastAnim.gather_index(0.49, 4), 1)
	assert_eq(CastAnim.gather_index(0.5, 4), 2)
	assert_eq(CastAnim.gather_index(0.84, 4), 2)
	assert_eq(CastAnim.gather_index(0.85, 4), 3)
	assert_eq(CastAnim.gather_index(2.0, 4), 3)
	assert_eq(CastAnim.gather_index(0.5, 2), 1, "4 dışı: eşit bölme")


func test_gather_hidden_while_walking_unless_flag() -> void:
	var a := _anim(false)
	a.update(DT, true)
	a.on_reload(1.3)
	a.update(DT, true)
	assert_eq(a.frame(), -1)
	var b := _anim(true)
	b.update(DT, true)
	b.on_reload(1.3)
	b.update(DT, true)
	assert_eq(b.frame(), 15)


func test_cast_beats_gather() -> void:
	var a := _anim()
	a.update(DT, false)
	a.on_reload(1.3)
	a.on_shot()
	assert_eq(a.frame(), 12, "öncelik cast > gather")


func test_missing_clips_do_nothing() -> void:
	var a := CastAnim.new()
	a.configure({"walk": {"frames": 8}})
	a.on_shot()
	a.on_reload(1.0)
	a.update(DT, false)
	assert_eq(a.frame(), -1)
