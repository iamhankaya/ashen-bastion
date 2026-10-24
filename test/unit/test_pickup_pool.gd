extends GutTest
## PickupPool (CAP 8): spawn/remove/uid gerçek; tick D2-1'de dolar (iskelet testi test_contract_stub.gd'de).

const K := 3


func test_spawn_fills_up_to_cap_then_reports_full() -> void:
	var p := PickupPool.new()
	for i in PickupPool.CAP:
		assert_eq(p.spawn(K, Vector2(i, 0), 1500), i)
	assert_eq(p.count, 8)
	assert_eq(p.spawn(K, Vector2.ZERO, 1500), -1, "dolu: -1")
	assert_eq(p.count, 8)


func test_spawn_writes_every_column() -> void:
	var p := PickupPool.new()
	var i := p.spawn(2, Vector2(10, 20), 600)
	assert_eq(p.pos[i], Vector2(10, 20))
	assert_eq(p.kind_idx[i], 2)
	assert_eq(p.age_steps[i], 0)
	assert_eq(p.left_steps[i], 600)


func test_uid_is_monotonic_even_when_slots_are_reused() -> void:
	var p := PickupPool.new()
	p.spawn(0, Vector2.ZERO, 10)
	p.spawn(0, Vector2.ZERO, 10)
	var u1 := p.uid[1]
	p.remove(0)
	var j := p.spawn(0, Vector2.ZERO, 10)
	assert_gt(p.uid[j], u1, "yeniden kullanılan yuva yeni uid alır")
	assert_ne(p.uid[0], 0)


func test_remove_swaps_the_last_element_into_the_hole() -> void:
	var p := PickupPool.new()
	for i in 4:
		p.spawn(i, Vector2(i, i), 100 + i)
	var last_uid := p.uid[3]
	p.remove(1)
	assert_eq(p.count, 3)
	assert_eq(p.kind_idx[1], 3)
	assert_eq(p.pos[1], Vector2(3, 3))
	assert_eq(p.left_steps[1], 103)
	assert_eq(p.uid[1], last_uid)
	p.remove(2)  # son eleman
	assert_eq(p.count, 2)
	p.remove(1)
	p.remove(0)
	assert_eq(p.count, 0)


func test_reverse_iteration_removal_is_safe() -> void:
	var p := PickupPool.new()
	for i in 6:
		p.spawn(i, Vector2.ZERO, 10)
	var i := p.count - 1
	while i >= 0:
		if p.kind_idx[i] % 2 == 0:
			p.remove(i)
		i -= 1
	assert_eq(p.count, 3)
	for k in p.count:
		assert_eq(p.kind_idx[k] % 2, 1)


func test_tick_counts_down_and_expires_exactly_at_life() -> void:
	var p := PickupPool.new()
	p.spawn(2, Vector2.ZERO, 3)
	var out := PackedInt32Array()
	p.tick(out)
	p.tick(out)
	assert_eq(p.count, 1)
	assert_eq(p.age_steps[0], 2)
	assert_eq(p.left_steps[0], 1)
	assert_true(out.is_empty())
	p.tick(out)
	assert_eq(p.count, 0, "3. adımda ömür dolar")
	assert_eq(out, PackedInt32Array([2]))


func test_tick_clears_output_and_removes_several_expired_in_one_step() -> void:
	var p := PickupPool.new()
	p.spawn(0, Vector2.ZERO, 1)
	p.spawn(1, Vector2.ZERO, 5)
	p.spawn(2, Vector2.ZERO, 1)
	p.spawn(3, Vector2.ZERO, 5)
	var out := PackedInt32Array([9])
	p.tick(out)
	assert_eq(out, PackedInt32Array([0, 2]), "artan indeks sırası")
	assert_eq(p.count, 2)
	var kinds := [p.kind_idx[0], p.kind_idx[1]]
	kinds.sort()
	assert_eq(kinds, [1, 3])
	for k in p.count:
		assert_eq(p.left_steps[k], 4)
