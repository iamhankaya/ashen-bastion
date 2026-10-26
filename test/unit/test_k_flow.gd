extends GutTest
## K akışı (controller entegrasyonu): KARAKTERLER → vitrin, seçim → koşu o karakterle, seviye atlama başlığı karakter adı,
## geri → menü. Settings paylaşılan autoload: store_path geçici, character_id geri yazılır.

const TMP := "user://test_ach_kflow_settings.cfg"

var _saved_id: String = ""
var _saved_path: String = ""


func before_each() -> void:
	var st := get_tree().root.get_node("Settings")
	_saved_id = st.character_id
	_saved_path = st.store_path
	st.store_path = TMP
	st.character_id = ""


func after_each() -> void:
	var st := get_tree().root.get_node("Settings")
	st.character_id = _saved_id
	st.store_path = _saved_path
	for p in [TMP, TMP + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _ctrl() -> GameController:
	var gc := GameController.new()
	gc.v2_opts = {"achievements_path": "user://test_ach_kflow_never_written.json"}
	add_child_autofree(gc)
	return gc


func test_select_zyfen_then_play_uses_zyfen() -> void:
	var gc := _ctrl()
	gc.open_characters()
	assert_eq(gc.screen, PauseLogic.Screen.CHARACTERS)
	var scr: CharactersScreen = gc.v2.characters.screen
	scr.set_focus_id(&"zyfen")
	assert_true(scr.press_select())
	assert_eq(gc.screen, PauseLogic.Screen.CHARACTERS, "SEÇ ekrandan çıkmaz")
	gc._on_back()
	assert_eq(gc.screen, PauseLogic.Screen.MENU)
	assert_string_contains((gc.menu.characters_button.get_node("Sub") as Label).text, "Zyfen")
	gc.start_run()
	assert_eq(gc.sim.character.id, &"zyfen")


func test_level_up_header_shows_character_name() -> void:
	get_tree().root.get_node("Settings").character_id = "zyfen"
	var gc := _ctrl()
	gc.start_run()
	gc.sim.debug_add_xp(30)
	for i in 5:
		gc.sim.step(Vector2.ZERO)
	assert_eq(gc.sim.state, GameSim.State.LEVEL_UP)
	gc._show_level_up()  # v1.1 ekran gecikmesi atlanır: başlık davranışı sınanır
	assert_eq(gc.screen, PauseLogic.Screen.LEVEL_UP)
	assert_eq(gc.level_up.name_label.text, "ZYFEN")


func test_characters_screen_hidden_stops_motion_after_leaving() -> void:
	var gc := _ctrl()
	gc.open_characters()
	var scr: CharactersScreen = gc.v2.characters.screen
	assert_true(scr.is_processing())
	gc._on_back()
	assert_false(scr.is_processing())
	assert_false(scr.particles.emitting)
	gc.open_characters()
	assert_true(scr.is_processing())
	assert_true(scr.particles.emitting)


func test_open_characters_is_noop_outside_menu() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc.open_characters()
	assert_eq(gc.screen, PauseLogic.Screen.PLAYING)
