extends GutTest
## v2.0.3 sözleşme (C ad alanı): kayıt göçü imzası ve çok sürümlü okuma. `zz` ayırıcısı için test_v203_c_zz_schema.gd'ye bak.

const PATH := "user://test_v203_store.json"


func after_each() -> void:
	for suffix in ["", ".tmp", ".bad"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))


func _write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_read_versioned_any_accepts_listed_versions_and_reports_which() -> void:
	for v in [1, 2]:
		_write('{"v":%d,"unlocked":{}}' % v)
		var r := StoreIo.read_versioned_any(PATH, PackedInt32Array([1, 2]))
		assert_true(r["ok"], "v%d" % v)
		assert_eq(r["version"], v)


func test_read_versioned_any_rejects_unlisted_version_as_corrupt() -> void:
	_write('{"v":3}')
	var r := StoreIo.read_versioned_any(PATH, PackedInt32Array([1, 2]))
	assert_false(r["ok"])
	assert_true(r["corrupt"])
	assert_true(FileAccess.file_exists(PATH + ".bad"), "bozuk içerik .bad olarak saklanır")


func test_read_versioned_any_missing_file_is_not_corrupt() -> void:
	var r := StoreIo.read_versioned_any(PATH, PackedInt32Array([1, 2]))
	assert_false(r["ok"])
	assert_false(r["corrupt"])


func test_read_versioned_still_accepts_only_its_version() -> void:
	_write('{"v":2}')
	assert_false(StoreIo.read_versioned(PATH, 1)["ok"])
	_write('{"v":1}')
	assert_true(StoreIo.read_versioned(PATH, 1)["ok"])


func test_store_declares_v2_constants() -> void:
	assert_eq(AchievementStore.VERSION, 1, "okuma/yazma v2'ye C fazında geçer")
	assert_eq(AchievementStore.VERSION_V2, 2)
	assert_eq(AchievementStore.BACKUP_SUFFIX, ".v1.bak")


func test_migrate_v1_signature_never_mutates_input_and_is_idempotent() -> void:
	var raw := {
		"v": 1,
		"unlocked": {"ilk_kan": 1761270000},
		"totals": {"kills": 5, "runs": 1, "wins": 0, "play_secs": 60},
		"best": {"score": 0, "time": 0, "level": 0},
		"chars5": ["gunslinger"],
	}
	var snapshot := raw.duplicate(true)
	var defs: Array = GameData.load_dir("res://data").achievements
	var once := AchievementStore.migrate_v1(raw, defs)
	assert_eq(raw, snapshot, "girdi değişmez")
	assert_eq(AchievementStore.migrate_v1(once, defs), once, "idempotent")
