class_name V2Characters
extends V2Part
## Karakter seçimi bağlama (K sahipli): vitrin ekranı kurulumu/`selected` işleyici, menü etiketi, seviye atlama güvenli alanı.
## Başarım bilmez (yalnız `AchievementStore` okur): depo, paylaşılan `refs` sözlüğündeki "store" anahtarından tembel okunur
## (B'nin `V2Achievements.build_world` kurulumu `refs["store"] = store` yazar; yoksa null => `unlock`lu karakter kilitli).
## Seçim çözümlemesi `V2Flow.selected_character()`'dadır (CharacterRoster.resolve); burası yalnız UI bağlar.

var screen: CharactersScreen = null

var _menu: Node = null
var _level_up: Node = null
var _set_screen: Callable = Callable()
var _refs: Dictionary = {}
var _data: GameData = null


func build_world(refs: Dictionary) -> void:
	_menu = refs.get("menu", null)
	_level_up = refs.get("level_up", null)
	var cb: Variant = refs.get("set_screen", null)
	_set_screen = cb if cb is Callable else Callable()
	_refs = refs
	var root: Node = refs.get("ui_root", null)
	if root == null:
		return
	screen = CharactersScreen.new()
	screen.name = "CharactersScreen"
	screen.visible = false
	root.add_child(screen)
	screen.back_requested.connect(_on_back)
	screen.selected.connect(_on_selected)
	refresh_menu_label()
	apply_safe_areas(null)
	var vp := root.get_viewport()
	if vp != null:
		vp.size_changed.connect(apply_safe_areas.bind(null))


## Ana menüden KARAKTERLER (yalnız Screen.MENU'de çağrılır; V2Flow denetler).
func open() -> void:
	if screen == null:
		return
	var d := _game_data()
	screen.open(d, _store(), _current_id())
	if _set_screen.is_valid():
		_set_screen.call(PauseLogic.Screen.CHARACTERS)


func on_screen(next: int) -> void:
	if screen != null:
		screen.visible = next == PauseLogic.Screen.CHARACTERS
	if next == PauseLogic.Screen.MENU:
		refresh_menu_label()


func apply_safe_areas(extra: Variant = null) -> void:
	if screen != null:
		screen.apply_safe_area(extra)
	if _level_up != null and _level_up.has_method(&"apply_safe_area"):
		_level_up.apply_safe_area(extra)


func release() -> void:
	screen = null
	_menu = null
	_level_up = null
	_set_screen = Callable()
	_refs = {}


## KARAKTERLER alt satırı + sürüm etiketi: seçili karakterin adı.
func refresh_menu_label() -> void:
	if _menu == null or not _menu.has_method(&"set_character_name"):
		return
	var c := _game_data().get_character(_current_id())
	_menu.set_character_name(c.display_name if c != null else "")
	if _menu.has_method(&"set_character_portrait"):
		_menu.set_character_portrait(UiKit.texture(c.portrait) if c != null else null)


func _current_id() -> StringName:
	var saved := ""
	var st := _settings()
	if st != null:
		var v: Variant = st.get("character_id")
		saved = v if v is String else ""
	var id := CharacterRoster.resolve(saved, _game_data(), _store())
	return id if id != &"" else CharacterRoster.DEFAULT_ID


func _on_selected(id: StringName) -> void:
	var st := _settings()
	if st != null:
		st.set_character(String(id))
		st.vibrate(30)
	refresh_menu_label()


func _on_back() -> void:
	if _set_screen.is_valid():
		_set_screen.call(PauseLogic.Screen.MENU)


func _game_data() -> GameData:
	if _data == null:
		var d: Variant = opts.get("data", null)
		_data = d if d is GameData else GameData.load_default()
	return _data


func _store() -> AchievementStore:
	var s: Variant = _refs.get("store", null)
	return s if s is AchievementStore else null


func _settings() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(^"Settings")
	return null
