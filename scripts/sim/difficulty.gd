class_name Difficulty
extends RefCounted
## Zamana bağlı çarpanlar (m = t/60). Saf fonksiyonlar.
## hp = 1+0.10m+0.004m²; dmg = 1+0.04m; speed = min(1+0.012m, 1.25); cap = min(400, 40+0.3t)


static func enemy_hp_mult(t: float) -> float:
	Stub.todo(&"Difficulty.enemy_hp_mult")
	return 1.0


static func enemy_dmg_mult(t: float) -> float:
	Stub.todo(&"Difficulty.enemy_dmg_mult")
	return 1.0


static func enemy_speed_mult(t: float) -> float:
	Stub.todo(&"Difficulty.enemy_speed_mult")
	return 1.0


static func alive_cap(t: float) -> int:
	Stub.todo(&"Difficulty.alive_cap")
	return 0
