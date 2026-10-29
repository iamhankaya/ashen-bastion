extends GutTest
## F-021 debug etiketi (yalnız debug derleme): AÇIK/KAPALI bayrağı ve sayaç, dokunuşla çevrilir.


func test_label_flag_and_counters_in_a_debug_build() -> void:
	assert_true(OS.is_debug_build())
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.start_run()
	assert_not_null(c._escape_label, "debug derlemede etiket kurulur")
	c._update_views(0.016)
	assert_true(c._escape_label.visible, "oyunda görünür")
	assert_true(c.escape_debug_text().contains("çıkmaz kaçışı: AÇIK (dokun)"))
	assert_true(c.escape_debug_text().contains("kaçışta 0"))
	c.toggle_escape_fix()
	assert_false(c._escape_enabled)
	assert_false(c.sim.enemies.escape_enabled, "çalışma anında değiştirme koşan sim'e uygulanır")
	assert_true(c.escape_debug_text().contains("KAPALI"))
	c.toggle_escape_fix()
	assert_true(c._escape_enabled)
	assert_true(c.sim.enemies.escape_enabled)


func test_flag_and_counter_carry_over_to_the_next_run() -> void:
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.start_run()
	c.toggle_escape_fix()
	c.sim.enemies.escape_begun = 3
	c.start_run()
	assert_false(c.sim.enemies.escape_enabled, "bayrak oturum kapsamlı: yeni sim'e uygulanır")
	assert_eq(c.sim.enemies.escape_begun, 0, "sayaç koşu kapsamlı")
	assert_true(c.escape_debug_text().contains("girilen 3"), "görüntü = oturum tabanı + koşu")
	c.sim.enemies.escape_begun = 2
	assert_true(c.escape_debug_text().contains("girilen 5"))


func test_label_hidden_in_menu() -> void:
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.start_run()
	c._update_views(0.016)
	assert_true(c._escape_label.visible)
	c.go_menu()
	assert_false(c._escape_label.visible, "menüde gizli")
