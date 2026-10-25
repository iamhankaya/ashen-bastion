extends GutTest
## Kabul (v2.0.2 K, R): yürüme kalite kapısı + waiver kuralı (plan U2/2 ve tasarım "Kurtarma"). Kapı: `walk.frames > 0` ve
## `art/source/zyfen/quality.json` `pass: true`; ayak kayması: çift başına <= 3 px olan çift sayısı >= N-2; klip yükseklik
## sapması <= %6; `hücre sayısı x hücre genişliği <= 8192`. Sessiz yedek YOK: kapı kırıksa yalnız
## `docs/design/v2.0.2/walk-waiver.md` (VLAD'ın kullanıcıdan aldığı açık onay) testi geçirir. quality.json'a değil, ham ölçümlere
## (strip_manifest.json) ve gerçek şerit görüntüsüne de bakılır: kalite dosyası tek başına kanıt sayılmaz.

const QUALITY := "res://art/source/zyfen/quality.json"
const MANIFEST := "res://art/source/zyfen/strip_manifest.json"
const WAIVER := "res://docs/design/v2.0.2/walk-waiver.md"
const SLIDE_TOL_PX := 3.0
const HEIGHT_TOL_PCT := 6.0
const MAX_TEXTURE := 8192


func _json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _waived() -> bool:
	return FileAccess.file_exists(WAIVER)


func test_r1_walk_cycle_exists_and_quality_gate_passes_unless_explicitly_waived() -> void:
	if V202Slice.require(self, "R"):
		return
	var rig: Dictionary = GameData.load_default().get_character(&"zyfen").rig
	var q := _json(QUALITY)
	assert_false(q.is_empty(), "quality.json okunur")
	var walk_ok := int(rig["walk"]["frames"]) > 0 and bool(q.get("pass", false))
	assert_true(
		walk_ok or _waived(),
		"walk.frames > 0 ve quality.pass; aksi halde walk-waiver.md (VLAD onayı) şart"
	)


func test_r2_quality_checks_are_all_true_and_agree_with_the_raw_measurements() -> void:
	if V202Slice.require(self, "R"):
		return
	var q := _json(QUALITY)
	var m := _json(MANIFEST)
	var checks: Dictionary = q.get("checks", {})
	for k in ["foot_slide", "height_dev", "strip_width"]:
		assert_true(bool(checks.get(k, false)), "quality.checks.%s" % k)
	var errs: Array = m["foot_slide"]["pair_err_px"]
	var ok := 0
	for e in errs:
		ok += 1 if float(e) <= SLIDE_TOL_PX else 0
	assert_gte(
		ok,
		errs.size() - 2,
		"ayak kayması: >= N-2 çift <= 3 px (ham ölçüm %d/%d)" % [ok, errs.size()]
	)
	assert_eq(int(q["foot_slide_ok_pairs"]), ok, "quality.json sayısı ham ölçümle aynı")


func test_r3_clip_height_deviation_is_within_six_percent() -> void:
	if V202Slice.require(self, "R"):
		return
	var dev: Dictionary = _json(MANIFEST)["height_dev_pct"]
	for clip in dev:
		for d in dev[clip]:
			assert_lte(absf(float(d)), HEIGHT_TOL_PCT, "%s klibi yükseklik sapması %s" % [clip, d])


func test_r4_strip_texture_fits_the_device_limit_and_matches_the_rig() -> void:
	if V202Slice.require(self, "R"):
		return
	var rig: Dictionary = GameData.load_default().get_character(&"zyfen").rig
	var img := Image.load_from_file(ProjectSettings.globalize_path(rig["walk"]["strip"]))
	assert_not_null(img, "şerit görüntüsü yüklenir")
	if img == null:
		return
	var cells := RigFrames.total_cells(rig)
	var cell: Array = rig["walk"]["cell"]
	assert_eq(cells, 19, "8 yürüme + 1 duruş + 6 cast + 4 gather")
	assert_lte(img.get_width(), MAX_TEXTURE, "doku genişliği cihaz sınırında")
	assert_eq(img.get_width(), cells * int(cell[0]), "şerit genişliği = hücre x genişlik")
	assert_eq(img.get_height(), int(cell[1]), "şerit yüksekliği = hücre yüksekliği")


func test_r5_every_cell_of_the_strip_has_visible_pixels_and_cells_are_distinct() -> void:
	if V202Slice.require(self, "R"):
		return
	var rig: Dictionary = GameData.load_default().get_character(&"zyfen").rig
	var img := Image.load_from_file(ProjectSettings.globalize_path(rig["walk"]["strip"]))
	var cw := int(rig["walk"]["cell"][0])
	var ch := int(rig["walk"]["cell"][1])
	var sigs := {}
	for c in RigFrames.total_cells(rig):
		var seen := 0
		var h := 0
		for y in range(0, ch, 4):
			for x in range(0, cw, 4):
				var px := img.get_pixel(c * cw + x, y)
				if px.a > 0.5:
					seen += 1
					h = (h * 31 + int(px.r8) * 7 + int(px.g8) * 13 + x * 3 + y) % 2147483647
		assert_gt(seen, 50, "hücre %d boş değil" % c)
		sigs[c] = h
	var uniq := {}
	for c in sigs:
		uniq[sigs[c]] = true
	assert_eq(
		uniq.size(),
		sigs.size(),
		"hiçbir iki hücre birebir aynı değil (döngü kareleri tekrar etmiyor)"
	)


func test_r6_waiver_file_if_present_states_a_date_and_a_reason() -> void:
	if V202Slice.require(self, "R"):
		return
	if not _waived():
		pass_test("waiver yok: kapı doğrudan yeşil olmak zorunda (r1)")
		return
	var t := FileAccess.get_file_as_string(WAIVER)
	assert_true(t.length() > 80, "waiver gerekçe içerir")
	var has_date := false
	for y in ["2026-", "2027-"]:
		has_date = has_date or t.contains(y)
	assert_true(has_date, "waiver onay tarihi içerir")
