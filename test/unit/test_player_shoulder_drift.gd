extends GutTest
## v2.0.1 omuz kayması (T20261024-72): yürürken kol pivotu gövdenin omuz noktasından ≤ 6 px ayrışır (tüm sekme
## kademeleri, iki bakış, iki tabanca), duruşta 0. Gövde omzu bağımsız ölçülür: Body düğümünün dönüşümü × duruş
## geometrisinin gövde yereli omzu (kol konumundan türetilmez).

const DT := 1.0 / 60.0
const MAX_DRIFT := 6.0
## Ölçüt (varsayım, bkz. rapor): kol pivotunun gövde eğimiyle (rig dönüşü) sim omzundan kayması; bob/squash gövdenin
## bütün olarak hareketidir ve kayma sayılmaz. Gövde omzu ölçümü ise kolun gövdeye bağlı kaldığını ayrıca sınar.
const STRIP := "user://test_shoulder_strip.png"
const CELL := Vector2i(40, 80)

var _tier_backup: int = PlayerAnim.bounce_tier
var _rig_ref: Dictionary


func after_each() -> void:
	PlayerAnim.bounce_tier = _tier_backup
	_rig_ref = {}
	if FileAccess.file_exists(STRIP):
		DirAccess.remove_absolute(STRIP)
	ArtLoader._cache.clear()


func _view(frames: int = 0) -> PlayerView:
	var sim := GameSim.new(
		11, &"gunslinger", {"end_mode": "timer", "end_time": 480.0, "data": DataKit.copy()}
	)
	if frames > 0:
		var img := Image.create(CELL.x * (frames + 1), CELL.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.4, 0.3, 1.0))
		img.save_png(STRIP)
		_rig_ref = sim.character.rig
		_rig_ref["walk"] = {
			"frames": frames,
			"stride": 136,
			"strip": STRIP,
			"cell": [CELL.x, CELL.y],
			"shoulder_dev": []
		}
	var v := PlayerView.new()
	add_child_autofree(v)
	v.bind(sim)
	return v


## Gövde yerelindeki omuz noktasının (duruş geometrisi, aynasız) Body dönüşümüyle dünyaya taşınmış hali.
func _body_shoulder(v: PlayerView, gun: int, facing_left: bool) -> Vector2:
	var rig: Dictionary = v._sim.character.rig
	var box := v._body_box()
	var half_h := PlayerView.body_size(rig).y * 0.5
	var d := PlayerRig.shoulder_world(gun, Vector2.ZERO, facing_left, rig)
	var dx := -d.x if facing_left else d.x
	var local := Vector2(box.x * 0.5 + dx, box.y - half_h + d.y)
	return v.position + v.rig_node.transform * (v.body.transform * local)


func _max_drift(v: PlayerView, facing_left: bool) -> float:
	v._sim.player_facing_left = facing_left
	var dir := -5.0 if facing_left else 5.0
	var worst := 0.0
	for i in 150:  # 2,5 sn @ 300 px/sn: birkaç adım çevrimi, eğim tam oturur
		v._sim.player_pos += Vector2(dir, 0.0)
		v._sim.step_count += 1
		v.update_view(DT)
		if i < 30:
			continue
		for g in 2:
			worst = maxf(worst, v.shoulder_view(g).distance_to(_body_shoulder(v, g, facing_left)))
	return worst


func test_arm_pivot_stays_within_6px_of_body_shoulder_in_every_tier() -> void:
	for t in PlayerAnim.BOUNCE_TIERS.size():
		PlayerAnim.bounce_tier = t
		for facing in [false, true]:
			var v := _view()
			var worst := _max_drift(v, facing)
			assert_lte(worst, MAX_DRIFT, "kademe %d sol=%s: %.2f px" % [t, facing, worst])


func test_arm_pivot_stays_within_6px_of_body_shoulder_in_frame_mode() -> void:
	for t in PlayerAnim.BOUNCE_TIERS.size():
		PlayerAnim.bounce_tier = t
		for facing in [false, true]:
			var v := _view(6)
			var worst := _max_drift(v, facing)
			assert_lte(worst, MAX_DRIFT, "kare modu kademe %d sol=%s: %.2f px" % [t, facing, worst])


func test_standing_arm_pivot_matches_body_shoulder_exactly() -> void:
	for frames in [0, 6]:
		var v := _view(frames)
		for i in 10:
			v.update_view(DT)
		for g in 2:
			assert_lt(v.shoulder_view(g).distance_to(_body_shoulder(v, g, false)), 0.01)


func test_walk_lean_pivots_about_the_hip_not_the_feet() -> void:
	var v := _view()
	for i in 60:
		v._sim.player_pos += Vector2(5.0, 0.0)
		v._sim.step_count += 1
		v.update_view(DT)
	var h := PlayerView.body_size(v._sim.character.rig).y
	var hip := Vector2(0.0, -PlayerView.HIP_FRAC * h)
	var moved := v.rig_node.transform * hip - (hip + Vector2(0.0, h * 0.5 - v.anim.bob_px))
	assert_lt(moved.length(), 0.01, "eğim bel noktasını yerinden oynatmaz (bob hariç)")


## Rig dönüşünün kol pivotunu (rig yerelinde q) dönüşsüz konumundan ayırdığı uzaklık: |(R-I)(q-bel)|.
func test_lean_drift_of_arm_pivot_is_at_most_6px_in_every_tier() -> void:
	for t in PlayerAnim.BOUNCE_TIERS.size():
		PlayerAnim.bounce_tier = t
		for facing in [false, true]:
			var v := _view()
			v._sim.player_facing_left = facing
			var h := PlayerView.body_size(v._sim.character.rig).y
			var hip := Vector2(0.0, -PlayerView.HIP_FRAC * h)
			var worst := 0.0
			for i in 150:
				v._sim.player_pos += Vector2(-5.0 if facing else 5.0, 0.0)
				v._sim.step_count += 1
				v.update_view(DT)
				if i < 30:
					continue
				for g in 2:
					var q: Vector2 = (v.near_arm if g == 0 else v.far_arm).position - hip
					worst = maxf(worst, (q.rotated(v.rig_node.rotation) - q).length())
			assert_lte(worst, MAX_DRIFT, "kademe %d sol=%s: %.2f px" % [t, facing, worst])


func test_standing_has_no_lean_drift() -> void:
	var v := _view()
	for i in 10:
		v.update_view(DT)
	assert_eq(v.rig_node.rotation, 0.0)
	assert_almost_eq(v.rig_node.position.x, 0.0, 0.001)
