class_name AchievementTracker
extends RefCounted
## Başarım izleyici: SimBus sinyallerinden sayaç, eşikte `store.unlock`. Sim durumuna YAZMAZ, RNG kullanmaz, diske yazmaz,
## `run_ended` dinlemez (controller `finish(won, stats)` çağırır). İSKELET (S2): gövdeler B2'de (şimdilik Stub.todo).
## Dinlenen sinyaller (test_contract_sim imza testiyle sabit): enemy_killed, level_up, score_changed, reload_started,
## streak_changed, pickup_collected, player_damaged, evolution_gained, buff_started, buff_ended, bomb_hits.

signal unlocked(def: AchievementDef)

const LISTENED: PackedStringArray = [
	"enemy_killed",
	"level_up",
	"score_changed",
	"reload_started",
	"streak_changed",
	"pickup_collected",
	"player_damaged",
	"evolution_gained",
	"buff_started",
	"buff_ended",
	"bomb_hits",
]

var data: GameData
var store: AchievementStore
var char_id: StringName = &""
var clock: Callable = Callable()


## p_clock: () -> int unix (varsayılan Time.get_unix_time_from_system; testte enjekte; dönüş < 1 ise 1 kullanılır).
func _init(
	p_data: GameData,
	p_store: AchievementStore,
	p_char_id: StringName,
	p_clock: Callable = Callable()
) -> void:
	data = p_data
	store = p_store
	char_id = p_char_id
	clock = p_clock


## YALNIZ dinleme (run_ended HARİÇ); ikinci çağrı önce detach.
func attach(_bus: SimBus) -> void:
	Stub.todo(&"AchievementTracker.attach")


func detach() -> void:
	Stub.todo(&"AchievementTracker.detach")


## SALT OKUR: sim.time, sim.loadout.actives().size(); <= 60 Hz çağrılır.
func poll(_sim: GameSim) -> void:
	Stub.todo(&"AchievementTracker.poll")


## Controller çağırır; ikinci çağrı no-op.
func finish(_won: bool, _stats: Dictionary) -> void:
	Stub.todo(&"AchievementTracker.finish")


## Bu koşuda açılanlar, açılış sırası.
func run_unlocked() -> Array[StringName]:
	Stub.todo(&"AchievementTracker.run_unlocked")
	return []


## Güncel sayaç (total: store + koşu, run: koşu).
func value_of(_stat: StringName) -> int:
	Stub.todo(&"AchievementTracker.value_of")
	return 0


## İlerleme kaynağı varsa değer, yoksa -1 (ekran "TEK KOŞU").
func progress(_def: AchievementDef) -> int:
	Stub.todo(&"AchievementTracker.progress")
	return -1


## store.dirty ise save(); yoksa true.
func flush() -> bool:
	Stub.todo(&"AchievementTracker.flush")
	return true
