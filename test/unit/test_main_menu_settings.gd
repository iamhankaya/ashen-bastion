extends GutTest
## v2.0.1: ana menü AYARLAR düğmesi — güvenli alan kaydırması ve başlıkla boşluk (U-15 kalıbı).

var m: MainMenu


func before_each() -> void:
	m = MainMenu.new()
	add_child_autofree(m)
	await get_tree().process_frame
	await get_tree().process_frame


func test_settings_button_follows_title_top_shift() -> void:
	m.apply_safe_area(Vector4.ZERO)
	var base_y := m.settings_button.position.y
	m.apply_safe_area(Vector4(0, 200, 0, 0))
	await get_tree().process_frame
	var drop := 200.0 - (MainMenu.HEAD_TOP - MainMenu.TOP_DEFAULT)
	assert_almost_eq(m.settings_button.position.y, base_y + drop, 0.5)
	assert_gte(m.settings_button.global_position.y, 96.0 + 200.0)


func test_settings_button_moves_in_from_right_inset() -> void:
	m.apply_safe_area(Vector4.ZERO)
	var base_r := m.settings_button.global_position.x + m.settings_button.size.x
	m.apply_safe_area(Vector4(0, 0, 90, 0))
	await get_tree().process_frame
	var r := m.settings_button.global_position.x + m.settings_button.size.x
	assert_almost_eq(r, base_r - 90.0, 0.5)
	assert_lte(r, m.size.x - UiKit.SIDE - 90.0 + 0.5)


func test_settings_button_clear_of_title_and_fits_label() -> void:
	m.apply_safe_area(Vector4.ZERO)
	await get_tree().process_frame
	var b := m.settings_button
	assert_lte(b.get_combined_minimum_size().x, b.size.x + 0.5, "AYARLAR etiketi sığmalı")
	var title_bottom := m._head.global_position.y + m._head.get_combined_minimum_size().y
	assert_gte(b.global_position.y, title_bottom + 12.0, "başlıkla görünür boşluk")
	assert_gte(b.global_position.y, 196.0)
	assert_lte(b.global_position.x + b.size.x, m.size.x - UiKit.SIDE + 0.5)
