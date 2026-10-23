class_name KitDev
extends RefCounted
## Developer test yardımcıları (kit_ öneki: sahip developer). Tester yardımcıları sim_kit.gd / bots.gd'dedir.

const FIXTURES := "res://test/fixtures"
const TMP_ROOT := "user://kit_dev_tmp"

static var _counter: int = 0


## Geçerli fixture'ı yeni bir geçici dizine kopyalar ve overlay varsa üstüne bindirir; yolu döndürür.
## overlay: res:// dizini ya da boş. `<yol>.deleted` dosyası ilgili dosyayı siler.
static func data_dir(overlay: String = "") -> String:
	_counter += 1
	var dest := "%s/%d_%d" % [TMP_ROOT, OS.get_process_id(), _counter]
	copy_dir(FIXTURES + "/data_valid", dest)
	if overlay != "":
		_apply_overlay(overlay, dest, "")
	return dest


## Sözlük {göreli_yol: Variant} yazar (metin ise ham, değilse JSON); `null` değeri dosyayı siler.
static func data_dir_with(files: Dictionary) -> String:
	var dest := data_dir()
	for rel in files.keys():
		var p: String = dest.path_join(rel)
		if files[rel] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string(files[rel] if files[rel] is String else JSON.stringify(files[rel], "  "))
	return dest


static func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func copy_dir(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst))
	for f in DirAccess.get_files_at(src):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		var out := FileAccess.open(dst.path_join(f), FileAccess.WRITE)
		out.store_buffer(FileAccess.get_file_as_bytes(src.path_join(f)))
	for d in DirAccess.get_directories_at(src):
		copy_dir(src.path_join(d), dst.path_join(d))


static func remove_tmp() -> void:
	_remove_recursive(ProjectSettings.globalize_path(TMP_ROOT))


static func _apply_overlay(src: String, dst: String, rel: String) -> void:
	var here := src if rel == "" else src.path_join(rel)
	for f in DirAccess.get_files_at(here):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		var r := f if rel == "" else rel.path_join(f)
		if f.ends_with(".deleted"):
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path(dst.path_join(r.trim_suffix(".deleted")))
			)
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst.path_join(rel)))
		var out := FileAccess.open(dst.path_join(r), FileAccess.WRITE)
		out.store_buffer(FileAccess.get_file_as_bytes(src.path_join(r)))
	for d in DirAccess.get_directories_at(here):
		_apply_overlay(src, dst, d if rel == "" else rel.path_join(d))


static func _remove_recursive(abs_path: String) -> void:
	for f in DirAccess.get_files_at(abs_path):
		DirAccess.remove_absolute(abs_path.path_join(f))
	for d in DirAccess.get_directories_at(abs_path):
		_remove_recursive(abs_path.path_join(d))
		DirAccess.remove_absolute(abs_path.path_join(d))
	DirAccess.remove_absolute(abs_path)


## "ad(arg1,arg2)" imzası: script'in kendi (sınıf) yöntemi için argüman adları; yoksa "".
static func arg_names(script: Script, method: String) -> String:
	for m in script.get_script_method_list():
		if m["name"] == method:
			var names := PackedStringArray()
			for a in m["args"]:
				names.append(a["name"])
			return ",".join(names)
	return "<yok>"


static func return_type(script: Script, method: String) -> int:
	for m in script.get_script_method_list():
		if m["name"] == method:
			return m["return"]["type"]
	return -1


static func has_signal_args(script: Script, sig: String) -> String:
	for s in script.get_script_signal_list():
		if s["name"] == sig:
			var names := PackedStringArray()
			for a in s["args"]:
				names.append(a["name"])
			return ",".join(names)
	return "<yok>"
