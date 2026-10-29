class_name AchievementTracker
extends RefCounted
## Başarım izleyici: SimBus sinyallerinden sayaç, eşikte `store.unlock`. Sim durumuna YAZMAZ, RNG kullanmaz, diske yazmaz,
## `run_ended` dinlemez (controller `finish(won, stats)` çağırır). Aile/kademe (v2.0.3): `steps` eşiklerini geçince depoya kademe yazar. Olay yolunda tahsis yok: yalnız skaler sayaçlar.
## R8: hangi olayın hangi statı nasıl beslediği kodda değil `data/achievements/<stat>.json` kaydındadır (AchievementMetricRegistry):
## yerleşik toplam (sum|max|count, filtreli), poll, finish ya da `AchievementReducer` eklentisi. Aynı olaydaki statlar metriğin `order` sırasıyla işlenir.
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
## Kayıtta olup STATS'ta olmayan statlar bunların ardından, ad sırasıyla eklenir.
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

## Elit/buff sabitleri eklenti reducer'larının kullandığı değerlerdir (EliteKindsReducer, UnlimitedKillsReducer); sınıf yüzeyi (rf_api_surface) için burada kalır.
const ELIT_PIYADE := &"elit_piyade"
const ELITE_MASKS := {&"elit_piyade": 1, &"elit_sovalye": 2, &"elit_karga": 4}
const UNLIMITED := &"unlimited"
## Elit türü bit maskesi -> tür sayısı (popcount, 3 bit).
const POPCOUNT3: PackedInt32Array = [0, 1, 1, 2, 1, 2, 2, 3]

## Kaynak türleri (stat başına).
const _K_NONE := 0
const _K_EVENT := 1
const _K_POLL := 2
const _K_FINISH := 3
const _K_REDUCER := 4
## Birleştirme: 0 toplam (sum|count), 1 en büyük.
const _AGG_SUM := 0
const _AGG_MAX := 1
## `_slot` özel değerleri: olay/finish için sabit 1 ve finish'te result.time; poll için 0 time, 1 active_slots.
const _SLOT_ONE := -1
const _SLOT_RESULT_TIME := -2
const _POLL_TIME := 0
const _POLL_ACTIVE_SLOTS := 1

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
var _finished: bool = false
var _run_unlocked: Array[StringName] = []
var _run_steps: int = 0

## Stat tabloları (hepsi stat dizinli; kayıttan kurulur).
var _stats: PackedStringArray = PackedStringArray()
var _kind: PackedInt32Array = PackedInt32Array()
var _agg: PackedInt32Array = PackedInt32Array()
var _slot: PackedInt32Array = PackedInt32Array()
var _result_key: PackedInt32Array = PackedInt32Array()  # 0 time, 1 level, 2 score, -1 yok
var _when_won: PackedByteArray = PackedByteArray()  # finish kaynağı yalnız kazanınca
var _filter: Array = []  # StringName dizisi; boş = süzgeç yok
var _total_key: Array[StringName] = []
var _total_s: PackedStringArray = PackedStringArray()  # depo `totals` anahtarı ("" = toplam yok)
var _best_s: PackedStringArray = PackedStringArray()  # depo `best` anahtarı ("" = en iyi yok)
var _reducers: Array = []  # stat dizini -> AchievementReducer ya da null
var _rstate: Array = []  # stat dizini -> reducer durum sözlüğü
var _reducer_finish: PackedByteArray = PackedByteArray()
## Olay dizini (LISTENED sırası) -> o olayı işleyen statlar (metrik `order` sırasıyla).
var _ev_stats: Array[PackedInt32Array] = []
var _ev_reducer: PackedByteArray = PackedByteArray()  # olayı dinleyen reducer var mı (payload doldurulur)
var _ev_names: Array[StringName] = []
var _poll_stats: PackedInt32Array = PackedInt32Array()
var _result_stats: PackedInt32Array = PackedInt32Array()
var _finish_stats: PackedInt32Array = PackedInt32Array()
var _best_stats: PackedInt32Array = PackedInt32Array()
## Reducer'a verilen yeniden kullanılan yük ve koşu sonu özeti (anahtarlar sabit, tahsis yok).
var _payload: Dictionary = {}
var _result: Dictionary = {"time": 0, "level": 0, "score": 0, "won": false, "counts_chars5": true}


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
	_build()
	if data != null:
		for i in data.achievements.size():
			var si := _stats.find(String(data.achievements[i].stat))
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
	for si in _poll_stats:
		if _kind[si] == _K_REDUCER:
			(_reducers[si] as AchievementReducer).poll(sim, _rstate[si])
			_sync(si)
		elif _slot[si] == _POLL_TIME:
			_raise(si, int(sim.time))
		elif sim.loadout != null:
			_raise(si, sim.loadout.actives().size())


## Controller çağırır; ikinci çağrı no-op.
func finish(won: bool, stats: Dictionary) -> void:
	if _finished:
		return
	var time := _stat_int(stats, "time")
	var level := _stat_int(stats, "level")
	var score := _stat_int(stats, "score")
	for si in _result_stats:
		match _result_key[si]:
			0:
				_raise(si, time)
			1:
				_raise(si, level)
			2:
				_raise(si, score)
	_finished = true  # bundan sonra olaylar ve poll sayılmaz; aşağıdaki kontroller doğrudan çağrılır
	_result["time"] = time
	_result["level"] = level
	_result["score"] = score
	_result["won"] = won
	_result["counts_chars5"] = _counts(&"chars5")
	for si in _finish_stats:
		_finish_one(si, won, time)
	for si in _best_stats:
		store.note_best_key(StringName(_best_s[si]), _run[si])


## Bu koşuda kademe kazanan aileler, ilk kazanış sırası (aile başına bir kez).
func run_unlocked() -> Array[StringName]:
	return _run_unlocked.duplicate()


## Bu koşuda kazanılan toplam kademe (sonuç ekranı "YENİ KADEME · N").
func run_new_steps() -> int:
	return _run_steps


## Güncel sayaç (total: depo, run: koşu).
func value_of(stat: StringName) -> int:
	var si := _stats.find(String(stat))
	return _value(si) if si >= 0 else 0


## İlerleme kaynağı varsa değer, yoksa -1 (ekran "TEK KOŞU"). Devam eden koşu `best` ile birleşir.
func progress(def: AchievementDef) -> int:
	var base := AchievementProgress.of(def, store)
	if base < 0:
		return -1
	var si := _stats.find(String(def.stat))
	if si >= 0 and _best_s[si] != "":
		return maxi(base, _run[si])
	return base


## store.dirty ise save(); yoksa true.
func flush() -> bool:
	if store == null or not store.dirty:
		return true
	return store.save()


# --- olaylar (tahsissiz) ------------------------------------------------------------------------


func _on_enemy_killed(type_id: StringName, _pos: Vector2) -> void:
	_dispatch(0, type_id, 0, 0, 0)


func _on_level_up(level: int) -> void:
	_dispatch(1, &"", level, 0, 0)


func _on_score_changed(score: int, mult: int, gain: int) -> void:
	_dispatch(2, &"", score, mult, gain)


func _on_reload_started(_duration: float) -> void:
	_dispatch(3, &"", 0, 0, 0)


func _on_streak_changed(mult: int, _left: float) -> void:
	_dispatch(4, &"", mult, 0, 0)


func _on_pickup_collected(kind_id: StringName, _pos: Vector2) -> void:
	_dispatch(5, kind_id, 0, 0, 0)


func _on_player_damaged(_amount: float, _hp: float) -> void:
	_dispatch(6, &"", 0, 0, 0)


func _on_evolution_gained(evo_id: StringName) -> void:
	_dispatch(7, evo_id, 0, 0, 0)


## Yenilemede de yayınlanır (sinyal `fresh` taşımaz): reducer bayrağı zaten açıksa sıfırlamaz.
func _on_buff_started(kind: StringName, _duration: float) -> void:
	_dispatch(8, kind, 0, 0, 0)


func _on_buff_ended(kind: StringName) -> void:
	_dispatch(9, kind, 0, 0, 0)


func _on_bomb_hits(_pos: Vector2, _radius: float, hits: int) -> void:
	_dispatch(10, &"", hits, 0, 0)


## Tek olay girişi: `a/b/c` olayın tamsayı alanları (MetricSchema.EVENTS sırası), `tag` etiket alanı.
func _dispatch(ev: int, tag: StringName, a: int, b: int, c: int) -> void:
	if _finished:
		return
	if _ev_reducer[ev] != 0:
		_fill_payload(ev, tag, a, b, c)
	for si in _ev_stats[ev]:
		if _kind[si] == _K_REDUCER:
			(_reducers[si] as AchievementReducer).on_event(_ev_names[ev], _payload, _rstate[si])
			_sync(si)
			continue
		var flt: Array = _filter[si]
		if not flt.is_empty() and not flt.has(tag):
			continue
		var v := 1
		match _slot[si]:
			0:
				v = a
			1:
				v = b
			2:
				v = c
		_apply(si, v)


# --- iç ------------------------------------------------------------------------------------------


## Olay kaynağından gelen değeri uygular: en büyük ya da toplam (depo toplamı varsa depoya), sonra kademe denetimi.
func _apply(si: int, v: int) -> void:
	if _agg[si] == _AGG_MAX:
		_raise(si, v)
		return
	if _total_s[si] != "":
		_add_total(_total_key[si], v)
	else:
		_run[si] += v
	_check(si)


## Koşu sonu kaynakları (kazanma süzgeci, `_finished` sonrası olduğundan doğrudan yazar).
func _finish_one(si: int, won: bool, time: int) -> void:
	if _kind[si] == _K_REDUCER:
		if _reducer_finish[si] != 0:
			var r := (_reducers[si] as AchievementReducer).finish(_result, _rstate[si])
			if r >= 0:
				_run[si] = r
				_check(si)
		return
	if _when_won[si] != 0 and not won:
		return
	var v := time if _slot[si] == _SLOT_RESULT_TIME else 1
	if _agg[si] == _AGG_MAX:
		_run[si] = maxi(_run[si], v)
	elif _total_s[si] != "":
		_add_total(_total_key[si], v)
	else:
		_run[si] += v
	_check(si)


func _raise(si: int, v: int) -> void:
	if _finished or v <= _run[si]:
		return
	_run[si] = v
	_check(si)


## Reducer değeri değiştiyse koşu sayacına yansıtır; yalnız artışta kademe denetimi (sıfırlama denetim istemez).
func _sync(si: int) -> void:
	var nv := (_reducers[si] as AchievementReducer).value(_rstate[si])
	var old := _run[si]
	if nv == old:
		return
	_run[si] = nv
	if nv > old:
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
	if _total_s[si] != "":
		return int(store.totals[_total_s[si]])
	if _kind[si] == _K_REDUCER:
		return (_reducers[si] as AchievementReducer).value(_rstate[si])
	return _run[si]


func _now() -> int:
	var t: int = int(clock.call()) if clock.is_valid() else int(Time.get_unix_time_from_system())
	return maxi(t, 1)


func _fill_payload(ev: int, tag: StringName, a: int, b: int, c: int) -> void:
	var sig: Dictionary = MetricSchema.EVENTS[LISTENED[ev]]
	if sig["tag"] != "":
		_payload[sig["tag"]] = tag
	var ints: Array = sig["ints"]
	for i in ints.size():
		_payload[ints[i]] = a if i == 0 else (b if i == 1 else c)


# --- kurulum (kayıttan) --------------------------------------------------------------------------


func _build() -> void:
	var reg := AchievementMetricRegistry.default()
	if data != null and not data._stat_metrics.is_empty():
		reg = AchievementMetricRegistry.from_dicts(data._stat_metrics)
	_stats = AchievementDef.STATS.duplicate()
	for s in reg.stats():
		if not _stats.has(s):
			_stats.append(s)
	var n := _stats.size()
	_run.resize(n)
	_kind.resize(n)
	_agg.resize(n)
	_slot.resize(n)
	_result_key.resize(n)
	_when_won.resize(n)
	_reducer_finish.resize(n)
	_result_key.fill(-1)
	_total_s.resize(n)
	_best_s.resize(n)
	for _i in n:
		_by_stat.append(PackedInt32Array())
		_filter.append([])
		_total_key.append(&"")
		_reducers.append(null)
		_rstate.append({})
	_ev_reducer.resize(LISTENED.size())
	for name in LISTENED:
		_ev_stats.append(PackedInt32Array())
		_ev_names.append(StringName(name))
	var ordered: Array = []
	for si in n:
		var m := reg.metric(_stats[si])
		if not m.is_empty():
			ordered.append([int(m.get("order", 1000)), si])
	ordered.sort()
	for pair in ordered:
		var si: int = pair[1]
		_setup_stat(si, reg.metric(_stats[si]))


func _setup_stat(si: int, m: Dictionary) -> void:
	var persist: Dictionary = m.get("persist", {})
	if persist.get("total", null) is String:
		_total_s[si] = persist["total"]
		_total_key[si] = StringName(persist["total"])
	if persist.get("best", null) is String:
		_best_s[si] = persist["best"]
		_best_stats.append(si)
	if m.has("result_max"):
		_result_key[si] = MetricSchema.RESULT_KEYS.find(str(m["result_max"]))
		_result_stats.append(si)
	if m.has("reducer"):
		_setup_reducer(si, m)
		return
	_agg[si] = _AGG_MAX if str(m.get("aggregate", "")) == "max" else _AGG_SUM
	var src: Dictionary = m.get("source", {})
	if src.has("poll"):
		_kind[si] = _K_POLL
		_slot[si] = MetricSchema.POLLS.find(str(src["poll"]))
		_poll_stats.append(si)
	elif src.has("finish"):
		_kind[si] = _K_FINISH
		_when_won[si] = 1 if str(src["finish"]) == "won" else 0
		_slot[si] = _SLOT_RESULT_TIME if str(src.get("value", "")) == "result.time" else _SLOT_ONE
		_finish_stats.append(si)
	else:
		_setup_event(si, src)


func _setup_event(si: int, src: Dictionary) -> void:
	var ev := LISTENED.find(str(src.get("event", "")))
	if ev < 0:
		return
	_kind[si] = _K_EVENT
	var value := str(src.get("value", "one"))
	var ints: Array = MetricSchema.EVENTS[LISTENED[ev]]["ints"]
	_slot[si] = ints.find(value.substr(8)) if value.begins_with("payload.") else _SLOT_ONE
	var flt: Array = []
	for tag_values: Array in (src.get("filter", {}) as Dictionary).values():
		for t in tag_values:
			flt.append(StringName(t))
	_filter[si] = flt
	_ev_stats[ev].append(si)


func _setup_reducer(si: int, m: Dictionary) -> void:
	var path := MetricSchema.script_path(str(m["reducer"]))
	var scr: GDScript = load(path) if path != "" else null
	var obj: Object = scr.new() if scr != null else null
	var rd := obj as AchievementReducer
	if rd == null:
		push_error("AchievementReducer yüklenemedi: %s" % m["reducer"])
		return
	_kind[si] = _K_REDUCER
	_reducers[si] = rd
	var st: Dictionary = {"value": 0, "store": store, "char_id": char_id}
	rd.reset(st)
	_rstate[si] = st
	for e in m.get("events", []):
		var ev := LISTENED.find(str(e))
		if ev >= 0:
			_ev_stats[ev].append(si)
			_ev_reducer[ev] = 1
	if bool(m.get("poll", false)):
		_poll_stats.append(si)
	_reducer_finish[si] = 1 if bool(m.get("finish", false)) else 0
	if bool(m.get("finish", false)):
		_finish_stats.append(si)


static func _stat_int(stats: Dictionary, key: String) -> int:
	var v: Variant = stats.get(key, 0)
	if (v is int or v is float) and is_finite(float(v)):
		return maxi(int(v), 0)
	return 0


static func _disconnect(sig: Signal, c: Callable) -> void:
	if sig.is_connected(c):
		sig.disconnect(c)
