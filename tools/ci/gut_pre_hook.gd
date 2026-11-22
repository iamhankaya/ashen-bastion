extends GutHookScript
## GUT ön-koşu kancası: `user://` taban özetini kaydeder (karşılaştırma gut_stub_hook.gd'de, koşu sonunda) ve koşu
## kapsamlı önbellekleri temiz başlatır (F-ashen-bastion-127).


func run() -> void:
	UserLeak.save_baseline()
	UserLeak.clear_run_caches()
