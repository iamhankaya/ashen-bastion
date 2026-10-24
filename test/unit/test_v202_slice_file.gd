extends GutTest
## V202Slice: tools/ci/tests/slice_cases_v202.json ortak vaka tablosu (test_check_slices_v202.py ile AYNI tablo),
## V202_SLICES_FORCE ayrı değişken, V2Slice/V11Slice davranışı değişmez.

const CASES := "res://tools/ci/tests/slice_cases_v202.json"


func _table() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CASES))


func test_shared_case_table() -> void:
	var t := _table()
	var valid := PackedStringArray(t["valid"])
	assert_eq(valid, V202Slice.SYMBOLS)
	assert_gt((t["cases"] as Array).size(), 8)
	for c in t["cases"]:
		var r := SliceFile.parse(c["text"], valid)
		assert_eq(r["ok"], c["ok"], c["name"])
		assert_eq(Array(r["marks"]), c["marks"], c["name"])


func test_file_is_valid_and_marks_only_known_symbols() -> void:
	var r := SliceFile.read(V202Slice.PATH, V202Slice.SYMBOLS)
	assert_true(r["ok"], str(r["errors"]))
	for m in V202Slice.marks():
		assert_true(V202Slice.SYMBOLS.has(m), m)


func test_require_pending_for_unmarked_and_pass_for_marked() -> void:
	if not OS.get_environment(V202Slice.FORCE_ENV).is_empty():
		pending("V202_SLICES_FORCE açık")
		return
	for s in V202Slice.SYMBOLS:
		assert_eq(V202Slice.done(s), V202Slice.marks().has(s), s)


func test_force_envs_are_separate() -> void:
	assert_ne(V202Slice.FORCE_ENV, SliceFile.FORCE_ENV)
	assert_eq(V2Slice.SYMBOLS, PackedStringArray(["K", "B", "M"]))
	assert_eq(Array(V11Slice.marks()), ["D1", "D2", "D3", "D4"])
