extends GutTest
## F-ashen-bastion-172 doğrulama: RfBaseline._rects_diff tolerans sınırı ve derin yol kenar durumları.


func _diff(cls: String, actual_rect: String, base_rect: String, path: String = "R/A") -> String:
	return RfBaseline._rects_diff(
		["%s|%s|%s" % [path, cls, actual_rect]], ["%s|%s|%s" % [path, cls, base_rect]], ""
	)


func test_tolerance_boundary_is_inclusive_for_text_classes() -> void:
	var edge := "%s" % RfBaseline.X_TOL_PX
	assert_eq(_diff("Label", "10.0,5.0,100.0,20.0", "18.0,5.0,108.0,20.0"), "", "tam sınır geçer")
	assert_true(
		_diff("Label", "10.0,5.0,100.0,20.0", "18.01,5.0,100.0,20.0") != "", "x sınırı + epsilon"
	)
	assert_true(
		_diff("Label", "10.0,5.0,100.0,20.0", "10.0,5.0,108.01,20.0") != "", "w sınırı + epsilon"
	)
	assert_true(edge != "", "X_TOL_PX tanımlı")


func test_deep_path_keeps_class_gate() -> void:
	var deep := "Root/A/B/C/D"
	assert_eq(_diff("Label", "10.0,5.0,100.0,20.0", "14.0,5.0,104.0,20.0", deep), "", "derin Label")
	assert_true(
		_diff("ColorRect", "10.0,5.0,100.0,20.0", "14.0,5.0,100.0,20.0", deep) != "",
		"derin ColorRect x kayması yakalanmalı"
	)


func test_class_mismatch_is_rejected_even_if_rect_equal() -> void:
	assert_true(_diff("Label", "1.0,1.0,2.0,2.0", "1.0,1.0,2.0,2.0") == "")
	var d := RfBaseline._rects_diff(["R|Label|1.0,1.0,2.0,2.0"], ["R|Control|1.0,1.0,2.0,2.0"], "")
	assert_true(d != "", "sınıf farkı kırmızı")


func test_unknown_class_gets_no_tolerance() -> void:
	assert_true(_diff("SomeCustomNode", "10.0,5.0,100.0,20.0", "11.0,5.0,100.0,20.0") != "")
