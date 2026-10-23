extends GutTest
## N1: Cinzel'de küçük harf yoktur; küçük `i` noktasız `I` çizilir. Cinzel ile gösterilen dinamik adlar (seviye kartı,
## kombo listesi) Türkçe büyük harfe çevrilir (i→İ, ı→I). Yeni beceri eklenince de yakalar (tüm veri taranır).


func _cinzel_labels(n: Node, out: Array[Label]) -> void:
	if n is Label:
		var v := (n as Label).theme_type_variation
		if v == &"LabelTimer" or v == &"LabelTitle" or v == &"LabelAccent":
			out.append(n)
	for c in n.get_children():
		_cinzel_labels(c, out)


func _choice(kind: StringName, id: StringName, title: String) -> Choice:
	var c := Choice.new()
	c.kind = kind
	c.skill_id = id
	c.from_level = 0
	c.to_level = 1
	c.title = title
	c.desc = "Açıklama"
	return c


func test_upper_tr_maps_turkish_letters() -> void:
	assert_eq(UiKit.upper_tr("Barut Kesesi"), "BARUT KESESİ")
	assert_eq(UiKit.upper_tr("Son Mermi Patlar"), "SON MERMİ PATLAR")
	assert_eq(UiKit.upper_tr("Şifa"), "ŞİFA")
	assert_eq(UiKit.upper_tr("Kıyamet Mermisi"), "KIYAMET MERMİSİ")
	assert_eq(UiKit.upper_tr("Keskin Nişan"), "KESKİN NİŞAN")
	assert_eq(UiKit.upper_tr("çiğ öğüt ışık"), "ÇİĞ ÖĞÜT IŞIK")
	assert_eq(UiKit.upper_tr("ABC 123 İI"), "ABC 123 İI", "büyük harf ve rakam değişmez")
	assert_eq(UiKit.upper_tr(""), "")


func test_every_skill_with_an_i_shows_a_dotted_capital_on_its_level_up_card() -> void:
	var data := GameData.load_default()
	var with_i := 0
	for id in data.skill_ids:
		var def: SkillDef = data.get_skill(id)
		var s := LevelUpScreen.new()
		add_child_autofree(s)
		s.show_choices([_choice(Choice.KIND_NEW, id, def.display_name)], 3, data)
		var labels: Array[Label] = []
		_cinzel_labels(s.cards[0], labels)
		var titles: Array[String] = []
		for l in labels:
			titles.append(l.text)
		assert_has(
			titles, UiKit.upper_tr(def.display_name), "%s: kart başlığı Türkçe büyük harf" % id
		)
		var shown := UiKit.upper_tr(def.display_name)
		assert_eq(
			shown.count("I"),
			def.display_name.count("ı") + def.display_name.count("I"),
			"%s: noktasız I yalnız ı/I'den gelir" % id
		)
		if def.display_name.contains("i"):
			with_i += 1
			assert_true(shown.contains("İ"), "%s: i → İ" % id)
	assert_gte(with_i, 11, "veride `i` içeren en az 11 beceri adı var (denetim N1)")


func test_heal_card_title_is_dotted_capital() -> void:
	var s := LevelUpScreen.new()
	add_child_autofree(s)
	s.show_choices([_choice(Choice.KIND_HEAL, &"", "Şifa")], 5)
	var labels: Array[Label] = []
	_cinzel_labels(s.cards[0], labels)
	var titles: Array[String] = []
	for l in labels:
		titles.append(l.text)
	assert_has(titles, "ŞİFA")
	assert_does_not_have(titles, "ŞIFA")


func test_result_screen_combo_names_use_dotted_capitals() -> void:
	var data := GameData.load_default()
	var evos: Array = []
	for id in data.skill_ids:
		var def: SkillDef = data.get_skill(id)
		if def.kind == &"evolution":
			evos.append(id)
	assert_gt(evos.size(), 0)
	var rows := UiKit.combo_rows(evos, data)
	var r := ResultScreen.new()
	add_child_autofree(r)
	var typed: Array[Dictionary] = []
	typed.assign(rows)
	r.show_result(true, {"time": 1300.0, "level": 30, "kills": 100, "evolutions": evos}, typed)
	var labels: Array[Label] = []
	_cinzel_labels(r.combo_box, labels)
	var shown: Array[String] = []
	for l in labels:
		shown.append(l.text)
	for row in rows:
		assert_has(shown, UiKit.upper_tr(str(row["name"])))
