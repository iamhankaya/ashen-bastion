extends GutTest
## F-ashen-bastion-177 (2. tur): paralel GUT parçaları Mac'te aynı `user://` dizinini paylaşır (XDG_DATA_HOME etkisiz,
## F-184). Biten parçanın temizliği (SimKit.remove_tmp, koşu sonu kancası UserLeak.remove_own_temp) ortak kökü silerse
## hâlâ koşan parçanın `kit_dev_tmp/<pid>_N` ve `sim_kit_tmp/<etiket>_<pid>_N` dizinleri altından çekilir. Temizlik
## yalnız KENDİ pid'sinin dizinlerini silmeli.

const NEIGHBOR_PID := 999999
const ROOTS: PackedStringArray = ["user://kit_dev_tmp", "user://sim_kit_tmp"]


func _neighbor_dirs() -> PackedStringArray:
	return PackedStringArray(
		[
			"user://kit_dev_tmp/%d_1" % NEIGHBOR_PID,
			"user://sim_kit_tmp/etiket_%d_1" % NEIGHBOR_PID,
		]
	)


func _make_neighbors() -> void:
	for d in _neighbor_dirs():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
		var f := FileAccess.open(d.path_join("x.txt"), FileAccess.WRITE)
		f.store_string("1")
		f.close()


func after_each() -> void:
	# Yalnız bu testin sahte komşu dizinleri (kendi oluşturduğumuz sabit yollar) silinir.
	for d in _neighbor_dirs():
		assert_true(d.contains("_%d_" % NEIGHBOR_PID) or d.contains("/%d_" % NEIGHBOR_PID))
		if DirAccess.dir_exists_absolute(d):
			KitDev.remove_dir(d)


func _assert_neighbors_alive(msg: String) -> void:
	for d in _neighbor_dirs():
		assert_true(FileAccess.file_exists(d.path_join("x.txt")), "%s: %s yerinde" % [msg, d])


func test_sim_kit_remove_tmp_keeps_other_process_dirs() -> void:
	_make_neighbors()
	var own := SimKit.copy_data(SimKit.FIXTURE_DIR, "t177")
	assert_true(DirAccess.dir_exists_absolute(own), "ön koşul: kendi dizinimiz var")
	SimKit.remove_tmp()
	assert_false(DirAccess.dir_exists_absolute(own), "kendi dizinimiz silindi")
	_assert_neighbors_alive("SimKit.remove_tmp")


func test_user_leak_remove_own_temp_keeps_other_process_dirs() -> void:
	_make_neighbors()
	var own_kit := KitDev.data_dir()
	var own_sim := SimKit.copy_data(SimKit.FIXTURE_DIR, "t177b")
	UserLeak.remove_own_temp(OS.get_process_id())
	assert_false(DirAccess.dir_exists_absolute(own_kit), "kendi kit_dev dizinimiz silindi")
	assert_false(DirAccess.dir_exists_absolute(own_sim), "kendi sim_kit dizinimiz silindi")
	_assert_neighbors_alive("UserLeak.remove_own_temp")


func test_user_leak_remove_own_temp_removes_only_given_pid() -> void:
	_make_neighbors()
	UserLeak.remove_own_temp(NEIGHBOR_PID)
	for d in _neighbor_dirs():
		assert_false(DirAccess.dir_exists_absolute(d), "verilen pid'nin dizini silindi: %s" % d)
