extends GutTest
## F-ashen-bastion-177: KitDev.remove_tmp yalnız KENDİ sürecinin geçici dizinlerini siler; paralel (GATE_JOBS>1) başka
## sürecin `kit_dev_tmp/<pid>_N` dizinine dokunmaz (ortak kökü silmek "Couldn't open directory" yarışına yol açıyordu).

const OTHER := "999999_1"


func _other_path() -> String:
	return KitDev.TMP_ROOT.path_join(OTHER)


func after_each() -> void:
	# Yalnız bu testin sahte komşu dizini (kendi oluşturduğumuz yol) silinir.
	assert_true(
		_other_path().begins_with("user://kit_dev_tmp/999999_"), "silinen yol sahte komşudur"
	)
	KitDev.remove_dir(_other_path())
	KitDev.remove_tmp()


func test_remove_tmp_keeps_other_process_dirs_and_removes_own() -> void:
	var own := KitDev.data_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_other_path()))
	var marker := FileAccess.open(_other_path().path_join("x.txt"), FileAccess.WRITE)
	marker.store_string("1")
	marker.close()
	assert_true(DirAccess.dir_exists_absolute(own), "ön koşul: kendi dizinimiz var")
	KitDev.remove_tmp()
	assert_false(DirAccess.dir_exists_absolute(own), "kendi dizinimiz silindi")
	assert_true(
		FileAccess.file_exists(_other_path().path_join("x.txt")), "komşu süreç dizini yerinde"
	)
