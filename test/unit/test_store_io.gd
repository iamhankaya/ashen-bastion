extends GutTest
## StoreIo (B1): sürümlü okuma, boyut tavanı, .bad yedeği, .tmp+rename yazma, güvenli tam sayı.

const PATH := "user://test_ach_storeio.json"


func after_each() -> void:
	for suffix in ["", ".tmp", ".bad"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _write(text: String, path: String = PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_missing_file_is_not_corrupt() -> void:
	var r := StoreIo.read_versioned(PATH, 1)
	assert_false(r["ok"])
	assert_false(r["corrupt"])
	assert_false(FileAccess.file_exists(PATH + ".bad"))


func test_valid_file_reads() -> void:
	_write('{"v":1,"a":2}')
	var r := StoreIo.read_versioned(PATH, 1)
	assert_true(r["ok"])
	assert_false(r["corrupt"])
	assert_eq(int(r["data"]["a"]), 2)


func test_broken_json_is_corrupt_and_kept_as_bad() -> void:
	_write('{"v":1,"a"')
	var r := StoreIo.read_versioned(PATH, 1)
	assert_false(r["ok"])
	assert_true(r["corrupt"])
	assert_eq(FileAccess.get_file_as_string(PATH + ".bad"), '{"v":1,"a"')


func test_wrong_version_root_array_are_corrupt() -> void:
	for text in ['{"v":2}', "[1,2]", '{"x":1}', '{"v":"1"}', '{"v":1.5}']:
		_write(text)
		var r := StoreIo.read_versioned(PATH, 1)
		assert_true(r["corrupt"], text)
		assert_false(r["ok"], text)


func test_empty_content_corrupt_but_not_saved_as_bad() -> void:
	_write("   \n")
	var r := StoreIo.read_versioned(PATH, 1)
	assert_true(r["corrupt"])
	assert_false(FileAccess.file_exists(PATH + ".bad"), "boş içerik saklanmaz")


func test_oversize_file_is_corrupt_without_bad_copy() -> void:
	_write('{"v":1,"pad":"' + "x".repeat(StoreIo.MAX_BYTES) + '"}')
	var r := StoreIo.read_versioned(PATH, 1)
	assert_true(r["corrupt"])
	assert_false(r["ok"])
	assert_false(FileAccess.file_exists(PATH + ".bad"))


func test_tmp_is_never_read() -> void:
	_write('{"v":1}', PATH + ".tmp")
	var r := StoreIo.read_versioned(PATH, 1)
	assert_false(r["ok"])
	assert_false(r["corrupt"])


func test_write_atomic_roundtrip_and_no_tmp_left() -> void:
	assert_true(StoreIo.write_atomic(PATH, '{"v":1}'))
	assert_false(FileAccess.file_exists(PATH + ".tmp"))
	assert_true(StoreIo.read_versioned(PATH, 1)["ok"])


func test_write_atomic_unwritable_path_returns_false() -> void:
	assert_false(StoreIo.write_atomic("user://yok_klasor_ach/x.json", "{}"))


func test_write_atomic_rename_failure_cleans_tmp_and_keeps_old() -> void:
	_write('{"v":1,"old":true}')
	# Hedef bir DİZİN: rename başarısız olur.
	var dir := "user://test_ach_dir_target"
	DirAccess.make_dir_absolute(dir)
	assert_false(StoreIo.write_atomic(dir, '{"v":1}'))
	assert_false(FileAccess.file_exists(dir + ".tmp"), ".tmp temizlenir")
	DirAccess.remove_absolute(dir)
	assert_true(FileAccess.get_file_as_string(PATH).contains("old"), "önceki dosya kalır")


func test_int_of_rules() -> void:
	assert_eq(StoreIo.int_of(5, false), 5)
	assert_eq(StoreIo.int_of(5.0, false), 5)
	assert_null(StoreIo.int_of(5.5, false))
	assert_null(StoreIo.int_of(NAN, false))
	assert_null(StoreIo.int_of(INF, false))
	assert_null(StoreIo.int_of("5", false))
	assert_null(StoreIo.int_of(true, false))
	assert_null(StoreIo.int_of(null, false))
	assert_null(StoreIo.int_of(1.0e16, false))
	assert_eq(StoreIo.int_of(1.0e16, true), int(StoreIo.INT_LIMIT))
	assert_null(StoreIo.int_of(-1.0e16, true))
