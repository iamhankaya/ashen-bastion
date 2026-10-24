class_name RigFrames
extends RefCounted
## Kolsuz rig şerit hücre düzeni (sim ve view için tek kaynak). Sıra: yürüme 0..W-1, duruş W, cast W+1..W+C,
## gather W+C+1..W+C+G, walk_cast sonra (WC). Toplam W+1+C+G+WC (8+1+6+4 = 19; walk_cast yoksa). Kümesi
## olmayan taban -1 döner. `rig`: karakter verisindeki "rig" sözlüğü.


static func total_cells(rig: Dictionary) -> int:
	return walk_frames(rig) + 1 + _n(rig, "cast") + _n(rig, "gather") + _n(rig, "walk_cast")


## Duruş hücresi (= yürüme kare sayısı).
static func idle_index(rig: Dictionary) -> int:
	return walk_frames(rig)


static func cast_base(rig: Dictionary) -> int:
	return walk_frames(rig) + 1 if _n(rig, "cast") > 0 else -1


static func gather_base(rig: Dictionary) -> int:
	return walk_frames(rig) + 1 + _n(rig, "cast") if _n(rig, "gather") > 0 else -1


static func walk_cast_base(rig: Dictionary) -> int:
	if _n(rig, "walk_cast") < 1:
		return -1
	return walk_frames(rig) + 1 + _n(rig, "cast") + _n(rig, "gather")


static func walk_frames(rig: Dictionary) -> int:
	var w: Variant = rig.get("walk", null)
	return maxi(0, int(w.get("frames", 0))) if w is Dictionary else 0


static func _n(rig: Dictionary, key: String) -> int:
	var b: Variant = rig.get(key, null)
	return maxi(0, int(b.get("frames", 0))) if b is Dictionary else 0
