extends GutTest
## V2Flow (S3 cephesi): kancaları üç dilim sınıfına sırayla dağıtır; open_* yalnız MENU'de; release sonrası no-op;
## selected_character() çözümleme ve enjeksiyon. Controller entegrasyonu: v1.1 davranışı korunur.

const ACH_PATH := "user://test_ach_v2flow_unit.json"

var _log: Array[String] = []
var _chars_before: String = ""


class SpyChars:
	extends V2Characters
	var log: Array[String]

	func build_world(_refs: Dictionary) -> void:
		log.append("c.build_world")

	func bind(_sim: GameSim) -> void:
		log.append("c.bind")

	func update_views(view_dt: float) -> void:
		log.append("c.update_views:%s" % view_dt)

	func on_run_ended(won: bool, _stats: Dictionary) -> void:
		log.append("c.on_run_ended:%s" % won)

	func on_screen(next: int) -> void:
		log.append("c.on_screen:%d" % next)

	func on_pause() -> void:
		log.append("c.on_pause")

	func flush() -> void:
		log.append("c.flush")

	func apply_safe_areas(_extra: Variant = null) -> void:
		log.append("c.apply_safe_areas")

	func release() -> void:
		log.append("c.release")

	func open() -> void:
		log.append("c.open")


class SpyAch:
	extends V2Achievements
	var log: Array[String]

	func build_world(_refs: Dictionary) -> void:
		log.append("a.build_world")

	func bind(_sim: GameSim) -> void:
		log.append("a.bind")

	func update_views(view_dt: float) -> void:
		log.append("a.update_views:%s" % view_dt)

	func on_run_ended(won: bool, _stats: Dictionary) -> void:
		log.append("a.on_run_ended:%s" % won)

	func on_screen(next: int) -> void:
		log.append("a.on_screen:%d" % next)

	func on_pause() -> void:
		log.append("a.on_pause")

	func flush() -> void:
		log.append("a.flush")

	func apply_safe_areas(_extra: Variant = null) -> void:
		log.append("a.apply_safe_areas")

	func release() -> void:
		log.append("a.release")

	func open() -> void:
		log.append("a.open")


class SpyMaint:
	extends V2Maint
	var log: Array[String]

	func build_world(_refs: Dictionary) -> void:
		log.append("m.build_world")

	func bind(_sim: GameSim) -> void:
		log.append("m.bind")

	func update_views(view_dt: float) -> void:
		log.append("m.update_views:%s" % view_dt)

	func on_run_ended(won: bool, _stats: Dictionary) -> void:
		log.append("m.on_run_ended:%s" % won)

	func on_screen(next: int) -> void:
		log.append("m.on_screen:%d" % next)

	func on_pause() -> void:
		log.append("m.on_pause")

	func flush() -> void:
		log.append("m.flush")

	func apply_safe_areas(_extra: Variant = null) -> void:
		log.append("m.apply_safe_areas")

	func release() -> void:
		log.append("m.release")


func before_each() -> void:
	_chars_before = _settings().character_id


func after_each() -> void:
	_settings().character_id = _chars_before
	for suffix in ["", ".tmp", ".bad"]:
		if FileAccess.file_exists(ACH_PATH + suffix):
			DirAccess.remove_absolute(ACH_PATH + suffix)


func _settings() -> Node:
	return get_node("/root/Settings")


func _flow() -> V2Flow:
	var f := V2Flow.new()
	var c := SpyChars.new()
	var a := SpyAch.new()
	var m := SpyMaint.new()
	c.log = _log
	a.log = _log
	m.log = _log
	f.characters = c
	f.achievements = a
	f.maint = m
	_log.clear()
	return f


func test_each_hook_dispatches_to_characters_then_achievements_then_maint() -> void:
	var f := _flow()
	f.build_world({})
	assert_eq(_log, ["c.build_world", "a.build_world", "m.build_world"])
	_log.clear()
	f.bind(null)
	assert_eq(_log, ["c.bind", "a.bind", "m.bind"])
	_log.clear()
	f.update_views(0.016)
	assert_eq(_log, ["c.update_views:0.016", "a.update_views:0.016", "m.update_views:0.016"])
	_log.clear()
	f.on_run_ended(true, {})
	assert_eq(_log, ["c.on_run_ended:true", "a.on_run_ended:true", "m.on_run_ended:true"])
	_log.clear()
	f.on_screen(PauseLogic.Screen.PAUSED)
	assert_eq(_log, ["c.on_screen:3", "a.on_screen:3", "m.on_screen:3"])
	_log.clear()
	f.apply_safe_areas(Vector4.ZERO)
	assert_eq(_log, ["c.apply_safe_areas", "a.apply_safe_areas", "m.apply_safe_areas"])


func test_on_pause_dispatches_then_flushes() -> void:
	var f := _flow()
	f.on_pause()
	assert_eq(_log, ["c.on_pause", "a.on_pause", "m.on_pause", "c.flush", "a.flush", "m.flush"])


func test_flush_dispatches_to_all() -> void:
	var f := _flow()
	f.flush()
	assert_eq(_log, ["c.flush", "a.flush", "m.flush"])


func test_open_only_while_on_menu() -> void:
	var f := _flow()
	f.open_characters()  # başlangıç ekranı MENU
	f.open_achievements()
	assert_eq(_log, ["c.open", "a.open"])
	_log.clear()
	for sc in [
		PauseLogic.Screen.PLAYING,
		PauseLogic.Screen.LEVEL_UP,
		PauseLogic.Screen.PAUSED,
		PauseLogic.Screen.RESULT,
		PauseLogic.Screen.SCORES,
		PauseLogic.Screen.CHARACTERS,
		PauseLogic.Screen.ACHIEVEMENTS
	]:
		f.on_screen(sc)
		_log.clear()
		f.open_characters()
		f.open_achievements()
		assert_eq(_log, [], "ekran %d: no-op" % sc)
	f.on_screen(PauseLogic.Screen.MENU)
	_log.clear()
	f.open_characters()
	assert_eq(_log, ["c.open"])


func test_release_flushes_releases_and_makes_later_hooks_noops() -> void:
	var f := _flow()
	f.release()
	assert_eq(_log, ["c.flush", "a.flush", "m.flush", "c.release", "a.release", "m.release"])
	_log.clear()
	f.release()
	f.bind(null)
	f.update_views(1.0)
	f.on_pause()
	f.flush()
	f.on_screen(1)
	f.on_run_ended(false, {})
	f.open_characters()
	f.apply_safe_areas()
	f.build_world({})
	assert_eq(_log, [], "release sonrası hiçbir kanca çalışmaz")


func test_opts_are_shared_with_parts() -> void:
	var opts := {"achievements_path": "user://test_ach_flow.json"}
	var f := V2Flow.new(opts)
	assert_eq(f.opts, opts)
	assert_eq(f.characters.opts, opts)
	assert_eq(f.achievements.opts, opts)
	assert_eq(f.maint.opts, opts)


func test_selected_character_defaults_to_gunslinger() -> void:
	_settings().character_id = ""
	assert_eq(V2Flow.new().selected_character(), &"gunslinger")


func test_selected_character_uses_saved_valid_id() -> void:
	_settings().character_id = "barutcu"
	assert_eq(V2Flow.new().selected_character(), &"barutcu")


func test_selected_character_falls_back_for_unknown_or_wrong_id() -> void:
	for bad in ["yok_boyle_biri", "BARUTCU", " barutcu", "../data/characters/barutcu", "barutcu\n"]:
		_settings().character_id = bad
		assert_eq(V2Flow.new().selected_character(), &"gunslinger", bad)


func test_selected_character_uses_injected_data_not_the_default_cache() -> void:
	var dir := KitDev.data_dir()  # data_valid: yalnız gunslinger
	var f := V2Flow.new({"data": GameData.load_dir(dir)})
	_settings().character_id = "barutcu"  # enjekte veride yok
	assert_eq(f.selected_character(), &"gunslinger")
	KitDev.remove_tmp()


func test_selected_character_never_empty_even_without_characters() -> void:
	var dir := KitDev.data_dir_with({"characters/gunslinger.json": null})
	var f := V2Flow.new({"data": GameData.load_dir(dir)})
	assert_eq(f.selected_character(), CharacterRoster.DEFAULT_ID)
	KitDev.remove_tmp()


func test_selected_character_does_not_mutate_default_data_cache() -> void:
	var before := GameData.load_default()
	V2Flow.new().selected_character()
	assert_same(GameData.load_default(), before)


# --- GameController entegrasyonu (v1.1 davranışı korunur) ---------------------------------


func _ctrl(opts: Dictionary = {}) -> GameController:
	var gc := GameController.new()
	if not opts.has("achievements_path"):
		opts["achievements_path"] = ACH_PATH  # koşu sonu/duraklatma kaydı gerçek user:// dosyasına yazmasın
	gc.v2_opts = opts
	add_child_autofree(gc)
	return gc


func test_controller_builds_v2_flow_with_opts() -> void:
	var opts := {"achievements_path": "user://test_ach_ctrl_never_written.json"}
	var gc := _ctrl(opts)
	assert_not_null(gc.v2)
	assert_eq(gc.v2.opts, opts)


func test_start_run_uses_selected_character_gunslinger_by_default() -> void:
	_settings().character_id = ""
	var gc := _ctrl()
	gc.start_run()
	assert_eq(gc.sim.character.id, &"gunslinger")


func test_start_run_uses_barutcu_when_selected() -> void:
	_settings().character_id = "barutcu"
	var gc := _ctrl()
	gc.start_run()
	assert_eq(gc.sim.character.id, &"barutcu")
	assert_eq(gc.sim.max_hp, 120.0)


func test_menu_buttons_do_not_open_screens_in_contract_phase() -> void:
	var gc := _ctrl()
	assert_eq(gc.screen, PauseLogic.Screen.MENU)
	gc.menu.characters_button.pressed.emit()
	# BAŞARIMLAR artık açılır (B4; test_v2_achievements.gd). KARAKTERLER K dilimi dolana dek açılmaz.
	assert_eq(gc.screen, PauseLogic.Screen.MENU, "boş ekran açılmaz (dilimler doldurana dek)")
	assert_true(gc.menu.visible)


func test_back_from_new_screens_returns_to_menu_via_controller() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc.go_menu()
	gc._set_screen(PauseLogic.Screen.CHARACTERS)
	gc._on_back()
	assert_eq(gc.screen, PauseLogic.Screen.MENU)
	gc._set_screen(PauseLogic.Screen.ACHIEVEMENTS)
	gc._on_back()
	assert_eq(gc.screen, PauseLogic.Screen.MENU)


func test_set_screen_forwards_to_v2_and_hides_menu_for_new_screens() -> void:
	var gc := _ctrl()
	gc.go_menu()
	gc._set_screen(PauseLogic.Screen.CHARACTERS)
	assert_false(gc.menu.visible)
	assert_false(gc.hud.visible)
	assert_false(gc.joystick.visible)
	gc.go_menu()
	assert_true(gc.menu.visible)


func test_pause_game_calls_v2_flush_point_before_skip_delay() -> void:
	var gc := _ctrl()
	var f := V2Flow.new()
	var a := SpyAch.new()
	a.log = _log
	f.achievements = a
	_log.clear()
	gc.v2 = f
	gc.start_run()
	_log.clear()
	gc.pause_game()
	assert_true(_log.has("a.on_pause"), str(_log))
	assert_true(_log.has("a.flush"))
	assert_eq(gc.screen, PauseLogic.Screen.PAUSED)


func test_pause_game_outside_playing_does_not_flush() -> void:
	var gc := _ctrl()
	var f := V2Flow.new()
	var a := SpyAch.new()
	a.log = _log
	f.achievements = a
	gc.v2 = f
	_log.clear()
	gc.pause_game()  # MENU'de no-op
	assert_false(_log.has("a.on_pause"))


func test_run_ended_hook_order_is_v2_then_result_and_flush_last() -> void:
	var gc := _ctrl()
	var f := V2Flow.new()
	var a := SpyAch.new()
	a.log = _log
	f.achievements = a
	gc.v2 = f
	gc.start_run()
	_log.clear()
	gc._on_run_ended(false, {"score": 0, "time": 3.0, "level": 1, "kills": 0, "evolutions": []})
	var i_end := _log.find("a.on_run_ended:false")
	var i_flush := _log.rfind("a.flush")
	assert_gte(i_end, 0, str(_log))
	assert_gt(i_flush, i_end, "flush koşu sonu işlemlerinden sonra")
