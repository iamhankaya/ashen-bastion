extends GutTest
## Kabul (v2.0 ek gruplar): test izolasyonu yardımcıları ve menü etiketi dayanıklılığı. USER_LEAK denetiminin kendisi gate'tedir
## (S3 kanıtı: bilerek sızdıran sahte test kırmızı verdi); burada yardımcının kendi temizlik sözleşmesi sınanır.


func after_each() -> void:
	AchKit.cleanup()


func test_iso_cleanup_removes_file_tmp_bad_and_directories() -> void:
	var p := AchKit.tmp_path("iso")
	AchKit.write_text(p, "{}")
	AchKit.write_text(p + ".tmp", "{}")
	AchKit.write_text(p + ".bad", "{}")
	var d := AchKit.tmp_path("isodir")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d).path_join("ic"))
	AchKit.write_text(d + "/ic/x.json", "{}")
	AchKit.cleanup()
	for q in [p, p + ".tmp", p + ".bad", d]:
		assert_false(
			(
				FileAccess.file_exists(q)
				or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(q))
			),
			q
		)


func test_iso_tmp_paths_are_unique_and_under_test_prefix() -> void:
	var a := AchKit.tmp_path("u")
	var b := AchKit.tmp_path("u")
	assert_ne(a, b)
	assert_true(a.begins_with(AchKit.PREFIX), "gate sözleşmesi: user://test_ach_ öneki")
	assert_false(FileAccess.file_exists(a), "yeni yol boş")


func test_iso_settings_store_path_default_is_restored_by_tests() -> void:
	# Bu dosyadaki testler Settings'e dokunmaz; varsayılan yol değişmemiş olmalı (diğer dosyalar geri alır).
	assert_eq(get_node("/root/Settings").store_path, "user://settings.cfg")


func test_iso_game_data_default_cache_not_mutated_by_acceptance_helpers() -> void:
	var a := GameData.load_default()
	var b := GameData.load_default()
	assert_same(a, b, "önbellek tek örnek")
	assert_eq(a.achievements.size(), 22)
	assert_true(a.character_ids.has(&"zyfen"))


func test_iso_menu_label_shows_character_and_truncates_long_names() -> void:
	var m := MainMenu.new()
	add_child_autofree(m)
	m.set_character_name("Barutçu")
	assert_true(AchKit.any_text_contains(m, "Barutçu"), "alt satır / sürüm etiketi adı gösterir")
	assert_true(AchKit.any_text_contains(m, "Sürüm 2.0.3"), "sürüm satırı (karakter adı yok)")
	m.set_character_name("ışıklı iğneli çok uzun bir karakter adı burada")
	assert_true(AchKit.any_text_contains(m, "…"), "24 harften uzun ad kırpılır")
	assert_false(AchKit.any_text_contains(m, "burada"), "kuyruk görünmez")
	m.set_character_name("İpek Işık")
	assert_true(AchKit.any_text_contains(m, "İpek Işık"), "i/ı bozulmadan")


func test_iso_menu_counter_text() -> void:
	var m := MainMenu.new()
	add_child_autofree(m)
	m.set_achievement_count(8, 22)
	assert_true(AchKit.any_text_contains(m, "8/22"))
	m.set_achievement_count(0, 22)
	assert_true(AchKit.any_text_contains(m, "0/22"))
