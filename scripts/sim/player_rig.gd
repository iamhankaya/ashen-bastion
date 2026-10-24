class_name PlayerRig
extends RefCounted
## Namlu konumu için TEK KAYNAK: sim mermi çıkış noktasını bununla hesaplar, view aynı fonksiyonla çizer.
##
## Geometri (karakter verisindeki normalize "rig" değerlerinden):
## - Gövde kutusu: yükseklik H = display_height, genişlik H * BODY_ASPECT; merkezi oyuncu konumudur.
## - Omuz: shoulders[gun] gövde kutusunda (0..1); sola bakışta x aynalanır.
## - Kol: uzunluğu L = arm_scale * H, yüksekliği L * ARM_ASPECT; pivot arm_pivot, namlu muzzle (kol kutusunda 0..1).
## - Kol aim_angle kadar döner; cos(aim_angle) < 0 ise kol dikey çevrilir (scale.y = -1).
## Kolsuz karakter (rig.armless): atış noktası `cast_point` (display_height kesri, gövde kutusu merkezine göre,
## +x = bakılan yön, +y aşağı); omuz/kol/namlu hesabı yoktur.
const BODY_ASPECT := 0.553  # gerçek gövde görseli 177x320
const ARM_ASPECT := 0.296  # gerçek kol görseli 240x71


## Omuz (dünya): duruş geometrisi (sim ve namlu için tek kaynak). Kare başına sapmayı bilen sürüm `shoulder_world_f`.
static func shoulder_world(
	gun: int, player_pos: Vector2, facing_left: bool, rig: Dictionary
) -> Vector2:
	return shoulder_world_f(gun, player_pos, facing_left, rig, _stand_frame(rig))


## Kare modunda `frame` karesinin omzu: duruş omzu + `rig.walk.shoulder_dev[frame]` (display_height kesri; sola
## bakışta dx aynalanır). Tablo yok/bozuk/boyu (frames+1) değil ya da kare aralık dışı ise duruş omzu döner.
static func shoulder_world_f(
	gun: int, player_pos: Vector2, facing_left: bool, rig: Dictionary, frame: int
) -> Vector2:
	var h := float(rig.get("display_height", 112.0))
	var sh: Array = rig.get("shoulders", [[0.38, 0.195], [0.62, 0.20]])
	var s: Array = sh[clampi(gun, 0, sh.size() - 1)]
	var dx := (float(s[0]) - 0.5) * h * BODY_ASPECT
	var dy := (float(s[1]) - 0.5) * h
	var dev := _frame_dev(rig, frame)
	dx += dev.x * h
	dy += dev.y * h
	if facing_left:
		dx = -dx
	return player_pos + Vector2(dx, dy)


## Duruş hücresinin indeksi (= yürüme kare sayısı); walk yoksa -1.
static func _stand_frame(rig: Dictionary) -> int:
	var w: Variant = rig.get("walk", null)
	return int(w.get("frames", 0)) if w is Dictionary else -1


static func _frame_dev(rig: Dictionary, frame: int) -> Vector2:
	var w: Variant = rig.get("walk", null)
	if not (w is Dictionary):
		return Vector2.ZERO
	var n := int(w.get("frames", 0))
	var tbl: Variant = w.get("shoulder_dev", null)
	if n < 1 or frame < 0 or frame >= n or not (tbl is Array) or tbl.size() != n + 1:
		return Vector2.ZERO
	var d: Variant = tbl[frame]
	if not (d is Array) or d.size() < 2:
		return Vector2.ZERO
	return Vector2(float(d[0]), float(d[1]))


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


## Kolsuz (tek parça gövde) rig mi: `rig.armless` true.
static func is_armless(rig: Dictionary) -> bool:
	var a: Variant = rig.get("armless", false)
	return a is bool and a


## Kolsuz rigin atış (el) noktası. `facing_left`: +x yönü aynalanır (y aynı kalır, |x| korunur).
static func cast_point_world(player_pos: Vector2, facing_left: bool, rig: Dictionary) -> Vector2:
	var h := float(rig.get("display_height", 112.0))
	var cp: Array = rig.get("cast_point", [0.30, -0.12])
	var dx := float(cp[0]) * h
	return player_pos + Vector2(-dx if facing_left else dx, float(cp[1]) * h)


## Mermi çıkış noktası (sim `_fire` ve view için tek kaynak). Kolsuz: hedefe göre (`target.x < player.x`,
## solve_aim ile AYNI kural) cast noktası. Kollu: namlu; hedef kolun menzilinden yakınsa omuzdan atılır.
static func shot_origin(gun: int, player_pos: Vector2, target: Vector2, rig: Dictionary) -> Vector2:
	if is_armless(rig):
		return cast_point_world(player_pos, target.x < player_pos.x, rig)
	var aim := solve_aim(gun, player_pos, target, rig)
	var origin := muzzle_world(gun, player_pos, aim, cos(aim) < 0.0, rig)
	var sh := shoulder_world(gun, player_pos, target.x < player_pos.x, rig)
	if target.distance_to(sh) < origin.distance_to(sh) * 1.3:
		origin = sh
	return origin


## Atıştan sonra bakış yönü: kolsuz hedefe göre (shot_origin ile aynı kural), kollu mermi yönüne göre.
static func facing_left(
	player_pos: Vector2, target: Vector2, dir: Vector2, rig: Dictionary
) -> bool:
	return target.x < player_pos.x if is_armless(rig) else dir.x < 0.0


## Namlunun hedefe baktığı kol açısı (radyan). Hedef kolun menzilinden yakınsa (namlu hedefi aşar) omuzdan hedefe bakılır.
## Kolsuzda kol yoktur: açı atış noktasından hedefe (view hizası için).
static func solve_aim(gun: int, player_pos: Vector2, target: Vector2, rig: Dictionary) -> float:
	if is_armless(rig):
		return (target - cast_point_world(player_pos, target.x < player_pos.x, rig)).angle()
	var sh := shoulder_world(gun, player_pos, target.x < player_pos.x, rig)
	var aim := (target - sh).angle()
	var reach := muzzle_world(gun, player_pos, aim, cos(aim) < 0.0, rig).distance_to(sh)
	if target.distance_to(sh) < reach * 1.3:
		return aim
	for k in 5:
		var m := muzzle_world(gun, player_pos, aim, cos(aim) < 0.0, rig)
		aim = (target - m).angle()
	return aim
