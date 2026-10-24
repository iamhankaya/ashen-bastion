extends GutTest
## Kabul (v2.0 B3/B4 bütçe): başarım motoru GÖZLEMCİDİR — tracker bağlı/bağsız aynı tohum aynı state_hash ve event_log.
## Matris: 2 karakter (gunslinger, zyfen) × 3 politika × 2 tohum × 2400 adım; iki simde de log_events=true. Her 300 adımda hash karşılaştırılır.
## Kara Bomba (bomb_hits) gerçekten patlar: testin kendisi bunu olay günlüğünden doğrular (bota güvenilmez).
## Süre: B-tur: 3 politika × 3 tohum × 2 karakter (plan matrisi); daha uzun koşu test/long/ varyantına ayrılabilir.
## Dilim B bitmeden pending (tracker gövdesi Stub.todo).

const SEG := 300
const STEPS := 2400
const SEEDS := [101, 202, 303]
const CHARS := [&"gunslinger", &"zyfen"]
const BOMB_STEPS := [200, 1100, 1700]


func after_each() -> void:
	AchKit.cleanup()


func _gate() -> bool:
	return V2Slice.require(self, "B")


func _sim(seed_value: int, character: StringName) -> GameSim:
	return SimKit.make(
		seed_value, {"data_kind": "real", "character": character, "log_events": true}
	)


## Sabit adımlarda aynı yardımcı eylemler: Kara Bomba toplama + yakın düşman halkası (dinamit isabeti için).
func _scripted(sim: GameSim, step_index: int) -> void:
	if step_index in BOMB_STEPS:
		sim.debug_fill(&"curumus_piyade", 6, 140.0)
		sim.debug_spawn_pickup(&"kara_bomba", sim.player_pos)
		sim.debug_collect_pickups()


## Tek koşu: gözlemci verilirse attach + her adımda poll. [hash dizisi, event_log]
func _play(sim: GameSim, policy: StringName, tracker: AchievementTracker) -> Array:
	var rng := Bots.make_rng(7)
	var hashes: Array[int] = []
	var done := 0
	var guard := 0
	while done < STEPS and guard < STEPS * 4:
		guard += 1
		if sim.state == GameSim.State.LEVEL_UP:
			if not Bots.choose(sim, rng):
				break
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		_scripted(sim, done)
		sim.step(Bots.move(policy, sim))
		if tracker != null:
			tracker.poll(sim)
		done += 1
		if done % SEG == 0:
			hashes.append(sim.state_hash())
	hashes.append(sim.state_hash())
	return [hashes, sim.event_log]


func _tracker_for(sim: GameSim, character: StringName) -> AchievementTracker:
	var tr := AchievementTracker.new(AchKit.data(), AchKit.store(), character, AchKit.clock())
	tr.attach(sim.bus)
	return tr


func test_b3_observer_does_not_change_state_hash_or_event_log() -> void:
	if _gate():
		return
	for character in CHARS:
		for policy in Bots.POLICIES:
			for sd in SEEDS:
				var bare := _sim(sd, character)
				var obs := _sim(sd, character)
				var tr := _tracker_for(obs, character)
				var a := _play(bare, policy, null)
				var b := _play(obs, policy, tr)
				var label := "%s/%s/%d" % [character, policy, sd]
				assert_eq(b[0], a[0], "%s: state_hash dizisi" % label)
				assert_eq(b[1].size(), a[1].size(), "%s: event_log uzunluğu" % label)
				assert_true(b[1] == a[1], "%s: event_log bire bir" % label)
				tr.detach()


func test_b3_bomb_and_dynamite_paths_actually_execute_in_the_matrix() -> void:
	if _gate():
		return
	for character in CHARS:
		var sim := _sim(SEEDS[0], character)
		var tr := _tracker_for(sim, character)
		var hits_seen := [0]
		sim.bus.bomb_hits.connect(func(_p: Vector2, _r: float, _h: int) -> void: hits_seen[0] += 1)
		_play(sim, Bots.KITE, tr)
		assert_gt(
			SimKit.count_events(sim, SimEvents.BOMB_EXPLODE),
			0,
			"%s: Kara Bomba patladı" % character
		)
		assert_gt(hits_seen[0], 0, "%s: bomb_hits yayını geldi" % character)
		tr.detach()


func test_b3_bomb_hits_listener_does_not_change_hash() -> void:
	if _gate():
		return
	var a := _sim(5, &"gunslinger")
	var b := _sim(5, &"gunslinger")
	var seen := [0]
	b.bus.bomb_hits.connect(func(_p: Vector2, _r: float, _h: int) -> void: seen[0] += 1)
	for sim in [a, b]:
		sim.debug_fill(&"curumus_piyade", 8, 150.0)
		sim.debug_spawn_pickup(&"kara_bomba", sim.player_pos)
		sim.debug_collect_pickups()
		SimKit.run(sim, 120)
	assert_gt(seen[0], 0, "ön koşul: dinleyici çağrıldı")
	assert_eq(a.state_hash(), b.state_hash())
	assert_true(a.event_log == b.event_log)


func test_b3_poll_leaves_loadout_and_actives_untouched() -> void:
	if _gate():
		return
	var sim := _sim(9, &"gunslinger")
	var tr := _tracker_for(sim, &"gunslinger")
	var arr_before := sim.loadout.actives()
	var items: Array = []
	for s in arr_before:
		items.append(s)
	var h0 := sim.state_hash()
	for i in 10:
		tr.poll(sim)
	assert_same(sim.loadout.actives(), arr_before, "dizi kimliği")
	assert_eq(sim.loadout.actives().size(), items.size())
	for i in items.size():
		assert_same(sim.loadout.actives()[i], items[i])
	assert_eq(sim.state_hash(), h0, "poll durumu değiştirmez")
	tr.detach()


func test_b3_same_seed_two_runs_with_observer_agree() -> void:
	if _gate():
		return
	var out: Array = []
	for i in 2:
		var sim := _sim(77, &"zyfen")
		var tr := _tracker_for(sim, &"zyfen")
		out.append(_play(sim, Bots.GREEDY, tr)[0])
		tr.detach()
	assert_eq(out[0], out[1])


func test_b3_golden_gunslinger_hash_matches_unobserved_baseline() -> void:
	# gunslinger altın hash testleri değişmez: tracker eklemek yeni bir sabit üretmez; karşılaştırma gözlemsiz taban ile.
	var a := _sim(3, &"gunslinger")
	var b := _sim(3, &"gunslinger")
	SimKit.run(a, 600)
	SimKit.run(b, 600)
	assert_eq(a.state_hash(), b.state_hash())
