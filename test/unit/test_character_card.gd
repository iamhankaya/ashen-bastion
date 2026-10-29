extends GutTest
## R5a CharacterCard: kart düğüm yapısı (ad, çocuk sırası) ve odak/kilit/seçili durumun rozet + erişilebilirlik adı.

var _data: GameData


func before_each() -> void:
	_data = GameData.load_dir("res://data")


func _card(id: StringName = &"gunslinger") -> Button:
	var b := CharacterCard.make(id, _data.get_character(id), func() -> void: pass)
	add_child_autofree(b)
	return b


func test_make_names_card_and_ends_with_ring_then_badge() -> void:
	var b := _card()
	assert_eq(b.name, &"Card_gunslinger")
	var n := b.get_child_count()
	assert_eq(b.get_child(n - 2).name, &"Ring")
	assert_eq(b.get_child(n - 1).name, &"Badge")
	assert_eq(b.custom_minimum_size, Vector2(CharacterCard.CARD_W, CharacterCard.CARD_H))


func test_make_connects_press_callback() -> void:
	var hits := [0]
	var b := CharacterCard.make(
		&"gunslinger", _data.get_character(&"gunslinger"), func() -> void: hits[0] += 1
	)
	add_child_autofree(b)
	b.pressed.emit()
	assert_eq(hits[0], 1)


func test_refresh_selected_adds_check_badge() -> void:
	var b := _card()
	CharacterCard.refresh(b, "Ad", true, false, true, "")
	assert_eq(b.get_node("Badge").get_child_count(), 1)
	assert_eq(b.accessibility_name, "Ad, seçili")
	assert_eq(b.modulate, Color.WHITE)


func test_refresh_locked_dims_and_reports_reason() -> void:
	var b := _card()
	CharacterCard.refresh(b, "Ad", false, true, false, "neden")
	assert_eq(b.get_node("Badge").get_child_count(), 1)
	assert_eq(b.accessibility_name, "Ad, kilitli. neden")
	assert_eq(b.modulate, Color(0.55, 0.55, 0.55))


func test_refresh_plain_has_no_badge_and_clears_previous() -> void:
	var b := _card()
	CharacterCard.refresh(b, "Ad", false, false, true, "")
	CharacterCard.refresh(b, "Ad", false, false, false, "")
	assert_eq(b.get_node("Badge").get_child_count(), 0)
	assert_eq(b.accessibility_name, "Ad")
