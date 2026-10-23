class_name Difficulty
extends RefCounted
## Zamana bağlı çarpanlar (m = t/60). Saf fonksiyonlar.
## hp = 1+0.10m+0.004m²; dmg = 1+0.04m; speed = min(1+0.012m, 1.25); cap = min(400, 40+0.3t)


static func enemy_hp_mult(t: float) -> float:
	var m := t / 60.0
	return 1.0 + 0.10 * m + 0.004 * m * m


static func enemy_dmg_mult(t: float) -> float:
	return 1.0 + 0.04 * (t / 60.0)


static func enemy_speed_mult(t: float) -> float:
	return minf(1.0 + 0.012 * (t / 60.0), 1.25)


static func alive_cap(t: float) -> int:
	return mini(EnemyPool.CAP, int(40.0 + 0.3 * t))
