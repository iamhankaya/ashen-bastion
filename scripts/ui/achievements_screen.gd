class_name AchievementsScreen
extends Control
## Başarımlar ekranı (liste). Kayıt yazmaz, tracker bilmez; ilerleme `AchievementProgress.of(def, store)`. Tasarım §5.1.
## İSKELET (S3): gövdeler B4'te (Stub.todo); V2Achievements ekranı kurana dek hiçbir yerde örneklenmez.

signal back_requested


func open(_data: GameData, _store: AchievementStore) -> void:
	Stub.todo(&"AchievementsScreen.open")


func row_count() -> int:
	Stub.todo(&"AchievementsScreen.row_count")
	return 0


## extra: Vector4(sol, üst, sağ, alt) ya da null (UiKit.current_safe_extra).
func apply_safe_area(_extra: Variant = null) -> void:
	Stub.todo(&"AchievementsScreen.apply_safe_area")
