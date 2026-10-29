extends GutTest
## Hedefleme: en yakın, silah 1 ikinci hedef, elit önceliği, eşitlikte en düşük indeks, menzil.

var pool: EnemyPool
var grid: SpatialHash


func before_each() -> void:
	pool = EnemyPool.new(GameData.load_default())
	grid = SpatialHash.new()


func _add(type_id: StringName, p: Vector2) -> int:
	return pool.spawn(type_id, p, 1.0, 1.0, 1.0)


func _index() -> void:
	grid.clear()
	for i in EnemyPool.CAP:
		if pool.alive[i] == 1:
			grid.insert(EnemyPool.make_id(pool.gen[i], i), pool.pos[i])


func test_no_enemy_means_no_target() -> void:
	_index()
	assert_eq(Targeting.pick(0, Vector2.ZERO, 700.0, pool, grid, -1), -1)
	assert_eq(Targeting.pick(1, Vector2.ZERO, 700.0, pool, grid, -1), -1)


func test_gun0_picks_nearest_within_range() -> void:
	var far := _add(&"curumus_piyade", Vector2(500, 0))
	var near := _add(&"curumus_piyade", Vector2(100, 0))
	_add(&"curumus_piyade", Vector2(900, 0))
	_index()
	assert_ne(far, near)
	assert_eq(Targeting.pick(0, Vector2.ZERO, 700.0, pool, grid, -1), near)
	assert_eq(Targeting.pick(0, Vector2.ZERO, 50.0, pool, grid, -1), -1, "menzil dışı")


func test_gun1_takes_second_nearest_or_same_when_alone() -> void:
	var a := _add(&"curumus_piyade", Vector2(100, 0))
	var b := _add(&"curumus_piyade", Vector2(200, 0))
	_index()
	var t0 := Targeting.pick(0, Vector2.ZERO, 700.0, pool, grid, -1)
	assert_eq(t0, a)
	assert_eq(Targeting.pick(1, Vector2.ZERO, 700.0, pool, grid, t0), b)
	pool.kill(b)
	_index()
	assert_eq(Targeting.pick(1, Vector2.ZERO, 700.0, pool, grid, t0), a, "tek düşman: aynı hedef")


func test_tie_breaks_to_lowest_index() -> void:
	var first := _add(&"curumus_piyade", Vector2(100, 0))
	var second := _add(&"curumus_piyade", Vector2(-100, 0))
	_index()
	assert_lt(EnemyPool.index_of(first), EnemyPool.index_of(second))
	assert_eq(Targeting.pick(0, Vector2.ZERO, 700.0, pool, grid, -1), first)


func test_dead_enemies_are_ignored() -> void:
	var a := _add(&"curumus_piyade", Vector2(100, 0))
	var b := _add(&"curumus_piyade", Vector2(300, 0))
	_index()
	pool.kill(a)  # hash eski kalır
	assert_eq(Targeting.pick(0, Vector2.ZERO, 700.0, pool, grid, -1), b)


func test_query_buffer_is_owned_by_the_pool_not_shared() -> void:
	_add(&"curumus_piyade", Vector2(100, 0))
	_index()
	var other := EnemyPool.new(GameData.load_default())
	assert_eq(Targeting.pick(0, Vector2.ZERO, 700.0, pool, grid, -1) >= 0, true)
	assert_eq(pool.pick_ids.size(), 1, "sorgu tamponu havuzda")
	assert_eq(other.pick_ids.size(), 0, "başka havuzun tamponu etkilenmez")
