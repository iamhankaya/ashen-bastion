extends GutTest
## A2b: 19 Gunslinger beceri ikonu (7 aktif, 4 evrim, Barut Kesesi, 7 ortak pasif) boyalı PNG olarak veriye bağlı;
## kare tuval, içerik %80 ve ortalı; boyalı ikonda renk çarpanı yok; Zyfen varyantları değişmedi.

const ACTIVES := [
	&"cift_tabanca",
	&"yelpaze_atis",
	&"keskin_nisan",
	&"seken_mermi",
	&"son_mermi_patlar",
	&"doldurma_sacilmasi",
	&"sarapnel",
]
const EVOLUTIONS := [
	&"gurleyen_yelpaze", &"kiyamet_mermisi", &"mermi_firtinasi", &"zincirleme_patlama"
]
const PASSIVES := [
	&"barut_kesesi",
	&"agir_kursun",
	&"cevik_cizme",
	&"fazladan_mermi",
	&"hizli_doldurma",
	&"hizli_parmak",
	&"miknatis",
	&"saglam_yelek",
]
const COMMON := [
	&"agir_kursun",
	&"cevik_cizme",
	&"fazladan_mermi",
	&"hizli_doldurma",
	&"hizli_parmak",
	&"miknatis",
	&"saglam_yelek",
]


func _all() -> Array:
	var ids: Array = []
	ids.append_array(ACTIVES)
	ids.append_array(EVOLUTIONS)
	ids.append_array(PASSIVES)
	return ids


func _path(id: StringName) -> String:
	return "res://assets/ui/icons/%s.png" % String(id).replace("_", "-")


func test_there_are_19_gunslinger_icons() -> void:
	assert_eq(_all().size(), 19)


func test_every_gunslinger_skill_icon_points_at_its_png() -> void:
	var g := GameData.load_dir("res://data")
	for id: StringName in _all():
		var d := g.get_skill(id)
		assert_eq(d.icon, _path(id), "%s: veri yolu" % id)
		assert_eq(d.icon_for(&"gunslinger"), _path(id), "%s: Gunslinger ikonu" % id)
		assert_true(ResourceLoader.exists(d.icon), "%s: dosya var" % id)
		assert_true(d.icon.ends_with(".png"), "%s: PNG" % id)


func test_icons_are_square_with_content_centered_in_80_percent() -> void:
	for id: StringName in _all():
		var img := (load(_path(id)) as Texture2D).get_image()
		assert_eq(img.get_width(), img.get_height(), "%s kare" % id)
		var box := img.get_used_rect()
		var side := maxi(box.size.x, box.size.y)
		assert_almost_eq(float(side) / float(img.get_width()), 0.8, 0.02, "%s uzun kenar ~%%80" % id)
		var c := Vector2(box.position) + Vector2(box.size) * 0.5
		assert_almost_eq(c.x, img.get_width() * 0.5, 3.0, "%s yatay ortalı" % id)
		assert_almost_eq(c.y, img.get_height() * 0.5, 3.0, "%s dikey ortalı" % id)


func test_skill_icon_lookup_gives_a_texture_for_all_19() -> void:
	var g := GameData.load_dir("res://data")
	for id: StringName in _all():
		assert_not_null(UiKit.skill_icon(id, g.get_skill(id).icon), "%s" % id)
		assert_not_null(UiKit.skill_icon(id), "%s: alan boşken de kimlikten bulunur" % id)


func test_zyfen_variants_of_common_passives_are_unchanged() -> void:
	var g := GameData.load_dir("res://data")
	for id: StringName in COMMON:
		var z := g.get_skill(id).icon_for(&"zyfen")
		assert_eq(z, "res://assets/ui/icons/zyfen/%s.png" % String(id).replace("_", "-"), "%s" % id)
		assert_ne(z, g.get_skill(id).icon_for(&"gunslinger"), "%s: iki karakter ayrı ikon" % id)


func test_painted_gunslinger_slots_have_white_modulate_and_no_material() -> void:
	var kinds := {&"cift_tabanca": &"active", &"barut_kesesi": &"passive"}
	for id: StringName in kinds:
		var slot := SkillSlot.new(kinds[id], 180.0)
		add_child_autofree(slot)
		slot.set_skill(id, 1, _path(id))
		assert_eq(slot.modulate, Color.WHITE, "%s" % id)
		assert_null(slot.material, "%s" % id)
		assert_not_null(slot.icon, "%s" % id)
	var evo := SkillSlot.new(&"active", 180.0)
	add_child_autofree(evo)
	evo.set_skill(&"kiyamet_mermisi", 1, _path(&"kiyamet_mermisi"), true)
	assert_eq(evo.modulate, Color.WHITE)
	assert_not_null(evo.icon)
