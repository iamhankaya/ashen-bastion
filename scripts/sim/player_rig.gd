class_name PlayerRig
extends RefCounted
## Namlu konumu için TEK KAYNAK: sim mermi çıkış noktasını bununla hesaplar, view aynı fonksiyonla çizer.


## gun: 0 sağ, 1 sol tabanca. rig: karakter verisindeki "rig" sözlüğü.
static func muzzle_world(
	gun: int, player_pos: Vector2, aim_angle: float, facing_left: bool, rig: Dictionary
) -> Vector2:
	Stub.todo(&"PlayerRig.muzzle_world")
	return player_pos
