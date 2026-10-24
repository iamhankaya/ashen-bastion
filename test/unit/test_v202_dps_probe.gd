extends GutTest
## DpsProbe (test/helpers/dps_probe.gd): kukla düzeni, determinizm, beceri eklenince DPS değişimi, önbelleğe yazmama.


func test_measure_is_deterministic_and_positive_for_gunslinger() -> void:
	var a := DpsProbe.measure(&"gunslinger", {}, &"ring", 8, 6.0)
	var b := DpsProbe.measure(&"gunslinger", {}, &"ring", 8, 6.0)
	assert_eq(a["dummies"], 8)
	assert_gt(a["dps"], 0.0)
	assert_gt(a["shots"], 0)
	assert_eq(a["total"], b["total"], "aynı tohum aynı toplam hasar")
	assert_eq(a["shots"], b["shots"])


func test_extra_skill_changes_dps() -> void:
	var base := DpsProbe.measure(&"gunslinger", {}, &"cluster", 8, 6.0)
	var more := DpsProbe.measure(&"gunslinger", {&"cift_tabanca": 1}, &"cluster", 8, 6.0)
	assert_gt(more["dps"], base["dps"], "çift tabanca ham DPS'i artırmalı")


func test_dummies_never_die_and_layouts_place_requested_count() -> void:
	for lay in [&"ring", &"line", &"cluster"]:
		var r := DpsProbe.measure(&"gunslinger", {}, lay, 6, 4.0)
		assert_eq(r["dummies"], 6, str(lay))
		assert_lt(r["total"], DpsProbe.DUMMY_HP, "kukla ölmemeli: %s" % lay)


func test_zyfen_base_attack_runs_without_error() -> void:
	var r := DpsProbe.measure(&"zyfen", {}, &"line", 6, 4.0)
	assert_eq(r["dummies"], 6)
	assert_gte(r["dps"], 0.0)


func test_line_layout_is_single_axis() -> void:
	var spots := DpsProbe._layout(Vector2(10, 20), &"line", 5)
	assert_eq(spots.size(), 5)
	for s in spots:
		assert_eq(s.y, 20.0)
	assert_gt(spots[4].x, spots[0].x)
