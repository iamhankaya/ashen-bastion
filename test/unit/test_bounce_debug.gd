extends GutTest
## v1.1.1 debug etiketi (yalnız debug derleme): yürüme sekmesi kademesi, dokunuşla döner.


func after_each() -> void:
	PlayerAnim.bounce_tier = PlayerAnim.BOUNCE_TIER_DEFAULT


func _controller() -> GameController:
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.start_run()
	c._update_views(0.016)
	return c


func test_label_shows_tier_and_cycles_through_all_tiers() -> void:
	var c := _controller()
	assert_not_null(c._bounce_label, "debug derlemede etiket kurulur")
	assert_true(c._bounce_label.visible, "oyunda görünür")
	assert_true(BounceDebug.text().contains("YUMUŞAK"), "varsayılan kademe")
	BounceDebug.cycle()
	assert_true(BounceDebug.text().contains("SAKİN"))
	BounceDebug.cycle()
	assert_true(BounceDebug.text().contains("ESKİ v1.1"), "başa sarar")
	assert_eq(PlayerAnim.bounce_tier, 0)


func test_label_hidden_in_menu() -> void:
	var c := _controller()
	c.go_menu()
	assert_false(c._bounce_label.visible, "menüde gizli")
