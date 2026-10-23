extends GutTest
## Kabul: determinizm. Aynı ikili + aynı tohum + aynı bot => aynı state_hash dizisi (her 300 adımda); farklı tohum farklı.
## Sabit "altın" hash yok (RNG dizisi Godot sürümleri arasında değişebilir).

const CHUNK := 300


func _run(seed_value: int, chunks: int, opts: Dictionary, policy: StringName) -> Dictionary:
	var o := opts.duplicate()
	o["data_kind"] = "real"
	var sim := SimKit.make(seed_value, o)
	var rng := Bots.make_rng(seed_value)
	var hashes: Array = []
	for c in chunks:
		Bots.play(sim, policy, CHUNK, rng)
		hashes.append(sim.state_hash())
	return {"sim": sim, "hashes": hashes}


func test_same_seed_same_hash_every_300_steps() -> void:
	var a := _run(131, 6, {}, Bots.KITE)
	var b := _run(131, 6, {}, Bots.KITE)
	assert_eq(a["hashes"], b["hashes"], "aynı tohum -> aynı state_hash dizisi")
	assert_true(
		(a["sim"] as GameSim).event_log == (b["sim"] as GameSim).event_log,
		"olay günlüğü birebir aynı"
	)
	assert_gt((a["sim"] as GameSim).step_count, 1000, "koşu ilerlemiş olmalı")
	assert_gt(
		SimKit.count_events(a["sim"], SimEvents.SPAWN), 20, "koşu anlamlı olmalı (doğuşlar var)"
	)
	assert_gt(
		SimKit.count_events(a["sim"], SimEvents.SHOT), 10, "koşu anlamlı olmalı (atışlar var)"
	)


func test_same_seed_same_hash_in_dense_late_game() -> void:
	var a := _run(132, 3, {"start_time": 900.0}, Bots.GREEDY)
	var b := _run(132, 3, {"start_time": 900.0}, Bots.GREEDY)
	assert_gt(SimKit.count_events(a["sim"], SimEvents.SPAWN), 50, "yoğun doğuş (15. dk)")
	assert_eq(a["hashes"], b["hashes"])


func test_different_seeds_diverge() -> void:
	var a := _run(133, 4, {}, Bots.KITE)
	var b := _run(134, 4, {}, Bots.KITE)
	assert_gte(SimKit.count_events(a["sim"], SimEvents.SPAWN), 10, "koşu anlamlı olmalı")
	assert_ne(a["hashes"][3], b["hashes"][3], "farklı tohum farklı gidişat")
	assert_ne(a["hashes"], b["hashes"])


func test_event_logging_does_not_change_the_simulation() -> void:
	var with_log := _run(135, 3, {"log_events": true}, Bots.KITE)
	var no_log := _run(135, 3, {"log_events": false}, Bots.KITE)
	assert_gte(SimKit.count_events(with_log["sim"], SimEvents.SPAWN), 10, "koşu anlamlı olmalı")
	assert_eq(with_log["hashes"], no_log["hashes"], "log_events yalnız gözlem; sonucu etkilemez")
	assert_eq((no_log["sim"] as GameSim).event_log.size(), 0, "üretimde günlük tutulmaz")


func test_hash_changes_as_the_game_progresses() -> void:
	var r := _run(136, 4, {}, Bots.KITE)
	assert_gte(SimKit.count_events(r["sim"], SimEvents.SPAWN), 10, "koşu anlamlı olmalı")
	var seen := {}
	for h in r["hashes"]:
		seen[h] = true
	assert_eq(seen.size(), 4, "durum her bölümde farklı")


func test_choice_stream_is_independent_of_bot_and_combat_noise() -> void:
	var a := SimKit.make(137)
	var b := SimKit.make(137)
	for i in 300:
		b.rng_spawn.randi()
		b.rng_combat.randi()
	var ids_a: Array = []
	var ids_b: Array = []
	SimKit.level_up_with(a, 12)
	SimKit.level_up_with(b, 12)
	for c in a.pending_choices():
		ids_a.append(c.skill_id)
	for c in b.pending_choices():
		ids_b.append(c.skill_id)
	assert_gt(ids_a.size(), 0)
	assert_eq(ids_a, ids_b)


func test_sims_do_not_share_global_state() -> void:
	var solo := _run(138, 4, {}, Bots.KITE)
	var a := SimKit.make(138, {"data_kind": "real"})
	var rng_a := Bots.make_rng(138)
	var hashes: Array = []
	for c in 4:
		Bots.play(a, Bots.KITE, CHUNK, rng_a)
		hashes.append(a.state_hash())
		# araya başka bir oyun girer: örnek başına durum (bus, havuzlar, RNG) sızmamalı
		var other := SimKit.make(900 + c, {"data_kind": "real"})
		Bots.play(other, Bots.GREEDY, 200, Bots.make_rng(900 + c))
	assert_gte(SimKit.count_events(a, SimEvents.SPAWN), 10, "koşu anlamlı olmalı")
	assert_eq(hashes, solo["hashes"], "araya giren oyun hash dizisini değiştirmemeli")


func test_every_run_starts_from_scratch() -> void:
	var played := SimKit.make(139, {"data_kind": "real"})
	Bots.play(played, Bots.GREEDY, 1200, Bots.make_rng(139))
	played.debug_grant(&"agir_kursun", 3)
	var fresh := SimKit.make(139, {"data_kind": "real"})
	assert_eq(fresh.level, 1)
	assert_eq(fresh.xp, 0)
	assert_eq(fresh.kills, 0)
	assert_eq(fresh.step_count, 0)
	assert_eq(fresh.time, 0.0)
	assert_eq(fresh.hp, fresh.max_hp)
	assert_eq(fresh.magazine.count, fresh.magazine.cap)
	assert_eq(fresh.enemies.count, 0)
	assert_eq(fresh.evolved_log.size(), 0)
	assert_eq(fresh.loadout.actives().size(), 1, "yalnız başlangıç becerisi")
	assert_eq(fresh.loadout.passives().size(), 0, "ilerleme taşınmaz (meta ilerleme yok)")
	assert_eq(fresh.loadout.level_of(&"cift_tabanca"), 1)
	assert_eq(fresh.loadout.level_of(&"agir_kursun"), 0)
	assert_eq(fresh.state, GameSim.State.RUNNING)
	assert_eq(fresh.state_hash(), SimKit.make(139, {"data_kind": "real"}).state_hash())
