extends GutTest
## Kabul (v2.0 B2): AchievementTracker. Her stat için AYRI test fonksiyonu (hangi stat kırıldığı görünsün): hedef-1 açmaz /
## hedefte açar / ikinci kez açmaz. Sentetik olaylar gerçek SimBus sinyalleri üzerinden gelir (imza uyumu sözleşme
## testinde, gerçek sim yolu B-tur'da). Sözleşme: docs/plan/v2.0-plan.md "Tracker" + stat tablosu. Dilim B bitmeden pending.

const UNLIMITED := &"unlimited"

var _unlock_log: Array[StringName] = []


func after_each() -> void:
	AchKit.cleanup()


func _gate() -> bool:
	return V2Slice.require(self, "B")


## Açılış sinyallerini günlüğe yazar.
func _rig(char_id: StringName = &"gunslinger") -> Dictionary:
	var r := AchKit.rig(char_id)
	_unlock_log.clear()
	var tr: AchievementTracker = r["tracker"]
	tr.unlocked.connect(func(def: AchievementDef) -> void: _unlock_log.append(def.id))
	return r


func _ids(r: Dictionary) -> Array:
	var tr: AchievementTracker = r["tracker"]
	return Array(tr.run_unlocked())


func _has(r: Dictionary, id: String) -> bool:
	return _ids(r).has(StringName(id))


func _stats(time: float = 10.0, level: int = 1, kills: int = 0, score: int = 0) -> Dictionary:
	return {
		"time": time,
		"level": level,
		"kills": kills,
		"evolutions": [],
		"score": score,
		"best_mult": 1,
	}


# --- toplam (total_*) --------------------------------------------------------------------------------------------


func test_b2_total_kills() -> void:
	if _gate():
		return
	var r := _rig()
	var st: AchievementStore = r["store"]
	assert_false(_has(r, "ilk_kan"))
	AchKit.kills(r["bus"], 1)
	assert_true(_has(r, "ilk_kan"), "hedefte açar")
	assert_true(st.is_unlocked(&"ilk_kan"), "mağazaya anında işlenir")
	assert_eq(int(st.totals["kills"]), 1)
	assert_true(st.dirty)
	assert_false(FileAccess.file_exists(st.path), "olay yolu diske yazmaz")
	AchKit.kills(r["bus"], 5)
	assert_eq(_unlock_log.count(&"ilk_kan"), 1, "ikinci kez açılmaz")
	assert_false(_has(r, "kalabalik_kesici"))
	AchKit.kills(r["bus"], 10000 - 6 - 1)
	assert_false(_has(r, "kalabalik_kesici"), "9999: açmaz")
	AchKit.kills(r["bus"], 1)
	assert_true(_has(r, "kalabalik_kesici"), "10000: açar")
	assert_eq(_unlock_log.count(&"kalabalik_kesici"), 1)


func test_b2_total_kills_counts_previous_runs_from_store() -> void:
	if _gate():
		return
	var r := _rig()
	var st: AchievementStore = r["store"]
	st.add_total(&"kills", 9999)
	AchKit.kills(r["bus"], 1)
	assert_true(_has(r, "kalabalik_kesici"), "store + koşu toplamı")
	assert_eq((r["tracker"] as AchievementTracker).value_of(&"total_kills"), 10000)


func test_b2_total_runs() -> void:
	if _gate():
		return
	var r := _rig()
	var st: AchievementStore = r["store"]
	st.add_total(&"runs", 8)
	(r["tracker"] as AchievementTracker).finish(false, _stats())
	assert_false(_has(r, "yerlesik"), "9. koşu: açmaz")
	assert_eq(int(st.totals["runs"]), 9)
	var r2 := _rig()
	(r2["store"] as AchievementStore).add_total(&"runs", 9)
	(r2["tracker"] as AchievementTracker).finish(false, _stats())
	assert_true(_has(r2, "yerlesik"), "10. koşu: açar")
	assert_eq(int((r2["store"] as AchievementStore).totals["runs"]), 10)


func test_b2_total_wins() -> void:
	if _gate():
		return
	var r := _rig()
	(r["tracker"] as AchievementTracker).finish(false, _stats())
	assert_eq(int((r["store"] as AchievementStore).totals["wins"]), 0, "kayıp: galibiyet yok")
	var r2 := _rig()
	(r2["tracker"] as AchievementTracker).finish(true, _stats())
	assert_eq(int((r2["store"] as AchievementStore).totals["wins"]), 1)
	assert_eq((r2["tracker"] as AchievementTracker).value_of(&"total_wins"), 1)


func test_b2_total_play_secs() -> void:
	if _gate():
		return
	var r := _rig()
	(r["tracker"] as AchievementTracker).finish(false, _stats(125.7))
	var got := int((r["store"] as AchievementStore).totals["play_secs"])
	assert_between(got, 125, 126, "koşu süresi saniye olarak eklenir")


func test_b2_total_chars5() -> void:
	if _gate():
		return
	var st := AchKit.store()
	var bus_a := SimBus.new()
	var a := AchievementTracker.new(AchKit.data(), st, &"gunslinger", AchKit.clock())
	a.attach(bus_a)
	a.finish(false, _stats(299.0))
	assert_eq(st.chars5.size(), 0, "299 sn: sayılmaz")
	var a2 := AchievementTracker.new(AchKit.data(), st, &"gunslinger", AchKit.clock())
	a2.attach(SimBus.new())
	a2.finish(false, _stats(300.0))
	assert_eq(Array(st.chars5), ["gunslinger"])
	assert_false(st.is_unlocked(&"cifte_yol"), "tek karakter: açmaz")
	var b := AchievementTracker.new(AchKit.data(), st, &"barutcu", AchKit.clock())
	b.attach(SimBus.new())
	b.finish(false, _stats(300.0))
	assert_eq(st.chars5.size(), 2)
	assert_true(st.is_unlocked(&"cifte_yol"), "iki farklı karakter: açar")
	assert_true(Array(b.run_unlocked()).has(&"cifte_yol"))


# --- koşu içi (run_*) --------------------------------------------------------------------------------------------


func test_b2_run_kills() -> void:
	if _gate():
		return
	var r := _rig()
	AchKit.kills(r["bus"], 499)
	assert_false(_has(r, "kirim"))
	AchKit.kills(r["bus"], 1)
	assert_true(_has(r, "kirim"))
	AchKit.kills(r["bus"], 3)
	assert_eq(_unlock_log.count(&"kirim"), 1)


func test_b2_run_time() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	tr.poll(AchKit.sim_at(299.0))
	assert_false(_has(r, "bes_dakika"), "hedef-1 açmaz")
	tr.poll(AchKit.sim_at(300.0))
	assert_true(_has(r, "bes_dakika"))
	assert_false(_has(r, "on_dakika"))
	tr.poll(AchKit.sim_at(600.0))
	assert_true(_has(r, "on_dakika"))
	assert_false(_has(r, "on_bes_dakika"))
	tr.poll(AchKit.sim_at(900.0))
	assert_true(_has(r, "on_bes_dakika"))
	tr.poll(AchKit.sim_at(901.0))
	assert_eq(_unlock_log.count(&"bes_dakika"), 1)


func test_b2_run_time_from_finish_stats() -> void:
	if _gate():
		return
	var r := _rig()
	(r["tracker"] as AchievementTracker).finish(false, _stats(300.0))
	assert_true(_has(r, "bes_dakika"), "run_ended süresi de değerlendirilir")
	assert_eq(int((r["store"] as AchievementStore).best["time"]), 300)


func test_b2_run_level() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	bus.level_up.emit(9)
	assert_false(_has(r, "seviye_10"))
	bus.level_up.emit(10)
	assert_true(_has(r, "seviye_10"))
	assert_false(_has(r, "seviye_20"))
	bus.level_up.emit(19)
	assert_false(_has(r, "seviye_20"))
	bus.level_up.emit(20)
	assert_true(_has(r, "seviye_20"))
	bus.level_up.emit(21)
	assert_eq(_unlock_log.count(&"seviye_10"), 1)
	assert_eq(_unlock_log.count(&"seviye_20"), 1)


func test_b2_run_score() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	bus.score_changed.emit(99999, 3, 40)
	assert_false(_has(r, "skor_100k"))
	bus.score_changed.emit(100000, 3, 1)
	assert_true(_has(r, "skor_100k"))
	bus.score_changed.emit(150000, 3, 50000)
	assert_eq(_unlock_log.count(&"skor_100k"), 1)


func test_b2_run_reloads() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	for i in 99:
		bus.reload_started.emit(1.0)
	assert_false(_has(r, "tambur_ustasi"))
	bus.reload_started.emit(1.0)
	assert_true(_has(r, "tambur_ustasi"))
	bus.reload_started.emit(1.0)
	assert_eq(_unlock_log.count(&"tambur_ustasi"), 1)


func test_b2_run_active_slots() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	var sim := AchKit.sim_at(1.0)
	AchKit.fill_actives(sim, 5)
	assert_eq(sim.loadout.actives().size(), 5, "ön koşul: 5 yuva")
	tr.poll(sim)
	assert_false(_has(r, "alti_silah"))
	AchKit.fill_actives(sim, 6)
	assert_eq(sim.loadout.actives().size(), 6, "ön koşul: 6 yuva")
	tr.poll(sim)
	assert_true(_has(r, "alti_silah"))
	tr.poll(sim)
	assert_eq(_unlock_log.count(&"alti_silah"), 1)


func test_b2_run_best_mult() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	bus.streak_changed.emit(4, 1.5)
	assert_false(_has(r, "seri_ustasi"))
	bus.streak_changed.emit(5, 1.5)
	assert_true(_has(r, "seri_ustasi"))
	bus.streak_changed.emit(1, 0.0)
	bus.streak_changed.emit(6, 1.5)
	assert_eq(_unlock_log.count(&"seri_ustasi"), 1)


func test_b2_run_elit_piyade() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	AchKit.kills(bus, 3, &"elit_sovalye")
	assert_false(_has(r, "piyade_avcisi"), "başka elit sayılmaz")
	AchKit.kills(bus, 1, &"elit_piyade")
	assert_true(_has(r, "piyade_avcisi"))
	AchKit.kills(bus, 1, &"elit_piyade")
	assert_eq(_unlock_log.count(&"piyade_avcisi"), 1)


func test_b2_run_elite_kinds() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	AchKit.kills(bus, 2, &"elit_piyade")
	AchKit.kills(bus, 2, &"elit_sovalye")
	assert_false(_has(r, "uc_elit"), "aynı tür iki kez sayılmaz")
	AchKit.kills(bus, 1, &"elit_sovalye")
	assert_false(_has(r, "uc_elit"))
	AchKit.kills(bus, 1, &"elit_karga")
	assert_true(_has(r, "uc_elit"), "üç farklı elit")
	assert_eq((r["tracker"] as AchievementTracker).value_of(&"run_elite_kinds"), 3)


func test_b2_run_pickups() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	for i in 4:
		bus.pickup_collected.emit(&"kizil_iksir", Vector2.ZERO)
	assert_false(_has(r, "eklenti_avcisi"))
	bus.pickup_collected.emit(&"cekim_tasi", Vector2.ZERO)
	assert_true(_has(r, "eklenti_avcisi"))
	bus.pickup_collected.emit(&"cekim_tasi", Vector2.ZERO)
	assert_eq(_unlock_log.count(&"eklenti_avcisi"), 1)


func test_b2_run_clean_secs() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	tr.poll(AchKit.sim_at(179.98))
	assert_false(_has(r, "dokunulmaz"), "179.98: açmaz")
	tr.poll(AchKit.sim_at(180.0))
	assert_true(_has(r, "dokunulmaz"), "180.0: açar")
	assert_eq(_unlock_log.count(&"dokunulmaz"), 1)


func test_b2_run_clean_secs_freezes_at_first_damage() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	var bus: SimBus = r["bus"]
	tr.poll(AchKit.sim_at(100.0))
	bus.player_damaged.emit(5.0, 95.0)
	tr.poll(AchKit.sim_at(200.0))
	assert_false(_has(r, "dokunulmaz"), "hasardan sonra süre ilerlemez")
	assert_lte(tr.value_of(&"run_clean_secs"), 100, "son poll değerinde donar")
	tr.poll(AchKit.sim_at(400.0))
	assert_false(_has(r, "dokunulmaz"))


func test_b2_run_clean_secs_damage_just_before_threshold_keeps_frozen_value() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	tr.poll(AchKit.sim_at(179.98))
	r["bus"].player_damaged.emit(1.0, 99.0)
	tr.poll(AchKit.sim_at(180.5))
	assert_false(_has(r, "dokunulmaz"), "muhafazakâr: hasarlı adımda açılmaz")


func test_b2_run_evolutions() -> void:
	if _gate():
		return
	var r := _rig()
	assert_false(_has(r, "ilk_evrim"))
	(r["bus"] as SimBus).evolution_gained.emit(&"kiyamet_mermisi")
	assert_true(_has(r, "ilk_evrim"))
	(r["bus"] as SimBus).evolution_gained.emit(&"mermi_firtinasi")
	assert_eq(_unlock_log.count(&"ilk_evrim"), 1)


func test_b2_run_unlimited_kills() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	AchKit.kills(bus, 50)  # tamburdan önce: sayılmaz
	bus.buff_started.emit(UNLIMITED, 10.0)
	AchKit.kills(bus, 60)
	bus.buff_started.emit(UNLIMITED, 10.0)  # yenileme: sayaç sürer
	AchKit.kills(bus, 39)
	assert_false(_has(r, "sinirsiz_kirim"), "99: açmaz")
	AchKit.kills(bus, 1)
	assert_true(_has(r, "sinirsiz_kirim"), "yenilemede sayaç sıfırlanmadı: 100")
	assert_eq(_unlock_log.count(&"sinirsiz_kirim"), 1)


func test_b2_run_unlimited_kills_resets_on_new_activation_after_end() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	bus.buff_started.emit(UNLIMITED, 10.0)
	AchKit.kills(bus, 99)
	bus.buff_ended.emit(UNLIMITED)
	AchKit.kills(bus, 20)  # etkin değil: sayılmaz
	bus.buff_started.emit(UNLIMITED, 10.0)  # yeni etkinleşme: sayaç sıfır
	AchKit.kills(bus, 99)
	assert_false(_has(r, "sinirsiz_kirim"), "etkinleşmeler arasında birikmez")
	AchKit.kills(bus, 1)
	assert_true(_has(r, "sinirsiz_kirim"))


func test_b2_run_unlimited_kills_ignores_other_buffs() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	bus.buff_started.emit(&"damage", 10.0)
	bus.buff_started.emit(&"fire_rate", 10.0)
	AchKit.kills(bus, 150)
	assert_false(_has(r, "sinirsiz_kirim"), "yalnız unlimited")


func test_b2_run_won() -> void:
	if _gate():
		return
	var r := _rig()
	(r["tracker"] as AchievementTracker).finish(false, _stats())
	assert_false(_has(r, "kale_lordu_devrildi"))
	var r2 := _rig()
	(r2["tracker"] as AchievementTracker).finish(true, _stats())
	assert_true(_has(r2, "kale_lordu_devrildi"))


func test_b2_run_bomb_hits() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	bus.bomb_hits.emit(Vector2.ZERO, 320.0, 19)
	assert_false(_has(r, "bomba_ustasi"))
	bus.bomb_hits.emit(Vector2.ZERO, 320.0, 10)
	bus.bomb_hits.emit(Vector2.ZERO, 320.0, 10)
	assert_false(_has(r, "bomba_ustasi"), "TEK bomba: toplanmaz, en büyüğü sayılır")
	bus.bomb_hits.emit(Vector2.ZERO, 320.0, 20)
	assert_true(_has(r, "bomba_ustasi"))


# --- yaşam döngüsü ------------------------------------------------------------------------------------------------


func test_b2_finish_writes_totals_best_and_second_finish_is_noop() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	var st: AchievementStore = r["store"]
	tr.finish(true, _stats(400.0, 12, 80, 5000))
	assert_eq(int(st.totals["runs"]), 1)
	assert_eq(int(st.totals["wins"]), 1)
	assert_eq(int(st.best["time"]), 400)
	assert_eq(int(st.best["level"]), 12)
	assert_eq(int(st.best["score"]), 5000)
	assert_true(st.dirty)
	tr.finish(true, _stats(900.0, 30, 80, 999999))
	assert_eq(int(st.totals["runs"]), 1, "ikinci finish no-op")
	assert_eq(int(st.totals["wins"]), 1)
	assert_eq(int(st.best["time"]), 400)


func test_b2_double_attach_counts_events_once() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	tr.attach(r["bus"])
	AchKit.kills(r["bus"], 3)
	assert_eq(int((r["store"] as AchievementStore).totals["kills"]), 3, "çift bağ çift saymaz")
	assert_eq(tr.value_of(&"run_kills"), 3)


func test_b2_detach_stops_effect() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	AchKit.kills(r["bus"], 2)
	tr.detach()
	AchKit.kills(r["bus"], 5)
	assert_eq(int((r["store"] as AchievementStore).totals["kills"]), 2)
	assert_false(_has(r, "kirim"))


func test_b2_poll_does_not_mutate_actives_array() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	var sim := AchKit.sim_at(5.0)
	AchKit.fill_actives(sim, 3)
	var before := sim.loadout.actives()
	var snapshot: Array = []
	for s in before:
		snapshot.append(s)
	tr.poll(sim)
	tr.poll(sim)
	var after := sim.loadout.actives()
	assert_same(after, before, "dizi nesne kimliği aynı")
	assert_eq(after.size(), snapshot.size())
	for i in snapshot.size():
		assert_same(after[i], snapshot[i], "içerik aynı (yuva %d)" % i)


func test_b2_progress_mapping() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	var d := AchKit.data()
	AchKit.kills(r["bus"], 34)
	assert_eq(tr.progress(d.get_achievement(&"kalabalik_kesici")), 34, "toplam: store + koşu")
	assert_eq(
		tr.progress(d.get_achievement(&"kirim")), -1, "koşu başarımı (best eşlemesi yok): TEK KOŞU"
	)
	assert_eq(tr.progress(d.get_achievement(&"ilk_evrim")), -1)
	assert_eq(tr.progress(d.get_achievement(&"piyade_avcisi")), -1)


func test_b2_clock_zero_or_negative_falls_back_to_one() -> void:
	if _gate():
		return
	for bad in [0, -5]:
		var st := AchKit.store()
		var tr := AchievementTracker.new(AchKit.data(), st, &"gunslinger", AchKit.clock(bad))
		var bus := SimBus.new()
		tr.attach(bus)
		AchKit.kills(bus, 1)
		assert_true(st.is_unlocked(&"ilk_kan"), "saat %d: yine açılır" % bad)
		assert_eq(st.unlocked_at(&"ilk_kan"), 1, "unix < 1 => 1")


func test_b2_unlock_uses_injected_clock() -> void:
	if _gate():
		return
	var r := AchKit.rig(&"gunslinger", 1700012345)
	AchKit.kills(r["bus"], 1)
	assert_eq((r["store"] as AchievementStore).unlocked_at(&"ilk_kan"), 1700012345)


func test_b2_already_unlocked_in_store_is_not_reopened_or_reported() -> void:
	if _gate():
		return
	var r := _rig()
	(r["store"] as AchievementStore).unlock(&"ilk_kan", 1700000001)
	AchKit.kills(r["bus"], 1)
	assert_false(_has(r, "ilk_kan"), "bu koşuda açılmadı")
	assert_eq(_unlock_log.count(&"ilk_kan"), 0)
	assert_eq(
		(r["store"] as AchievementStore).unlocked_at(&"ilk_kan"), 1700000001, "ilk zaman korunur"
	)


func test_b2_flush_writes_when_dirty_and_is_true_when_clean() -> void:
	if _gate():
		return
	var r := _rig()
	var tr: AchievementTracker = r["tracker"]
	var st: AchievementStore = r["store"]
	assert_true(tr.flush(), "kirli değil: true")
	assert_false(FileAccess.file_exists(st.path), "temiz depo dosya yazmaz")
	AchKit.kills(r["bus"], 1)
	assert_true(tr.flush())
	assert_true(FileAccess.file_exists(st.path))
	assert_false(st.dirty)
	var again := AchievementStore.new(st.path)
	assert_true(again.load_file())
	assert_true(again.is_unlocked(&"ilk_kan"))


func test_b2_run_unlocked_keeps_unlock_order() -> void:
	if _gate():
		return
	var r := _rig()
	var bus: SimBus = r["bus"]
	bus.level_up.emit(10)
	AchKit.kills(bus, 1)
	assert_eq(_ids(r), [&"seviye_10", &"ilk_kan"], "açılış sırası")


func test_b2_all_22_real_defs_are_reachable_by_some_stat() -> void:
	if _gate():
		return
	var d := AchKit.data()
	assert_eq(d.achievements.size(), 22)
	for row in ExpectedTablesV2.ACHIEVEMENTS:
		assert_not_null(d.get_achievement(StringName(row[0])), row[0])
		assert_true(ExpectedTablesV2.STATS.has(row[1]), "%s: bilinen stat" % row[0])
