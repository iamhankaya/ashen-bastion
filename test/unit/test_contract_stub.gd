extends GutTest
## Sözleşme: iskelet gövdeleri Stub.todo çağırır (push_error değil); kayıt varsa GUT post-run kancası gate'i kırar.

var _nodes: Array = []


func after_each() -> void:
	Stub.reset()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func test_todo_records_and_reset_clears() -> void:
	Stub.todo(&"A.b")
	Stub.todo(&"C.d")
	assert_eq(Stub.calls(), [&"A.b", &"C.d"] as Array[StringName])
	Stub.reset()
	assert_eq(Stub.calls().size(), 0)


func test_calls_returns_a_copy() -> void:
	Stub.todo(&"X.y")
	Stub.calls().clear()
	assert_eq(Stub.calls().size(), 1)


func test_no_skeleton_methods_remain() -> void:
	# Hâlâ iskelet olan gövdeler buraya [çağrı, kimlik] olarak eklenir; içerik tamamlandığında liste boştur.
	var cases: Array = []
	assert_eq(cases.size(), 0, "iskelet gövde kalmadı")
	for c in cases:
		Stub.reset()
		c[0].call()
		assert_eq(Stub.calls(), [c[1]] as Array[StringName], "%s" % c[1])


func test_sfx_play_is_a_silent_noop() -> void:
	Sfx.play(&"hit")
	Sfx.play(&"yok_boyle_ses", {"pitch": 1.2})
	assert_eq(Stub.calls().size(), 0)


func test_post_run_hook_is_configured() -> void:
	var cfg: Dictionary = KitDev.read_json("res://.gutconfig.json")
	assert_eq(cfg.get("post_run_script"), "res://tools/ci/gut_stub_hook.gd")
	assert_true(FileAccess.file_exists("res://tools/ci/gut_stub_hook.gd"))


# --- v1.1 iskeletleri: her gövde Stub.todo kaydı bırakır; D fazları uyguladıkça girdi buradan SİLİNİR ---------


func _node(n: Node) -> Node:
	_nodes.append(n)
	return n


## [çağrı, beklenen kimlik]. Faz başına ayrı işlev: her D fazı YALNIZ kendi işlevini düzenler (birleştirme çakışması olmasın).
## Boşta no-op olan gövdeler için önce "iş var" durumu kurulur. Uyguladığın yöntemin satırını sil.
func _v11_cases() -> Array:
	return _cases_d1() + _cases_d2() + _cases_d3()


## D1: oyuncu/düşman animasyonu, gölge, hayalet, FX
func _cases_d1() -> Array:
	var sim := GameSim.new(1, &"gunslinger")
	var anim := PlayerAnim.new()
	var fx := FxRenderer.new()
	_nodes.append(fx)
	return [
		[func() -> void: anim.configure({}), &"PlayerAnim.configure"],
		[func() -> void: anim.reset(), &"PlayerAnim.reset"],
		[func() -> void: anim.update(0.016, Vector2.ZERO, false, -1.0), &"PlayerAnim.update"],
		[func() -> void: anim.on_shot(0), &"PlayerAnim.on_shot"],
		[func() -> void: anim.on_damaged(5.0, Vector2.LEFT), &"PlayerAnim.on_damaged"],
		[func() -> void: anim.on_level_up(), &"PlayerAnim.on_level_up"],
		[func() -> void: anim.on_buffs(1), &"PlayerAnim.on_buffs"],
		[func() -> void: anim.on_died(Vector2.LEFT), &"PlayerAnim.on_died"],
		[func() -> void: anim.on_won(), &"PlayerAnim.on_won"],
		[func() -> void: anim.death_done(), &"PlayerAnim.death_done"],
		[func() -> void: EnemyAnim.new().bind(null, null), &"EnemyAnim.bind"],
		[func() -> void: EnemyAnim.new().sync_slot(0, 0, Vector2.ZERO), &"EnemyAnim.sync_slot"],
		[func() -> void: EnemyAnim.pose_of(0, 1.0, 5.0, 0.1, 0.05, 1.0, 0.0), &"EnemyAnim.pose_of"],
		[
			func() -> void: _node(EnemyShadowLayer.new()).write(PackedFloat32Array(), 0),
			&"EnemyShadowLayer.write"
		],
		[func() -> void: _node(EnemyRenderer.new()).set_ghosts(null), &"EnemyRenderer.set_ghosts"],
		[func() -> void: _node(AshGhostRenderer.new()).bind(sim, null), &"AshGhostRenderer.bind"],
		[
			func() -> void: _node(AshGhostRenderer.new()).update_ghosts(0.016),
			&"AshGhostRenderer.update_ghosts"
		],
		[
			func() -> void: _node(AshGhostRenderer.new()).ghost_count(),
			&"AshGhostRenderer.ghost_count"
		],
		[
			func() -> void: fx.add_ring(Vector2.ZERO, 100.0, 0.5, Color.WHITE, 4.0),
			&"FxRenderer.add_ring"
		],
		[func() -> void: fx.add_shell(Vector2.ZERO, Vector2.UP), &"FxRenderer.add_shell"],
		[
			func() -> void: fx.add_particle(&"dust", Vector2.ZERO, Vector2.UP, 0.5),
			&"FxRenderer.add_particle"
		],
		[func() -> void: fx.add_char(Vector2.ZERO, 40.0), &"FxRenderer.add_char"],
	]


## D2: eklentiler, etkiler, bomba, eklenti HUD
func _cases_d2() -> Array:
	var sim := GameSim.new(1, &"gunslinger")
	var pool := PickupPool.new()
	pool.count = 1
	var bombs := BombPool.new()
	var buffs := BuffManager.new()
	buffs.left_steps[0] = 3
	var director := PickupDirector.new({}, RandomNumberGenerator.new())
	director.armed = true
	var busy := GameSim.new(1, &"gunslinger")
	busy.debug_spawn_pickup(&"kizil_iksir", Vector2.ZERO)
	busy.bombs.count = 1
	var ints := PackedInt32Array()
	var buff_row: BuffRow = _node(BuffRow.new())
	buff_row.visible = true
	var arrow: OffscreenArrow = _node(OffscreenArrow.new())
	arrow.visible = true
	var floaty: FloatText = _node(FloatText.new())
	floaty.visible = true
	return [
		[func() -> void: pool.tick(ints), &"PickupPool.tick"],
		[func() -> void: bombs.plant(Vector2.ZERO, 48, 320.0, 4), &"BombPool.plant"],
		[func() -> void: bombs.remove(0), &"BombPool.remove"],
		[func() -> void: buffs.start(0, 720), &"BuffManager.start"],
		[func() -> void: buffs.active(0), &"BuffManager.active"],
		[func() -> void: buffs.ratio(0), &"BuffManager.ratio"],
		[func() -> void: buffs.tick(ints), &"BuffManager.tick"],
		[func() -> void: buffs.damage_mult(), &"BuffManager.damage_mult"],
		[func() -> void: buffs.fire_rate_mult(), &"BuffManager.fire_rate_mult"],
		[func() -> void: buffs.unlimited(), &"BuffManager.unlimited"],
		[func() -> void: director.step(sim), &"PickupDirector.step"],
		[func() -> void: director.skip_to(600), &"PickupDirector.skip_to"],
		[func() -> void: director.progress_hash(), &"PickupDirector.progress_hash"],
		[
			func() -> void: sim.bomb_blast(Vector2.ZERO, 320.0, 600.0, 0.08, 600.0),
			&"PickupSystem.blast"
		],
		[func() -> void: busy.debug_collect_pickups(), &"PickupSystem.collect"],
		[func() -> void: busy._tick_bombs(), &"PickupSystem.tick_bombs"],
		[func() -> void: busy._apply_buffs(), &"PickupSystem.apply_buffs"],
		[func() -> void: busy._buffs_ended(PackedInt32Array([0])), &"PickupSystem.buffs_ended"],
		[func() -> void: Magazine.new().set_unlimited(true), &"Magazine.set_unlimited"],
		[func() -> void: _node(PickupRenderer.new()).bind(sim), &"PickupRenderer.bind"],
		[func() -> void: _node(PickupRenderer.new()).refresh(0.016), &"PickupRenderer.refresh"],
		[func() -> void: buff_row.bind(sim), &"BuffRow.bind"],
		[func() -> void: buff_row.refresh(0.016), &"BuffRow.refresh"],
		[func() -> void: BuffRow.badge_x(1), &"BuffRow.badge_x"],
		[func() -> void: BuffRow.seconds_text(600), &"BuffRow.seconds_text"],
		[func() -> void: BuffRow.blinking(2.0), &"BuffRow.blinking"],
		[func() -> void: arrow.bind(sim), &"OffscreenArrow.bind"],
		[func() -> void: arrow.refresh(0.016), &"OffscreenArrow.refresh"],
		[
			func() -> void:
				OffscreenArrow.place(Vector2.ZERO, Vector2.ZERO, Vector2(1080, 2400), Rect2(), 50.0),
			&"OffscreenArrow.place"
		],
		[func() -> void: floaty.show_text("x", Vector2.ZERO), &"FloatText.show_text"],
		[func() -> void: floaty.refresh(0.016), &"FloatText.refresh"],
		[
			func() -> void: _node(MagazineDrum.new()).set_unlimited(true),
			&"MagazineDrum.set_unlimited"
		],
	]


## D3: skor, highscore, ekranlar
func _cases_d3() -> Array:
	var sim := GameSim.new(1, &"gunslinger")
	var scores: HighscoreScreen = _node(HighscoreScreen.new())
	return [
		[
			func() -> void: scores.show_scores([] as Array[Dictionary]),
			&"HighscoreScreen.show_scores"
		],
		[func() -> void: scores.apply_safe_area(), &"HighscoreScreen.apply_safe_area"],
		[func() -> void: _node(MainMenu.new()).apply_safe_area(), &"MainMenu.apply_safe_area"],
	]


func test_v11_skeleton_bodies_record_stub_todo() -> void:
	var cases := _v11_cases()
	assert_gt(cases.size(), 70)
	var ids := {}
	for c in cases:
		assert_false(ids.has(c[1]), "yinelenen kimlik %s" % c[1])
		ids[c[1]] = true
		Stub.reset()
		c[0].call()
		assert_eq(Stub.calls(), [c[1]] as Array[StringName], "%s" % c[1])


func test_v11_skeleton_bodies_are_idle_when_there_is_no_work() -> void:
	# v1 davranışını koruyan korumalar: iş yokken iskelet kaydı oluşmaz.
	var ints := PackedInt32Array([7])
	PickupPool.new().tick(ints)
	assert_true(ints.is_empty(), "çıktı dizisi temizlenir")
	ints = PackedInt32Array([7])
	BombPool.new().tick(ints)
	assert_true(ints.is_empty())
	ints = PackedInt32Array([7])
	BuffManager.new().tick(ints)
	assert_true(ints.is_empty())
	var sim := GameSim.new(1, &"gunslinger")
	sim.debug_collect_pickups()
	sim._tick_bombs()
	PickupDirector.new({}, RandomNumberGenerator.new()).step(sim)
	PickupDirector.new({}, RandomNumberGenerator.new()).skip_to(100)
	var keeper := ScoreKeeper.new(ScoreTable.new())
	assert_eq(keeper.on_kill(&"curumus_piyade", 1), 0)
	keeper.on_evolution()
	keeper.on_lord()
	keeper.break_streak(1)
	keeper.tick(1)
	assert_eq(keeper.streak_left(1), 0.0)
	var hidden: Array[Control] = [
		ScoreBlock.new(), BuffRow.new(), OffscreenArrow.new(), FloatText.new()
	]
	for node in hidden:
		assert_false(node.visible, "v1.1 HUD öğeleri gizli doğar")
		node.call("refresh", 0.016)
		if node.has_method("bind"):
			node.call("bind", sim)
		node.free()
	assert_eq(Stub.calls().size(), 0, "boşta/gizliyken iskelet çağrısı yok: %s" % [Stub.calls()])


func test_v11_real_pure_parts_do_not_record_stub_calls() -> void:
	var t := ScoreTable.new()
	assert_eq(t.points(&"x"), 0)
	assert_eq(ScoreKeeper.new(t).total(), 0)
	assert_eq(BombPool.new().is_full(), false)
	assert_eq(BuffManager.kind_of("damage"), 0)
	var pool := PickupPool.new()
	assert_eq(pool.spawn(0, Vector2.ONE, 10), 0)
	pool.remove(0)
	assert_eq(pool.count, 0)
	assert_eq(WalkCycle.frame_at(0.5, 6), 3)
	assert_eq(Stub.calls().size(), 0)
