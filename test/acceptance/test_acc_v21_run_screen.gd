extends GutTest
## Kabul (v2.1 A): KOŞU ekranı temeli (spec UI maddesi, tasarım docs/design/v2.1/DESIGN.md §3). Yalnız davranış sözleşmesi:
## ekranın varlığı, mod/zorluk adları, görünürlük, seçimin yalnız bilinçli eylemle değişmesi. Piksel/yerleşim ve güvenli alan
## `test_a<N>_` birim testleri (test_v21_a_run_ui) + shots_v21 görüntüleridir. V21Slice "A" açılana dek pending.
## T-turu (gerçek koda ayar): seçim ekran düğmelerinden (RunScreen.mode_buttons/diff_buttons) yapılır; metin araması
## büyük/küçük harf dönüşümsüzdür (Godot to_upper "i" -> "I" üretir, "İ" değil: Türkçe i/İ tuzağı); seçim sahte Settings'tedir.
## İzolasyon: Settings.store_path geçici yola alınır (ekran/controller save_settings'i gerçek user://settings.cfg'yi sızdırır).

const DIR := "user://v21_run_screen_acc"

var _fake: V21Kit.FakeSettings
var _ctrl: GameController = null
var _store_path: String = ""
var _pinned: Array = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var st := get_node("/root/Settings")
	_store_path = st.store_path
	st.store_path = AchKit.tmp_path("settings")
	# RunScreen yazı ölçeği/hareket ayarını gerçek Settings'ten okur: testten önce sabitle, sonra geri al.
	_pinned = [st.buyuk_yazi, st.hareket_azalt]
	st.buyuk_yazi = false
	st.hareket_azalt = false
	# Seçim (mod/zorluk) sahte Settings'te: kullanıcının gerçek kaydı sonucu etkilemez, hiçbir şey diske yazılmaz.
	_fake = V21Kit.use_fake_settings()


func after_each() -> void:
	# Controller, AchKit/DIR temizliğinden ÖNCE serbest bırakılır: _exit_tree -> release -> flush dosyayı yeniden yazardı.
	_free_controller()
	V21Kit.clear_fake_settings()
	var st := get_node("/root/Settings")
	st.store_path = _store_path
	st.buyuk_yazi = _pinned[0]
	st.hareket_azalt = _pinned[1]
	AchKit.cleanup()
	_clear_dir()


func after_all() -> void:
	_clear_dir()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func _clear_dir() -> void:
	var abs_dir := ProjectSettings.globalize_path(DIR)
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))


func _free_controller() -> void:
	if _ctrl != null and is_instance_valid(_ctrl):
		if _ctrl.get_parent() != null:
			_ctrl.get_parent().remove_child(_ctrl)
		_ctrl.free()
	_ctrl = null


func _controller() -> GameController:
	var c := GameController.new()
	c.v2_opts = {"achievements_path": DIR + "/ach.json"}
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.highscores = Highscores.new(DIR + "/hs.json")
	add_child(c)
	_ctrl = c
	c.go_menu()
	return c


func _has_text(texts: PackedStringArray, needle: String) -> bool:
	for t in texts:
		if t.contains(needle):
			return true
	return false


func test_a1_the_controller_builds_a_run_screen_that_is_hidden_on_the_menu() -> void:
	if V21Slice.require(self, "A"):
		return
	var c := _controller()
	assert_not_null(c.run_screen, "U4a KOŞU ekranını kurar")
	if c.run_screen == null:
		return
	assert_false(c.run_screen.visible, "menüde gizli")
	c.open_run_screen()
	assert_eq(c.screen, PauseLogic.Screen.RUN)
	assert_true(c.run_screen.visible, "KOŞU ekranında görünür")
	assert_false(c.menu.visible, "menü örtülür")
	c._on_back()
	assert_false(c.run_screen.visible, "GERİ ile kapanır")
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	assert_true(c.menu.visible, "menü geri gelir")


func test_a2_every_mode_and_difficulty_is_offered_by_name() -> void:
	if V21Slice.require(self, "A"):
		return
	var c := _controller()
	if c.run_screen == null:
		fail_test("run_screen yok")
		return
	var texts := AchKit.texts(c.run_screen)
	# Ad etiketleri DESIGN §3'te büyük harfle yazılır (RunStrip.MODE_NAMES/DIFF_NAMES); tam eşleşme aranır.
	for name in ["HIZLI", "NORMAL", "SONSUZ", "KOLAY", "ZOR"]:
		assert_true(texts.has(name), "ekranda '%s' etiketi var" % name)


func test_a3_the_screen_reflects_the_saved_selection_and_leaves_it_alone() -> void:
	if V21Slice.require(self, "A"):
		return
	_fake.run_mode = "endless"
	_fake.run_diff = "easy"
	var c := _controller()
	var rs := c.run_screen as RunScreen
	assert_not_null(rs, "run_screen bir RunScreen")
	if rs == null:
		return
	c.open_run_screen()
	assert_eq(_fake.saves, 0, "yalnız açmak seçimi yazmaz")
	assert_eq([_fake.run_mode, _fake.run_diff], ["endless", "easy"])
	assert_eq(V21Runs.selection(), {"mode": &"endless", "diff": &"easy"})
	assert_eq(
		rs.selection(), {"mode": &"endless", "diff": &"easy"}, "ekran kayıtlı seçimi yansıtır"
	)
	var endless_name := (rs.mode_buttons[&"endless"] as Button).accessibility_name
	var quick_name := (rs.mode_buttons[&"quick"] as Button).accessibility_name
	assert_true(endless_name.ends_with("seçili"), "Sonsuz seçili: '%s'" % endless_name)
	assert_true(quick_name.ends_with("seçili değil"), "Hızlı seçili değil: '%s'" % quick_name)
	# Seçim yalnız bilinçli eylemle (düğmeye dokunma) değişir ve o anda kaydedilir.
	(rs.diff_buttons[&"hard"] as Button).pressed.emit()
	assert_eq([_fake.run_mode, _fake.run_diff], ["endless", "hard"], "ZOR'a dokunmak seçer")
	assert_eq(_fake.saves, 1, "dokunma anında bir kez kaydeder")
	assert_eq(rs.selection(), {"mode": &"endless", "diff": &"hard"})


func test_a4_the_easy_rule_warning_is_shown_only_for_easy() -> void:
	if V21Slice.require(self, "A"):
		return
	_fake.run_diff = "easy"
	var c := _controller()
	c.open_run_screen()
	assert_true(
		_has_text(AchKit.texts(c.run_screen), "toplam sayaçlar ilerlemez"),
		"Kolay: Lord başarımları ve toplam sayaçlar ilerlemez uyarısı (K6-B)"
	)
	c._on_back()
	_fake.run_diff = "normal"
	c.open_run_screen()
	assert_false(
		_has_text(AchKit.texts(c.run_screen), "toplam sayaçlar ilerlemez"), "Normal'de uyarı yok"
	)


func test_a5_play_with_starts_the_chosen_run_and_hides_the_screen() -> void:
	if V21Slice.require(self, "A"):
		return
	var c := _controller()
	c.open_run_screen()
	c.play_with(&"quick", &"easy")
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	assert_eq(c.sim.run_profile.mode, &"quick")
	assert_eq(c.sim.run_profile.diff, &"easy")
	assert_eq(c.sim.end_time, 600.0)
	assert_eq(_fake.run_mode, "quick", "'BU AYARLA OYNA' seçimi kaydeder")
	assert_eq(_fake.run_diff, "easy")
	if c.run_screen != null:
		assert_false(c.run_screen.visible)
