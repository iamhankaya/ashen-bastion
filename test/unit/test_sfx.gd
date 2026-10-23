extends GutTest
## Sfx: eşzamanlı ses sınırı, en eski kesilir, dosyasız kimlik sessiz, XP çınlaması perde formülü.

var host: Node


func before_each() -> void:
	host = Node.new()
	add_child_autofree(host)
	Sfx.setup(host)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 8000
	wav.data = PackedByteArray([0, 0, 0, 0])
	var long := AudioStreamWAV.new()
	long.format = AudioStreamWAV.FORMAT_8_BITS
	long.mix_rate = 100  # çok yavaş: oynama süresince "playing" kalır
	long.data = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	Sfx.register_stream(&"shot_right", long)
	Sfx.register_stream(&"hit", long)
	Sfx.register_stream(&"ui_click", long)
	Sfx.register_stream(&"yok_dosya", null)


func after_each() -> void:
	Sfx.teardown()
	Sfx.clear_registered()


func test_pool_has_sixteen_players_on_the_sfx_bus() -> void:
	assert_eq(host.get_child_count(), Sfx.POOL_SIZE)
	for c in host.get_children():
		assert_eq((c as AudioStreamPlayer).bus, &"SFX")


func test_per_id_limit_cuts_the_oldest() -> void:
	for i in 8:
		Sfx.play(&"shot_right")
	assert_lte(Sfx.playing_count(&"shot_right"), 4, "shot_* en çok 4")
	Sfx.play(&"hit")
	Sfx.play(&"hit")
	Sfx.play(&"hit")
	Sfx.play(&"hit")
	assert_lte(Sfx.playing_count(&"hit"), 3, "hit en çok 3")


func test_unlisted_ids_use_the_pool_size_as_limit() -> void:
	for i in 40:
		Sfx.play(&"ui_click")
	assert_lte(Sfx.playing_count(&"ui_click"), Sfx.POOL_SIZE)


func test_missing_file_is_silent_and_not_a_stub() -> void:
	Sfx.play(&"yok_dosya")
	Sfx.play(&"hic_yok")
	assert_eq(Sfx.playing_count(&"yok_dosya"), 0)
	assert_eq(Stub.calls().size(), 0)


func test_xp_pitch_formula_and_combo_reset() -> void:
	assert_almost_eq(Sfx.xp_pitch(0), 1.0, 1e-6)
	assert_almost_eq(Sfx.xp_pitch(5), 1.30, 1e-6)
	assert_almost_eq(Sfx.xp_pitch(12), 1.72, 1e-6)
	assert_almost_eq(Sfx.xp_pitch(99), 1.72, 1e-6, "12'de sınırlı")
	var p0 := Sfx.note_pickup(1000)
	var p1 := Sfx.note_pickup(1200)
	var p2 := Sfx.note_pickup(1400)
	assert_almost_eq(p0, 1.0, 1e-6)
	assert_almost_eq(p1, 1.06, 1e-6)
	assert_almost_eq(p2, 1.12, 1e-6)
	var p3 := Sfx.note_pickup(1400 + Sfx.COMBO_WINDOW_MS + 1)
	assert_almost_eq(p3, 1.0, 1e-6, "0,6 sn toplama yoksa sıfırlanır")
