extends GutTest
## Kabul (v2.1 B): skor ekranı sekmeleri ve sonuç ekranı koşu bilgisi (spec UI maddesi, DESIGN.md §5-6). Davranış sözleşmesi:
## skor ekranı iki sıra üçlü sekme (MOD 3 + ZORLUK 3 = 9 liste) sunar, açılan liste istenen çifttir; sonuç ekranı mod/zorluğu
## söyler, Sonsuz'da Lord sayısı, yalnız Kolay'da kural notu. Yerleşim/çakışma `test_b<N>_` birim testleri + görüntülerdir.
## V21Slice "B" açılana dek pending. Metinler gerçek ekranlardan (RunStrip.MODE_NAMES/DIFF_NAMES, ResultScreen.EASY_NOTE) doğrulandı.

const DIR := "user://v21_scores_acc"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_clean()


func after_each() -> void:
	V21Kit.clear_fake_settings()


func after_all() -> void:
	_clean()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func _clean() -> void:
	var abs_dir := ProjectSettings.globalize_path(DIR)
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))


func _controller() -> GameController:
	var c := GameController.new()
	c.v2_opts = {"achievements_path": DIR + "/ach.json"}
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.highscores = Highscores.new(DIR + "/hs.json")
	add_child_autofree(c)
	c.start_run()
	return c


func _finish(c: GameController) -> void:
	c.sim.score.on_kill(&"elit_karga", c.sim.step_count)
	for i in 30:
		c.sim.step(Vector2.ZERO)
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c._after_step()
	c.flush_delay()


## Yalnız GÖRÜNÜR metinler: Kolay notu paneli ve LORD çipi gizliyken de ağaçta durur (AchKit.texts görünürlüğe bakmaz),
## "yok" iddiaları (b4, b5) görünürlüğe göre sınanır.
func _visible_texts(n: Node, out: PackedStringArray) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_visible_texts(c, out)


func _upper(root: Node) -> String:
	var texts := PackedStringArray()
	_visible_texts(root, texts)
	var out := ""
	for t in texts:
		out += t.to_upper() + "\n"
	return out


func test_b1_the_scores_screen_offers_three_modes_and_three_difficulties() -> void:
	if V21Slice.require(self, "B"):
		return
	V21Kit.use_fake_settings()
	var c := _controller()
	c.go_menu()
	c.open_scores()
	assert_eq(c.screen, PauseLogic.Screen.SCORES)
	var text := _upper(c.scores_screen)
	for name in ["HIZLI", "SONSUZ", "KOLAY", "ZOR"]:
		assert_true(text.contains(name), "sekme: %s" % name)
	assert_gte(text.count("NORMAL"), 2, "NORMAL hem MOD hem ZORLUK sırasında")


func test_b2_the_requested_pair_is_the_one_shown() -> void:
	if V21Slice.require(self, "B"):
		return
	V21Kit.use_fake_settings()
	var c := _controller()
	c.highscores.submit(
		{
			"score": 4242,
			"time": 5,
			"won": false,
			"level": 2,
			"unix": 1,
			"mode": "quick",
			"diff": "easy"
		}
	)
	c.highscores.submit(
		{
			"score": 9191,
			"time": 5,
			"won": false,
			"level": 2,
			"unix": 1,
			"mode": "endless",
			"diff": "hard"
		}
	)
	c.go_menu()
	c.open_scores(&"quick", &"easy")
	var text := _upper(c.scores_screen)
	assert_true(text.contains("4242") or text.contains("4.242") or text.contains("4,242"))
	assert_false(text.contains("9191") or text.contains("9.191") or text.contains("9,191"))


func test_b3_the_result_screen_names_the_mode_and_difficulty_of_the_finished_run() -> void:
	if V21Slice.require(self, "B"):
		return
	var fake := V21Kit.use_fake_settings()
	fake.run_mode = "quick"
	fake.run_diff = "hard"
	var c := _controller()
	_finish(c)
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	var text := _upper(c.result_screen)
	assert_true(text.contains("HIZLI"), "mod çipi")
	assert_true(text.contains("ZOR"), "zorluk çipi")


func test_b4_endless_result_shows_the_lord_count_only_in_endless() -> void:
	if V21Slice.require(self, "B"):
		return
	var fake := V21Kit.use_fake_settings()
	fake.run_mode = "endless"
	var c := _controller()
	c.sim.milestone_won = true
	c.sim.lords_killed = 2
	_finish(c)
	assert_true(_upper(c.result_screen).contains("LORD ×2"), "Sonsuz: LORD ×N çipi")
	c.go_menu()
	fake.run_mode = "normal"
	var c2 := _controller()
	_finish(c2)
	assert_false(_upper(c2.result_screen).contains("LORD ×"), "Normal'de Lord sayısı çipi yok")


func test_b5_the_easy_rule_note_appears_on_easy_results_only() -> void:
	if V21Slice.require(self, "B"):
		return
	var fake := V21Kit.use_fake_settings()
	fake.run_diff = "easy"
	var easy := _controller()
	_finish(easy)
	assert_true(
		_upper(easy.result_screen).contains("YAZILMADI"),
		"Kolay: bu koşu Lord başarımlarına ... yazılmadı"
	)
	fake.run_diff = "normal"
	var normal := _controller()
	_finish(normal)
	assert_false(_upper(normal.result_screen).contains("YAZILMADI"), "Normal'de not yok")
