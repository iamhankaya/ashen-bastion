extends GutTest
## AchievementStore (B1): yükleme/kaydetme, temizleme, sınırlar, onarım. Highscores ilkeleriyle aynı davranış.

const PATH := "user://test_ach_store.json"


func after_each() -> void:
	for suffix in ["", ".tmp", ".bad"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _loaded(text: String) -> AchievementStore:
	_write(text)
	var s := AchievementStore.new(PATH)
	s.load_file()
	return s


func test_missing_file_gives_empty_state() -> void:
	var s := AchievementStore.new(PATH)
	assert_false(s.load_file())
	assert_false(s.corrupt)
	assert_eq(s.unlocked.size(), 0)
	assert_eq(s.totals["kills"], 0)
	assert_false(s.dirty)


func test_empty_file_is_corrupt_without_bad() -> void:
	var s := _loaded("")
	assert_true(s.corrupt)
	assert_false(FileAccess.file_exists(PATH + ".bad"))


func test_half_json_is_corrupt_with_bad_backup() -> void:
	var s := _loaded('{"v":1,"unlocked":{"ilk_k')
	assert_true(s.corrupt)
	assert_eq(s.unlocked.size(), 0)
	assert_true(FileAccess.file_exists(PATH + ".bad"))


func test_wrong_version_is_corrupt() -> void:
	var s := _loaded('{"v":2,"unlocked":{"ilk_kan":5}}')
	assert_true(s.corrupt)
	assert_false(s.is_unlocked(&"ilk_kan"))


func test_root_array_is_corrupt() -> void:
	assert_true(_loaded("[1,2,3]").corrupt)


func test_unlocked_wrong_container_type_gives_empty() -> void:
	var s := _loaded('{"v":1,"unlocked":[1,2]}')
	assert_false(s.corrupt)
	assert_eq(s.unlocked.size(), 0)


func test_wrong_typed_negative_nan_fractional_entries_dropped_one_by_one() -> void:
	var s := _loaded(
		'{"v":1,"unlocked":{"a_ok":100,"b_neg":-5,"c_str":"x","d_frac":1.5,"e_zero":0,"f_null":null,"g_bool":true,"h_ok":7}}'
	)
	assert_eq(s.unlocked.keys().size(), 2)
	assert_eq(s.unlocked_at(&"a_ok"), 100)
	assert_eq(s.unlocked_at(&"h_ok"), 7)


func test_bad_id_shapes_dropped() -> void:
	var s := _loaded('{"v":1,"unlocked":{"Büyük":5,"":5,"a b":5,"ok_1":5}}')
	assert_eq(s.unlocked.keys(), [&"ok_1"])
	var long_id := "a".repeat(41)
	var s2 := _loaded('{"v":1,"unlocked":{"%s":5}}' % long_id)
	assert_eq(s2.unlocked.size(), 0, "41 harfli kimlik reddedilir")


func test_counters_negative_and_wrong_type_dropped_defaults_kept() -> void:
	var s := _loaded(
		'{"v":1,"totals":{"kills":-3,"runs":"7","wins":2.5,"play_secs":40},"best":{"score":9}}'
	)
	assert_eq(s.totals["kills"], 0)
	assert_eq(s.totals["runs"], 0)
	assert_eq(s.totals["wins"], 0)
	assert_eq(s.totals["play_secs"], 40)
	assert_eq(s.best["score"], 9)
	assert_eq(s.best["time"], 0, "eksik alan = varsayılan")


func test_counter_cap_clamps_big_values() -> void:
	var s := _loaded('{"v":1,"totals":{"kills":5000000000}}')
	assert_eq(s.totals["kills"], AchievementStore.COUNTER_CAP)


func test_raw_value_above_int_limit_is_dropped_not_clamped() -> void:
	# 1e16 ham değer (INT_LIMIT üstü) atılır; COUNTER_CAP kırpmasından AYRI durum.
	var s := _loaded('{"v":1,"totals":{"kills":10000000000000000}}')
	assert_eq(s.totals["kills"], 0)


func test_unknown_ids_are_preserved_and_roundtrip() -> void:
	var s := _loaded('{"v":1,"unlocked":{"gelecek_basarim":99}}')
	assert_true(s.is_unlocked(&"gelecek_basarim"))
	s.unlock(&"ilk_kan", 5)
	assert_true(s.save())
	var s2 := AchievementStore.new(PATH)
	assert_true(s2.load_file())
	assert_eq(s2.unlocked_at(&"gelecek_basarim"), 99)
	assert_eq(s2.unlocked_at(&"ilk_kan"), 5)


func test_65th_id_rejected_with_sorted_processing() -> void:
	var d := {}
	for i in 70:
		d["k%02d" % i] = 10 + i
	var clean := AchievementStore.sanitize({"unlocked": d})
	assert_eq(clean["unlocked"].size(), 64)
	assert_true(clean["unlocked"].has(&"k00"))
	assert_true(clean["unlocked"].has(&"k63"))
	assert_false(clean["unlocked"].has(&"k64"), "sıralı işleme: ilk 64 korunur")
	# Ekleme sırasına bağımlılık yok.
	var rev := {}
	for i in range(69, -1, -1):
		rev["k%02d" % i] = 10 + i
	assert_eq(
		AchievementStore.sanitize({"unlocked": rev})["unlocked"].keys(), clean["unlocked"].keys()
	)


func test_unlock_refuses_when_full() -> void:
	var s := AchievementStore.new(PATH)
	for i in AchievementStore.MAX_UNLOCKED:
		assert_true(s.unlock(StringName("k%02d" % i), 5))
	assert_false(s.unlock(&"fazla", 5))


func test_chars5_unique_bounded_and_shape_checked() -> void:
	var items: Array = ["a", "a", "B", "c d", 5, "b"]
	for i in 20:
		items.append("x%02d" % i)
	var clean := AchievementStore.sanitize({"chars5": items})
	var c: PackedStringArray = clean["chars5"]
	assert_eq(c.size(), AchievementStore.MAX_CHARS5)
	assert_eq(c[0], "a")
	assert_eq(c[1], "b")
	assert_eq(c.count("a"), 1)
	assert_false(c.has("B"))


func test_note_char5_unique() -> void:
	var s := AchievementStore.new(PATH)
	assert_true(s.note_char5(&"gunslinger"))
	assert_false(s.note_char5(&"gunslinger"))
	assert_true(s.note_char5(&"barutcu"))
	assert_true(s.dirty)


func test_tmp_is_not_read() -> void:
	var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	f.store_string('{"v":1,"unlocked":{"ilk_kan":5}}')
	f.close()
	var s := AchievementStore.new(PATH)
	assert_false(s.load_file())
	assert_false(s.is_unlocked(&"ilk_kan"))


func test_corrupt_file_repaired_by_next_save() -> void:
	var s := _loaded("{bozuk")
	assert_true(s.corrupt)
	s.unlock(&"ilk_kan", 9)
	assert_true(s.save())
	var s2 := AchievementStore.new(PATH)
	assert_true(s2.load_file())
	assert_false(s2.corrupt)
	assert_eq(s2.unlocked_at(&"ilk_kan"), 9)


func test_roundtrip_and_file_layout() -> void:
	var s := AchievementStore.new(PATH)
	s.unlock(&"ilk_kan", 1761270000)
	s.add_total(&"kills", 12)
	s.note_best(100, 200, 3)
	s.note_char5(&"gunslinger")
	assert_true(s.save())
	assert_false(s.dirty)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(d["v"]), 1)
	assert_eq(int(d["unlocked"]["ilk_kan"]), 1761270000)
	assert_eq(int(d["totals"]["kills"]), 12)
	assert_eq(int(d["best"]["score"]), 100)
	assert_eq(d["chars5"], ["gunslinger"])
	assert_lt(FileAccess.get_file_as_string(PATH).length(), 4096)


func test_unwritable_path_save_false_keeps_dirty_and_retries() -> void:
	var s := AchievementStore.new("user://yok_klasor_ach/x.json")
	s.unlock(&"ilk_kan", 5)
	assert_false(s.save())
	assert_true(s.dirty)
	s.path = PATH
	assert_true(s.save(), "sonraki save yeniden dener")
	assert_false(s.dirty)


func test_unlock_zero_or_negative_unix_rejected() -> void:
	var s := AchievementStore.new(PATH)
	assert_false(s.unlock(&"ilk_kan", 0))
	assert_false(s.unlock(&"ilk_kan", -4))
	assert_false(s.is_unlocked(&"ilk_kan"))
	assert_eq(s.unlocked_at(&"ilk_kan"), 0)


func test_second_unlock_keeps_first_unix() -> void:
	var s := AchievementStore.new(PATH)
	assert_true(s.unlock(&"ilk_kan", 100))
	assert_false(s.unlock(&"ilk_kan", 200))
	assert_eq(s.unlocked_at(&"ilk_kan"), 100)


func test_add_total_caps_and_marks_dirty() -> void:
	var s := AchievementStore.new(PATH)
	s.add_total(&"kills", AchievementStore.COUNTER_CAP - 1)
	s.add_total(&"kills", 10)
	assert_eq(s.totals["kills"], AchievementStore.COUNTER_CAP)
	assert_true(s.dirty)


func test_add_total_ignores_unknown_key_and_non_positive() -> void:
	var s := AchievementStore.new(PATH)
	s.add_total(&"yok", 5)
	s.add_total(&"kills", 0)
	s.add_total(&"kills", -3)
	assert_false(s.dirty)
	assert_eq(s.totals["kills"], 0)


func test_note_best_takes_per_field_max() -> void:
	var s := AchievementStore.new(PATH)
	s.note_best(100, 50, 3)
	s.note_best(80, 90, 2)
	assert_eq([s.best["score"], s.best["time"], s.best["level"]], [100, 90, 3])


func test_count_unlocked_only_known() -> void:
	var s := AchievementStore.new(PATH)
	s.unlock(&"a", 1)
	s.unlock(&"gelecek", 1)
	var known: Array[StringName] = [&"a", &"b"]
	assert_eq(s.count_unlocked(known), 1)


func test_sanitize_invalid_root_gives_empty_dict() -> void:
	assert_eq(AchievementStore.sanitize(5), {})
	assert_eq(AchievementStore.sanitize(null), {})
	assert_eq(AchievementStore.sanitize([1]), {})
