class_name V2Maint
extends V2Part
## Bakım dilimi bağları (M sahipli): debug dokunma alanlarının eşlenmesi (scripts/debug/DebugLabels), güvenli alan
## yenileme dağıtımı (HUD + seviye atlama + duraklatma; M8a/N7). Sim'e ve v1.1 akışına dokunmaz.

var _ui_root: Node = null
var _hud: Control = null
var _level_up: Control = null
var _pause: Control = null
var _screen: int = -1


func build_world(refs: Dictionary) -> void:
	_ui_root = refs.get("ui_root", null)
	_hud = refs.get("hud", null)
	_level_up = refs.get("level_up", null)
	_pause = refs.get("pause_screen", null)


func on_screen(next: int) -> void:
	_screen = next
	_sync_debug()


func update_views(_view_dt: float) -> void:
	_sync_debug()


## extra: Vector4(sol, üst, sağ, alt) ya da null (her ekran UiKit.current_safe_extra'yı kendisi okur).
## Seviye atlama ekranı `apply_safe_area` taşıyorsa (K1/N7) çağrılır; yoksa atlanır.
func apply_safe_areas(extra: Variant = null) -> void:
	for screen in [_hud, _level_up, _pause]:
		if screen != null and is_instance_valid(screen) and screen.has_method(&"apply_safe_area"):
			screen.call(&"apply_safe_area", extra)
	if OS.is_debug_build():
		DebugLabels.apply_safe_area(_ui_root, extra)


func release() -> void:
	_ui_root = null
	_hud = null
	_level_up = null
	_pause = null


func _sync_debug() -> void:
	if _ui_root != null and is_instance_valid(_ui_root) and OS.is_debug_build():
		DebugLabels.sync_taps(_ui_root, _screen == PauseLogic.Screen.PLAYING)
