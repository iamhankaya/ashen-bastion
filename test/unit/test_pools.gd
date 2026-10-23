extends GutTest
## Havuzlar: nesil kimliği, CAP, LIFO serbest liste, mermi hit_ids, taş birleşmesinde XP korunumu.


func _pool() -> EnemyPool:
	return EnemyPool.new(GameData.load_default())


func test_spawn_applies_multipliers_and_def_values() -> void:
	var p := _pool()
	var id := p.spawn(&"curumus_piyade", Vector2(5, 6), 2.0, 3.0, 0.5)
	var i := EnemyPool.index_of(id)
	assert_eq(p.count, 1)
	assert_almost_eq(p.hp[i], 60.0, 1e-4)
	assert_almost_eq(p.contact[i], 18.0, 1e-4)
	assert_almost_eq(p.speed[i], 47.5, 1e-4)
	assert_eq(p.radius_of(id), 26.0)
	assert_eq(p.pos[i], Vector2(5, 6))


func test_unknown_type_returns_minus_one() -> void:
	assert_eq(_pool().spawn(&"yok", Vector2.ZERO, 1.0, 1.0, 1.0), -1)


func test_cap_returns_minus_one_and_does_not_grow() -> void:
	var p := _pool()
	for k in EnemyPool.CAP:
		assert_ne(p.spawn(&"curumus_piyade", Vector2.ZERO, 1.0, 1.0, 1.0), -1)
	assert_eq(p.count, EnemyPool.CAP)
	assert_eq(p.spawn(&"curumus_piyade", Vector2.ZERO, 1.0, 1.0, 1.0), -1)
	assert_eq(p.count, EnemyPool.CAP)


func test_kill_invalidates_old_id_and_free_list_is_lifo() -> void:
	var p := _pool()
	var a := p.spawn(&"curumus_piyade", Vector2.ZERO, 1.0, 1.0, 1.0)
	var b := p.spawn(&"curumus_piyade", Vector2.ZERO, 1.0, 1.0, 1.0)
	assert_eq(EnemyPool.index_of(a), 0)
	assert_eq(EnemyPool.index_of(b), 1)
	p.kill(a)
	assert_false(p.is_alive(a))
	assert_true(p.is_alive(b))
	var c := p.spawn(&"curumus_piyade", Vector2.ZERO, 1.0, 1.0, 1.0)
	assert_eq(EnemyPool.index_of(c), 0, "son boşalan slot önce")
	assert_ne(c, a, "nesil değişti")
	assert_false(p.is_alive(a))
	assert_true(p.is_alive(c))
	p.kill(a)  # eski kimlikle öldürme etkisiz
	assert_true(p.is_alive(c))
	assert_eq(p.count, 2)


func test_generation_wraps_at_65536() -> void:
	var p := _pool()
	var first := p.spawn(&"curumus_piyade", Vector2.ZERO, 1.0, 1.0, 1.0)
	var id := first
	for k in 65536:
		p.kill(id)
		id = p.spawn(&"curumus_piyade", Vector2.ZERO, 1.0, 1.0, 1.0)
	assert_eq(id, first, "65536. yeniden kullanımda nesil 0'a döner")
	assert_true(p.is_alive(id))
	assert_eq(p.count, 1)


func test_alive_ids_ascending() -> void:
	var p := _pool()
	var ids: Array[int] = []
	for k in 5:
		ids.append(p.spawn(&"curumus_piyade", Vector2.ZERO, 1.0, 1.0, 1.0))
	p.kill(ids[2])
	var got := p.alive_ids()
	assert_eq(got.size(), 4)
	for k in range(1, got.size()):
		assert_gt(got[k], got[k - 1])


func test_projectile_spawn_cap_and_defaults() -> void:
	var pp := ProjectilePool.new()
	var i := pp.spawn(Vector2(1, 2), Vector2(3, 4), 7.0)
	assert_eq(i, 0)
	assert_almost_eq(pp.life[0], ProjectilePool.DEFAULT_LIFE, 1e-5)
	for k in ProjectilePool.CAP - 1:
		pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0)
	assert_eq(pp.count, ProjectilePool.CAP)
	assert_eq(pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0), -1)


func test_projectile_remove_swaps_last_and_keeps_hits() -> void:
	var pp := ProjectilePool.new()
	pp.spawn(Vector2(1, 0), Vector2.ZERO, 1.0)
	pp.spawn(Vector2(2, 0), Vector2.ZERO, 2.0, {"bounces": 4})
	pp.spawn(Vector2(3, 0), Vector2.ZERO, 3.0)
	pp.mark_hit(2, 77)
	pp.remove(0)
	assert_eq(pp.count, 2)
	assert_eq(pp.pos[0], Vector2(3, 0), "son mermi 0'a taşındı")
	assert_true(pp.has_hit(0, 77))
	assert_eq(pp.pos[1], Vector2(2, 0))
	assert_eq(pp.bounces[1], 4)


func test_projectile_hit_ring_buffer_forgets_oldest() -> void:
	var pp := ProjectilePool.new()
	pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0)
	for k in ProjectilePool.HIT_SLOTS + 1:
		pp.mark_hit(0, 100 + k)
	assert_false(pp.has_hit(0, 100), "en eski kayıt unutuldu")
	assert_true(pp.has_hit(0, 100 + ProjectilePool.HIT_SLOTS))
	assert_true(pp.has_hit(0, 101))


func test_gem_drop_collect_and_conservation() -> void:
	var g := GemPool.new()
	g.drop(Vector2(1, 1), 3)
	g.drop(Vector2(5, 5), 2)
	assert_eq(g.count, 2)
	assert_eq(g.total_value(), 5)
	assert_eq(g.dropped_total - g.collected_total, g.total_value())
	assert_eq(g.collect(0), 3)
	assert_eq(g.count, 1)
	assert_eq(g.pos[0], Vector2(5, 5))
	assert_eq(g.dropped_total - g.collected_total, g.total_value())


func test_gem_merge_at_cap_preserves_total_xp() -> void:
	var g := GemPool.new()
	for k in GemPool.CAP:
		g.drop(Vector2(k * 10, 0), 1)
	g.drop(Vector2(31, 0), 5)
	assert_eq(g.count, GemPool.CAP)
	assert_eq(g.total_value(), GemPool.CAP + 5)
	assert_eq(g.value[3], 6, "en yakın taşa (x=30) katıldı")
	assert_eq(g.dropped_total - g.collected_total, g.total_value())
