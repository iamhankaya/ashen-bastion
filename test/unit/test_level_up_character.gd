extends GutTest
## K1 seviye atlama başlığı/portre (N4/N7): üst yazı karakter adı (upper_tr), portre karakterden, portresiz düzen çökmez,
## başlık y 880/924, alt pay kartları yukarı alır. Saf birim (sim yok).

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func _screen() -> LevelUpScreen:
	var s := LevelUpScreen.new()
	add_child_autofree(s)
	return s


func _char(id: StringName, portrait: String = "", display: String = "") -> CharacterDef:
	var c := CharacterDef.new()
	c.id = id
	c.display_name = display if display != "" else String(id)
	c.portrait = portrait
	return c


func test_default_header_is_gunslinger() -> void:
	var s := _screen()
	s.show_choices([], 2, _data)
	assert_eq(s.name_label.text, "GUNSLINGER")
	assert_not_null(s.portrait_node, "v1.1: varsayılan portre")


func test_header_uses_character_name_upper_tr() -> void:
	var s := _screen()
	s.show_choices([], 3, _data, _data.get_character(&"barutcu"))
	assert_eq(s.name_label.text, "BARUTÇU")
	s.show_choices([], 3, _data, _data.get_character(&"gunslinger"))
	assert_eq(s.name_label.text, "GUNSLINGER", "F-029: display_upper (özel ad, noktalı İ yok)")
	assert_eq(s.title_label.text, "SEVİYE 3")


func test_name_with_dotted_i_is_uppercased_correctly() -> void:
	var s := _screen()
	s.show_choices([], 2, _data, _char(&"x", "", "kilit çiçeği"))
	assert_eq(s.name_label.text, "KİLİT ÇİÇEĞİ")
	s.show_choices([], 2, _data, _char(&"y", "", "ışık"))
	assert_eq(s.name_label.text, "IŞIK")


func test_portrait_comes_from_character() -> void:
	var s := _screen()
	var c := _data.get_character(&"barutcu")
	s.show_choices([], 2, _data, c)
	assert_eq(s.portrait_node.texture, UiKit.texture(c.portrait))


func test_missing_portrait_opens_without_portrait_node() -> void:
	var s := _screen()
	s.show_choices([], 2, _data, _char(&"z", "res://yok/yok.png"))
	assert_null(s.portrait_node)
	assert_not_null(s.title_label, "başlık düğümü hâlâ var")
	assert_not_null(s.find_child("Backdrop", true, false), "bordo radyal zemin")
	assert_null(s.find_child("Portrait", true, false))
	s.show_choices([], 2, _data, _char(&"w", ""))
	assert_null(s.portrait_node, "portrait alanı boş: portresiz")


func test_switching_back_to_portrait_character_restores_it() -> void:
	var s := _screen()
	s.show_choices([], 2, _data, _char(&"z", "res://yok/yok.png"))
	s.show_choices([], 2, _data, _data.get_character(&"gunslinger"))
	assert_not_null(s.portrait_node)
	assert_null(s.find_child("Backdrop", true, false))


func test_header_geometry_y880_and_title_below() -> void:
	var s := _screen()
	s.show_choices([], 2, _data)
	await get_tree().process_frame
	assert_eq(s.name_label.get_parent().position.y, 880.0)
	var ny := s.name_label.global_position.y
	var ty := s.title_label.global_position.y
	assert_gt(ty, ny)
	assert_almost_eq(ty - 6.0 + 4.0, 924.0, 24.0, "başlık y ≈ 924")


func test_safe_area_bottom_lifts_cards() -> void:
	var s := _screen()
	s.show_choices([], 2, _data)
	s.apply_safe_area(Vector4.ZERO)
	var base := s.cards_box.offset_bottom
	s.apply_safe_area(Vector4(0, 100, 0, 150))
	assert_eq(s.cards_box.offset_bottom, base - 150.0)
	assert_eq(s.get_node("PortraitHost").offset_bottom, 1620.0, "üst pay etkilemez")


func test_shade_has_no_top_veil_and_bottom_stops() -> void:
	var g := LevelUpScreen._shade_texture().gradient
	assert_almost_eq(g.colors[0].a, 0.0, 1e-6, "üst perde yok")
	var by_y := {}
	for i in g.offsets.size():
		by_y[int(roundf(g.offsets[i] * LevelUpScreen.PORTRAIT_H))] = g.colors[i].a
	assert_almost_eq(float(by_y[560]), 0.0, 1e-6)
	assert_almost_eq(float(by_y[860]), 0.72, 1e-6)
	assert_almost_eq(float(by_y[1000]), 0.90, 1e-6)
	assert_almost_eq(float(by_y[1150]), 1.0, 1e-6)
