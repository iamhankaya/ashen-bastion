extends GutTest
## Stres koşusu: sabit senaryo, ölçüm özeti ve perf.json yazımı (zaman değil, deterministik kısımlar).


func test_scenario_keeps_400_enemies_and_about_500_projectiles() -> void:
	var sc := StressScenario.new()
	for i in 120:
		sc.step(i)
	assert_eq(sc.sim.enemies.count, StressScenario.ENEMIES)
	assert_between(sc.sim.projectiles.count, 400, StressScenario.PROJECTILES)
	assert_eq(sc.sim.check_invariants(), PackedStringArray())


func test_run_finishes_after_duration_and_writes_result() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StressRun.RESULT_PATH))
	var run := StressRun.new()
	add_child_autofree(run)
	watch_signals(run)
	for i in 3700:
		run.advance(1.0 / 60.0)
		if run.is_done():
			break
	assert_true(run.is_done())
	assert_signal_emitted(run, "finished")
	var res := run.build_result()
	assert_between(res["seconds"], 59.9, 60.2)
	assert_gt(res["sim_steps"], 3000)
	assert_between(res["enemies"], 380, 400)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(StressRun.RESULT_PATH))
	assert_true(parsed is Dictionary)
	assert_true(parsed.has("p95_frame_ms") and parsed.has("avg_frame_ms"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StressRun.RESULT_PATH))


func test_status_text_is_turkish_and_nonempty() -> void:
	var run := StressRun.new()
	add_child_autofree(run)
	run.advance(0.016)
	assert_string_contains(run.status_text(), "STRES")


func test_controller_stress_entry_keeps_run_alive_and_drives_scenario() -> void:
	var gc := GameController.new()
	add_child_autofree(gc)
	gc.start_stress()
	assert_not_null(gc._stress, "start_stress sonrası koşu nesnesi yaşamalı")
	for i in 30:
		gc._process(1.0 / 60.0)
	assert_gt(gc._stress.scenario.sim.step_count, 20)
	assert_eq(gc.sim, gc._stress.scenario.sim)
	gc.go_menu()
	assert_null(gc._stress)


func test_death_load_kills_a_few_each_period_and_refills() -> void:
	var sc := StressScenario.new({}, true)
	var kills := [0]
	sc.sim.bus.enemy_killed.connect(func(_t: StringName, _p: Vector2) -> void: kills[0] += 1)
	for i in 100:
		sc.step(i)
	assert_gte(
		kills[0], StressScenario.DEATH_KILLS * 5, "100 adımda 5 dönem × 5 ölüm (+ oyun içi ölümler)"
	)
	assert_eq(sc.sim.enemies.count, StressScenario.ENEMIES, "havuz yeniden dolar")
	assert_eq(sc.sim.check_invariants(), PackedStringArray())
	var plain := StressScenario.new()
	var none := [0]
	plain.sim.bus.enemy_killed.connect(func(_t: StringName, _p: Vector2) -> void: none[0] += 1)
	plain.step(0)
	assert_eq(none[0], 0, "varsayılan senaryo ölüm yükü eklemez (sayaç bütçesi değişmez)")


func test_view_ms_is_recorded_and_reported() -> void:
	var run := StressRun.new()
	add_child_autofree(run)
	for ms in [1.0, 2.0, 3.0, 4.0]:
		run.record_view(ms)
	var res := run.build_result()
	assert_almost_eq(res["view_ms_avg"], 2.5, 0.01)
	assert_gte(res["view_ms_p95"], 3.0)
	assert_string_contains(run.status_text(), "görünüm")
	var empty := StressRun.new()
	add_child_autofree(empty)
	assert_eq(empty.build_result()["view_ms_avg"], 0.0)


func test_controller_stress_records_view_time_each_frame() -> void:
	var gc := GameController.new()
	add_child_autofree(gc)
	gc.start_stress()
	for i in 20:
		gc._process(1.0 / 60.0)
	assert_eq(gc._stress._view_ms.size(), 20)
	assert_gt(gc._stress.build_result()["view_ms_avg"], 0.0)
