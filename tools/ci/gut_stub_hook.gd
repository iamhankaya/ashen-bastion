extends GutHookScript
## GUT post-run kancası: koşu sonunda Stub.todo kaydı varsa gate'i kırar ("uygulanmadı" sahte yeşil olamaz).


func run() -> void:
	var calls := Stub.calls()
	if calls.is_empty():
		return
	var uniq := {}
	for c in calls:
		uniq[c] = true
	gut.logger.failed("STUB: uygulanmamış iskelet çağrıldı: %s" % [uniq.keys()])
	set_exit_code(1)
