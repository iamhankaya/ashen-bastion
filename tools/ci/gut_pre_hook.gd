extends GutHookScript
## GUT ön-koşu kancası: `user://` taban özetini kaydeder (karşılaştırma gut_stub_hook.gd'de, koşu sonunda).


func run() -> void:
	UserLeak.save_baseline()
