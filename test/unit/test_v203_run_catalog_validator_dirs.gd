extends GutTest
## F-ashen-bastion-139: RunCatalogValidator yalnız `run_modes/` varlığına değil, `difficulties/` varlığına da bakar:
## tek başına difficulties/ olan kök sessiz geçmez. İkisi de yoksa (eski fixture kökleri) hâlâ sessiz geçer.

var _dir := ""


func before_each() -> void:
	_dir = "user://rcv_dirs_%d" % OS.get_process_id()
	_cleanup()
	DirAccess.make_dir_recursive_absolute(_dir)


func after_each() -> void:
	_cleanup()


func _cleanup() -> void:
	# Yalnız bu testin kendi user:// kökü silinir (iki düzey: kök + alt dizinler, içlerinde yalnız dosya var).
	assert_true(_dir.begins_with("user://rcv_dirs_"), "silinen yol test köküdür")
	if not DirAccess.dir_exists_absolute(_dir):
		return
	for sub in DirAccess.get_directories_at(_dir):
		var sp := _dir.path_join(sub)
		for f in DirAccess.get_files_at(sp):
			DirAccess.remove_absolute(sp.path_join(f))
		DirAccess.remove_absolute(sp)
	for f in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(f))
	DirAccess.remove_absolute(_dir)


func _validate() -> PackedStringArray:
	var g := GameData.new()
	g.root_dir = _dir
	var out := PackedStringArray()
	RunCatalogValidator.new().run(g, out, true)
	return out


func test_root_with_neither_dir_stays_silent() -> void:
	assert_eq(_validate().size(), 0, "eski fixture kökü: sessiz")


func test_root_with_only_difficulties_dir_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(_dir.path_join("difficulties"))
	var out := _validate()
	assert_gt(out.size(), 0, "yalnız difficulties/ olan kök sessiz geçmemeli")
