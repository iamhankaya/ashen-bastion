extends GutTest
## Kabul (v2.1 K): başarım kuralı (spec senaryo 10, K6-B, plan K-C5). Kolay'da Lord'a bağlı kademeler (lordslayer, endure 1200,
## ascension 4) olay anında açılmaz; toplam sayaçlardan yalnız runs/play_secs artar; koşu içi en iyiler her zorlukta işler;
## geri alma yok; Kolay -> Normal ardışık koşular doğru. Veri/kural testleri (r1-r2) C'den beri koşar; tracker yolları (v21k21-v21k28)
## V21Slice "K" açılana dek pending.
## VARSAYIM (plan: "tracker kurulurken enjekte edilir", imza sözleşmede yok): AchievementTracker._init 5. ve 6. parametre olarak
## (rules: AchievementRules, diff: StringName) alır ya da `set_rules(rules, diff)` sunar. İkisi de yoksa `_tracker` testi
## pending bırakır (T-turu bu tek yardımcıyı gerçek imzaya uyarlar).

const TRACKER := "res://scripts/ctrl/achievement_tracker.gd"
const TIME := 1300
const LORD_BOUND := ["lordslayer:1", "lordslayer:2", "lordslayer:3", "endure:4", "ascension:3"]


func after_each() -> void:
	AchKit.cleanup()


func _init_arg_count() -> int:
	for m: Dictionary in (load(TRACKER) as GDScript).get_script_method_list():
		if m["name"] == "_init":
			return (m["args"] as Array).size()
	return 0


## {"store","tracker","bus"} ya da boş sözlük (enjeksiyon imzası bulunamadı).
func _rig(diff: StringName, store: AchievementStore = null) -> Dictionary:
	var st := store if store != null else AchKit.store()
	var rules := AchievementRules.new(V21Kit.cfg())
	var data := AchKit.data()
	var script: GDScript = load(TRACKER)
	var tr: AchievementTracker = null
	if _init_arg_count() >= 6:
		tr = script.new(data, st, &"gunslinger", AchKit.clock(), rules, diff)
	else:
		tr = AchievementTracker.new(data, st, &"gunslinger", AchKit.clock())
		if tr.has_method("set_rules"):
			tr.call("set_rules", rules, diff)
		else:
			return {}
	var bus := SimBus.new()
	tr.attach(bus)
	return {"store": st, "tracker": tr, "bus": bus}


func _stats(level: int = 20, score: int = 5000, time: int = TIME) -> Dictionary:
	return {"time": time, "level": level, "score": score}


func _total(st: AchievementStore, key: String) -> int:
	return int(st.totals.get(key, 0))


# --- Kural verisi (C) --------------------------------------------------------------------------


func test_r1_lord_bound_ids_match_the_real_achievement_thresholds() -> void:
	var by_id := {}
	for def in AchKit.data().achievements:
		by_id[String(def.id)] = def
	for id: String in LORD_BOUND:
		var parts := id.split(":")
		assert_true(by_id.has(parts[0]), "aile var: %s" % id)
		if not by_id.has(parts[0]):
			continue
		assert_lte(int(parts[1]), (by_id[parts[0]].steps as Array).size(), "kademe var: %s" % id)
	assert_eq(by_id["endure"].steps[3], 1200, "endure:4 = 1200 sn (Lord anı)")
	assert_eq(by_id["ascension"].steps[2], 4, "ascension:3 = 4 evrim")
	assert_eq(by_id["lordslayer"].stat, &"total_wins", "lordslayer kazanma sayacına bağlı")
	assert_eq((by_id["lordslayer"].steps as Array).size(), 3)


func test_r2_rules_block_exactly_the_lord_bound_tiers_on_easy() -> void:
	var rules := AchievementRules.new(V21Kit.cfg())
	var blocked := 0
	for def in AchKit.data().achievements:
		for k in (def.steps as Array).size():
			var id := AchievementRules.tier_id(def.id, k + 1)
			if not rules.allows(id, &"easy"):
				blocked += 1
				assert_has(LORD_BOUND, id, "beklenmeyen kapalı kademe: %s" % id)
			assert_true(rules.allows(id, &"normal"), "Normal'de açık: %s" % id)
			assert_true(rules.allows(id, &"hard"), "Zor'da açık: %s" % id)
	assert_eq(blocked, LORD_BOUND.size(), "Kolay'da tam 5 kademe kapalı")


# --- Tracker (K dilimi) ------------------------------------------------------------------------


func test_v21k21_easy_win_counts_only_runs_and_play_secs() -> void:
	if V21Slice.require(self, "K"):
		return
	var r := _rig(&"easy")
	if r.is_empty():
		pending("tracker kural enjeksiyonu yok (K dilimi bitince T-turu imzayı bağlar)")
		return
	r["tracker"].finish(true, _stats())
	var st: AchievementStore = r["store"]
	assert_eq(_total(st, "runs"), 1)
	assert_eq(_total(st, "play_secs"), TIME)
	assert_eq(_total(st, "wins"), 0, "Kolay kazanma sayılmaz")
	assert_eq(st.step_count(&"lordslayer"), 0, "lordslayer:1 açılmadı")


func test_v21k22_normal_and_hard_wins_count_and_unlock_lordslayer() -> void:
	if V21Slice.require(self, "K"):
		return
	for diff in [&"normal", &"hard"]:
		var r := _rig(diff)
		if r.is_empty():
			pending("tracker kural enjeksiyonu yok")
			return
		r["tracker"].finish(true, _stats())
		assert_eq(_total(r["store"], "wins"), 1, str(diff))
		assert_eq(r["store"].step_count(&"lordslayer"), 1, str(diff))


func test_v21k23_easy_still_records_run_bests_and_non_lord_tiers() -> void:
	if V21Slice.require(self, "K"):
		return
	var r := _rig(&"easy")
	if r.is_empty():
		pending("tracker kural enjeksiyonu yok")
		return
	AchKit.kills(r["bus"], 520)
	r["tracker"].finish(false, _stats(25, 150000, 700))
	var st: AchievementStore = r["store"]
	assert_eq(_total(st, "kills"), 0, "toplam öldürme sayılmaz")
	assert_gte(st.step_count(&"rampage"), 1, "rampage koşu içi: Kolay'da da açılır")
	assert_gte(st.step_count(&"renown"), 1, "renown (skor) Kolay'da açılır")
	assert_gte(st.step_count(&"endure"), 2, "endure 300/600 Kolay'da açılır")
	assert_eq(int(st.best.get("level", 0)), 25, "koşu en iyisi her zorlukta işler")


func test_v21k24_easy_never_grants_endure_1200() -> void:
	if V21Slice.require(self, "K"):
		return
	var easy := _rig(&"easy")
	var normal := _rig(&"normal")
	if easy.is_empty() or normal.is_empty():
		pending("tracker kural enjeksiyonu yok")
		return
	easy["tracker"].finish(false, _stats(10, 1000, 1250))
	normal["tracker"].finish(false, _stats(10, 1000, 1250))
	assert_eq(easy["store"].step_count(&"endure"), 3, "300/600/900 evet, 1200 hayır")
	assert_eq(normal["store"].step_count(&"endure"), 4)


func test_v21k25_easy_never_grants_ascension_4() -> void:
	if V21Slice.require(self, "K"):
		return
	var easy := _rig(&"easy")
	var normal := _rig(&"normal")
	if easy.is_empty() or normal.is_empty():
		pending("tracker kural enjeksiyonu yok")
		return
	for r in [easy, normal]:
		for i in 4:
			(r["bus"] as SimBus).evolution_gained.emit(StringName("evo_%d" % i))
		r["tracker"].finish(false, _stats())
	assert_eq(easy["store"].step_count(&"ascension"), 2, "1 ve 2 evrim evet, 4 hayır (olay anında)")
	assert_eq(normal["store"].step_count(&"ascension"), 3)


func test_v21k26_easy_then_normal_on_the_same_save_unlocks_in_order() -> void:
	if V21Slice.require(self, "K"):
		return
	var path := AchKit.tmp_path("seq")
	var first := _rig(&"easy", AchKit.store(path))
	if first.is_empty():
		pending("tracker kural enjeksiyonu yok")
		return
	first["tracker"].finish(true, _stats())
	first["tracker"].flush()
	var second := _rig(&"normal", AchKit.store(path))
	second["store"].load_file()
	assert_eq(second["store"].step_count(&"lordslayer"), 0, "Kolay kazanma hiçbir şey bırakmadı")
	second["tracker"].finish(true, _stats())
	assert_eq(_total(second["store"], "wins"), 1, "yalnız Normal kazanma sayıldı")
	assert_eq(second["store"].step_count(&"lordslayer"), 1)
	assert_eq(_total(second["store"], "runs"), 2, "iki koşu da sayıldı")


func test_v21k27_a_later_easy_run_never_rolls_back_a_normal_unlock() -> void:
	if V21Slice.require(self, "K"):
		return
	var path := AchKit.tmp_path("noroll")
	var normal := _rig(&"normal", AchKit.store(path))
	if normal.is_empty():
		pending("tracker kural enjeksiyonu yok")
		return
	normal["tracker"].finish(true, _stats(10, 1000, 1250))
	normal["tracker"].flush()
	var easy := _rig(&"easy", AchKit.store(path))
	easy["store"].load_file()
	easy["tracker"].finish(true, _stats())
	assert_eq(easy["store"].step_count(&"lordslayer"), 1, "geri alınmadı")
	assert_eq(easy["store"].step_count(&"endure"), 4)
	assert_eq(_total(easy["store"], "wins"), 1, "Kolay kazanma eklenmedi")


func test_v21k28_endless_counts_one_win_however_many_lords_fall() -> void:
	if V21Slice.require(self, "K"):
		return
	var r := _rig(&"normal")
	if r.is_empty():
		pending("tracker kural enjeksiyonu yok")
		return
	var bus: SimBus = r["bus"]
	bus.milestone_reached.emit()
	bus.lord_slain.emit(1)
	bus.lord_slain.emit(2)
	bus.lord_slain.emit(3)
	r["tracker"].finish(true, _stats())
	assert_eq(_total(r["store"], "wins"), 1, "Sonsuz: yalnız ilk Lord ölümü wins")
