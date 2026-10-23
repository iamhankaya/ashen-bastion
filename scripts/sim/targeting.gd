class_name Targeting
extends RefCounted
## Tabanca başına hedef seçimi (ateş etmez). -1 = hedef yok. Eşitlikte en düşük indeks.


static func pick(
	gun: int,
	from: Vector2,
	attack_range: float,
	enemies: EnemyPool,
	grid: SpatialHash,
	other_target: int
) -> int:
	Stub.todo(&"Targeting.pick")
	return -1
