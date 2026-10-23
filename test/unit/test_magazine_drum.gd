extends GutTest
## MagazineDrum sınırsız durumu: describe, çizim (polyline ∞), doldurma halkası yok.


func test_unlimited_describe_and_toggle() -> void:
	var d := MagazineDrum.new()
	add_child_autofree(d)
	d.set_state(4, 6, false, 0.0)
	assert_eq(d.describe(), "Şarjör 4 / 6")
	d.set_unlimited(true)
	assert_eq(d.describe(), "Şarjör sınırsız")
	d.set_unlimited(false)
	assert_eq(d.describe(), "Şarjör 4 / 6")


func test_unlimited_overrides_reloading_text_and_draws() -> void:
	var d := MagazineDrum.new()
	add_child_autofree(d)
	d.set_state(0, 6, true, 0.5)
	d.set_unlimited(true)
	assert_eq(d.describe(), "Şarjör sınırsız", "doldurma halkası/metni yok")
	d.queue_redraw()
	await get_tree().process_frame
	assert_true(d.unlimited)
