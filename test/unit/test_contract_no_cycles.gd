extends GutTest
## Sözleşme: `extends` ve `preload` zincirlerinde döngü yok; scripts/ ve tools/ altındaki tüm .gd derlenir.
## (Tür ek açıklamalarındaki class_name başvuruları Godot'ta döngü sayılmaz; derleme bunu doğrular.)

const ROOTS: Array[String] = ["res://scripts", "res://tools"]


func _gd_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)


func _all() -> Array[String]:
	var out: Array[String] = []
	for r in ROOTS:
		_gd_files(r, out)
	out.sort()
	return out


func test_every_script_loads() -> void:
	var files := _all()
	assert_gt(files.size(), 30)
	for f in files:
		var s: Variant = load(f)
		assert_not_null(s, "%s yüklenemedi" % f)


func test_no_extends_or_preload_cycles() -> void:
	# graf: dosya -> {preload yolları, extends ile başvurulan class_name'in dosyası}
	var class_path := {}
	for c in ProjectSettings.get_global_class_list():
		class_path[c["class"]] = c["path"]
	var graph := {}
	var rx_pre := RegEx.create_from_string('preload\\("(res://[^"]+\\.gd)"\\)')
	var rx_ext := RegEx.create_from_string("(?m)^extends\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*$")
	for f in _all():
		var text := FileAccess.get_file_as_string(f)
		var deps: Array[String] = []
		for m in rx_pre.search_all(text):
			deps.append(m.get_string(1))
		var e := rx_ext.search(text)
		if e != null and class_path.has(e.get_string(1)):
			deps.append(class_path[e.get_string(1)])
		graph[f] = deps
	for f in graph.keys():
		var cyc := _find_cycle(graph, f, [])
		assert_eq(cyc.size(), 0, "döngü: %s" % [cyc])


func _find_cycle(graph: Dictionary, node: String, path: Array) -> Array:
	if node in path:
		return path + [node]
	if not graph.has(node):
		return []
	var next_path := path + [node]
	for d in graph[node]:
		var c := _find_cycle(graph, d, next_path)
		if c.size() > 0:
			return c
	return []
