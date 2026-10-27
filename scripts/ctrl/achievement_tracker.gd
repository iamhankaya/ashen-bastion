class_name AchievementTracker
extends RefCounted
## Başarım izleyici: SimBus sinyallerinden sayaç, eşikte `store.unlock`. Sim durumuna YAZMAZ, RNG kullanmaz, diske yazmaz,
## `run_ended` dinlemez (controller `finish(won, stats)` çağırır). Aile/kademe (v2.0.3): `steps` eşiklerini geçince depoya kademe yazar. Olay yolunda tahsis yok: yalnız skaler sayaçlar.
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

## Stat dizinleri (AchievementDef.STATS sırası; testle sabit). Olay yolunda ad araması yok, dizinle O(1).
const S_TOTAL_KILLS := 0
const S_TOTAL_RUNS := 1
const S_TOTAL_WINS := 2
const S_TOTAL_PLAY_SECS := 3
const S_TOTAL_CHARS5 := 4
const S_RUN_KILLS := 5
const S_RUN_TIME := 6
const S_RUN_LEVEL := 7
const S_RUN_SCORE := 8
const S_RUN_RELOADS := 9
const S_RUN_ACTIVE_SLOTS := 10
const S_RUN_BEST_MULT := 11
const S_RUN_ELIT_PIYADE := 12
const S_RUN_ELITE_KINDS := 13
const S_RUN_PICKUPS := 14
const S_RUN_CLEAN_SECS := 15
const S_RUN_EVOLUTIONS := 16
const S_RUN_UNLIMITED_KILLS := 17
const S_RUN_WON := 18
const S_RUN_BOMB_HITS := 19
const S_TOTAL_BOSS_KILLS := 20

const ELIT_PIYADE := &"elit_piyade"
const ELITE_MASKS := {&"elit_piyade": 1, &"elit_sovalye": 2, &"elit_karga": 4}
const UNLIMITED := &"unlimited"
## Elit türü bit maskesi -> tür sayısı (popcount, 3 bit).
const POPCOUNT3: PackedInt32Array = [0, 1, 1, 2, 1, 2, 2, 3]

var data: GameData
var store: AchievementStore
var char_id: StringName = &""
var clock: Callable = Callable()
## v2.1 (K-C5): zorluğa bağlı kural; null = kısıt yok. Kolay'da Lord'a bağlı kademeler olay anında verilmez, toplamlardan
## yalnız runs/play_secs artar (sonradan geri alma yok). Tek kademe verme noktası `_check`, toplamlar `_add_total`.
var rules: AchievementRules = null
var diff: StringName = &"hard"

## Koşu sayaçları (stat dizini -> değer); total_* değerleri depodadır.
var _run: PackedInt32Array = PackedInt32Array()
## stat dizini -> tanım indeksleri (`data.achievements`).
var _by_stat: Array[PackedInt32Array] = []
var _bus: SimBus = null
var _elite_mask: int = 0
var _unlimited_active: bool = false
var _damaged: bool = false
var _finished: bool = false
var _run_unlocked: Array[StringName] = []
var _run_steps: int = 0
## [stat dizini, best anahtarı]: `finish` koşu en iyilerini depoya yazar.
var _best_pairs: Array = []


## p_clock: () -> int unix (varsayılan Time.get_unix_time_from_system; testte enjekte; dönüş < 1 ise 1 kullanılır).
## p_rules/p_diff: v2.1 zorluk kuralı (V21Runs.achievement_rules / diff_of); verilmezse kısıt yok.
func _init(
	p_data: GameData,
	p_store: AchievementStore,
	p_char_id: StringName,
	p_clock: Callable = Callable(),
	p_rules: AchievementRules = null,
	p_diff: StringName = &"hard"
) -> void:
	data = p_data
	store = p_store
	char_id = p_char_id
	clock = p_clock
	rules = p_rules
	diff = p_diff
	_run.resize(AchievementDef.STATS.size())
	for _i in AchievementDef.STATS.size():
		_by_stat.append(PackedInt32Array())
	for stat: String in AchievementDef.BEST_KEY:
		_best_pairs.append([AchievementDef.STATS.find(stat), AchievementDef.BEST_KEY[stat]])
	if data != null:
		for i in data.achievements.size():
			var si := AchievementDef.STATS.find(String(data.achievements[i].stat))
			if si >= 0:
				_by_stat[si].append(i)


## YALNIZ dinleme (run_ended HARİÇ); ikinci çağrı önce detach.
func attach(bus: SimBus) -> void:
	detach()
	if bus == null:
		return
	_bus = bus
	bus.enemy_killed.connect(_on_enemy_killed)
	bus.level_up.connect(_on_level_up)
	bus.score_changed.connect(_on_score_changed)
	bus.reload_started.connect(_on_reload_started)
	bus.streak_changed.connect(_on_streak_changed)
	bus.pickup_collected.connect(_on_pickup_collected)
	bus.player_damaged.connect(_on_player_damaged)
	bus.evolution_gained.connect(_on_evolution_gained)
	bus.buff_started.connect(_on_buff_started)
	bus.buff_ended.connect(_on_buff_ended)
	bus.bomb_hits.connect(_on_bomb_hits)


func detach() -> void:
	if _bus == null:
		return
	_disconnect(_bus.enemy_killed, _on_enemy_killed)
	_disconnect(_bus.level_up, _on_level_up)
	_disconnect(_bus.score_changed, _on_score_changed)
	_disconnect(_bus.reload_started, _on_reload_started)
	_disconnect(_bus.streak_changed, _on_streak_changed)
	_disconnect(_bus.pickup_collected, _on_pickup_collected)
	_disconnect(_bus.player_damaged, _on_player_damaged)
	_disconnect(_bus.evolution_gained, _on_evolution_gained)
	_disconnect(_bus.buff_started, _on_buff_started)
	_disconnect(_bus.buff_ended, _on_buff_ended)
	_disconnect(_bus.bomb_hits, _on_bomb_hits)
	_bus = null


## SALT OKUR: sim.time, sim.loadout.actives().size(); <= 60 Hz çağrılır.
func poll(sim: GameSim) -> void:
	if _finished or sim == null:
		return
	var secs := int(sim.time)
	if secs > _run[S_RUN_TIME]:
		_run[S_RUN_TIME] = secs
		_check(S_RUN_TIME)
	# Hasar adımı poll'dan önce gelir: ilk hasardan sonra değer son poll'un değerinde donar.
	if not _damaged and secs > _run[S_RUN_CLEAN_SECS]:
		_run[S_RUN_CLEAN_SECS] = secs
		_check(S_RUN_CLEAN_SECS)
	if sim.loadout != null:
		var n := sim.loadout.actives().size()
		if n > _run[S_RUN_ACTIVE_SLOTS]:
			_run[S_RUN_ACTIVE_SLOTS] = n
			_check(S_RUN_ACTIVE_SLOTS)


## Controller çağırır; ikinci çağrı no-op.
func finish(won: bool, stats: Dictionary) -> void:
	if _finished:
		return
	var time := _stat_int(stats, "time")
	var level := _stat_int(stats, "level")
	var score := _stat_int(stats, "score")
	_raise(S_RUN_TIME, time)
	_raise(S_RUN_LEVEL, level)
	_raise(S_RUN_SCORE, score)
	_finished = true  # bundan sonra olaylar ve poll sayılmaz; aşağıdaki kontroller doğrudan çağrılır
	store.add_total(&"runs", 1)
	_check(S_TOTAL_RUNS)
	if won:
		_add_total(&"wins", 1)
		_check(S_TOTAL_WINS)
	store.add_total(&"play_secs", time)
	_check(S_TOTAL_PLAY_SECS)
	store.note_best(score, time, level)
	for pair in _best_pairs:
		store.note_best_key(pair[1], _run[pair[0]])
	if time >= 300 and _counts(&"chars5"):
		store.note_char5(char_id)
		_check(S_TOTAL_CHARS5)
	if won:
		_run[S_RUN_WON] = 1
		_check(S_RUN_WON)


## Bu koşuda kademe kazanan aileler, ilk kazanış sırası (aile başına bir kez).
func run_unlocked() -> Array[StringName]:
	return _run_unlocked.duplicate()


## Bu koşuda kazanılan toplam kademe (sonuç ekranı "YENİ KADEME · N").
func run_new_steps() -> int:
	return _run_steps


## Güncel sayaç (total: depo, run: koşu).
func value_of(stat: StringName) -> int:
	var si := AchievementDef.STATS.find(String(stat))
	return _value(si) if si >= 0 else 0


## İlerleme kaynağı varsa değer, yoksa -1 (ekran "TEK KOŞU"). Devam eden koşu `best` ile birleşir.
func progress(def: AchievementDef) -> int:
	var base := AchievementProgress.of(def, store)
	if base < 0:
		return -1
	var s := String(def.stat)
	if AchievementDef.BEST_KEY.has(s):
		return maxi(base, _run[AchievementDef.STATS.find(s)])
	return base


## store.dirty ise save(); yoksa true.
func flush() -> bool:
	if store == null or not store.dirty:
		return true
	return store.save()


# --- olaylar (tahsissiz) ------------------------------------------------------------------------


func _on_enemy_killed(type_id: StringName, _pos: Vector2) -> void:
	if _finished:
		return
	_add_total(&"kills", 1)
	_check(S_TOTAL_KILLS)
	_run[S_RUN_KILLS] += 1
	_check(S_RUN_KILLS)
	var mask: int = ELITE_MASKS.get(type_id, 0)
	if mask != 0:
		_add_total(&"boss_kills", 1)
		_check(S_TOTAL_BOSS_KILLS)
		if type_id == ELIT_PIYADE:
			_run[S_RUN_ELIT_PIYADE] += 1
			_check(S_RUN_ELIT_PIYADE)
		if _elite_mask & mask == 0:
			_elite_mask |= mask
			_run[S_RUN_ELITE_KINDS] = POPCOUNT3[_elite_mask]
			_check(S_RUN_ELITE_KINDS)
	if _unlimited_active:
		_run[S_RUN_UNLIMITED_KILLS] += 1
		_check(S_RUN_UNLIMITED_KILLS)


func _on_level_up(level: int) -> void:
	_raise(S_RUN_LEVEL, level)


func _on_score_changed(score: int, _mult: int, _gain: int) -> void:
	_raise(S_RUN_SCORE, score)


func _on_reload_started(_duration: float) -> void:
	if _finished:
		return
	_run[S_RUN_RELOADS] += 1
	_check(S_RUN_RELOADS)


func _on_streak_changed(mult: int, _left: float) -> void:
	_raise(S_RUN_BEST_MULT, mult)


func _on_pickup_collected(_kind_id: StringName, _pos: Vector2) -> void:
	if _finished:
		return
	_run[S_RUN_PICKUPS] += 1
	_check(S_RUN_PICKUPS)


func _on_player_damaged(_amount: float, _hp: float) -> void:
	_damaged = true


func _on_evolution_gained(_evo_id: StringName) -> void:
	if _finished:
		return
	_run[S_RUN_EVOLUTIONS] += 1
	_check(S_RUN_EVOLUTIONS)


## Yenilemede de yayınlanır (sinyal `fresh` taşımaz): bayrak zaten açıksa hiçbir şey yapılmaz.
func _on_buff_started(kind: StringName, _duration: float) -> void:
	if kind == UNLIMITED and not _unlimited_active:
		_unlimited_active = true
		_run[S_RUN_UNLIMITED_KILLS] = 0


func _on_buff_ended(kind: StringName) -> void:
	if kind == UNLIMITED:
		_unlimited_active = false


func _on_bomb_hits(_pos: Vector2, _radius: float, hits: int) -> void:
	_raise(S_RUN_BOMB_HITS, hits)


# --- iç ------------------------------------------------------------------------------------------


func _raise(si: int, v: int) -> void:
	if _finished or v <= _run[si]:
		return
	_run[si] = v
	_check(si)


## Değeri değişen stat için: eşiği geçen ve henüz kayıtlı olmayan kademeleri açar. Aynı denetimde birden çok eşik
## geçilirse tek `unlocked` yayınlanır (en yüksek kademe); kademe asla geri alınmaz.
func _check(si: int) -> void:
	var idxs := _by_stat[si]
	if idxs.is_empty():
		return
	var v := _value(si)
	for i in idxs:
		var def: AchievementDef = data.achievements[i]
		var have := store.step_count(def.id)
		var reached := mini(AchievementStep.reached(def, v), AchievementStep.total(def))
		if reached > have and rules != null:
			reached = _allowed_upto(def.id, have, reached)
		if reached > have and store.unlock_step(def.id, reached, _now()):
			_run_steps += reached - have
			if not _run_unlocked.has(def.id):
				_run_unlocked.append(def.id)
			unlocked.emit(def)


## Kademeler ardışık verilir: (have, reached] içinde zorlukta kapalı ilk kademeden önceki sayı.
func _allowed_upto(id: StringName, have: int, reached: int) -> int:
	for k in range(have + 1, reached + 1):
		if not rules.allows(AchievementRules.tier_id(id, k), diff):
			return k - 1
	return reached


func _counts(key: StringName) -> bool:
	return rules == null or rules.counts_total(key, diff)


func _add_total(key: StringName, n: int) -> void:
	if _counts(key):
		store.add_total(key, n)


func _value(si: int) -> int:
	match si:
		S_TOTAL_KILLS:
			return int(store.totals["kills"])
		S_TOTAL_RUNS:
			return int(store.totals["runs"])
		S_TOTAL_WINS:
			return int(store.totals["wins"])
		S_TOTAL_PLAY_SECS:
			return int(store.totals["play_secs"])
		S_TOTAL_CHARS5:
			return store.chars5.size()
		S_TOTAL_BOSS_KILLS:
			return int(store.totals["boss_kills"])
	return _run[si]


func _now() -> int:
	var t: int = int(clock.call()) if clock.is_valid() else int(Time.get_unix_time_from_system())
	return maxi(t, 1)


static func _stat_int(stats: Dictionary, key: String) -> int:
	var v: Variant = stats.get(key, 0)
	if (v is int or v is float) and is_finite(float(v)):
		return maxi(int(v), 0)
	return 0


static func _disconnect(sig: Signal, c: Callable) -> void:
	if sig.is_connected(c):
		sig.disconnect(c)
