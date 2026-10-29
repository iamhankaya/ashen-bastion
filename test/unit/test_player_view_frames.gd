extends GutTest
## PlayerView kare modu (D4-2): sentetik 6 ve 7 kareli şeritle A2/A11/A12/A24 ve omuz uyumu.
## Şerit çalışma anında user://'a yazılır (gerçek kareler bağlanmadan kod yolu tam sınanır).

const DT := 1.0 / 60.0
const STRIP := "user://test_walk_strip.png"
const CELL := Vector2i(40, 80)

var _walk_backup: Variant = null
var _rig_ref: Dictionary


func before_each() -> void:
	ArtLoader._cache.clear()


func after_each() -> void:
	if _rig_ref.size() > 0:  # GameData önbelleği paylaşımlıdır: işin sonunda geri al
		_rig_ref["walk"] = _walk_backup
	if FileAccess.file_exists(STRIP):
		DirAccess.remove_absolute(STRIP)
	ArtLoader._cache.clear()


func _write_strip(cells: int, w: int = CELL.x, h: int = CELL.y) -> void:
	var img := Image.create(w * cells, h, false, Image.FORMAT_RGBA8)
	for c in cells:
		img.fill_rect(Rect2i(c * w, 0, w, h), Color(0.1 + 0.1 * c, 0.4, 0.3, 1.0))
	img.save_png(STRIP)


## N yürüme karesi + duruş; `dev` boş ya da N+1 çift.
func _view(n: int, dev: Array = [], write: bool = true, strip_cells: int = -1) -> PlayerView:
	if write:
		_write_strip(n + 1 if strip_cells < 0 else strip_cells)
	var sim := GameSim.new(11, &"gunslinger", {"end_mode": "timer", "end_time": 480.0})
	_rig_ref = sim.character.rig
	_walk_backup = _rig_ref.get("walk", null)
	_rig_ref["walk"] = {
		"frames": n, "stride": 136, "strip": STRIP, "cell": [CELL.x, CELL.y], "shoulder_dev": dev
	}
	var v := PlayerView.new()
	add_child_autofree(v)
	v.bind(sim)
	return v


func _walk(v: PlayerView, px_per_step: float, steps: int) -> void:
	for i in steps:
		v._sim.player_pos += Vector2(px_per_step, 0.0)
		v._sim.step_count += 1
		v.update_view(DT)


func _stand(v: PlayerView, steps: int) -> void:
	for i in steps:  # sim adımlar ama oyuncu durur
		v._sim.step_count += 1
		v.update_view(DT)


func _param(v: PlayerView, name: String) -> Variant:
	return (v.body.material as ShaderMaterial).get_shader_parameter(name)


func test_synthetic_strip_switches_to_frame_mode_for_6_and_7_frames() -> void:
	for n in [6, 7]:
		var v := _view(n)
		assert_true(v._strip_ready, "n=%d" % n)
		assert_eq(float(_param(v, "cells")), float(n + 1), "N yürüme + 1 duruş hücresi")
		assert_eq(v.anim.frame_a, n, "durma: duruş hücresi (indeks N)")
		var tex := _param(v, "body_tex") as Texture2D
		assert_eq(
			tex.get_width(), (n + 1) * (CELL.x + 2 * PlayerView.PAD), "her hücre ayrı dolgulu"
		)
		assert_eq(tex.get_height(), CELL.y + 2 * PlayerView.PAD)
		after_each()


func test_frames_zero_or_missing_strip_keeps_the_procedural_fallback() -> void:
	var v := _view(6, [], false)  # şerit dosyası yok
	assert_false(v._strip_ready)
	assert_eq(float(_param(v, "cells")), 1.0)
	_walk(v, 5.0, 30)
	assert_gt(v.anim.bob_px, 0.0, "prosedürel bob")
	after_each()
	var z := _view(0, [], true, 7)  # frames: 0, şerit dosyası var: yine prosedürel
	assert_false(z._strip_ready)
	assert_eq(float(_param(z, "cells")), 1.0)


func test_uneven_or_mismatched_strip_falls_back_without_errors() -> void:
	var v := _view(6, [], true, 5)  # 5 hücrelik dosya, 7 bekleniyor: 200 px / 7 bölünmez
	assert_false(v._strip_ready)
	assert_eq(float(_param(v, "cells")), 1.0)
	_walk(v, 5.0, 10)
	assert_eq(v.anim.frame_a, 0)


func test_body_box_is_the_cell_at_the_stand_scale_with_the_foot_on_the_pivot() -> void:
	var v := _view(6)
	v.update_view(DT)
	var h := float(v._rig["display_height"])
	var stand_px := float(ArtLoader.texture(str(v._rig["body"])).get_height())
	var k := h / stand_px
	var want := Vector2(CELL) * k
	assert_almost_eq(v.body.position.y, -want.y, 0.01, "mesh alt kenarı = ayak (Rig pivotu)")
	assert_almost_eq(v.body.position.x, -want.x * 0.5, 0.01, "hücre yatayda ortalı")
	var aabb := v.body.mesh.get_aabb()
	var pad_w := float(PlayerView.PAD) * k
	assert_almost_eq(aabb.size.x, want.x + 2.0 * pad_w, 0.05)
	assert_almost_eq(aabb.size.y, want.y + 2.0 * pad_w, 0.05)
	assert_almost_eq(v.rig_node.position.y, h * 0.5, 0.01, "ayak pivotu duruş yüksekliğinden")


func test_walking_advances_the_frame_by_distance_and_has_no_procedural_bob() -> void:
	var v := _view(6)
	var seen := {}
	for i in 140:
		_walk(v, 1.5, 1)  # 90 px/sn
		assert_eq(v.anim.bob_px, 0.0, "A2: kare modunda bob 0")
		assert_eq(v.anim.sx, 1.0)
		seen[v.anim.frame_a] = true
		assert_eq(float(_param(v, "frame_a")), float(v.anim.frame_a))
	assert_eq(seen.size(), 6, "bir adımda 6 kare görülür")
	assert_false(seen.has(6), "yürürken duruş hücresi yok")


func test_one_stride_of_distance_advances_the_phase_by_one() -> void:
	var v := _view(6)
	_walk(v, 1.0, 5)  # harekete başla
	var f0 := v.anim.walk_phase
	_walk(v, 1.0, 136)
	var turn := fposmod(v.anim.walk_phase - f0, 1.0)
	assert_almost_eq(minf(turn, 1.0 - turn), 0.0, 0.01, "136 px = 1 çevrim")
	var f1 := v.anim.walk_phase
	_walk(v, 1.0, 34)
	assert_almost_eq(fposmod(v.anim.walk_phase - f1, 1.0), 0.25, 0.01)


func test_stopping_crossfades_to_the_stand_cell_within_80ms_and_walking_restarts_at_frame_0(
) -> void:
	var v := _view(6)
	_walk(v, 5.0, 40)
	assert_ne(v.anim.frame_a, 6)
	_stand(v, 6)  # 100 ms
	assert_eq(v.anim.frame_a, 6, "A12: ≤80 ms içinde duruş hücresi")
	assert_eq(v.anim.frame_mix, 0.0)
	_walk(v, 5.0, 1)
	assert_eq(v.anim.frame_a, 0, "A12: harekete başlayınca kare 0")


func test_mid_stop_blends_two_cells() -> void:
	var v := _view(6)
	_walk(v, 5.0, 40)
	_stand(v, 2)
	assert_gt(v.anim.frame_mix, 0.0)
	assert_lt(v.anim.frame_mix, 1.0)
	assert_eq(v.anim.frame_b, 6)
	assert_almost_eq(float(_param(v, "frame_mix")), v.anim.frame_mix, 1e-5)


func test_shoulders_follow_the_sim_within_the_hip_lean_drift_while_walking_in_frame_mode() -> void:
	var v := _view(6)
	for facing in [false, true]:
		v._sim.player_facing_left = facing
		for i in 60:
			_walk(v, -5.0 if facing else 5.0, 1)  # 300 px/sn: en büyük eğim
		assert_gt(absf(rad_to_deg(v.anim.lean)), 2.0, "eğim %60'a inmiş ama var")
		for g in 2:
			var want := PlayerRig.shoulder_world(g, v._sim.player_pos, facing, v._sim.character.rig)
			var dev := v.shoulder_view(g).distance_to(want)
			# bel pivotu: eğim kayması + bob/squash (gövdenin bütünü); kenet yok (v2.0.1)
			assert_lte(dev, 9.0, "omuz sim'den ≤9 px (g=%d sol=%s, %.2f px)" % [g, facing, dev])


func test_standing_shoulders_still_match_within_a_pixel_in_frame_mode() -> void:
	var v := _view(6)
	for i in 5:
		v.update_view(DT)
	for g in 2:
		var want := PlayerRig.shoulder_world(g, v._sim.player_pos, false, v._sim.character.rig)
		assert_lt(v.shoulder_view(g).distance_to(want), 1.5)


func test_arms_follow_the_per_frame_shoulder_deviation() -> void:
	var v := _view(6)
	_walk(v, 0.2, 3)  # 12 px/sn: yürüme eşiği (8) üstünde, eğim ~0
	assert_eq(v.anim.frame_a, 0)
	var before := v.shoulder_view(0)
	var dev: Array = []
	for f in 7:
		dev.append([0.0, 0.0] if f == 6 else [0.02, 0.0])
	v._rig["walk"]["shoulder_dev"] = dev
	v.update_view(0.0)
	var shift := v.shoulder_view(0).x - before.x
	assert_almost_eq(shift, 0.02 * float(v._rig["display_height"]), 0.3, "kare 0 omzu dx=+%2")


func test_arm_pivot_is_not_clamped_to_the_sim_shoulder() -> void:
	var dev: Array = []
	for f in 7:
		dev.append([0.0, 0.0] if f == 6 else [0.15, 0.0])  # 30 px: kol gövdeyle birlikte gider (v2.0.1)
	var v := _view(6, dev)
	_walk(v, 0.2, 3)
	var want := PlayerRig.shoulder_world(0, v._sim.player_pos, false, v._sim.character.rig)
	assert_gt(v.shoulder_view(0).distance_to(want), 20.0)


func test_recoil_is_not_cut_by_the_shoulder_clamp_in_frame_mode() -> void:
	var v := _view(6)
	_walk(v, 0.2, 3)
	var before := v.near_arm.position
	v.anim.on_shot(0)
	var peak := 0.0
	var moved := 0.0
	for i in 8:
		_walk(v, 0.2, 1)
		if v.anim.arm_back[0] > peak:
			peak = v.anim.arm_back[0]
			moved = v.near_arm.position.distance_to(before)
	assert_gt(peak, 5.0, "tepme tepe noktası")
	assert_almost_eq(moved, peak, 1.0, "geri tepme tam uygulanır (kenet yalnız omuz tabanında)")


func test_crossfade_blends_the_deviation_of_both_frames_and_mirrors_when_facing_left() -> void:
	var dev: Array = []
	for f in 7:
		dev.append([0.0, 0.0] if f == 6 else [0.02, 0.0])
	var v := _view(6, dev)
	_walk(v, 0.2, 3)
	_stand(v, 2)  # 0 < mix < 1: kare 0 (dx 0,02) ile duruş (0) harmanı
	var mix := v.anim.frame_mix
	assert_between(mix, 0.01, 0.99)
	var sh := v._shoulder_now(0)
	var base := PlayerRig.shoulder_world(0, Vector2.ZERO, false, v._rig)
	assert_almost_eq(sh.x - base.x, 0.02 * 200.0 * (1.0 - mix), 0.05)
	v._sim.player_facing_left = true
	v._facing_left = true
	var left := v._shoulder_now(0)
	var lbase := PlayerRig.shoulder_world(0, Vector2.ZERO, true, v._rig)
	assert_almost_eq(
		left.x - lbase.x, -0.02 * 200.0 * (1.0 - mix), 0.05, "sola bakışta dx aynalanır"
	)
