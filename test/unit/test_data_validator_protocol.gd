extends GutTest
## R6a: `scripts/sim/validators/` eklenti protokolü (keşif, sıra, hata sırası, bağımlılık sınırı) ve kuru deneme.
## Kuru deneme: test/helpers/validator_fixtures/ altına `extends DataValidator` dosyaları eklendi; hiçbir kayıt
## dosyasına/mevcut koda dokunulmadı, keşif onları buldu.

const FIXTURES := "res://test/helpers/validator_fixtures/"
const REAL_DIR := "res://scripts/sim/validators/"
const BASE_FILE := "data_validator.gd"
const FORBIDDEN_LAYERS := ["ctrl", "ui", "view", "store", "domain", "autoload", "debug", "validate"]


func _ids(found: Array[DataValidator]) -> Array:
	var ids := []
	for v in found:
		ids.append(String(v.validator_id()))
	return ids


func _sources(dir: String) -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out[f] = FileAccess.get_file_as_string(dir.path_join(f))
	return out


func test_discovery_orders_by_order_then_id() -> void:
	var found := GameData._discover_validators(FIXTURES)
	assert_eq(_ids(found), ["z_first", "a", "b"], "order küçük önce, eşitlikte kimlik")


func test_discovery_is_repeatable_across_runs() -> void:
	var first := _ids(GameData._discover_validators(FIXTURES))
	var second := _ids(GameData._discover_validators(FIXTURES))
	assert_eq(first, second, "iki ardışık keşif aynı sırayı verir")


func test_plugin_errors_come_out_in_discovery_order() -> void:
	var g := DataKit.copy()
	var out := PackedStringArray()
	for v in GameData._discover_validators(FIXTURES):
		v.run(g, out, true)
	assert_eq(
		Array(out),
		["[fx] z_first: çalıştı", "[fx] a: çalıştı", "[fx] b: çalıştı complete=true"],
		"hata sırası keşif sırasıdır"
	)


func test_discovery_ignores_classes_outside_the_directory() -> void:
	assert_eq(GameData._discover_validators("res://yok/"), [], "dizin dışı sınıf alınmaz")
	var real := _ids(GameData._discover_validators())
	assert_false(real.has("z_first"), "fixture eklentisi gerçek dizinde görünmez")


func test_base_validator_is_inert_by_default() -> void:
	var out := PackedStringArray()
	var v := DataValidator.new()
	v.run(DataKit.copy(), out, false)
	assert_eq(out.size(), 0)
	assert_eq(v.validator_order(), 1000)
	assert_eq(v.validator_id(), &"")


func test_validators_dir_files_extend_base_and_stay_in_sim_layer() -> void:
	var sources := _sources(REAL_DIR)
	assert_true(sources.has(BASE_FILE), "taban sınıf dosyası var")
	var class_names := []
	for f in sources:
		var src: String = sources[f]
		if f != BASE_FILE:
			assert_true(src.contains("extends DataValidator"), "%s: DataValidator'dan türemeli" % f)
		for layer in FORBIDDEN_LAYERS:
			assert_false(
				src.contains("res://scripts/%s/" % layer), "%s: sim dışı katman: %s" % [f, layer]
			)
		if f == BASE_FILE:
			continue
		for line in src.split("\n"):
			if line.begins_with("class_name "):
				class_names.append(line.trim_prefix("class_name ").strip_edges())
	for f in sources:
		for cn in class_names:
			if f.trim_suffix(".gd") != String(cn).to_snake_case():
				assert_false(
					(sources[f] as String).contains(String(cn)),
					"%s: başka eklentiye bağımlı: %s" % [f, cn]
				)


func test_core_files_do_not_name_plugin_classes() -> void:
	var core: String = FileAccess.get_file_as_string("res://scripts/sim/game_data.gd")
	for f in _sources(REAL_DIR):
		if f == BASE_FILE:
			continue
		for line in (_sources(REAL_DIR)[f] as String).split("\n"):
			if line.begins_with("class_name "):
				var cn := line.trim_prefix("class_name ").strip_edges()
				assert_false(
					core.contains(cn), "game_data.gd eklenti sınıfını adıyla anmaz: %s" % cn
				)
