extends GutTest
## Kabul (v1.1 D3): denetleyici akışı - ana menüden En İyi Skorlar, ölüm/kazanma gecikmesi (1,3 / 1,8 sn), dokunma/geri/arka
## plan ile atlama, sonuç ekranının tek kez gösterilmesi, seviye ön vurgusu 0,18 sn (U11 akış, U14). Dilim D3 bitmeden pending.
## Review Focus 4: gecikme sırasında dokunma, geri tuşu, arka plana atma - sonuç ekranı tek kez, skor tek kez yazılır.

const ROOT := "user://v11_flow_tests"

var _n: int = 0
var _dir: String = ""


func before_each() -> void:
	_n += 1
	_dir = "%s/%d_%d" % [ROOT, OS.get_process_id(), _n]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_all() -> void:
	_rm(ProjectSettings.globalize_path(ROOT))


func _rm(abs_path: String) -> void:
	for f in DirAccess.get_files_at(abs_path):
		DirAccess.remove_absolute(abs_path.path_join(f))
	for d in DirAccess.get_directories_at(abs_path):
		_rm(abs_path.path_join(d))
	DirAccess.remove_absolute(abs_path)


func test_u11_controller_opens_scores_screen_from_menu_and_back_returns() -> void:
	if V11Slice.require(self, "D3"):
		return
	var c := GameController.new()
	c.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}  # v2.0 izolasyon: yazılamaz yol, gerçek dosya oluşmaz
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.highscores = Highscores.new(_dir.path_join("hs.json"))
	assert_not_null(c.scores_screen, "scores_screen kuruldu")
	if c.scores_screen == null:
		return
	c.menu.scores_requested.emit()
	assert_eq(c.screen, PauseLogic.Screen.SCORES)
	assert_true(c.scores_screen.visible)
	assert_false(c.menu.visible)
	c._on_back()
	assert_eq(c.screen, PauseLogic.Screen.MENU, "geri tuşu SCORES'ta ana menüye döner")
	assert_true(c.menu.visible)
	assert_false(c.scores_screen.visible)


class SpyController:
	extends GameController
	var result_shown: int = 0

	func _show_result() -> void:
		result_shown += 1
		super()


func _spy(highscore_path: String) -> SpyController:
	var c := SpyController.new()
	c.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}  # v2.0 izolasyon
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.highscores = Highscores.new(highscore_path)
	c.start_run()
	return c


func _die(c: GameController) -> void:
	for i in 130:
		c.sim.step(Vector2.ZERO)
		c._after_step()
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c._after_step()


func _touch() -> InputEventScreenTouch:
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = Vector2(500, 1200)
	return t


func test_u14_death_delay_is_1_3_seconds_then_result_shows_once() -> void:
	if V11Slice.require(self, "D3"):
		return
	var c := _spy(_dir.path_join("hs.json"))
	_die(c)
	assert_eq(c.sim.state, GameSim.State.LOST)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "gecikme boyunca PLAYING kalır")
	assert_eq(c.result_shown, 0)
	c._process(1.0)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "1,0 sn: henüz")
	c._process(0.4)
	assert_eq(c.screen, PauseLogic.Screen.RESULT, "1,4 sn: sonuç ekranı")
	assert_eq(c.result_shown, 1)
	for i in 5:
		c._process(0.5)
	assert_eq(c.result_shown, 1, "sonuç ekranı tek kez")
	assert_eq(c.sim.state, GameSim.State.LOST)


func test_u14_win_delay_is_1_8_seconds() -> void:
	if V11Slice.require(self, "D3"):
		return
	var c := _spy(_dir.path_join("hs.json"))
	var lord := c.sim.debug_spawn(&"kale_lordu", Vector2(900, 0))
	c.sim.damage_enemy(lord, 1.0e9, &"bullet")
	c.sim.step(Vector2.ZERO)
	c._after_step()
	assert_eq(c.sim.state, GameSim.State.WON)
	c._process(1.5)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "1,5 sn: kazanma gecikmesi sürer")
	c._process(0.4)
	assert_eq(c.screen, PauseLogic.Screen.RESULT, "1,9 sn: sonuç")
	assert_eq(c.result_shown, 1)


func test_u14_touch_during_delay_skips_to_result_once() -> void:
	if V11Slice.require(self, "D3"):
		return
	var c := _spy(_dir.path_join("hs.json"))
	_die(c)
	c._unhandled_input(_touch())
	assert_eq(c.screen, PauseLogic.Screen.RESULT, "dokunma gecikmeyi atlar")
	assert_eq(c.result_shown, 1)
	c._unhandled_input(_touch())
	for i in 4:
		c._process(0.5)
	assert_eq(c.result_shown, 1, "ikinci dokunma/zamanlayıcı ikinci sonuç üretmez")
	assert_eq(c.sim.state, GameSim.State.LOST)


func test_u14_back_key_during_delay_skips_instead_of_pausing() -> void:
	if V11Slice.require(self, "D3"):
		return
	var c := _spy(_dir.path_join("hs.json"))
	_die(c)
	c._on_back()
	assert_eq(c.screen, PauseLogic.Screen.RESULT, "geri tuşu gecikmeyi atlar (duraklatmaz)")
	assert_eq(c.result_shown, 1)
	c._process(2.0)
	assert_eq(c.result_shown, 1)


func test_u14_app_pause_during_delay_skips_without_pausing_the_game() -> void:
	if V11Slice.require(self, "D3"):
		return
	var c := _spy(_dir.path_join("hs.json"))
	_die(c)
	c._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(
		c.screen, PauseLogic.Screen.RESULT, "arka plana atma gecikmeyi atlar, oyun duraklatılmaz"
	)
	assert_eq(c.result_shown, 1)
	c._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	c._process(2.0)
	assert_eq(c.result_shown, 1, "tek kez")
	assert_ne(c.screen, PauseLogic.Screen.PAUSED)


func test_u14_level_up_preroll_is_0_18_seconds_before_the_card_screen() -> void:
	if V11Slice.require(self, "D3"):
		return
	var c := _spy(_dir.path_join("hs.json"))
	c.sim.debug_add_xp(c.sim.xp_to_next)
	c.sim.step(Vector2.ZERO)
	c._after_step()
	assert_eq(c.sim.state, GameSim.State.LEVEL_UP)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "ön vurgu sırasında henüz kart ekranı yok")
	c._process(0.1)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "0,1 sn")
	c._process(0.1)
	assert_eq(c.screen, PauseLogic.Screen.LEVEL_UP, "0,2 sn: kart ekranı")
