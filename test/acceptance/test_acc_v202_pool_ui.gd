extends GutTest
## Kabul (v2.0.2 K, P): karaktere göre ad/ikonun UI çağrı yerleri (plan Arayüzler/3: "UI çağrı yerleri def.icon_for(sim.character.id)
## kullanır: hud, pause_screen, UiKit.combo_rows(evolutions, data, character_id := &"") (result_screen geçirir), characters_screen").
## Ekran düğümleri kurulmaz; saf yardımcılar ve sim durumu denetlenir.

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func _combo_rows_arg_count() -> int:
	var ui: Script = load("res://scripts/ui/ui_kit.gd")
	for m in ui.get_script_method_list():
		if m["name"] == "combo_rows":
			return (m["args"] as Array).size()
	return -1


func test_p1_hud_and_pause_use_the_zyfen_icon_of_a_common_passive() -> void:
	if V202Slice.require(self, "P"):
		return
	var z := SimKit.make(1, {"character": &"zyfen", "data_kind": "real"})
	z.debug_grant(&"agir_kursun", 1)
	var st := z.loadout.state_of(&"agir_kursun")
	assert_eq(Hud._icon_of(st), "res://assets/ui/icons/zyfen/agir-kursun.svg", "Zyfen ikonu")
	var g := SimKit.make(1, {"character": &"gunslinger", "data_kind": "real"})
	g.debug_grant(&"agir_kursun", 1)
	assert_eq(
		Hud._icon_of(g.loadout.state_of(&"agir_kursun")),
		_data.get_skill(&"agir_kursun").icon,
		"Gunslinger ikonu değişmedi"
	)


func test_p2_characters_screen_starting_skill_name_and_icon_are_resolved_per_character() -> void:
	if V202Slice.require(self, "P"):
		return
	var z := _data.get_character(&"zyfen")
	var sk := _data.get_skill(z.starting_skill)
	assert_eq(sk.name_for(z.id), "Rüzgar Kesiği")
	assert_ne(sk.icon_for(z.id), "", "başlangıç becerisi ikonu var")


func test_p3_result_screen_combo_rows_accepts_the_character_and_uses_its_names() -> void:
	if V202Slice.require(self, "P"):
		return
	var n := _combo_rows_arg_count()
	assert_eq(
		n,
		3,
		(
			'UiKit.combo_rows(evolutions, data, character_id := &"") — plan Arayüzler/3 (şu an %d parametre)'
			% n
		)
	)
	if n != 3:
		return
	var rows: Array = Callable(UiKit, "combo_rows").call(["ay_oragi"], _data, &"zyfen")
	assert_eq(rows.size(), 1)
	assert_true(
		String(rows[0]["pair"]).contains("Bilenmiş Rüzgar"), "Zyfen adı: %s" % rows[0]["pair"]
	)
	assert_false(String(rows[0]["pair"]).contains("Ağır Kurşun"), "Gunslinger adı sızmaz")


func test_p4_combo_rows_without_a_character_keeps_the_default_names() -> void:
	if V202Slice.require(self, "P"):
		return
	var rows: Array = UiKit.combo_rows(["zincirleme_patlama"], _data)
	assert_eq(rows.size(), 1)
	var want := (
		"%s + %s"
		% [
			_data.get_skill(&"seken_mermi").display_name,
			_data.get_skill(&"barut_kesesi").display_name
		]
	)
	assert_eq(rows[0]["pair"], want, "karaktersiz çağrı varsayılan adlar")
