class_name V2Part
extends RefCounted
## v2.0 dilim sınıflarının ortak tabanı (S3 sahipli; K/B/M değiştirmez). `V2Flow` kancaları buradaki yöntemlerle
## dağıtır; her dilim (V2Characters, V2Achievements, V2Maint) yalnız ihtiyacı olanı geçersiz kılar. Gövdeler boştur:
## kanca çağrısı v1.1 davranışını değiştirmez. İş mantığı dilim sınıfında yaşar, `game_controller.gd`'de değil.

## V2Flow.opts: "data" (GameData), "achievements_path" (String), "clock" (Callable). Testler doldurur.
var opts: Dictionary = {}


func _init(p_opts: Dictionary = {}) -> void:
	opts = p_opts


## Açılışta bir kez (world/ui kurulduktan sonra). refs: ui_root, menu, hud, level_up, result_screen, pause_screen,
## set_screen (Callable: int -> void, controller._set_screen).
func build_world(_refs: Dictionary) -> void:
	pass


## Her `_bind` sonunda; sim null olabilir (menüye dönüş, stres koşusu).
func bind(_sim: GameSim) -> void:
	pass


## Her karede `_update_views` sonunda; view_dt = PLAYING iken dt, aksi halde 0.
func update_views(_view_dt: float) -> void:
	pass


## `_on_run_ended` başında (sonuç ekranından ve skor kaydından ÖNCE).
func on_run_ended(_won: bool, _stats: Dictionary) -> void:
	pass


## `_set_screen` sonunda (next = PauseLogic.Screen).
func on_screen(_next: int) -> void:
	pass


## `pause_game()` içinde (otomatik duraklama ve geri tuşu dahil).
func on_pause() -> void:
	pass


## Güvenli kayıt noktası (koşu sonu, duraklatma, menüye dönüş).
func flush() -> void:
	pass


## extra: Vector4(sol, üst, sağ, alt) ya da null (UiKit.current_safe_extra).
func apply_safe_areas(_extra: Variant = null) -> void:
	pass


## Controller `_exit_tree`: referansları bırak (RefCounted <-> Node döngüsü kalmaz).
func release() -> void:
	pass
