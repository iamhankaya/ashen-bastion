extends GutTest


func test_need_table() -> void:
	var expected := {1: 12, 2: 16, 3: 20, 4: 25, 5: 30, 10: 58, 20: 128, 30: 218, 40: 328}
	for n in expected.keys():
		assert_eq(XpCurve.need(n), expected[n], "need(%d)" % n)


func test_cumulative() -> void:
	assert_eq(XpCurve.cumulative(1), 0)
	assert_eq(XpCurve.cumulative(2), 12)
	assert_eq(XpCurve.cumulative(10), 276)
