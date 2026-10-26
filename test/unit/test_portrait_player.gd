extends GutTest
## PortraitPlayer (v2.0.3 A): hareketli portre yalnız hareket serbestse ve video yüklenebiliyorsa görünür; aksi halde sessizce
## statik portreye düşer.

const OGV := "res://assets/video/portrait/zyfen.ogv"

var _p: PortraitPlayer


func before_each() -> void:
	_p = PortraitPlayer.new()
	add_child_autofree(_p)


func test_starts_hidden_and_idle() -> void:
	assert_false(_p.visible)
	assert_false(_p.is_playing())
	assert_true(_p.loop, "döngü")


func test_reduced_motion_never_loads_or_plays() -> void:
	assert_false(_p.show_source(OGV, true))
	assert_null(_p.stream)
	assert_false(_p.visible)
	assert_false(_p.is_playing())


func test_empty_or_missing_path_falls_back() -> void:
	assert_false(_p.show_source("", false))
	assert_false(_p.show_source("res://assets/video/portrait/yok.ogv", false))
	assert_null(_p.stream)
	assert_false(_p.visible)


func test_valid_source_plays_looped_and_clears_when_reduced_later() -> void:
	assert_true(_p.show_source(OGV, false))
	assert_not_null(_p.stream)
	assert_true(_p.is_playing())
	assert_true(_p.loop)
	_p.show_source(OGV, true)  # hareket azalt sonradan açıldı
	assert_false(_p.is_playing())
	assert_false(_p.visible)
	assert_null(_p.stream)


func test_undecodable_stream_gives_up_after_timeout_and_signals_failed() -> void:
	var f := FileAccess.open("user://bozuk_portre.ogv", FileAccess.WRITE)
	f.store_string("bu bir video degil")
	f.close()
	watch_signals(_p)
	_p.show_source("user://bozuk_portre.ogv", false)
	assert_engine_error("has no video stream")  # motor hatası beklenen: oynatıcı bunu sessizce statik portreye çevirir
	_p._process(PortraitPlayer.START_TIMEOUT_SEC + 0.1)
	assert_false(_p.visible, "bozuk akış gösterilmez")
	assert_null(_p.stream)
	assert_signal_emitted(_p, "failed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bozuk_portre.ogv"))
