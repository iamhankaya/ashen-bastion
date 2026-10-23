class_name Targeting
extends RefCounted
## Tabanca başına hedef seçimi (ateş etmez). -1 = hedef yok. Eşitlikte en düşük indeks.
## Silah 0: menzildeki en yakın. Silah 1: menzilde elit/boss varsa onların en yakını, yoksa silah 0'ın hedefi dışındaki
## en yakın (ikinci); tek düşman varsa aynı hedef.

## Sıcak yolda tahsis olmasın diye ortak sorgu tamponu (sim tek iş parçacığında, çağrı içinde tüketilir).
static var _ids: PackedInt32Array = PackedInt32Array()


static func pick(
	gun: int,
	from: Vector2,
	attack_range: float,
	enemies: EnemyPool,
	grid: SpatialHash,
	other_target: int
) -> int:
	grid.query_circle(from, attack_range, _ids)
	var ids := _ids
	var best := -1
	var best_d := INF
	var best_elite := -1
	var best_elite_d := INF
	var best_other := -1
	var best_other_d := INF
	for id in ids:
		if not enemies.is_alive(id):
			continue
		var i := EnemyPool.index_of(id)
		var d := enemies.pos[i].distance_squared_to(from)
		if gun == 1 and enemies.is_elite(i) and _better(d, id, best_elite_d, best_elite):
			best_elite = id
			best_elite_d = d
		if id != other_target and _better(d, id, best_other_d, best_other):
			best_other = id
			best_other_d = d
		if _better(d, id, best_d, best):
			best = id
			best_d = d
	if gun == 0:
		return best
	if best_elite >= 0:
		return best_elite
	if best_other >= 0:
		return best_other
	return best  # yalnız other_target var (ya da hiç yok)


## d daha küçükse; eşitse indeksi daha düşükse.
static func _better(d: float, id: int, best_d: float, best_id: int) -> bool:
	if best_id < 0:
		return true
	if d < best_d:
		return true
	return d == best_d and EnemyPool.index_of(id) < EnemyPool.index_of(best_id)
