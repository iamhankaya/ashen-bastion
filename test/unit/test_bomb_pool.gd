extends GutTest
## BombPool (CAP 4): plant/tick/remove.


func test_plant_fills_to_cap_then_reports_full() -> void:
	var b := BombPool.new()
	assert_false(b.is_full())
	for i in BombPool.CAP:
		assert_eq(b.plant(Vector2(i, 0), 48, 320.0, 4), i)
	assert_true(b.is_full())
	assert_eq(b.plant(Vector2.ZERO, 48, 320.0, 4), -1)
	assert_eq(b.count, 4)


func test_plant_writes_every_column() -> void:
	var b := BombPool.new()
	var i := b.plant(Vector2(5, 6), 48, 320.0, 4)
	assert_eq(b.pos[i], Vector2(5, 6))
	assert_eq(b.fuse_steps[i], 48)
	assert_eq(b.fuse_total[i], 48)
	assert_eq(b.radius[i], 320.0)
	assert_eq(b.kind_idx[i], 4)


func test_fuse_burns_exactly_fuse_steps() -> void:
	var b := BombPool.new()
	b.plant(Vector2.ZERO, 48, 320.0, 4)
	var ready := PackedInt32Array()
	for _s in 47:
		b.tick(ready)
		assert_true(ready.is_empty())
	b.tick(ready)
	assert_eq(ready, PackedInt32Array([0]), "48. adımda hazır")


func test_ready_indices_ascending_and_output_cleared() -> void:
	var b := BombPool.new()
	b.plant(Vector2.ZERO, 2, 100.0, 0)
	b.plant(Vector2.ZERO, 5, 100.0, 0)
	b.plant(Vector2.ZERO, 2, 100.0, 0)
	var ready := PackedInt32Array([7])
	b.tick(ready)
	assert_true(ready.is_empty())
	b.tick(ready)
	assert_eq(ready, PackedInt32Array([0, 2]))


func test_remove_swaps_last_into_hole_in_reverse_loop() -> void:
	var b := BombPool.new()
	for i in 4:
		b.plant(Vector2(i, 0), 10 + i, 100.0 + i, i)
	b.remove(1)
	assert_eq(b.count, 3)
	assert_eq(b.pos[1], Vector2(3, 0))
	assert_eq(b.fuse_steps[1], 13)
	assert_eq(b.radius[1], 103.0)
	assert_eq(b.kind_idx[1], 3)
	b.remove(2)
	b.remove(1)
	b.remove(0)
	assert_eq(b.count, 0)
