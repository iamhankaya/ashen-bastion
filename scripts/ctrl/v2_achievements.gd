class_name V2Achievements
extends V2Part
## Başarım bağlama (B sahipli): tracker/depo yaşam döngüsü, `poll`, bildirim kuyruğu/host, `finish` sırası, flush noktaları,
## ekran açılışları, menü sayacı. Karakter bilmez. S3: boş gövde; B3/B4 doldurur.
## opts: "achievements_path" (depo yolu; yoksa AchievementStore.DEFAULT_PATH), "clock" (tracker saati), "data".

## Depo; B3 kurar (S3: null). CharacterRoster.resolve ve karakter kilidi bunu okur.
var store: AchievementStore = null


## Ana menüden BAŞARIMLAR (yalnız Screen.MENU'de çağrılır; V2Flow denetler). B4: ekranı açar.
func open() -> void:
	pass
