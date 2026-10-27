extends GutTest
## Kabul (v2.1 A): KOŞU ekranı temeli (spec UI maddesi, tasarım docs/design/v2.1/DESIGN.md §3). Yalnız davranış sözleşmesi:
## ekranın varlığı, mod/zorluk adları, görünürlük, seçimin yalnız bilinçli eylemle değişmesi. Piksel/yerleşim ve güvenli alan
## `test_a<N>_` birim testleri + shots_v21 görüntüleridir. V21Slice "A" açılana dek pending.
## Ekrandan seçim yapmanın dahili API'si sözleşmede yok: seçim testi V21Runs (Settings köprüsü) üzerinden, ekran yeniden
## kurulumu `open_run_screen()` ile yapılır; T-turu gerçek düğme yoluna uyarlar.

const DIR := "user://v21_run_screen_acc"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))


func after_each() -> void:
	V21Kit.clear_fake_settings()


func after_all() -> void:
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(DIR)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR).path_join(f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func _controller() -> GameController:
	var c := GameController.new()
	c.v2_opts = {"achievements_path": DIR + "/ach.json"}
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.highscores = Highscores.new(DIR + "/hs.json")
	add_child_autofree(c)
	c.go_menu()
	return c


func _upper_texts(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for t in AchKit.texts(root):
		out.append(t.to_upper())
	return out


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


func test_a2_every_mode_and_difficulty_is_offered_by_name() -> void:
	if V21Slice.require(self, "A"):
		return
	var c := _controller()
	if c.run_screen == null:
		fail_test("run_screen yok")
		return
	var texts := _upper_texts(c.run_screen)
	for name in ["HIZLI", "NORMAL", "SONSUZ", "KOLAY", "ZOR"]:
		assert_true(_has_text(texts, name), "ekranda '%s' var" % name)


func test_a3_the_screen_reflects_the_saved_selection_and_leaves_it_alone() -> void:
	if V21Slice.require(self, "A"):
		return
	var fake := V21Kit.use_fake_settings()
	fake.run_mode = "endless"
	fake.run_diff = "easy"
	var c := _controller()
	c.open_run_screen()
	assert_eq(fake.saves, 0, "yalnız açmak seçimi yazmaz")
	assert_eq([fake.run_mode, fake.run_diff], ["endless", "easy"])
	assert_eq(V21Runs.selection(), {"mode": &"endless", "diff": &"easy"})


func test_a4_the_easy_rule_warning_is_shown_only_for_easy() -> void:
	if V21Slice.require(self, "A"):
		return
	var fake := V21Kit.use_fake_settings()
	fake.run_diff = "easy"
	var c := _controller()
	c.open_run_screen()
	assert_true(
		_has_text(_upper_texts(c.run_screen), "TOPLAM SAYAÇLAR İLERLEMEZ"),
		"Kolay: Lord başarımları ve toplam sayaçlar ilerlemez uyarısı (K6-B)"
	)
	c._on_back()
	fake.run_diff = "normal"
	c.open_run_screen()
	assert_false(
		_has_text(_upper_texts(c.run_screen), "TOPLAM SAYAÇLAR İLERLEMEZ"), "Normal'de uyarı yok"
	)


func test_a5_play_with_starts_the_chosen_run_and_hides_the_screen() -> void:
	if V21Slice.require(self, "A"):
		return
	var fake := V21Kit.use_fake_settings()
	var c := _controller()
	c.open_run_screen()
	c.play_with(&"quick", &"easy")
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	assert_eq(c.sim.run_profile.mode, &"quick")
	assert_eq(c.sim.end_time, 600.0)
	assert_eq(fake.run_mode, "quick", "'BU AYARLA OYNA' seçimi kaydeder")
	if c.run_screen != null:
		assert_false(c.run_screen.visible)
