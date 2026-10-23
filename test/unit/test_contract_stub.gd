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
	return []


## D3: skor, highscore, ekranlar — hepsi uygulandı (D3-1..D3-5); iskelet kaydı kalmadı.
func _cases_d3() -> Array:
	return []


func test_v11_skeleton_bodies_record_stub_todo() -> void:
	var cases := _v11_cases()
	assert_gte(cases.size(), 0, "faz uygulandıkça liste küçülür; hepsi bitince boş")
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
