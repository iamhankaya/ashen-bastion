extends GutTest
## F-ashen-bastion-002 (C): her adım sonrası renderer.visible_count == canlı sayı ve buffer konumları == canlı
## konumlar (toplama + ölüm aynı adımda dahil). Kesme dikdörtgeni düzeltmesi (RenderFix) açık/kapalı çalışır.

const STEPS := 600
## v1.1 bob/itme payı (px): tampon merkezi = sim konumu ± bu kadar.
const POS_TOL := 16.0


func after_each() -> void:
	RenderFix.enabled = true


func _sim() -> GameSim:
	return GameSim.new(17, &"gunslinger", {"end_mode": "timer", "end_time": 600.0})


func _check_enemies(sim: GameSim, r: EnemyRenderer, label: String) -> void:
	r.refresh()
	assert_eq(r.visible_count(), sim.enemies.count, "%s: görünür düşman = canlı" % label)
	var buf := r.multimesh.buffer
	var n := 0
	for i in EnemyPool.CAP:
		if sim.enemies.alive[i] != 1:
			continue
		var o := n * EnemyRenderer.STRIDE
		# v1.1: hareket dönüşüme yazılır (bob/itme/squash); merkez sim konumundan en çok ±16 px ayrışır (plan D1).
		if (
			absf(buf[o + 3] - sim.enemies.pos[i].x) > POS_TOL
			or absf(buf[o + 7] - sim.enemies.pos[i].y) > POS_TOL
		):
			fail_test("%s: düşman %d konumu buffer'da farklı" % [label, i])
			return
		n += 1
	assert_eq(n, sim.enemies.count)


func _check_gems(sim: GameSim, r: GemRenderer, label: String) -> void:
	r.refresh()
	assert_eq(r.visible_count(), sim.gems.count, "%s: görünür taş = canlı" % label)
	var buf := r.multimesh.buffer
	for i in sim.gems.count:
		var o := i * GemRenderer.STRIDE
		if (
			absf(buf[o + 3] - sim.gems.pos[i].x) > 0.01
			or absf(buf[o + 7] - sim.gems.pos[i].y) > 0.01
		):
			fail_test("%s: taş %d konumu buffer'da farklı" % [label, i])
			return


func _check_projectiles(sim: GameSim, r: ProjectileRenderer, label: String) -> void:
	r.refresh()
	assert_eq(r.visible_count(), sim.projectiles.count, "%s: görünür mermi = canlı" % label)


func _run_checked(fix_on: bool) -> Dictionary:
	RenderFix.enabled = fix_on
	var sim := _sim()
	sim.debug_grant(&"cift_tabanca", 4)
	sim.debug_grant(&"son_mermi_patlar", 5)
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"agir_kursun", 5)
	sim.debug_grant(&"hizli_parmak", 5)
	SimKit.godmode(sim)
	var er := EnemyRenderer.new()
	var gr := GemRenderer.new()
	var pr := ProjectileRenderer.new()
	add_child_autofree(er)
	add_child_autofree(gr)
	add_child_autofree(pr)
	er.bind(sim)
	gr.bind(sim)
	pr.bind(sim)
	sim.debug_fill(&"curumus_piyade", 120, 260.0)
	var both := 0
	var killed_total := 0
	for s in STEPS:
		var k0 := sim.kills
		var x0 := sim.xp + sim.level * 1000
		sim.step(Vector2(0.15, 0.05))
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			SimKit.godmode(sim)  # choose() azami canı yeniler
		var label := "adım %d" % s
		if sim.kills > k0 and sim.xp + sim.level * 1000 > x0:
			both += 1
		killed_total += sim.kills - k0
		_check_enemies(sim, er, label)
		_check_gems(sim, gr, label)
		_check_projectiles(sim, pr, label)
		if s % 120 == 0:
			sim.debug_fill(&"curumus_piyade", 40, 240.0)
	return {"both": both, "killed": killed_total}


func test_views_match_sim_every_step_with_fix_on() -> void:
	var r := _run_checked(true)
	assert_gt(r["killed"], 10, "koşuda ölümler olmalı")
	assert_gt(r["both"], 0, "toplama ve ölüm aynı adımda en az bir kez")


func test_views_match_sim_every_step_with_fix_off() -> void:
	var r := _run_checked(false)
	assert_gt(r["killed"], 10)


func test_apply_cull_fix_toggles_without_error() -> void:
	var er := EnemyRenderer.new()
	add_child_autofree(er)
	RenderFix.enabled = false
	er.apply_cull_fix()
	RenderFix.enabled = true
	er.apply_cull_fix()
	assert_true(RenderFix.enabled)
	assert_eq(RenderFix.HUGE_RECT.size, Vector2(2.0e6, 2.0e6))
