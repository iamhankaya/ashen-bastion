extends GutTest
## Kabul (v2.0.2 K, R): yürüme kalite kapısı + waiver kuralı (plan U2/2 ve tasarım "Kurtarma"). Her kolsuz (`rig.armless`) karakter
## için: `walk.frames > 0` ve `art/source/<id>/quality.json` `pass: true`; ayak kayması: çift başına <= 3 px olan çift sayısı >= N-2;
## klip yükseklik sapması <= %6; `hücre sayısı x hücre genişliği <= 8192`. Sessiz yedek YOK: kapı kırıksa yalnız waiver dosyası
## (VLAD'ın kullanıcıdan aldığı açık onay) testi geçirir: `docs/design/walk-waiver-<id>.md` (zyfen için eski yol
## `docs/design/v2.0.2/walk-waiver.md`). quality.json'a değil, ham ölçümlere (strip_manifest.json) ve gerçek şerit görüntüsüne de
## bakılır: kalite dosyası tek başına kanıt sayılmaz.

const SLIDE_TOL_PX := 3.0
const HEIGHT_TOL_PCT := 6.0
const MAX_TEXTURE := 8192
const LEGACY_WAIVERS := {&"zyfen": "res://docs/design/v2.0.2/walk-waiver.md"}
## id -> [hücre sayısı] (zyfen: 8 yürüme + 1 duruş + 6 cast + 4 gather)
const PINNED_CELLS := {&"zyfen": 19}

var _rigs: Dictionary = {}
## id -> art/source sahibi (AccV202.art_owner): veri-yalnız karakter paylaşılan şeridin sahibine bakar
var _owner: Dictionary = {}


func before_all() -> void:
	var data := GameData.load_default()
	for id in data.character_ids:
		var c := data.get_character(id)
		if c.armless:
			_rigs[id] = c.rig
			_owner[id] = AccV202.art_owner(id, c.rig)


func _json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _quality(id: StringName) -> Dictionary:
	return _json("res://art/source/%s/quality.json" % _owner.get(id, id))


func _manifest(id: StringName) -> Dictionary:
	return _json("res://art/source/%s/strip_manifest.json" % _owner.get(id, id))


func _waiver_path(id: StringName) -> String:
	var o: StringName = _owner.get(id, id)
	return LEGACY_WAIVERS.get(o, "res://docs/design/walk-waiver-%s.md" % o)


func _waived(id: StringName) -> bool:
	return FileAccess.file_exists(_waiver_path(id))


func test_r0_there_is_an_armless_character() -> void:
	if V202Slice.require(self, "R"):
		return
	assert_true(_rigs.has(&"zyfen"), "zyfen kolsuz rig")


func test_r1_walk_cycle_exists_and_quality_gate_passes_unless_explicitly_waived() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var q := _quality(id)
		assert_false(q.is_empty(), "%s: quality.json okunur" % id)
		var walk_ok := int(_rigs[id]["walk"]["frames"]) > 0 and bool(q.get("pass", false))
		assert_true(
			walk_ok or _waived(id),
			(
				"%s: walk.frames > 0 ve quality.pass; aksi halde %s (VLAD onayı) şart"
				% [id, _waiver_path(id)]
			)
		)


func test_r2_quality_checks_are_all_true_and_agree_with_the_raw_measurements() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var q := _quality(id)
		var m := _manifest(id)
		var checks: Dictionary = q.get("checks", {})
		for k in ["foot_slide", "height_dev", "strip_width"]:
			assert_true(bool(checks.get(k, false)), "%s quality.checks.%s" % [id, k])
		var errs: Array = m["foot_slide"]["pair_err_px"]
		var ok := 0
		for e in errs:
			ok += 1 if float(e) <= SLIDE_TOL_PX else 0
		assert_gte(
			ok,
			errs.size() - 2,
			"%s ayak kayması: >= N-2 çift <= 3 px (ham ölçüm %d/%d)" % [id, ok, errs.size()]
		)
		assert_eq(int(q["foot_slide_ok_pairs"]), ok, "%s quality.json sayısı ham ölçümle aynı" % id)


func test_r3_clip_height_deviation_is_within_six_percent() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var dev: Dictionary = _manifest(id)["height_dev_pct"]
		for clip in dev:
			for d in dev[clip]:
				assert_lte(
					absf(float(d)),
					HEIGHT_TOL_PCT,
					"%s %s klibi yükseklik sapması %s" % [id, clip, d]
				)


func test_r4_strip_texture_fits_the_device_limit_and_matches_the_rig() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var rig: Dictionary = _rigs[id]
		var img := Image.load_from_file(ProjectSettings.globalize_path(rig["walk"]["strip"]))
		assert_not_null(img, "%s şerit görüntüsü yüklenir" % id)
		if img == null:
			continue
		var cells := RigFrames.total_cells(rig)
		var cell: Array = rig["walk"]["cell"]
		if PINNED_CELLS.has(id):
			assert_eq(cells, PINNED_CELLS[id], "%s sabit hücre sayısı" % id)
		assert_lte(img.get_width(), MAX_TEXTURE, "%s doku genişliği cihaz sınırında" % id)
		assert_eq(
			img.get_width(), cells * int(cell[0]), "%s şerit genişliği = hücre x genişlik" % id
		)
		assert_eq(img.get_height(), int(cell[1]), "%s şerit yüksekliği = hücre yüksekliği" % id)


func test_r5_every_cell_of_the_strip_has_visible_pixels_and_cells_are_distinct() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		var rig: Dictionary = _rigs[id]
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
			assert_gt(seen, 50, "%s hücre %d boş değil" % [id, c])
			sigs[c] = h
		var uniq := {}
		for c in sigs:
			uniq[sigs[c]] = true
		assert_eq(
			uniq.size(),
			sigs.size(),
			"%s hiçbir iki hücre birebir aynı değil (döngü kareleri tekrar etmiyor)" % id
		)


func test_r6_waiver_file_if_present_states_a_date_and_a_reason() -> void:
	if V202Slice.require(self, "R"):
		return
	for id in _rigs:
		if not _waived(id):
			pass_test("%s waiver yok: kapı doğrudan yeşil olmak zorunda (r1)" % id)
			continue
		var t := FileAccess.get_file_as_string(_waiver_path(id))
		assert_true(t.length() > 80, "%s waiver gerekçe içerir" % id)
		var has_date := false
		for y in ["2026-", "2027-"]:
			has_date = has_date or t.contains(y)
		assert_true(has_date, "%s waiver onay tarihi içerir" % id)
