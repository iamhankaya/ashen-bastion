class_name Stub
extends RefCounted
## "Uygulanmadı" işareti. İskelet gövdeleri push_error yerine Stub.todo çağırır:
## günlük temiz kalır; GUT post-run kancası (tools/ci/gut_stub_hook.gd) kayıt varsa gate'i kırar.

static var _calls: Array[StringName] = []


static func todo(what: StringName) -> void:
	_calls.append(what)


static func calls() -> Array[StringName]:
	return _calls.duplicate()


static func reset() -> void:
	_calls.clear()
