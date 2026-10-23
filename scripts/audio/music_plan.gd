class_name MusicPlan
extends RefCounted
## Hangi müzik hangi durumda (saf fonksiyon).
## flags: in_menu, boss_alive, lord_alive, won, lost, paused (bool)
## Dönüş: "menu" | "savas-1" | "savas-2" | "kale-lordu" | "kazandin" | "kaybettin" | ""

const TRACKS: Array[StringName] = [
	&"menu", &"savas-1", &"savas-2", &"kale-lordu", &"kazandin", &"kaybettin"
]


static func track_for(time: float, flags: Dictionary) -> StringName:
	Stub.todo(&"MusicPlan.track_for")
	return &""
