class_name PlayerRig
extends RefCounted
## Namlu konumu için TEK KAYNAK: sim mermi çıkış noktasını bununla hesaplar, view aynı fonksiyonla çizer.
##
## Geometri (karakter verisindeki normalize "rig" değerlerinden):
## - Gövde kutusu: yükseklik H = display_height, genişlik H * BODY_ASPECT; merkezi oyuncu konumudur.
## - Omuz: shoulders[gun] gövde kutusunda (0..1); sola bakışta x aynalanır.
## - Kol: uzunluğu L = arm_scale * H, yüksekliği L * ARM_ASPECT; pivot arm_pivot, namlu muzzle (kol kutusunda 0..1).
## - Kol aim_angle kadar döner; cos(aim_angle) < 0 ise kol dikey çevrilir (scale.y = -1).
const BODY_ASPECT := 0.5
const ARM_ASPECT := 0.4


## Omuz (dünya).
static func shoulder_world(
	gun: int, player_pos: Vector2, facing_left: bool, rig: Dictionary
) -> Vector2:
	var h := float(rig.get("display_height", 112.0))
	var sh: Array = rig.get("shoulders", [[0.38, 0.195], [0.62, 0.20]])
	var s: Array = sh[clampi(gun, 0, sh.size() - 1)]
	var dx := (float(s[0]) - 0.5) * h * BODY_ASPECT
	var dy := (float(s[1]) - 0.5) * h
	if facing_left:
		dx = -dx
	return player_pos + Vector2(dx, dy)


## gun: 0 sağ, 1 sol tabanca. rig: karakter verisindeki "rig" sözlüğü.
static func muzzle_world(
	gun: int, player_pos: Vector2, aim_angle: float, facing_left: bool, rig: Dictionary
) -> Vector2:
	var h := float(rig.get("display_height", 112.0))
	var arm_len := float(rig.get("arm_scale", 0.62)) * h
	var pivot: Array = rig.get("arm_pivot", [0.11, 0.47])
	var muzzle: Array = rig.get("muzzle", [0.98, 0.37])
	var local := Vector2(
		(float(muzzle[0]) - float(pivot[0])) * arm_len,
		(float(muzzle[1]) - float(pivot[1])) * arm_len * ARM_ASPECT
	)
	if cos(aim_angle) < 0.0:
		local.y = -local.y
	return shoulder_world(gun, player_pos, facing_left, rig) + local.rotated(aim_angle)
