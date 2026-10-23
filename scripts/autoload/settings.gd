extends Node
## Kullanıcı ayarları (user://settings.cfg). Yol enjekte edilebilir (testte geçici yol).

var sound_on: bool = true
var vibration_on: bool = true


func load_settings(path: String = "user://settings.cfg") -> void:
	Stub.todo(&"Settings.load_settings")


func save_settings(path: String = "user://settings.cfg") -> void:
	Stub.todo(&"Settings.save_settings")


## vibration_on ve Android ise Input.vibrate_handheld(ms).
func vibrate(ms: int) -> void:
	Stub.todo(&"Settings.vibrate")
