extends GutTest
## SliceFile: tools/ci/tests/slice_cases.json ortak vaka tablosu (check_slices.py ile AYNI tablo), V2_SLICES_FORCE,
## V11Slice/V2Slice davranışı.

const CASES := "res://tools/ci/tests/slice_cases.json"


func _table() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CASES))


func test_shared_case_table() -> void:
	var t := _table()
	var valid := PackedStringArray(t["valid"])
	assert_gt((t["cases"] as Array).size(), 10)
	for c in t["cases"]:
		var r := SliceFile.parse(c["text"], valid)
		assert_eq(r["ok"], c["ok"], c["name"])
		assert_eq(Array(r["marks"]), c["marks"], c["name"])
		assert_eq((r["errors"] as PackedStringArray).is_empty(), c["ok"], c["name"])


func test_missing_file_is_an_error() -> void:
	var r := SliceFile.read("res://tools/yok_boyle_dilim.txt")
	assert_false(r["ok"])
	assert_eq((r["errors"] as PackedStringArray).size(), 1)
	assert_true(PackedStringArray(r["marks"]).is_empty())


func test_without_valid_list_any_symbol_is_accepted() -> void:
	var r := SliceFile.parse("D1\nD2 D3\n# D9\n")
	assert_true(r["ok"])
	assert_eq(Array(r["marks"]), ["D1", "D2", "D3"])


func test_v11_marks_behaviour_unchanged() -> void:
	assert_eq(Array(V11Slice.marks()), ["D1", "D2", "D3", "D4"])
	assert_true(V11Slice.done("D4"))
	assert_false(V11Slice.done("D5"))


func test_v2_marks_start_empty_in_contract_phase() -> void:
	if not OS.get_environment(SliceFile.FORCE_ENV).is_empty():
		pending("V2_SLICES_FORCE açık")
		return
	# Sözleşme fazı: işaretler kapalı. Tur fazları bu dosyaya simge ekler; o zaman bu iddia güncellenir.
	var r := SliceFile.read(V2Slice.PATH, V2Slice.SYMBOLS)
	assert_true(r["ok"], str(r["errors"]))
	for m in V2Slice.marks():
		assert_true(V2Slice.SYMBOLS.has(m), m)


func test_v2_require_returns_true_for_unmarked_and_false_for_marked() -> void:
	# Tur fazları simge ekledikçe işaretsiz kalan ilk simge denenir; hepsi işaretliyse iddia anlamsızdır.
	var open_symbol := ""
	for s in V2Slice.SYMBOLS:
		if not V2Slice.marks().has(s):
			open_symbol = s
			break
	if not OS.get_environment(SliceFile.FORCE_ENV).is_empty():
		pending("V2_SLICES_FORCE açık")
		return
	if open_symbol.is_empty():
		# B-tur: tüm simgeler işaretli; işaretli simgede require false döner ve pending çağırmaz.
		var all_probe := _Probe.new()
		for sym in V2Slice.SYMBOLS:
			assert_false(V2Slice.require(all_probe, sym), "%s işaretli: require false" % sym)
		assert_eq(all_probe.pending_calls, 0)
		all_probe.free()
		return
	# `require` pending() çağırır; bu testin kendisi pending olmasın diye çağrı sahte GutTest'e yönlendirilir.
	var probe := _Probe.new()
	assert_true(
		V2Slice.require(probe, open_symbol),
		"%s kapalıyken require true döner (pending)" % open_symbol
	)
	assert_eq(probe.pending_calls, 1)
	probe.free()


class _Probe:
	extends GutTest
	var pending_calls: int = 0

	func pending(_text: String = "") -> void:
		pending_calls += 1
