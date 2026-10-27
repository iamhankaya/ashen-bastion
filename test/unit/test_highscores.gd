extends GutTest
## Highscores: sıralama, rekor bilgisi, sanitize, bozuk/eksik/yarım dosya, atomik yazma, tarih.

const DIR := "user://hs_test"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()


func after_all() -> void:
	_clean()
	DirAccess.remove_absolute(DIR)


func _clean() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, f])


func _path() -> String:
	return DIR + "/highscores.json"


func _write(text: String, path: String = "") -> void:
	var f := FileAccess.open(path if path != "" else _path(), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _e(
	score: int, unix: int = 1000, won: bool = false, time: int = 60, level: int = 3
) -> Dictionary:
	return {
		"score": score,
		"time": time,
		"won": won,
		"level": level,
		"unix": unix,
		"mode": "normal",
		"diff": "normal",
	}


func test_missing_file_gives_empty_list_and_false() -> void:
	var h := Highscores.new(_path())
	assert_false(h.load_file())
	assert_eq(h.entries.size(), 0)
	assert_false(h.corrupt, "dosya yok bozuk sayılmaz")


func test_first_score_is_record_rank_1() -> void:
	var h := Highscores.new(_path())
	var r := h.submit(_e(500))
	assert_eq(r["rank"], 1)
	assert_true(r["is_record"])
	assert_eq(r["previous_best"], 0)
	assert_eq(r["needed_for_top10"], 0)
	assert_eq(r["index"], 0)


func test_zero_or_negative_score_is_not_recorded() -> void:
	var h := Highscores.new(_path())
	var r := h.submit(_e(0))
	assert_eq(r["rank"], 0)
	assert_false(r["is_record"])
	assert_eq(h.entries.size(), 0)
	r = h.submit(_e(-5))
	assert_eq(r["rank"], 0)
	assert_eq(h.entries.size(), 0)


func test_sorted_descending_and_tie_older_first() -> void:
	var h := Highscores.new(_path())
	h.submit(_e(100, 10))
	h.submit(_e(300, 20))
	h.submit(_e(100, 5))  # eşit skor, daha eski unix -> öne geçer
	h.submit(_e(200, 30))
	var scores: Array = []
	for e in h.entries:
		scores.append([e["score"], e["unix"]])
	assert_eq(scores, [[300, 20], [200, 30], [100, 5], [100, 10]])


func test_tie_with_equal_unix_keeps_insertion_order() -> void:
	var h := Highscores.new(_path())
	var a := _e(100, 10, false, 1)
	var b := _e(100, 10, false, 2)
	h.submit(a)
	h.submit(b)
	assert_eq(h.entries[0]["time"], 1)
	assert_eq(h.entries[1]["time"], 2)


func test_new_tie_with_current_best_is_not_a_record() -> void:
	var h := Highscores.new(_path())
	h.submit(_e(100, 10))
	var r := h.submit(_e(100, 20))
	assert_eq(r["rank"], 2)
	assert_false(r["is_record"], "eşitlikte eski önde: rekor değil")
	assert_eq(r["previous_best"], 100)


func test_rank_and_previous_best_when_beating_the_best() -> void:
	var h := Highscores.new(_path())
	h.submit(_e(100, 1))
	h.submit(_e(50, 2))
	var r := h.submit(_e(400, 3))
	assert_eq(r["rank"], 1)
	assert_true(r["is_record"])
	assert_eq(r["previous_best"], 100)
	assert_eq(r["index"], 0)


func test_eleventh_entry_drops_the_lowest() -> void:
	var h := Highscores.new(_path())
	for i in 10:
		h.submit(_e(1000 + i * 100, i))
	assert_eq(h.entries.size(), 10)
	var r := h.submit(_e(50, 99))
	assert_eq(r["rank"], 0, "10 dolu ve en düşükten düşük: dışarıda")
	assert_eq(r["needed_for_top10"], 1000)
	assert_eq(h.entries.size(), 10)
	r = h.submit(_e(5000, 100))
	assert_eq(r["rank"], 1)
	assert_eq(h.entries.size(), 10)
	assert_eq(h.entries[9]["score"], 1100, "en düşük (1000) atıldı")


func test_needed_for_top10_zero_when_fewer_than_ten() -> void:
	var h := Highscores.new(_path())
	for i in 9:
		h.submit(_e(100 + i, i))
	var r := h.submit(_e(1, 50))
	assert_eq(r["needed_for_top10"], 0)
	assert_eq(r["rank"], 10)


func test_save_load_roundtrip_and_file_shape() -> void:
	var h := Highscores.new(_path())
	h.submit(_e(700, 1_700_000_000, true, 1200, 14))
	h.submit(_e(300, 1_700_000_100, false, 90, 4))
	assert_true(h.save())
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	assert_eq(int(raw["v"]), 2)
	var list: Array = raw["lists"]["normal:normal"]
	assert_eq(list.size(), 2)
	var first: Dictionary = list[0]
	assert_eq(first.keys().size(), 7)
	for k in ["score", "time", "won", "level", "unix", "mode", "diff"]:
		assert_true(first.has(k), k)
	var h2 := Highscores.new(_path())
	assert_true(h2.load_file())
	assert_eq(h2.entries, h.entries)
	assert_false(FileAccess.file_exists(_path() + ".tmp"), "geçici dosya kalmaz")


func test_corrupt_json_gives_empty_keeps_bad_and_next_save_repairs() -> void:
	_write("{this is not json")
	var h := Highscores.new(_path())
	assert_false(h.load_file())
	assert_true(h.corrupt)
	assert_eq(h.entries.size(), 0)
	assert_true(FileAccess.file_exists(_path() + ".bad"))
	assert_eq(FileAccess.get_file_as_string(_path() + ".bad"), "{this is not json")
	h.submit(_e(10))
	assert_true(h.save())
	var h2 := Highscores.new(_path())
	assert_true(h2.load_file())
	assert_eq(h2.entries.size(), 1)


func test_bad_variants_all_load_empty() -> void:
	var variants := [
		"",
		"   ",
		"[1,2,3]",
		"42",
		"null",
		'{"v":2,"entries":[{"score":5,"time":1,"won":true,"level":1,"unix":1}]}',
		'{"entries":[]}',
		'{"v":1}',
		'{"v":1,"entries":{"a":1}}',
		'{"v":"1","entries":[]}',
		'{"v":1,"entries":[',
	]
	for text in variants:
		_write(text)
		var h := Highscores.new(_path())
		var ok := h.load_file()
		assert_eq(h.entries.size(), 0, "boş liste: '%s'" % text)
		if text.strip_edges() != "" and not text.begins_with('{"v":1,"entries":[]'):
			assert_false(ok, "false döner: '%s'" % text)
		h.submit(_e(1))
		assert_true(h.save(), "sonraki kayıt onarır: '%s'" % text)
		var chk := Highscores.new(_path())
		assert_true(chk.load_file())
		assert_eq(chk.entries.size(), 1)


func test_single_bad_entry_is_dropped_others_kept() -> void:
	_write(
		(
			'{"v":1,"entries":['
			+ '{"score":900,"time":10,"won":true,"level":2,"unix":5},'
			+ '{"score":"x","time":10,"won":true,"level":2,"unix":5},'
			+ '{"score":-5,"time":10,"won":true,"level":2,"unix":5},'
			+ '{"time":10,"won":true,"level":2,"unix":5},'
			+ '"junk",'
			+ '{"score":100,"time":10,"won":"evet","level":2,"unix":5},'
			+ '{"score":400,"time":20,"won":false,"level":3,"unix":6}'
			+ "]}"
		)
	)
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_eq(h.entries.size(), 2)
	assert_eq(h.entries[0]["score"], 900)
	assert_eq(h.entries[1]["score"], 400)
	assert_false(h.corrupt)


func test_sanitize_caps_score_sorts_and_limits_to_10() -> void:
	var raw: Array = []
	for i in 14:
		raw.append(_e(100 + i, i))
	raw.append(_e(999_999_999_999, 77))
	var out := Highscores.sanitize({"v": 1, "entries": raw})
	assert_eq(out.size(), 10)
	assert_eq(out[0]["score"], 99_999_999, "display_cap ile kırpılır")
	assert_eq(out[1]["score"], 113)


func test_sanitize_accepts_float_ints_and_rejects_nan_and_garbage() -> void:
	var out := (
		Highscores
		. sanitize(
			{
				"v": 1,
				"entries":
				[
					{"score": 50.0, "time": 3.0, "won": false, "level": 1.0, "unix": 9.0},
					{"score": 50.5, "time": 3, "won": false, "level": 1, "unix": 9},
					{"score": NAN, "time": 3, "won": false, "level": 1, "unix": 9},
				]
			}
		)
	)
	assert_eq(out.size(), 1)
	assert_eq(out[0]["score"], 50)
	assert_eq(typeof(out[0]["score"]), TYPE_INT)
	assert_eq(Highscores.sanitize("nope").size(), 0)
	assert_eq(Highscores.sanitize(null).size(), 0)
	assert_eq(Highscores.sanitize({"v": 1, "entries": 5}).size(), 0)


func test_partial_tmp_file_is_ignored_on_load() -> void:
	var h := Highscores.new(_path())
	h.submit(_e(123))
	assert_true(h.save())
	_write('{"v":1,"entries":[{"sco', _path() + ".tmp")
	var h2 := Highscores.new(_path())
	assert_true(h2.load_file())
	assert_eq(h2.entries.size(), 1)
	assert_eq(h2.entries[0]["score"], 123)


func test_stale_tmp_does_not_block_next_save() -> void:
	_write("yarım", _path() + ".tmp")
	var h := Highscores.new(_path())
	h.submit(_e(77))
	assert_true(h.save())
	assert_false(FileAccess.file_exists(_path() + ".tmp"))
	var h2 := Highscores.new(_path())
	assert_true(h2.load_file())
	assert_eq(h2.entries[0]["score"], 77)


func test_unwritable_path_returns_false_without_crash() -> void:
	var h := Highscores.new("user://yok_dizin_x/alt/highscores.json")
	h.submit(_e(5))
	assert_false(h.save())
	assert_eq(h.entries.size(), 1, "bellekteki liste korunur")


func test_second_bad_file_overwrites_single_bad_backup() -> void:
	_write("bozuk1")
	Highscores.new(_path()).load_file()
	_write("bozuk2")
	Highscores.new(_path()).load_file()
	assert_eq(FileAccess.get_file_as_string(_path() + ".bad"), "bozuk2")


func test_better_orders_by_score_then_older() -> void:
	assert_true(Highscores.better(_e(200, 50), _e(100, 1)))
	assert_false(Highscores.better(_e(100, 1), _e(200, 50)))
	assert_true(Highscores.better(_e(100, 1), _e(100, 2)))
	assert_false(Highscores.better(_e(100, 2), _e(100, 1)))
	assert_false(Highscores.better(_e(100, 1), _e(100, 1)), "tam eşit: kararlı, öne geçmez")


func test_format_date_applies_timezone_bias() -> void:
	# 1_700_000_000 = 2023-11-14 22:13:20 UTC; +180 dk -> 15.11.2023 01:13
	assert_eq(Highscores.format_date(1_700_000_000, 180), "15.11.2023")
	assert_eq(Highscores.format_date(1_700_000_000, 0), "14.11.2023")
	assert_eq(Highscores.format_date(1_700_000_000, -300), "14.11.2023")
	assert_eq(Highscores.format_date(0, 0), "01.01.1970")
	assert_eq(Highscores.format_date(0, -60), "31.12.1969")


func test_failed_save_keeps_previous_valid_file() -> void:
	var h := Highscores.new(_path())
	h.submit(_e(321))
	assert_true(h.save())
	# rename hedefi dolu bir dizin: rename başarısız olur, önceki dosya ve içerik korunur
	var blocked := Highscores.new(DIR + "/blocked")
	DirAccess.make_dir_recursive_absolute(DIR + "/blocked")
	blocked.submit(_e(1))
	assert_false(blocked.save())
	assert_false(FileAccess.file_exists(DIR + "/blocked.tmp"), "geçici dosya temizlenir")
	var h2 := Highscores.new(_path())
	assert_true(h2.load_file())
	assert_eq(h2.entries[0]["score"], 321)
	DirAccess.remove_absolute(DIR + "/blocked")
