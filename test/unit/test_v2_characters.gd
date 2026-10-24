extends GutTest
## V2Characters (K bağlama): ekranı kurar, KARAKTERLER → Screen.CHARACTERS, GERİ → MENU, SEÇ → Settings + menü etiketi.
## Settings otomatik yük (autoload) kopyalanmaz: store_path geçici yola alınır, character_id geri yazılır.

const TMP := "user://test_ach_v2chars_settings.cfg"

var _screens: Array[int] = []
var _root: Control
var _menu: MainMenu
var _chars: V2Characters
var _saved_id: String = ""
var _saved_path: String = ""


func before_each() -> void:
	var st := get_tree().root.get_node("Settings")
	_saved_id = st.character_id
	_saved_path = st.store_path
	st.store_path = TMP
	st.character_id = ""
	_screens.clear()
	_root = Control.new()
	add_child_autofree(_root)
	_menu = MainMenu.new()
	_root.add_child(_menu)
	_chars = V2Characters.new({"data": GameData.load_default()})
	_chars.build_world(
		{"ui_root": _root, "menu": _menu, "set_screen": func(n: int) -> void: _screens.append(n)}
	)


func after_each() -> void:
	var st := get_tree().root.get_node("Settings")
	st.character_id = _saved_id
	st.store_path = _saved_path
	for p in [TMP, TMP + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_chars.release()


func test_builds_hidden_screen_and_menu_label() -> void:
	assert_not_null(_chars.screen)
	assert_false(_chars.screen.visible)
	assert_string_contains(_menu.version_label.text, "Gunslinger")


func test_open_requests_characters_screen_and_focuses_selected() -> void:
	_chars.open()
	assert_eq(_screens, [PauseLogic.Screen.CHARACTERS] as Array[int])
	assert_eq(_chars.screen.focus_id(), &"gunslinger")


func test_on_screen_toggles_visibility() -> void:
	_chars.on_screen(PauseLogic.Screen.CHARACTERS)
	assert_true(_chars.screen.visible)
	_chars.on_screen(PauseLogic.Screen.MENU)
	assert_false(_chars.screen.visible)


func test_back_requests_menu() -> void:
	_chars.screen.back_requested.emit()
	assert_eq(_screens, [PauseLogic.Screen.MENU] as Array[int])


func test_select_saves_character_and_updates_menu() -> void:
	_chars.open()
	_chars.screen.set_focus_id(&"zyfen")
	assert_true(_chars.screen.press_select())
	assert_eq(get_tree().root.get_node("Settings").character_id, "zyfen")
	assert_string_contains(_menu.version_label.text, "Zyfen")
	assert_true(FileAccess.file_exists(TMP), "geçici yola yazıldı, gerçek dosyaya değil")


func test_saved_character_is_focused_on_reopen() -> void:
	get_tree().root.get_node("Settings").character_id = "zyfen"
	_chars.open()
	assert_eq(_chars.screen.focus_id(), &"zyfen")


func test_no_ui_root_is_safe() -> void:
	var c := V2Characters.new({"data": GameData.load_default()})
	c.build_world({})
	c.open()
	c.on_screen(PauseLogic.Screen.MENU)
	c.apply_safe_areas(null)
	assert_null(c.screen)
