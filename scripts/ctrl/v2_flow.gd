class_name V2Flow
extends RefCounted
## v2.0 cephesi (S3 sahipli, gövdesi GERÇEK; yalnız dağıtım, iş mantığı yok): controller'ın tek v2 giriş noktası.
## Kancaları üç dilim sınıfına dağıtır: V2Characters (K), V2Achievements (B), V2Maint (M). Controller tipini BİLMEZ
## (class_name döngüsü yok): düğümler `build_world(refs)` sözlüğüyle gelir. Plan: docs/plan/v2.0-plan.md "V2 sınıfları".
## Test izolasyonu: `opts` (controller `v2_opts` alanı, testler `add_child`'dan ÖNCE doldurur):
##   "data": GameData (varsayılan GameData.load_default()), "achievements_path": String, "clock": Callable.

var opts: Dictionary
var characters: V2Characters
var achievements: V2Achievements
var maint: V2Maint

var _screen: int = PauseLogic.Screen.MENU
var _released: bool = false


func _init(p_opts: Dictionary = {}) -> void:
	opts = p_opts
	characters = V2Characters.new(opts)
	achievements = V2Achievements.new(opts)
	maint = V2Maint.new(opts)


## refs: ui_root, menu, hud, level_up, result_screen, pause_screen (Node'lar), set_screen (Callable: int -> void).
func build_world(refs: Dictionary) -> void:
	if _released:
		return
	characters.build_world(refs)
	achievements.build_world(refs)
	maint.build_world(refs)


## sim null olabilir (menüye dönüş, stres koşusu).
func bind(sim: GameSim) -> void:
	if _released:
		return
	characters.bind(sim)
	achievements.bind(sim)
	maint.bind(sim)


## Her `_update_views`; view_dt = PLAYING iken dt, aksi halde 0 (duraklamada bildirim kuyruğu donar).
func update_views(view_dt: float) -> void:
	if _released:
		return
	characters.update_views(view_dt)
	achievements.update_views(view_dt)
	maint.update_views(view_dt)


## tracker.finish → result.set_new_achievements; sonra controller skor kaydı ve show_result; en sonda flush().
func on_run_ended(won: bool, stats: Dictionary) -> void:
	if _released:
		return
	characters.on_run_ended(won, stats)
	achievements.on_run_ended(won, stats)
	maint.on_run_ended(won, stats)


func on_screen(next: int) -> void:
	if _released:
		return
	_screen = next
	characters.on_screen(next)
	achievements.on_screen(next)
	maint.on_screen(next)


## pause_game: flush noktası.
func on_pause() -> void:
	if _released:
		return
	characters.on_pause()
	achievements.on_pause()
	maint.on_pause()
	flush()


func flush() -> void:
	if _released:
		return
	characters.flush()
	achievements.flush()
	maint.flush()


## Yalnız Screen.MENU'de; aksi no-op (open_scores kalıbı).
func open_characters() -> void:
	if not _released and _screen == PauseLogic.Screen.MENU:
		characters.open()


## Yalnız Screen.MENU'de; aksi no-op.
func open_achievements() -> void:
	if not _released and _screen == PauseLogic.Screen.MENU:
		achievements.open()


## CharacterRoster.resolve(Settings.character_id, opts.data ?? GameData.load_default(), achievements.store).
## Çözümleme boş dönerse (hiç karakter yok) DEFAULT_ID.
func selected_character() -> StringName:
	var data: GameData = opts.get("data", null)
	if data == null:
		data = GameData.load_default()
	var saved := ""
	var st := _settings()
	if st != null:
		var v: Variant = st.get("character_id")
		saved = v if v is String else ""
	var id := CharacterRoster.resolve(saved, data, achievements.store)
	return id if id != &"" else CharacterRoster.DEFAULT_ID


func apply_safe_areas(extra: Variant = null) -> void:
	if _released:
		return
	characters.apply_safe_areas(extra)
	achievements.apply_safe_areas(extra)
	maint.apply_safe_areas(extra)


## Controller `_exit_tree`: dilimleri bırakır (kayıt flush edilir); sonraki kancalar no-op.
func release() -> void:
	if _released:
		return
	flush()
	characters.release()
	achievements.release()
	maint.release()
	_released = true


## Autoload'a düğüm yolundan erişilir (`-s` betik bağlamında autoload adı derlemede tanınmayabilir); yoksa null.
func _settings() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(^"Settings")
	return null
