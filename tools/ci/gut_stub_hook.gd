extends GutHookScript
## GUT post-run kancası: (1) koşu sonunda Stub.todo kaydı varsa gate'i kırar ("uygulanmadı" sahte yeşil olamaz);
## (2) `user://` sızıntısı varsa her yol için `USER_LEAK: <yol>` yazar ve gate'i kırar (bkz. UserLeak).


func run() -> void:
	var failed := false
	var calls := Stub.calls()
	if not calls.is_empty():
		var uniq := {}
		for c in calls:
			uniq[c] = true
		gut.logger.failed("STUB: uygulanmamış iskelet çağrıldı: %s" % [uniq.keys()])
		failed = true
	for path in UserLeak.current_leaks():
		gut.logger.failed("USER_LEAK: %s" % path)
		failed = true
	for path in UserLeak.allowed_leaks():
		gut.logger.info("USER_LEAK izinli (bulgu, tools/ci/user_leak_allow.txt): %s" % path)
	UserLeak.cleanup_and_restore()
	if failed:
		set_exit_code(1)
