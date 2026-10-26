extends GutTest
## v2.0.3 C: kayıt göçü (v1 -> v2) ve aile/kademe depo davranışı. Tüm yollar geçici; `after_each` temizler.

const T := 1761270000

var _defs: Array


func before_each() -> void:
	_defs = GameData.load_dir("res://data").achievements


func after_each() -> void:
	AchKit.cleanup()


func _legacy_all() -> Dictionary:
	var un := {}
	for id in AchievementDef.LEGACY_IDS:
		un[id] = T + un.size()
	return un


func _v1(unlocked: Dictionary, totals: Dictionary = {}, best: Dictionary = {}) -> Dictionary:
	var t := {"kills": 0, "runs": 0, "wins": 0, "play_secs": 0}
	t.merge(totals, true)
	var b := {"score": 0, "time": 0, "level": 0}
	b.merge(best, true)
	return {"v": 1, "unlocked": unlocked, "totals": t, "best": b, "chars5": ["gunslinger"]}


func _load_v1(raw: Dictionary) -> Array:
	var p := AchKit.tmp_path()
	AchKit.write_text(p, JSON.stringify(raw))
	var st := AchievementStore.new(p)
	assert_true(st.load_file(_defs))
	return [st, p]


func test_all_22_legacy_open_makes_every_family_complete() -> void:
	var st: AchievementStore = _load_v1(_v1(_legacy_all()))[0]
	for d: AchievementDef in _defs:
		if not d.legacy.is_empty():
			assert_gte(st.step_count(d.id), 1, "%s açık" % d.id)
	assert_eq(st.step_count(&"endure"), 3, "bes/on/on_bes -> kademe 3")
	assert_eq(st.step_count(&"reaper"), 4)
	assert_eq(st.step_count(&"ascendant"), 2)
	assert_eq(st.step_count(&"vigil"), 0, "yeni aile; eski kimliği yok")
	for id in AchievementDef.LEGACY_IDS:
		assert_false(st.unlocked.has(StringName(id)), "%s eski kimlik aileye taşındı" % id)


func test_migration_keeps_legacy_unlock_dates_and_fills_lower_steps() -> void:
	var st: AchievementStore = _load_v1(_v1({"kalabalik_kesici": T + 7}))[0]
	assert_eq(st.step_count(&"reaper"), 4)
	for n in range(1, 5):
		assert_eq(st.step_unix(&"reaper", n), T + 7, "alt kademe aynı tarihi taşır")
	assert_eq(st.unlocked_at(&"reaper"), T + 7)


func test_migration_seeds_total_counters_with_lower_bound_but_not_run_bests() -> void:
	var st: AchievementStore = _load_v1(_v1({"kalabalik_kesici": T}))[0]
	assert_gte(int(st.totals["kills"]), 10000)
	var st2: AchievementStore = _load_v1(_v1({"on_bes_dakika": T, "skor_100k": T}))[0]
	assert_eq(int(st2.best["time"]), 0, "koşu en iyileri tohumlanmaz")
	assert_eq(int(st2.best["score"]), 0)
	assert_eq(st2.step_count(&"endure"), 3, "kademe steps'te; ekran değeri eşikten gelir")
	assert_eq(int(st2.totals["kills"]), 0, "başka sayaç tohumlanmaz")


func test_partial_progress_maps_highest_step() -> void:
	var st: AchievementStore = _load_v1(_v1({"ilk_kan": T, "bes_dakika": T, "on_dakika": T + 1}))[0]
	assert_eq(st.step_count(&"reaper"), 1)
	assert_eq(st.step_count(&"endure"), 2)
	assert_eq(st.step_unix(&"endure", 1), T)
	assert_eq(st.step_unix(&"endure", 2), T + 1)
	assert_eq(st.step_count(&"rampage"), 0)


func test_unknown_ids_are_preserved() -> void:
	var st: AchievementStore = _load_v1(_v1({"gelecek_basarim": T, "ilk_kan": T}))[0]
	assert_true(st.unlocked.has(&"gelecek_basarim"))
	assert_true(st.unlocked.has(&"reaper"))


func test_migrate_v1_is_pure_and_idempotent() -> void:
	var raw := _v1(_legacy_all())
	var snap := raw.duplicate(true)
	var once := AchievementStore.migrate_v1(raw, _defs)
	assert_eq(raw, snap, "girdi değişmez")
	assert_eq(int(once["v"]), 2)
	assert_true(once.has("steps"))
	assert_eq(AchievementStore.migrate_v1(once, _defs), once, "idempotent")


func test_migrate_v1_tolerates_garbage_without_crashing() -> void:
	for bad in [{}, {"v": 1}, {"v": 1, "unlocked": [1, 2]}, {"v": 1, "unlocked": {"ilk_kan": "x"}}]:
		var out := AchievementStore.migrate_v1(bad, _defs)
		assert_true(out is Dictionary)


func test_first_save_writes_backup_once_and_v2_layout() -> void:
	var raw := _v1({"ilk_kan": T, "bes_dakika": T}, {"kills": 4})
	var r := _load_v1(raw)
	var st: AchievementStore = r[0]
	var p: String = r[1]
	var original := AchKit.read_text(p)
	assert_true(st.dirty, "göç sonrası kayıt bekler")
	assert_true(st.save())
	assert_eq(AchKit.read_text(p + AchievementStore.BACKUP_SUFFIX), original, "yedek v1 aynen")
	var d: Dictionary = JSON.parse_string(AchKit.read_text(p))
	assert_eq(int(d["v"]), 2)
	assert_true(d.has("steps"))
	st.add_total(&"kills", 1)
	assert_true(st.save())
	assert_eq(
		AchKit.read_text(p + AchievementStore.BACKUP_SUFFIX), original, "yedek yeniden yazılmaz"
	)


func test_reloading_a_migrated_file_changes_nothing_and_makes_no_backup() -> void:
	var r := _load_v1(_v1(_legacy_all()))
	var st: AchievementStore = r[0]
	st.save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(r[1] + AchievementStore.BACKUP_SUFFIX))
	var again := AchievementStore.new(r[1])
	assert_true(again.load_file(_defs))
	assert_false(again.dirty)
	assert_eq(again.unlocked, st.unlocked)
	assert_eq(again.steps, st.steps)
	assert_false(FileAccess.file_exists(r[1] + AchievementStore.BACKUP_SUFFIX))


func test_v2_roundtrip_keeps_steps_and_new_counters() -> void:
	var p := AchKit.tmp_path()
	var st := AchievementStore.new(p)
	assert_true(st.unlock_step(&"reaper", 2, T))
	assert_true(st.unlock_step(&"reaper", 3, T + 5))
	st.add_total(&"boss_kills", 3)
	st.note_best_key(&"kills", 412)
	assert_true(st.save())
	var again := AchievementStore.new(p)
	assert_true(again.load_file(_defs))
	assert_eq(again.step_count(&"reaper"), 3)
	assert_eq(again.step_unix(&"reaper", 1), T)
	assert_eq(again.step_unix(&"reaper", 3), T + 5)
	assert_eq(int(again.totals["boss_kills"]), 3)
	assert_eq(int(again.best["kills"]), 412)


func test_unlock_step_never_goes_back_and_rejects_bad_input() -> void:
	var st := AchKit.store()
	assert_true(st.unlock_step(&"reaper", 3, T))
	assert_false(st.unlock_step(&"reaper", 2, T + 1), "kademe geri alınmaz")
	assert_false(st.unlock_step(&"reaper", 3, T + 1), "aynı kademe tekrar açılmaz")
	assert_false(st.unlock_step(&"reaper", 4, 0), "unix < 1")
	assert_false(st.unlock_step(&"reaper", AchievementDef.MAX_STEPS + 1, T))
	assert_eq(st.step_count(&"reaper"), 3)
	assert_eq(st.step_unix(&"reaper", 1), T, "alt kademeler aynı tarihi taşır")


func test_legacy_single_unlock_counts_as_step_one() -> void:
	var st := AchKit.store()
	assert_true(st.unlock(&"ilk_kan", T))
	assert_eq(st.step_count(&"ilk_kan"), 1)
	assert_eq(st.step_unix(&"ilk_kan", 1), T)


func test_sanitize_steps_drops_garbage() -> void:
	var clean := AchievementStore.sanitize(
		{
			"v": 2,
			"unlocked": {"reaper": T},
			"steps":
			{
				"reaper": [T, "x", T + 1, -5, 1.5],
				"Bad Id": [T],
				"long": [1, 2, 3, 4, 5, 6, 7],
				"notarray": 5
			}
		}
	)
	assert_eq(clean["steps"][&"reaper"], [T, T + 1])
	assert_false(clean["steps"].has(&"Bad Id"))
	assert_false(clean["steps"].has(&"notarray"))
	assert_lte((clean["steps"][&"long"] as Array).size(), AchievementDef.MAX_STEPS)


func test_corrupt_v1_is_set_aside_and_state_is_empty() -> void:
	var p := AchKit.tmp_path()
	AchKit.write_text(p, '{"v":1,"unlocked":{"ilk_kan":17')
	var st := AchievementStore.new(p)
	assert_false(st.load_file(_defs))
	assert_true(st.corrupt)
	assert_true(FileAccess.file_exists(p + ".bad"))
	assert_eq(st.unlocked.size(), 0)


func test_load_file_without_defs_uses_default_data_and_migrates() -> void:
	var p := AchKit.tmp_path()
	AchKit.write_text(p, JSON.stringify(_v1({"ilk_kan": T})))
	var st := AchievementStore.new(p)
	assert_true(st.load_file())
	assert_eq(st.step_count(&"reaper"), 1)
	assert_false(st.unlocked.has(&"ilk_kan"))


func test_v20_single_step_defs_keep_v1_layout_so_no_mapping_is_lost() -> void:
	var p := AchKit.tmp_path()
	AchKit.write_text(p, JSON.stringify(_v1({"ilk_kan": T})))
	var st := AchievementStore.new(p)
	assert_true(st.load_file(AchKit.legacy_data().achievements))
	assert_true(st.unlocked.has(&"ilk_kan"))
	assert_true(st.save())
	var d: Dictionary = JSON.parse_string(AchKit.read_text(p))
	assert_eq(int(d["v"]), 1, "aile yokken göç yapılmaz")
	var again := AchievementStore.new(p)
	assert_true(again.load_file(_defs))
	assert_eq(again.step_count(&"reaper"), 1, "tanım gelince göçer")


func test_reconcile_grants_steps_from_counters_silently_and_never_lowers() -> void:
	var st := AchKit.store()
	st.unlock_step(&"reaper", 1, T)
	st.totals["kills"] = 300
	st.best["time"] = 650
	st.unlock_step(&"rampage", 2, T)
	var n := AchievementMigration.reconcile(st, _defs, T + 50)
	assert_eq(st.step_count(&"reaper"), 2, "300 >= 250")
	assert_eq(st.step_unix(&"reaper", 2), T + 50)
	assert_eq(st.step_count(&"endure"), 2, "650 sn >= 600")
	assert_eq(st.step_count(&"rampage"), 2, "geri alınmaz")
	assert_eq(n, 3, "reaper +1, endure +2 kademe")
	assert_eq(AchievementMigration.reconcile(st, _defs, T + 99), 0, "ikinci geçiş sessiz ve boş")
