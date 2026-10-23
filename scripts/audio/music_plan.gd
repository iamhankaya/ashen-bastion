class_name MusicPlan
extends RefCounted
## Hangi müzik hangi durumda (saf fonksiyon). Dosyalar: assets/audio/music/<ad>.ogg (tools/audio/process_audio.py).
## flags: in_menu, boss_alive, lord_alive, won, lost, paused (bool)
## Dönüş: "menu" | "savas-1" | "savas-2" | "kale-lordu" | "kazandin" | "kaybettin" | ""

const TRACKS: Array[StringName] = [
	&"menu", &"savas-1", &"savas-2", &"kale-lordu", &"kazandin", &"kaybettin"
]
## Döngülü parçalar (kodda AudioStreamOggVorbis.loop = true verilir); kalanlar tek seferlik.
const LOOPING: Array[StringName] = [&"menu", &"savas-1", &"savas-2", &"kale-lordu"]
const SWITCH_TO_SAVAS_2 := 600.0  # sn
const STINGER := &"boss-uyari"


static func track_for(time: float, flags: Dictionary) -> StringName:
	if bool(flags.get("in_menu", false)):
		return &"menu"
	if bool(flags.get("won", false)):
		return &"kazandin"
	if bool(flags.get("lost", false)):
		return &"kaybettin"
	if bool(flags.get("lord_alive", false)):
		return &"kale-lordu"
	return &"savas-2" if time >= SWITCH_TO_SAVAS_2 else &"savas-1"


## Parçadan parçaya geçiş süresi (sn): oyun başı 1,5; 600. sn savaş-2'ye 4; Lord'a 2; sonuç parçalarına kısa.
static func fade_seconds(from_track: StringName, to_track: StringName) -> float:
	match to_track:
		&"savas-1":
			return 1.5
		&"savas-2":
			return 4.0
		&"kale-lordu":
			return 2.0
		&"kazandin", &"kaybettin":
			return 0.6
	return 1.0 if from_track != &"" else 0.0
