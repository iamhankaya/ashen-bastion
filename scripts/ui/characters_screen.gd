class_name CharactersScreen
extends Control
## Karakterler ekranı: vitrin sahnesi (portre + parçacık) + bilgi paneli + kart şeridi + SEÇ/GERİ. Karakter BAŞLATMAZ
## (sinyal yayar), sim yok. Tasarım: docs/design/v2.0/DESIGN.md §4. İSKELET (S3): gövdeler K1/K2'de (Stub.todo);
## V2Characters ekranı kurana dek (K2) hiçbir yerde örneklenmez.

signal back_requested
## SEÇ basıldı (yalnız kilitsiz ve odak != seçili).
signal selected(id: StringName)

enum SelectState { SELECT, SELECTED, LOCKED }


func open(_data: GameData, _store: AchievementStore, _selected_id: StringName) -> void:
	Stub.todo(&"CharactersScreen.open")


func focus_id() -> StringName:
	Stub.todo(&"CharactersScreen.focus_id")
	return &""


func set_focus_id(_id: StringName) -> void:
	Stub.todo(&"CharactersScreen.set_focus_id")


## Test/D-pad için; kilitliyse false.
func press_select() -> bool:
	Stub.todo(&"CharactersScreen.press_select")
	return false


## SelectState.
func select_button_state() -> int:
	Stub.todo(&"CharactersScreen.select_button_state")
	return SelectState.SELECT


## extra: Vector4(sol, üst, sağ, alt) ya da null (UiKit.current_safe_extra).
func apply_safe_area(_extra: Variant = null) -> void:
	Stub.todo(&"CharactersScreen.apply_safe_area")
