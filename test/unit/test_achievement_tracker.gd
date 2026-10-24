extends GutTest
## AchievementTracker + AchievementProgress (B2): olay -> sayaç -> açılış hattı. Sentetik SimBus olayları;
## her stat için AYRI test işlevi (hangi stat kırıldığı görünsün). Gerçek sim yolu B-tur kabul testlerindedir.

const PATH := "user://test_ach_tracker.json"
const T0 := 1761270000

var _data: GameData
var _store: AchievementStore
var _bus: SimBus
var _tr: AchievementTracker
var _opened: Array[StringName] = []
var _now: int = T0


func before_each() -> void:
	_data = GameData.load_default()
	_store = AchievementStore.new(PATH)
	_bus = SimBus.new()
	_opened = []
	_now = T0
	_tr = _make()
	_tr.attach(_bus)


func after_each() -> void:
	for suffix in ["", ".tmp", ".bad"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _make(char_id: StringName = &"gunslinger") -> AchievementTracker:
	var tr := AchievementTracker.new(_data, _store, char_id, func() -> int: return _now)
	tr.unlocked.connect(func(d: AchievementDef) -> void: _opened.append(d.id))
	return tr


func _kill(n: int, type_id: StringName = &"curumus_piyade") -> void:
	for _i in n:
		_bus.enemy_killed.emit(type_id, Vector2.ZERO)


## Stat için hedefi (ilk tanım) döndürür.
func _target(id: StringName) -> int:
	return _data.get_achievement(id).target


func _assert_one_shot(id: StringName, below: Callable, reach: Callable) -> void:
	below.call()
	assert_false(_store.is_unlocked(id), "%s: hedef-1 açmaz" % id)
	reach.call()
	assert_true(_store.is_unlocked(id), "%s: hedefte açar" % id)
	assert_eq(_store.unlocked_at(id), T0)
	var n := _opened.count(id)
	reach.call()
	assert_eq(_opened.count(id), n, "%s: ikinci kez açmaz" % id)
	assert_eq(n, 1)


func _fake_sim(time: float) -> GameSim:
	var sim := SimKit.make(1, {"log_events": false})
	sim.time = time
	return sim


# --- yapı ----------------------------------------------------------------------------------------


func test_stat_index_constants_match_stats_order() -> void:
	var names := {
		"total_kills": AchievementTracker.S_TOTAL_KILLS,
		"total_runs": AchievementTracker.S_TOTAL_RUNS,
		"total_wins": AchievementTracker.S_TOTAL_WINS,
		"total_play_secs": AchievementTracker.S_TOTAL_PLAY_SECS,
		"total_chars5": AchievementTracker.S_TOTAL_CHARS5,
		"run_kills": AchievementTracker.S_RUN_KILLS,
		"run_time": AchievementTracker.S_RUN_TIME,
		"run_level": AchievementTracker.S_RUN_LEVEL,
		"run_score": AchievementTracker.S_RUN_SCORE,
		"run_reloads": AchievementTracker.S_RUN_RELOADS,
		"run_active_slots": AchievementTracker.S_RUN_ACTIVE_SLOTS,
		"run_best_mult": AchievementTracker.S_RUN_BEST_MULT,
		"run_elit_piyade": AchievementTracker.S_RUN_ELIT_PIYADE,
		"run_elite_kinds": AchievementTracker.S_RUN_ELITE_KINDS,
		"run_pickups": AchievementTracker.S_RUN_PICKUPS,
		"run_clean_secs": AchievementTracker.S_RUN_CLEAN_SECS,
		"run_evolutions": AchievementTracker.S_RUN_EVOLUTIONS,
		"run_unlimited_kills": AchievementTracker.S_RUN_UNLIMITED_KILLS,
		"run_won": AchievementTracker.S_RUN_WON,
		"run_bomb_hits": AchievementTracker.S_RUN_BOMB_HITS,
	}
	assert_eq(names.size(), AchievementDef.STATS.size())
	for n in names:
		assert_eq(AchievementDef.STATS.find(n), names[n], n)


func test_every_real_stat_is_handled_by_the_tracker() -> void:
	# Gerçek 22 kaydın her stat'ı için tracker bir kaynağa sahip (kapalı küme ile uyum).
	for def in _data.achievements:
		assert_true(AchievementDef.STATS.has(String(def.stat)), String(def.id))


func test_double_attach_binds_once() -> void:
	_tr.attach(_bus)
	_kill(3)
	assert_eq(_store.totals["kills"], 3, "olay çift sayılmaz")


func test_detach_stops_events() -> void:
	_tr.detach()
	_kill(5)
	assert_eq(_store.totals["kills"], 0)
	_tr.detach()  # ikinci detach güvenli


func test_events_after_finish_are_ignored() -> void:
	_tr.finish(false, {"time": 10})
	_kill(5)
	assert_eq(_store.totals["kills"], 0)


# --- stat başına testler ---------------------------------------------------------------------------


func test_b2_total_kills() -> void:
	_assert_one_shot(&"ilk_kan", func() -> void: pass, func() -> void: _kill(1))
	var big := _target(&"kalabalik_kesici")
	_store.add_total(&"kills", big - 2 - _store.totals["kills"])
	_kill(1)
	assert_false(_store.is_unlocked(&"kalabalik_kesici"), "hedef-1")
	_kill(1)
	assert_true(_store.is_unlocked(&"kalabalik_kesici"))
	assert_true(_store.dirty, "depoya anında işlenir, diske yazılmaz")
	assert_false(FileAccess.file_exists(PATH))


func test_b2_total_runs() -> void:
	_store.add_total(&"runs", _target(&"yerlesik") - 2)
	_tr.finish(false, {"time": 5})
	assert_false(_store.is_unlocked(&"yerlesik"))
	_tr = _make()
	_tr.finish(false, {"time": 5})
	assert_true(_store.is_unlocked(&"yerlesik"))
	assert_eq(_opened.count(&"yerlesik"), 1)
	_tr = _make()
	_tr.finish(false, {"time": 5})
	assert_eq(_opened.count(&"yerlesik"), 1, "ikinci kez açmaz")


func test_b2_total_wins_and_play_secs_accumulate_without_def() -> void:
	# Gerçek veride total_wins / total_play_secs tanımı yok: sayaç yine depoda toplanır.
	_tr.finish(true, {"time": 90})
	assert_eq(_store.totals["wins"], 1)
	assert_eq(_store.totals["play_secs"], 90)
	assert_eq(_tr.value_of(&"total_wins"), 1)
	assert_eq(_tr.value_of(&"total_play_secs"), 90)


func test_b2_total_chars5() -> void:
	var tr_a := _make(&"gunslinger")
	tr_a.finish(false, {"time": 299})
	assert_eq(_store.chars5.size(), 0, "300 sn altı sayılmaz")
	tr_a = _make(&"gunslinger")
	tr_a.finish(false, {"time": 300})
	assert_eq(_store.chars5.size(), 1)
	assert_false(_store.is_unlocked(&"cifte_yol"))
	var tr_b := _make(&"gunslinger")
	tr_b.finish(false, {"time": 400})
	assert_false(_store.is_unlocked(&"cifte_yol"), "aynı karakter iki kez sayılmaz")
	var tr_c := _make(&"barutcu")
	tr_c.finish(false, {"time": 400})
	assert_true(_store.is_unlocked(&"cifte_yol"))
	assert_eq(_opened.count(&"cifte_yol"), 1)


func test_b2_run_kills() -> void:
	_assert_one_shot(
		&"kirim", func() -> void: _kill(_target(&"kirim") - 1), func() -> void: _kill(1)
	)


func test_b2_run_time() -> void:
	var sim := _fake_sim(0.0)
	sim.time = 299.99
	_tr.poll(sim)
	assert_false(_store.is_unlocked(&"bes_dakika"))
	sim.time = 300.0
	_tr.poll(sim)
	assert_true(_store.is_unlocked(&"bes_dakika"))
	sim.time = 600.0
	_tr.poll(sim)
	assert_true(_store.is_unlocked(&"on_dakika"))
	sim.time = 900.0
	_tr.poll(sim)
	assert_true(_store.is_unlocked(&"on_bes_dakika"))
	assert_eq(_opened.count(&"bes_dakika"), 1)
	_tr.poll(sim)
	assert_eq(_opened.count(&"on_bes_dakika"), 1)


func test_b2_run_time_from_finish_stats() -> void:
	_tr.finish(false, {"time": 300.4})
	assert_true(_store.is_unlocked(&"bes_dakika"))
	assert_eq(_store.best["time"], 300)


func test_b2_run_level() -> void:
	_assert_one_shot(
		&"seviye_10",
		func() -> void: _bus.level_up.emit(_target(&"seviye_10") - 1),
		func() -> void: _bus.level_up.emit(_target(&"seviye_10"))
	)
	assert_false(_store.is_unlocked(&"seviye_20"))
	_bus.level_up.emit(_target(&"seviye_20"))
	assert_true(_store.is_unlocked(&"seviye_20"))


func test_b2_run_score() -> void:
	_assert_one_shot(
		&"skor_100k",
		func() -> void: _bus.score_changed.emit(_target(&"skor_100k") - 1, 1, 5),
		func() -> void: _bus.score_changed.emit(_target(&"skor_100k"), 1, 5)
	)


func test_b2_run_reloads() -> void:
	_assert_one_shot(
		&"tambur_ustasi",
		func() -> void:
			for _i in _target(&"tambur_ustasi") - 1:
				_bus.reload_started.emit(1.0),
		func() -> void: _bus.reload_started.emit(1.0)
	)


func _fill_actives(sim: GameSim, count: int) -> void:
	for sid in _data.skill_ids:
		if sim.loadout.actives().size() >= count:
			return
		if _data.get_skill(sid).kind == SkillDef.KIND_ACTIVE:
			sim.loadout.add_or_upgrade(sid)


func test_b2_run_active_slots() -> void:
	var sim := _fake_sim(1.0)
	_fill_actives(sim, 5)
	assert_eq(sim.loadout.actives().size(), 5)
	_tr.poll(sim)
	assert_eq(_tr.value_of(&"run_active_slots"), 5)
	assert_false(_store.is_unlocked(&"alti_silah"), "hedef-1 açmaz")
	_fill_actives(sim, 6)
	assert_eq(sim.loadout.actives().size(), 6)
	_tr.poll(sim)
	assert_true(_store.is_unlocked(&"alti_silah"), "hedefte açar")
	_tr.poll(sim)
	assert_eq(_opened.count(&"alti_silah"), 1, "ikinci kez açmaz")


func test_b2_run_best_mult() -> void:
	_assert_one_shot(
		&"seri_ustasi",
		func() -> void:
			_bus.streak_changed.emit(_target(&"seri_ustasi") - 1, 2.0),
		func() -> void: _bus.streak_changed.emit(_target(&"seri_ustasi"), 2.0)
	)
	_bus.streak_changed.emit(1, 0.0)
	assert_eq(_tr.value_of(&"run_best_mult"), _target(&"seri_ustasi"), "en iyi çarpan düşmez")


func test_b2_run_elit_piyade() -> void:
	_kill(1, &"elit_sovalye")
	_kill(1, &"curumus_piyade")
	assert_false(_store.is_unlocked(&"piyade_avcisi"))
	_kill(1, &"elit_piyade")
	assert_true(_store.is_unlocked(&"piyade_avcisi"))
	_kill(1, &"elit_piyade")
	assert_eq(_opened.count(&"piyade_avcisi"), 1)


func test_b2_run_elite_kinds_same_kind_twice_counts_once() -> void:
	_kill(1, &"elit_piyade")
	_kill(1, &"elit_piyade")
	_kill(1, &"elit_sovalye")
	assert_eq(_tr.value_of(&"run_elite_kinds"), 2)
	assert_false(_store.is_unlocked(&"uc_elit"), "hedef-1")
	_kill(1, &"elit_karga")
	assert_eq(_tr.value_of(&"run_elite_kinds"), 3)
	assert_true(_store.is_unlocked(&"uc_elit"))
	_kill(1, &"elit_karga")
	assert_eq(_opened.count(&"uc_elit"), 1)


func test_b2_run_pickups() -> void:
	_assert_one_shot(
		&"eklenti_avcisi",
		func() -> void:
			for _i in _target(&"eklenti_avcisi") - 1:
				_bus.pickup_collected.emit(&"yenilenme", Vector2.ZERO),
		func() -> void: _bus.pickup_collected.emit(&"kara_bomba", Vector2.ZERO)
	)


func test_b2_run_clean_secs_freezes_at_first_damage() -> void:
	var sim := _fake_sim(0.0)
	sim.time = 179.98
	_tr.poll(sim)
	assert_false(_store.is_unlocked(&"dokunulmaz"), "179.98 açmaz")
	sim.time = 180.0
	_tr.poll(sim)
	assert_true(_store.is_unlocked(&"dokunulmaz"), "180.0 açar")
	assert_eq(_opened.count(&"dokunulmaz"), 1)
	_tr.poll(sim)
	assert_eq(_opened.count(&"dokunulmaz"), 1)


func test_b2_run_clean_secs_damage_freezes_value() -> void:
	var sim := _fake_sim(0.0)
	sim.time = 100.0
	_tr.poll(sim)
	_bus.player_damaged.emit(5.0, 95.0)
	sim.time = 200.0
	_tr.poll(sim)
	assert_eq(_tr.value_of(&"run_clean_secs"), 100, "hasardan sonra donar")
	assert_false(_store.is_unlocked(&"dokunulmaz"))
	assert_eq(_tr.value_of(&"run_time"), 200, "koşu süresi akar")


func test_b2_run_evolutions() -> void:
	_assert_one_shot(
		&"ilk_evrim",
		func() -> void: pass,
		func() -> void: _bus.evolution_gained.emit(&"evrim_x")
	)


func test_b2_run_unlimited_kills_flag_semantics() -> void:
	var target := _target(&"sinirsiz_kirim")
	_kill(20)  # etkin değilken sayılmaz
	assert_eq(_tr.value_of(&"run_unlimited_kills"), 0)
	_bus.buff_started.emit(&"unlimited", 6.0)
	_kill(40)
	_bus.buff_started.emit(&"unlimited", 6.0)  # yenileme: sayaç sürer
	assert_eq(_tr.value_of(&"run_unlimited_kills"), 40, "yenilemede sıfırlanmaz")
	_kill(target - 41)
	assert_false(_store.is_unlocked(&"sinirsiz_kirim"), "hedef-1")
	_kill(1)
	assert_true(_store.is_unlocked(&"sinirsiz_kirim"))
	assert_eq(_opened.count(&"sinirsiz_kirim"), 1)


func test_b2_run_unlimited_kills_reset_on_new_activation() -> void:
	_bus.buff_started.emit(&"unlimited", 6.0)
	_kill(30)
	_bus.buff_ended.emit(&"unlimited")
	_kill(30)
	assert_eq(_tr.value_of(&"run_unlimited_kills"), 30, "bitişten sonra sayılmaz")
	_bus.buff_started.emit(&"unlimited", 6.0)
	assert_eq(_tr.value_of(&"run_unlimited_kills"), 0, "yeni etkinleşmede sıfırlanır")
	_kill(5)
	assert_eq(_tr.value_of(&"run_unlimited_kills"), 5)


func test_b2_run_unlimited_ignores_other_buffs() -> void:
	_bus.buff_started.emit(&"damage", 6.0)
	_kill(10)
	assert_eq(_tr.value_of(&"run_unlimited_kills"), 0)
	_bus.buff_started.emit(&"unlimited", 6.0)
	_bus.buff_ended.emit(&"damage")
	_kill(3)
	assert_eq(_tr.value_of(&"run_unlimited_kills"), 3, "başka etkinin bitişi bayrağı değiştirmez")


func test_b2_run_won() -> void:
	_tr.finish(false, {"time": 100})
	assert_false(_store.is_unlocked(&"kale_lordu_devrildi"))
	_tr = _make()
	_tr.finish(true, {"time": 1200})
	assert_true(_store.is_unlocked(&"kale_lordu_devrildi"))
	_tr = _make()
	_tr.finish(true, {"time": 1200})
	assert_eq(_opened.count(&"kale_lordu_devrildi"), 1)


func test_b2_run_bomb_hits_is_max_of_single_bomb() -> void:
	var target := _target(&"bomba_ustasi")
	_bus.bomb_hits.emit(Vector2.ZERO, 100.0, target - 1)
	_bus.bomb_hits.emit(Vector2.ZERO, 100.0, 5)
	assert_false(_store.is_unlocked(&"bomba_ustasi"), "bombalar toplanmaz, en yüksek tek isabet")
	_bus.bomb_hits.emit(Vector2.ZERO, 100.0, target)
	assert_true(_store.is_unlocked(&"bomba_ustasi"))
	_bus.bomb_hits.emit(Vector2.ZERO, 100.0, target + 3)
	assert_eq(_opened.count(&"bomba_ustasi"), 1)


# --- finish / depo / ilerleme / okunabilirlik ---------------------------------------------------------


func test_finish_writes_totals_best_and_chars5() -> void:
	_tr.finish(true, {"time": 650, "level": 12, "score": 4200})
	assert_eq(_store.totals["runs"], 1)
	assert_eq(_store.totals["wins"], 1)
	assert_eq(_store.totals["play_secs"], 650)
	assert_eq([_store.best["score"], _store.best["time"], _store.best["level"]], [4200, 650, 12])
	assert_eq(_store.chars5, PackedStringArray(["gunslinger"]))


func test_second_finish_is_noop() -> void:
	_tr.finish(true, {"time": 650, "level": 12, "score": 4200})
	var runs: int = _store.totals["runs"]
	_tr.finish(true, {"time": 650, "level": 12, "score": 4200})
	assert_eq(_store.totals["runs"], runs)
	assert_eq(_store.totals["play_secs"], 650)


func test_finish_tolerates_missing_or_bad_stats() -> void:
	_tr.finish(false, {"time": "x", "level": NAN, "score": null})
	assert_eq(_store.totals["runs"], 1)
	assert_eq(_store.totals["play_secs"], 0)


func test_unlocks_do_not_write_disk() -> void:
	_kill(1)
	assert_true(_store.is_unlocked(&"ilk_kan"))
	assert_true(_store.dirty)
	assert_false(FileAccess.file_exists(PATH))
	assert_true(_tr.flush())
	assert_true(FileAccess.file_exists(PATH))
	assert_false(_store.dirty)


func test_flush_without_dirty_does_not_write() -> void:
	assert_true(_tr.flush())
	assert_false(FileAccess.file_exists(PATH))


func test_run_unlocked_in_open_order() -> void:
	_kill(1)
	_bus.evolution_gained.emit(&"x")
	assert_eq(_tr.run_unlocked(), [&"ilk_kan", &"ilk_evrim"] as Array[StringName])


func test_clock_zero_or_negative_falls_back_to_one() -> void:
	_now = 0
	_kill(1)
	assert_eq(_store.unlocked_at(&"ilk_kan"), 1)
	_store.unlocked.erase(&"ilk_kan")
	_now = -50
	_tr = _make()
	_tr.attach(_bus)
	_kill(1)
	assert_eq(_store.unlocked_at(&"ilk_kan"), 1)


func test_unlock_keeps_first_unix_across_trackers() -> void:
	_kill(1)
	_now = T0 + 999
	var tr2 := _make()
	tr2.attach(_bus)
	_kill(1)
	assert_eq(_store.unlocked_at(&"ilk_kan"), T0)


func test_progress_mapping() -> void:
	_store.add_total(&"kills", 34)
	_store.add_total(&"runs", 3)
	_store.note_best(900, 120, 4)
	_store.note_char5(&"gunslinger")
	assert_eq(_tr.progress(_data.get_achievement(&"kalabalik_kesici")), 34)
	assert_eq(_tr.progress(_data.get_achievement(&"yerlesik")), 3)
	assert_eq(_tr.progress(_data.get_achievement(&"cifte_yol")), 1)
	assert_eq(_tr.progress(_data.get_achievement(&"bes_dakika")), 120)
	assert_eq(_tr.progress(_data.get_achievement(&"seviye_10")), 4)
	assert_eq(_tr.progress(_data.get_achievement(&"skor_100k")), 900)
	for id in [&"kirim", &"tambur_ustasi", &"alti_silah", &"seri_ustasi", &"ilk_evrim", &"kale_lordu_devrildi"]:
		assert_eq(_tr.progress(_data.get_achievement(id)), -1, String(id))


func test_progress_includes_running_run_values() -> void:
	_bus.level_up.emit(7)
	assert_eq(_tr.progress(_data.get_achievement(&"seviye_10")), 7)


func test_progress_of_is_store_only_and_null_safe() -> void:
	_store.add_total(&"kills", 5)
	assert_eq(AchievementProgress.of(_data.get_achievement(&"kalabalik_kesici"), _store), 5)
	assert_eq(AchievementProgress.of(null, _store), -1)
	assert_eq(AchievementProgress.of(_data.get_achievement(&"ilk_kan"), null), -1)


func test_poll_does_not_mutate_actives() -> void:
	var sim := _fake_sim(1.0)
	var before: Array[SkillState] = sim.loadout.actives()
	var snapshot := before.duplicate()
	_tr.poll(sim)
	_tr.poll(sim)
	var after: Array[SkillState] = sim.loadout.actives()
	assert_true(after == before, "aynı dizi nesnesi")
	assert_eq(after, snapshot, "içerik aynı")


func test_poll_ignores_null_sim_and_finished() -> void:
	_tr.poll(null)
	var sim := _fake_sim(400.0)
	_tr.finish(false, {"time": 10})
	_tr.poll(sim)
	assert_false(_store.is_unlocked(&"bes_dakika"))


func test_tracker_with_empty_achievement_list_is_inert() -> void:
	var empty := GameData.new()
	var tr := AchievementTracker.new(empty, _store, &"gunslinger")
	var bus := SimBus.new()
	tr.attach(bus)
	bus.enemy_killed.emit(&"x", Vector2.ZERO)
	assert_eq(tr.run_unlocked().size(), 0)
