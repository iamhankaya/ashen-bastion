extends GutTest
## Sözleşme: SpatialHash.query_circle sonucu ARTAN id sıralıdır ve daireyle sınırlıdır (gerçek gövde).


func test_query_returns_ascending_ids_regardless_of_insert_order() -> void:
	var h := SpatialHash.new()
	for id in [30, 5, 17, 2, 99]:
		h.insert(id, Vector2(10, 10))
	var out := PackedInt32Array()
	h.query_circle(Vector2(10, 10), 50.0, out)
	assert_eq(out, PackedInt32Array([2, 5, 17, 30, 99]))


func test_query_filters_by_circle_across_cells() -> void:
	var h := SpatialHash.new(96.0)
	h.insert(1, Vector2(0, 0))
	h.insert(2, Vector2(200, 0))
	h.insert(3, Vector2(-95, -95))
	h.insert(4, Vector2(500, 500))
	var out := PackedInt32Array()
	h.query_circle(Vector2(0, 0), 210.0, out)
	assert_eq(out, PackedInt32Array([1, 2, 3]))


func test_query_boundary_is_inclusive_and_out_is_cleared() -> void:
	var h := SpatialHash.new()
	h.insert(1, Vector2(100, 0))
	var out := PackedInt32Array([99, 98])
	h.query_circle(Vector2.ZERO, 100.0, out)
	assert_eq(out, PackedInt32Array([1]))
	h.query_circle(Vector2.ZERO, 99.0, out)
	assert_eq(out.size(), 0)


func test_clear_and_work_counters() -> void:
	var h := SpatialHash.new()
	h.insert(1, Vector2.ZERO)
	h.insert(2, Vector2(5, 5))
	assert_eq(h.stat_inserts, 2)
	var out := PackedInt32Array()
	h.query_circle(Vector2.ZERO, 10.0, out)
	assert_eq(h.stat_queries, 1)
	assert_gt(h.stat_cells_scanned, 0)
	h.clear()
	h.query_circle(Vector2.ZERO, 10.0, out)
	assert_eq(out.size(), 0)


func test_negative_coordinates() -> void:
	var h := SpatialHash.new(96.0)
	h.insert(7, Vector2(-1, -1))
	h.insert(8, Vector2(1, 1))
	var out := PackedInt32Array()
	h.query_circle(Vector2.ZERO, 5.0, out)
	assert_eq(out, PackedInt32Array([7, 8]))
