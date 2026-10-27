extends GutTest
## v2.1 U3 (K dilimi): zorluğa bağlı başarım kuralı kademe düzeyinde ve olay anında (K-C5). Kolay'da Lord'a bağlı kademeler
## (lordslayer 1-3, endure 4 = 1200 sn, ascension 3 = 4 evrim) açılmaz; toplamlardan yalnız runs/play_secs artar.
## Tüm depolar geçici yoldadır (AchKit); sonradan geri alma yoktur.

const CHAR := &"gunslinger"

var _store: AchievementStore
var _opened: Array[StringName] = []


func before_each() -> void:
	_store = AchKit.store()
	_opened = []


func after_each() -> void:
	AchKit.cleanup()


## {"tracker","bus"}: verilen zorlukta kurallı tracker (rules=null: kuralsız).
func _rig(diff: StringName, with_rules: bool = true) -> Dictionary:
	var rules: AchievementRules = AchievementRules.new(V21Kit.cfg()) if with_rules else null
	var tr := AchievementTracker.new(AchKit.data(), _store, CHAR, AchKit.clock(), rules, diff)
	tr.unlocked.connect(func(d: AchievementDef) -> void: _opened.append(d.id))
	var bus := SimBus.new()
	tr.attach(bus)
	return {"tracker": tr, "bus": bus}


func _evolve(bus: SimBus, n: int) -> void:
	for i in n:
		bus.evolution_gained.emit(&"x%d" % i)


func test_k20_easy_blocks_endure_step_4_at_the_event_but_grants_steps_1_to_3() -> void:
	var r := _rig(&"easy")
	var tr: AchievementTracker = r["tracker"]
	tr.poll(AchKit.sim_at(900.0))
	assert_eq(_store.step_count(&"endure"), 3)
	tr.poll(AchKit.sim_at(1200.0))
	assert_eq(_store.step_count(&"endure"), 3, "1200 sn Kolay'da kademe vermez")
	assert_eq(_opened.count(&"endure"), 1, "ikinci bildirim yok")
	tr.finish(false, {"time": 1250, "level": 1, "score": 1})
	assert_eq(_store.step_count(&"endure"), 3, "finish de vermez")


func test_k21_easy_win_does_not_count_wins_or_open_lordslayer() -> void:
	var r := _rig(&"easy")
	var tr: AchievementTracker = r["tracker"]
	tr.finish(true, {"time": 700, "level": 5, "score": 10})
	assert_eq(int(_store.totals["wins"]), 0)
	assert_eq(_store.step_count(&"lordslayer"), 0)
	assert_eq(int(_store.totals["runs"]), 1, "runs Kolay'da artar")
	assert_eq(int(_store.totals["play_secs"]), 700, "play_secs Kolay'da artar")


func test_k22_easy_ascension_caps_at_step_2_not_step_3() -> void:
	var r := _rig(&"easy")
	_evolve(r["bus"], 4)
	assert_eq(_store.step_count(&"ascension"), 2, "4 evrim = 3. kademe, Kolay'da kapalı")


func test_k23_easy_totals_skip_kills_elites_chars5_but_run_bests_still_work() -> void:
	var r := _rig(&"easy")
	var tr: AchievementTracker = r["tracker"]
	AchKit.kills(r["bus"], 5)
	AchKit.kills(r["bus"], 2, &"elit_piyade")
	tr.finish(false, {"time": 400, "level": 3, "score": 99})
	assert_eq(int(_store.totals["kills"]), 0)
	assert_eq(int(_store.totals["boss_kills"]), 0)
	assert_eq(_store.chars5.size(), 0)
	assert_eq(tr.value_of(&"run_kills"), 7, "koşu içi en iyiler her zorlukta işler")
	assert_eq(int(_store.totals["runs"]), 1)


func test_k24_normal_and_hard_apply_no_restriction() -> void:
	for diff in [&"normal", &"hard"]:
		_store = AchKit.store()
		var r := _rig(diff)
		var tr: AchievementTracker = r["tracker"]
		tr.poll(AchKit.sim_at(1200.0))
		_evolve(r["bus"], 4)
		AchKit.kills(r["bus"], 3)
		tr.finish(true, {"time": 1300, "level": 9, "score": 1000})
		assert_eq(_store.step_count(&"endure"), 4, str(diff))
		assert_eq(_store.step_count(&"ascension"), 3, str(diff))
		assert_eq(_store.step_count(&"lordslayer"), 1, str(diff))
		assert_eq(int(_store.totals["kills"]), 3, str(diff))
		assert_eq(int(_store.totals["wins"]), 1, str(diff))
		assert_true(_store.chars5.has(CHAR), str(diff))


func test_k25_easy_then_normal_runs_unlock_tiers_in_order() -> void:
	var easy := _rig(&"easy")
	easy["tracker"].poll(AchKit.sim_at(1200.0))
	easy["tracker"].finish(true, {"time": 1200, "level": 4, "score": 5})
	assert_eq(_store.step_count(&"endure"), 3)
	assert_eq(_store.step_count(&"lordslayer"), 0)
	_opened.clear()
	var normal := _rig(&"normal")
	normal["tracker"].poll(AchKit.sim_at(1200.0))
	assert_eq(_store.step_count(&"endure"), 4, "Normal koşu 4. kademeyi açar (3 -> 4, ardışık)")
	assert_eq(_opened.count(&"endure"), 1)
	normal["tracker"].finish(true, {"time": 1200, "level": 4, "score": 5})
	assert_eq(_store.step_count(&"lordslayer"), 1)
	assert_eq(int(_store.totals["wins"]), 1, "Kolay'daki galibiyet sayılmamıştı")


func test_k26_endless_double_lord_counts_a_single_win() -> void:
	var r := _rig(&"normal")
	var tr: AchievementTracker = r["tracker"]
	AchKit.kills(r["bus"], 2, &"kale_lordu")
	tr.finish(true, {"time": 2000, "level": 9, "score": 5})
	tr.finish(true, {"time": 2000, "level": 9, "score": 5})
	assert_eq(int(_store.totals["wins"]), 1)


func test_k27_without_rules_tracker_keeps_legacy_behavior_on_any_diff() -> void:
	var r := _rig(&"easy", false)
	var tr: AchievementTracker = r["tracker"]
	tr.poll(AchKit.sim_at(1200.0))
	tr.finish(true, {"time": 1200, "level": 4, "score": 5})
	assert_eq(_store.step_count(&"endure"), 4)
	assert_eq(int(_store.totals["wins"]), 1)


func test_k28_v21_runs_gives_tracker_rules_and_diff_from_the_sim_profile() -> void:
	var easy := SimKit.make(1, {"run_profile": V21Kit.profile(&"normal", &"easy")})
	assert_eq(V21Runs.diff_of(easy), &"easy")
	assert_eq(V21Runs.diff_of(SimKit.make(1)), &"hard", "profilsiz = Zor")
	assert_false(V21Runs.achievement_rules().allows("endure:4", &"easy"))
