extends GutTest
## v2.1 U3 (K dilimi): Highscores v2 biçimi, v1 göçü, .v1.bak kuralları, atomik yazım ve uç durumlar (K-C6).
## Tüm yollar geçici dizindedir (user:// sızıntısı yok); yardımcı dosyalar (.bad/.tmp/.v1.bak) enjekte edilen yoldan türer.

const DIR := "user://v21_k_hs"
const V1 := '{"v":1,"entries":[{"score":900,"time":10,"won":true,"level":2,"unix":5},{"score":400,"time":20,"won":false,"level":3,"unix":6}]}'


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()


func after_all() -> void:
	_clean()
	DirAccess.remove_absolute(DIR)


func _clean() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, f])
	for d in DirAccess.get_directories_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, d])


func _path() -> String:
	return DIR + "/highscores.json"


func _write(text: String, path: String = "") -> void:
	var f := FileAccess.open(path if path != "" else _path(), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(path: String = "") -> String:
	return FileAccess.get_file_as_string(path if path != "" else _path())


func _json(path: String = "") -> Dictionary:
	var j := JSON.new()
	assert_eq(j.parse(_read(path)), OK, "geçerli JSON")
	return j.data


func _e(score: int, unix: int = 1000) -> Dictionary:
	return {"score": score, "time": 60, "won": false, "level": 3, "unix": unix}


func _numbered_baks() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("highscores.json.v1.") and f != "highscores.json.v1.bak":
			out.append(f)
	return out


func _scores(list: Array) -> Array[int]:
	var out: Array[int] = []
	for e in list:
		out.append(int(e["score"]))
	return out


# --- v2 biçimi -------------------------------------------------------------------------------


func test_k1_save_writes_v2_lists_with_mode_and_diff_on_every_entry() -> void:
	var h := Highscores.new(_path())
	h.submit(_e(700).merged({"mode": "quick", "diff": "easy"}))
	h.submit(_e(300))
	assert_true(h.save())
	var raw := _json()
	assert_eq(int(raw["v"]), 2)
	var lists: Dictionary = raw["lists"]
	assert_eq(lists["quick:easy"][0]["mode"], "quick")
	assert_eq(lists["quick:easy"][0]["diff"], "easy")
	assert_eq(lists["normal:normal"][0]["mode"], "normal")
	assert_eq(lists["normal:normal"][0]["diff"], "normal")
	assert_false(FileAccess.file_exists(_path() + ".tmp"), "geçici dosya kalmaz")


func test_k2_v2_roundtrip_keeps_every_list() -> void:
	var h := Highscores.new(_path())
	h.submit(_e(700).merged({"mode": "endless", "diff": "hard"}))
	h.submit(_e(300).merged({"mode": "quick", "diff": "easy"}))
	h.submit(_e(100))
	assert_true(h.save())
	var back := Highscores.new(_path())
	assert_true(back.load_file())
	assert_eq(_scores(back.list_for(&"endless", &"hard")), [700] as Array[int])
	assert_eq(_scores(back.list_for(&"quick", &"easy")), [300] as Array[int])
	assert_eq(_scores(back.entries), [100] as Array[int])
	assert_eq(back.list_for(&"normal", &"hard").size(), 0)
	assert_eq(_numbered_baks().size(), 0, "v2 dosya yedek üretmez")
	assert_false(FileAccess.file_exists(_path() + ".v1.bak"))


func test_k3_valid_v2_without_lists_content_loads_true_and_empty() -> void:
	_write('{"v":2,"lists":{}}')
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_false(h.corrupt)
	assert_eq(h.entries.size(), 0)


# --- v1 göçü ---------------------------------------------------------------------------------


func test_k4_v1_migrates_to_normal_normal_and_writes_v2_with_backup() -> void:
	_write(V1)
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_eq(_scores(h.entries), [900, 400] as Array[int])
	assert_eq(_scores(h.list_for(&"normal", &"normal")), [900, 400] as Array[int])
	assert_eq(_read(_path() + ".v1.bak"), V1, "yedek v1 baytlarının aynısı")
	var raw := _json()
	assert_eq(int(raw["v"]), 2)
	assert_eq(_scores(raw["lists"]["normal:normal"]), [900, 400] as Array[int])
	assert_false(FileAccess.file_exists(_path() + ".tmp"))


func test_k5_existing_v1_bak_is_never_overwritten() -> void:
	_write("eski yedek", _path() + ".v1.bak")
	_write(V1)
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_eq(_read(_path() + ".v1.bak"), "eski yedek", "var olan yedek korunur")
	var baks := _numbered_baks()
	assert_eq(baks.size(), 1, "numaralı yedek açılır: %s" % [baks])
	assert_true(baks[0].ends_with(".bak"))
	assert_eq(_read(DIR + "/" + baks[0]), V1)
	assert_eq(int(_json()["v"]), 2)


func test_k6_backup_failure_cancels_migration_and_leaves_v1_untouched() -> void:
	_write(V1)
	# Yedeğin .tmp'si dizin: yedek yazılamaz (K-C6 2).
	DirAccess.make_dir_recursive_absolute(_path() + ".v1.bak.tmp")
	var h := Highscores.new(_path())
	assert_true(h.load_file(), "oturum belleğinde çalışır")
	assert_eq(_scores(h.entries), [900, 400] as Array[int])
	assert_eq(_read(), V1, "v1 dosyası dokunulmaz")
	assert_false(FileAccess.file_exists(_path() + ".v1.bak"))
	h.submit(_e(50))
	assert_false(h.save(), "göç iptalinde v2 yazılmaz")
	assert_eq(_read(), V1, "save sonrası da v1 sağlam")
	DirAccess.remove_absolute(_path() + ".v1.bak.tmp")
	var retry := Highscores.new(_path())
	assert_true(retry.load_file())
	assert_eq(int(_json()["v"]), 2, "sonraki açılışta göç yeniden denenir")
	assert_eq(_scores(retry.entries), [900, 400] as Array[int])


func test_k7_v2_write_failure_keeps_v1_intact_and_retries_next_load() -> void:
	_write(V1)
	# Ana dosyanın .tmp'si dizin: v2 yazılamaz, yedek ise yazılır.
	DirAccess.make_dir_recursive_absolute(_path() + ".tmp")
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_eq(_scores(h.entries), [900, 400] as Array[int], "bellekte göç edilmiş")
	assert_eq(_read(), V1, "v1 dosyası sağlam")
	assert_eq(_read(_path() + ".v1.bak"), V1)
	DirAccess.remove_absolute(_path() + ".tmp")
	var retry := Highscores.new(_path())
	assert_true(retry.load_file())
	assert_eq(int(_json()["v"]), 2)
	assert_eq(_read(_path() + ".v1.bak"), V1, "ilk yedek yerinde")
	assert_eq(_numbered_baks().size(), 0, "aynı v1 için yeni yedek açılmaz")


func test_k8_v1_mixed_valid_and_invalid_entries_keep_valid_ones_only() -> void:
	_write(
		(
			'{"v":1,"entries":['
			+ '{"score":900,"time":10,"won":true,"level":2,"unix":5},'
			+ '{"score":"x","time":10,"won":true,"level":2,"unix":5},'
			+ '{"score":-5,"time":10,"won":true,"level":2,"unix":5},'
			+ '"junk",'
			+ '{"score":400,"time":20,"won":false,"level":3,"unix":6}'
			+ "]}"
		)
	)
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_eq(_scores(h.entries), [900, 400] as Array[int])
	assert_eq(_scores(_json()["lists"]["normal:normal"]), [900, 400] as Array[int])


func test_k9_empty_v1_still_migrates_without_error() -> void:
	_write('{"v":1,"entries":[]}')
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_false(h.corrupt)
	assert_eq(int(_json()["v"]), 2)


# --- bozuk / uç dosyalar ---------------------------------------------------------------------


func test_k10_bad_variants_keep_bad_copy_and_load_empty() -> void:
	var variants := [
		"{bozuk",
		'{"v":"2","lists":{}}',
		'{"v":3,"lists":{}}',
		'{"v":2}',
		'{"v":2,"lists":[]}',
		'{"v":2,"entries":[]}',
		'{"lists":{}}',
		"[1,2]",
	]
	for text in variants:
		_clean()
		_write(text)
		var h := Highscores.new(_path())
		assert_false(h.load_file(), "false: '%s'" % text)
		assert_true(h.corrupt, "corrupt: '%s'" % text)
		assert_eq(h.entries.size(), 0)
		assert_eq(_read(_path() + ".bad"), text, ".bad özgün: '%s'" % text)
		assert_false(FileAccess.file_exists(_path() + ".v1.bak"), "bozukta yedek yok")
		h.submit(_e(7))
		assert_true(h.save(), "sonraki kayıt onarır: '%s'" % text)
		assert_eq(int(_json()["v"]), 2)


func test_k11_list_key_is_authoritative_over_entry_fields() -> void:
	_write(
		(
			'{"v":2,"lists":{"quick:easy":['
			+ '{"score":50,"time":1,"won":false,"level":1,"unix":1,"mode":"endless","diff":"hard"},'
			+ '{"score":40,"time":1,"won":false,"level":1,"unix":1}'
			+ "]}}"
		)
	)
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_eq(_scores(h.list_for(&"quick", &"easy")), [50, 40] as Array[int])
	assert_eq(h.list_for(&"endless", &"hard").size(), 0, "giriş alanı listeyi değiştirmez")
	assert_true(h.save())
	for e in _json()["lists"]["quick:easy"]:
		assert_eq(e["mode"], "quick")
		assert_eq(e["diff"], "easy")


func test_k12_unknown_list_keys_are_preserved_across_save() -> void:
	_write(
		(
			'{"v":2,"lists":{"normal:normal":[{"score":5,"time":1,"won":false,"level":1,"unix":1}],'
			+ '"ultra:normal":[{"score":9,"time":1,"won":false,"level":1,"unix":1}],'
			+ '"quick:impossible":[1,2,3],"bozuk":"x"}}'
		)
	)
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_eq(h.list_for(&"ultra", &"normal").size(), 0, "gösterilmez")
	h.submit(_e(77))
	assert_true(h.save())
	var lists: Dictionary = _json()["lists"]
	assert_eq(lists["ultra:normal"][0]["score"], 9)
	assert_eq(lists["quick:impossible"], [1, 2, 3])
	assert_eq(lists["bozuk"], "x")
	assert_eq(_scores(lists["normal:normal"]), [77, 5] as Array[int])


func test_k13_more_than_ten_entries_are_trimmed_with_stable_ties() -> void:
	var items: Array = []
	for i in 12:
		items.append({"score": 100, "time": 1, "won": false, "level": 1, "unix": 50 + i, "id": i})
	items.append({"score": 100, "time": 1, "won": false, "level": 1, "unix": 10})
	_write(JSON.stringify({"v": 2, "lists": {"normal:hard": items}}))
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	var list := h.list_for(&"normal", &"hard")
	assert_eq(list.size(), 10)
	assert_eq(int(list[0]["unix"]), 10, "eşit skorda eski önde")
	assert_eq(int(list[1]["unix"]), 50)
	assert_eq(int(list[9]["unix"]), 58)


func test_k14_missing_negative_and_huge_numbers_are_sanitized() -> void:
	_write(
		(
			'{"v":2,"lists":{"endless:easy":['
			+ '{"score":999999999999,"time":9,"won":true,"level":1,"unix":3},'
			+ '{"score":10,"time":-1,"won":true,"level":1,"unix":3},'
			+ '{"score":10,"won":true,"level":1,"unix":3},'
			+ '{"score":10,"time":1,"won":true,"level":1e30,"unix":3},'
			+ '{"score":20,"time":1,"won":false,"level":1,"unix":3}'
			+ "]}}"
		)
	)
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_eq(_scores(h.list_for(&"endless", &"easy")), [99_999_999, 20] as Array[int])


func test_k15_non_array_known_list_loads_empty_without_crash() -> void:
	_write('{"v":2,"lists":{"quick:hard":5,"normal:easy":{"a":1}}}')
	var h := Highscores.new(_path())
	assert_true(h.load_file())
	assert_eq(h.list_for(&"quick", &"hard").size(), 0)
	assert_eq(h.list_for(&"normal", &"easy").size(), 0)


func test_k16_helper_files_derive_from_injected_path() -> void:
	var p := DIR + "/baska.json"
	_write(V1, p)
	var h := Highscores.new(p)
	assert_true(h.load_file())
	assert_true(FileAccess.file_exists(p + ".v1.bak"))
	assert_false(FileAccess.file_exists(DIR + "/highscores.json.v1.bak"))


func test_k17_save_failure_keeps_previous_valid_v2_file() -> void:
	var h := Highscores.new(_path())
	h.submit(_e(321))
	assert_true(h.save())
	DirAccess.make_dir_recursive_absolute(_path() + ".tmp")
	h.submit(_e(999))
	assert_false(h.save())
	DirAccess.remove_absolute(_path() + ".tmp")
	var back := Highscores.new(_path())
	assert_true(back.load_file())
	assert_eq(_scores(back.entries), [321] as Array[int])
