extends GutTest
## Sözleşme: iskelet gövdeleri Stub.todo çağırır (push_error değil); kayıt varsa GUT post-run kancası gate'i kırar.


func after_each() -> void:
	Stub.reset()


func test_todo_records_and_reset_clears() -> void:
	Stub.todo(&"A.b")
	Stub.todo(&"C.d")
	assert_eq(Stub.calls(), [&"A.b", &"C.d"] as Array[StringName])
	Stub.reset()
	assert_eq(Stub.calls().size(), 0)


func test_calls_returns_a_copy() -> void:
	Stub.todo(&"X.y")
	Stub.calls().clear()
	assert_eq(Stub.calls().size(), 1)


func test_no_skeleton_methods_remain() -> void:
	# Hâlâ iskelet olan gövdeler buraya [çağrı, kimlik] olarak eklenir; içerik tamamlandığında liste boştur.
	var cases: Array = []
	assert_eq(cases.size(), 0, "iskelet gövde kalmadı")
	for c in cases:
		Stub.reset()
		c[0].call()
		assert_eq(Stub.calls(), [c[1]] as Array[StringName], "%s" % c[1])


func test_sfx_play_is_a_silent_noop() -> void:
	Sfx.play(&"hit")
	Sfx.play(&"yok_boyle_ses", {"pitch": 1.2})
	assert_eq(Stub.calls().size(), 0)


func test_post_run_hook_is_configured() -> void:
	var cfg: Dictionary = KitDev.read_json("res://.gutconfig.json")
	assert_eq(cfg.get("post_run_script"), "res://tools/ci/gut_stub_hook.gd")
	assert_true(FileAccess.file_exists("res://tools/ci/gut_stub_hook.gd"))
