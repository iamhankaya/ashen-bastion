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
