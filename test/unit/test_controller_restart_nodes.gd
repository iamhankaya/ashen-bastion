extends GutTest
## F-ashen-bastion-125: yeniden başlatma (start_run) eski koşunun görünüm düğümlerini bırakmaz; düğüm sayısı sabit kalır.


func _ctrl() -> GameController:
	var gc := GameController.new()
	gc.highscores = Highscores.new("user://yok_klasor_v2_izolasyon/hs.json")
	gc.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}
	gc.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(gc)
	return gc


func _count(n: Node, cls: String) -> int:
	var k := 1 if n.is_class(cls) else 0
	for c in n.get_children():
		k += _count(c, cls)
	return k


func test_restart_keeps_sprite_count_after_a_frame() -> void:
	var gc := _ctrl()
	seed(4242)
	gc.start_run()
	var first := _count(gc, "Sprite2D")
	seed(4242)
	gc.start_run()
	var immediately := _count(gc, "Sprite2D")
	await get_tree().process_frame
	var settled := _count(gc, "Sprite2D")
	gut.p("sprite: ilk=%d hemen=%d bir kare sonra=%d" % [first, immediately, settled])
	assert_gt(first, 0, "harabe sprite'ları var")
	assert_eq(settled, first, "bir kare sonra sayı sabit")
	assert_eq(
		immediately, first, "yeniden başlatma anında da sabit (eski sprite'lar hemen serbest)"
	)
