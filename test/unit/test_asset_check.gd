extends GutTest
## R6b: AssetCheck (validate katmanı) rig şerit doku boyutunu denetler; DataV2._step_int sim içinde StoreIo'suz çalışır.

const TEX := "res://assets/gfx/char/zyfen_portrait.png"


func _probe(path: String, w: int, h: int) -> Dictionary:
	return {"ctx": "zyfen.json rig walk", "path": path, "w": w, "h": h}


func test_matching_size_gives_no_error() -> void:
	var img := (load(TEX) as Texture2D)
	var g := GameData.load_dir("res://data")
	g.strip_probes.append(_probe(TEX, img.get_width(), img.get_height()))
	assert_eq(AssetCheck.validate(g), PackedStringArray())


func test_size_mismatch_reports_bad_type_with_both_sizes() -> void:
	var img := (load(TEX) as Texture2D)
	var g := GameData.load_dir("res://data")
	g.strip_probes.append(_probe(TEX, img.get_width() + 1, img.get_height()))
	var errs := AssetCheck.validate(g)
	assert_eq(errs.size(), 1)
	assert_eq(
		errs[0],
		(
			"[bad_type] zyfen.json rig walk: şerit %dx%d, beklenen %dx%d"
			% [img.get_width(), img.get_height(), img.get_width() + 1, img.get_height()]
		)
	)


func test_validate_resets_probes_each_call() -> void:
	var g := GameData.load_dir("res://data")
	g.validate({}, true)
	var n := g.strip_probes.size()
	assert_gt(n, 0, "gerçek veride şerit denetimi kaydedilir")
	g.validate({}, true)
	assert_eq(g.strip_probes.size(), n, "ikinci çağrı yinelemez")
	assert_eq(AssetCheck.validate(g), PackedStringArray(), "gerçek veri şerit boyutları uyumlu")


func test_step_int_accepts_only_integral_in_range() -> void:
	assert_eq(DataV2._step_int(2), 2)
	assert_eq(DataV2._step_int(2.0), 2)
	for bad in [0, 2.5, "2", true, null, 1000000000, 1.0e30, NAN, INF, -INF]:
		assert_eq(DataV2._step_int(bad), -1, "geçersiz: %s" % str(bad))
