extends GutTest
## U1: seviye atlama kartında her karakterin her becerisinin başlığı kart genişliğine sığar (diakritikli Zyfen
## adları dahil). Etiket `get_minimum_size().x` ≤ kartın metin sütunu (kart − kenar boşlukları − ikon − ara).

const CARD_MARGINS := 72.0  # LevelUpScreen._make_card: row.offset_left/right = ±36
const ROW_SEPARATION := 40.0

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func _title_label(card: Button) -> Label:
	var row := card.get_child(0) as HBoxContainer
	var col := row.get_child(1) as VBoxContainer
	return col.get_child(0) as Label


func _check(character: StringName, expected: int) -> void:
	var screen := LevelUpScreen.new()
	add_child_autofree(screen)
	var loadout := Loadout.new(_data, character)
	var column := LevelUpScreen.CARD_W - CARD_MARGINS - LevelUpScreen.ICON - ROW_SEPARATION
	var checked := 0
	for def in (
		_data.skills_of_kind(SkillDef.KIND_ACTIVE)
		+ _data.skills_of_kind(SkillDef.KIND_PASSIVE)
		+ _data.skills_of_kind(SkillDef.KIND_EVOLUTION)
	):
		if not def.available_to(character):
			continue
		var choices: Array = [loadout.card_for(def.id, 1)]
		screen.show_choices(choices, 2, _data, _data.get_character(character))
		var label := _title_label(screen.cards[0])
		assert_lte(
			label.get_minimum_size().x,
			column,
			"%s/%s: '%s' kartta taşıyor" % [character, def.id, label.text]
		)
		checked += 1
	assert_eq(checked, expected, "%s: tüm kayıtlar denetlendi" % character)


func test_gunslinger_card_titles_fit() -> void:
	_check(&"gunslinger", 19)  # 7 aktif + 8 pasif + 4 evrim


func test_zyfen_card_titles_fit() -> void:
	_check(&"zyfen", 20)  # 8 aktif + 8 pasif + 4 evrim
