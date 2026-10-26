extends GutTest
## v2.0.3 C: aile/kademe izleme (gerçek 19 aile verisi): kademe atlama, çoklu eşik = tek bildirim, boss sayacı, koşu en iyileri.

const T0 := 1761270000

var _data: GameData
var _store: AchievementStore
var _bus: SimBus
var _tr: AchievementTracker
var _opened: Array[StringName] = []


func before_each() -> void:
	_data = GameData.load_dir("res://data")
	_store = AchKit.store()
	_bus = SimBus.new()
	_opened = []
	_tr = AchievementTracker.new(_data, _store, &"gunslinger", AchKit.clock(T0))
	_tr.unlocked.connect(func(d: AchievementDef) -> void: _opened.append(d.id))
	_tr.attach(_bus)


func after_each() -> void:
	AchKit.cleanup()


func _kill(n: int, type_id: StringName = &"curumus_piyade") -> void:
	AchKit.kills(_bus, n, type_id)


func test_reaper_steps_open_at_1_250_2500() -> void:
	_kill(1)
	assert_eq(_store.step_count(&"reaper"), 1)
	_kill(248)
	assert_eq(_store.step_count(&"reaper"), 1, "249 öldürme")
	_kill(1)
	assert_eq(_store.step_count(&"reaper"), 2, "250. düşman")
	assert_eq(_store.step_unix(&"reaper", 2), T0)
	assert_eq(_opened, [&"reaper", &"reaper"], "her kademe bir bildirim")
	assert_eq(_tr.run_new_steps(), 2)
	assert_eq(_tr.run_unlocked(), [&"reaper"], "aile bir kez listelenir")


func test_two_thresholds_in_one_check_emit_once_with_highest_step() -> void:
	_store.totals["kills"] = 2499
	_kill(1)
	assert_eq(_store.step_count(&"reaper"), 3, "1, 250 ve 2500 birden")
	assert_eq(_opened.count(&"reaper"), 1, "tek bildirim")
	assert_eq(_tr.run_new_steps(), 3)
	for k in 3:
		assert_eq(_store.step_unix(&"reaper", k + 1), T0)


func test_finish_with_long_run_grants_all_time_steps_in_one_signal() -> void:
	_tr.finish(false, {"time": 700, "level": 3, "score": 10})
	assert_eq(_store.step_count(&"endure"), 2, "300 ve 600 sn")
	assert_eq(_opened.count(&"endure"), 1)


func test_step_is_never_lowered_by_a_smaller_value() -> void:
	_store.unlock_step(&"reaper", 3, T0 - 100)
	_kill(1)
	assert_eq(_store.step_count(&"reaper"), 3)
	assert_eq(_opened.count(&"reaper"), 0)


func test_elite_kill_feeds_boss_counter_and_bossbane() -> void:
	_kill(1)
	assert_eq(int(_store.totals["boss_kills"]), 0, "sıradan düşman sayılmaz")
	_kill(1, &"elit_piyade")
	assert_eq(int(_store.totals["boss_kills"]), 1)
	assert_eq(_store.step_count(&"bossbane"), 1)
	_kill(9, &"elit_karga")
	assert_eq(_store.step_count(&"bossbane"), 2, "10. elit")
	assert_eq(_tr.value_of(&"total_boss_kills"), 10)


func test_elite_trio_is_a_single_step_family() -> void:
	for t in [&"elit_piyade", &"elit_sovalye", &"elit_karga"]:
		_kill(1, t)
	assert_eq(_store.step_count(&"elite_trio"), 1)


func test_finish_persists_run_bests_and_progress_reads_them() -> void:
	_kill(412)
	_bus.reload_started.emit(1.0)
	_bus.reload_started.emit(1.0)
	_tr.finish(false, {"time": 200, "level": 4, "score": 5000})
	assert_eq(int(_store.best["kills"]), 412)
	assert_eq(int(_store.best["reloads"]), 2)
	var rampage := _data.get_achievement(&"rampage")
	assert_eq(AchievementProgress.of(rampage, _store), 412)
	assert_eq(_tr.progress(rampage), 412)
	assert_eq(_store.step_count(&"rampage"), 0, "412 < 500")


func test_progress_merges_live_run_value_before_finish() -> void:
	_kill(120)
	assert_eq(_tr.progress(_data.get_achievement(&"rampage")), 120)
	assert_eq(_tr.progress(_data.get_achievement(&"reaper")), 120)


func test_total_wins_family_lordslayer_uses_win_counter() -> void:
	_tr.finish(true, {"time": 1300, "level": 12, "score": 1})
	assert_eq(_store.step_count(&"lordslayer"), 1)
	assert_eq(_store.step_count(&"garrison"), 0, "tek koşu < 10")
	assert_eq(_store.step_count(&"endure"), 4, "1200 sn dahil 4 kademe")


func test_best_stats_without_a_source_report_minus_one() -> void:
	var legacy := AchKit.legacy_data()
	assert_eq(AchievementProgress.of(legacy.get_achievement(&"kale_lordu_devrildi"), _store), -1)
	assert_eq(AchievementProgress.of(legacy.get_achievement(&"piyade_avcisi"), _store), -1)
