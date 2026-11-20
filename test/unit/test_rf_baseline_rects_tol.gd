extends GutTest
## F-ashen-bastion-172: RfBaseline._rects_diff x/genişlik toleransı (±X_TOL_PX) yalnız metin ölçülü sınıflara
## (Label, Button, kapsayıcılar...) uygulanır; sabit boyutlu sınıflarda (ColorRect, TextureRect, Panel, Control...) ±0.


func _diff(cls: String, actual_rect: String, base_rect: String) -> String:
	return RfBaseline._rects_diff(
		["R/A|%s|%s" % [cls, actual_rect]], ["R/A|%s|%s" % [cls, base_rect]], ""
	)


func test_text_classes_tolerate_x_and_width_within_tol() -> void:
	for cls in [
		"Label", "Button", "RichTextLabel", "HBoxContainer", "VBoxContainer", "PanelContainer"
	]:
		assert_eq(_diff(cls, "10.0,5.0,100.0,20.0", "14.0,5.0,106.0,20.0"), "", cls)


func test_text_classes_reject_x_beyond_tol() -> void:
	assert_true(_diff("Label", "10.0,5.0,100.0,20.0", "19.0,5.0,100.0,20.0") != "")
	assert_true(_diff("Label", "10.0,5.0,100.0,20.0", "10.0,5.0,109.0,20.0") != "")


func test_text_classes_reject_y_and_height_shift() -> void:
	assert_true(_diff("Label", "10.0,5.0,100.0,20.0", "10.0,6.0,100.0,20.0") != "")
	assert_true(_diff("Label", "10.0,5.0,100.0,20.0", "10.0,5.0,100.0,21.0") != "")


func test_fixed_size_classes_reject_any_x_or_width_shift() -> void:
	for cls in ["ColorRect", "TextureRect", "Panel", "Control", "HSlider"]:
		assert_true(_diff(cls, "10.0,5.0,100.0,20.0", "11.0,5.0,100.0,20.0") != "", cls + " x")
		assert_true(_diff(cls, "10.0,5.0,100.0,20.0", "10.0,5.0,101.0,20.0") != "", cls + " w")


func test_fixed_size_classes_accept_identical_rect() -> void:
	assert_eq(_diff("ColorRect", "10.0,5.0,100.0,20.0", "10.0,5.0,100.0,20.0"), "")
