extends GutTest
## Sözleşme (S2): SimBus.bomb_hits — imza, kaynak ayrımı (yalnız Kara Bomba), sim durumuna etkisizlik; tracker'ın dinlediği
## sinyallerin gerçek imzası. Başarım motoru sim'i yalnız dinler (plan: "Bomba isabeti (#22) — karar").

const AT := Vector2(60, 0)
const FUSE_STEPS := 60
## Tracker'ın bağlandığı her sinyal: ad -> argüman adları (gerçek get_signal_list ile birebir).
const LISTENED := {
	"enemy_killed": ["type_id", "pos"],
	"level_up": ["level"],
	"score_changed": ["score", "mult", "gain"],
	"reload_started": ["duration"],
	"streak_changed": ["mult", "left"],
	"pickup_collected": ["kind_id", "pos"],
	"player_damaged": ["amount", "hp"],
	"evolution_gained": ["evo_id"],
	"buff_started": ["kind", "duration"],
	"buff_ended": ["kind"],
	"bomb_hits": ["pos", "radius", "hits"],
}

var _hits: Array = []
var _order: Array[String] = []


func before_each() -> void:
	_hits = []
	_order = []


func _on_hits(pos: Vector2, radius: float, hits: int) -> void:
	_hits.append({"pos": pos, "radius": radius, "hits": hits})
	_order.append("bomb_hits")


func _on_exploded(_pos: Vector2, _radius: float) -> void:
	_order.append("bomb_exploded")


## Sessiz veri, ateşsiz oyuncu; n düşman bombanın yakınında; bomba toplanıp yerleştirilmiş.
func _bombed(seed_value: int, enemies: int, listen: bool) -> GameSim:
	var sim := SimKit.make(seed_value, {"data_kind": "quiet_pickups"})
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	if listen:
		sim.bus.bomb_hits.connect(_on_hits)
		sim.bus.bomb_exploded.connect(_on_exploded)
	for k in enemies:
		var id := SimKit.add_enemy(sim, &"curumus_piyade", AT + Vector2(40.0 * k, 120.0))
		sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
	assert_gte(sim.debug_spawn_pickup(&"kara_bomba", AT), 0)
	sim.debug_collect_pickups()
	return sim


func test_bomb_hits_signal_signature() -> void:
	var found := {}
	for s in SimBus.new().get_signal_list():
		found[s["name"]] = s
	assert_true(found.has("bomb_hits"))
	var args: Array = found["bomb_hits"]["args"]
	assert_eq(args.size(), 3)
	assert_eq(args[0]["name"], "pos")
	assert_eq(args[0]["type"], TYPE_VECTOR2)
	assert_eq(args[1]["name"], "radius")
	assert_eq(args[1]["type"], TYPE_FLOAT)
	assert_eq(args[2]["name"], "hits")
	assert_eq(args[2]["type"], TYPE_INT)


func test_existing_bomb_exploded_signature_unchanged() -> void:
	for s in SimBus.new().get_signal_list():
		if s["name"] == "bomb_exploded":
			assert_eq((s["args"] as Array).size(), 2, "bomb_exploded imzası genişletilmedi")
			return
	fail_test("bomb_exploded yok")


func test_new_signals_are_appended_at_the_end_in_source_order() -> void:
	# Yeni sinyal SONA eklenir (mevcut sinyallerin sırası/imzası değişmez): ... bomb_hits, enemy_hit (v2.0.1),
	# milestone_reached, lord_slain (v2.1). Sondan dördü sırayla sabit.
	var sigs: Array[String] = []
	for line in FileAccess.get_file_as_string("res://scripts/sim/sim_bus.gd").split("\n"):
		if line.begins_with("signal "):
			sigs.append(line)
	assert_true(sigs.size() >= 4)
	var tail := sigs.slice(sigs.size() - 4)
	assert_true(tail[0].begins_with("signal bomb_hits("), tail[0])
	assert_true(tail[1].begins_with("signal enemy_hit("), tail[1])
	assert_true(tail[2].begins_with("signal milestone_reached"), tail[2])
	assert_true(tail[3].begins_with("signal lord_slain("), tail[3])


func test_tracker_listened_signals_exist_with_exact_signatures() -> void:
	var found := {}
	for s in SimBus.new().get_signal_list():
		found[s["name"]] = s
	assert_eq(AchievementTracker.LISTENED.size(), LISTENED.size())
	for name: String in LISTENED:
		assert_true(AchievementTracker.LISTENED.has(name), "%s tracker listesinde" % name)
		assert_true(found.has(name), "%s SimBus'ta" % name)
		if not found.has(name):
			continue
		var got: Array[String] = []
		for a in found[name]["args"]:
			got.append(a["name"])
		assert_eq(got, LISTENED[name], "%s argümanları" % name)


func test_run_ended_is_not_listened_by_the_tracker() -> void:
	assert_false(AchievementTracker.LISTENED.has("run_ended"), "finish controller'dan çağrılır")


func test_hits_equals_logged_bomb_explode_hits_and_follows_bomb_exploded() -> void:
	var sim := _bombed(1, 3, true)
	SimKit.run(sim, FUSE_STEPS + 5)
	assert_eq(_hits.size(), 1, "tek bomba tek bomb_hits")
	var logged := SimKit.last_event(sim, SimEvents.BOMB_EXPLODE)
	assert_false(logged.is_empty())
	assert_eq(
		_hits[0]["hits"], int(logged["hits"]), "hits günlükteki bomb_explode.hits ile birebir"
	)
	assert_gte(_hits[0]["hits"], 1)
	assert_eq(_hits[0]["pos"], logged["pos"])
	assert_eq(_hits[0]["radius"], float(logged["radius"]))
	assert_eq(_order, ["bomb_exploded", "bomb_hits"], "bomb_exploded'ten hemen sonra")


func test_bomb_with_no_enemies_still_emits_zero_hits() -> void:
	var sim := _bombed(1, 0, true)
	SimKit.run(sim, FUSE_STEPS + 5)
	assert_eq(_hits.size(), 1)
	assert_eq(_hits[0]["hits"], 0)


func test_two_bombs_emit_two_signals() -> void:
	var sim := _bombed(1, 2, true)
	assert_gte(sim.debug_spawn_pickup(&"kara_bomba", Vector2(40, 20)), 0)
	sim.debug_collect_pickups()
	SimKit.run(sim, FUSE_STEPS + 5)
	assert_eq(_hits.size(), 2)


func test_zyfen_run_never_emits_bomb_hits() -> void:
	# v2.0.2 S1: Barutçu/dinamit yerine Zyfen (no-op gövdeler); bomb_hits yalnız Kara Bomba'dan gelir.
	var sim := SimKit.make(3, {"data_kind": "real", "character": &"zyfen"})
	sim.bus.bomb_hits.connect(_on_hits)
	SimKit.godmode(sim)
	for k in 8:
		SimKit.add_enemy(sim, &"curumus_piyade", Vector2.from_angle(TAU * k / 8.0) * 220.0)
	SimKit.run(sim, 900)
	assert_gt(
		SimKit.count_events(sim, SimEvents.SHOT),
		0,
		"test yolu görmeden yeşil olmasın: Zyfen ateş etti"
	)
	assert_eq(_hits.size(), 0, "Kara Bomba dışı hiçbir kaynak bomb_hits yayınlamaz")


func test_listener_does_not_change_state_hash_or_event_log() -> void:
	var a := _bombed(5, 4, false)
	var b := _bombed(5, 4, true)
	for chunk in 4:
		SimKit.run(a, 30)
		SimKit.run(b, 30)
		assert_eq(
			a.state_hash(),
			b.state_hash(),
			"dinleyicili/dinleyicisiz state_hash (adım %d)" % ((chunk + 1) * 30)
		)
	assert_eq(a.event_log, b.event_log)
	assert_gt(_hits.size(), 0, "bomba gerçekten patladı")


func test_same_seed_twice_same_hash_with_bomb() -> void:
	var a := _bombed(9, 4, true)
	var b := _bombed(9, 4, true)
	SimKit.run(a, 120)
	SimKit.run(b, 120)
	assert_eq(a.state_hash(), b.state_hash())


func test_zyfen_same_seed_two_runs_same_hash() -> void:
	var a := SimKit.make(11, {"data_kind": "real", "character": &"zyfen"})
	var b := SimKit.make(11, {"data_kind": "real", "character": &"zyfen"})
	for k in 5:
		SimKit.add_enemy(a, &"curumus_piyade", Vector2.from_angle(float(k)) * 200.0)
		SimKit.add_enemy(b, &"curumus_piyade", Vector2.from_angle(float(k)) * 200.0)
	SimKit.run(a, 600, Vector2.RIGHT)
	SimKit.run(b, 600, Vector2.RIGHT)
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.character.id, &"zyfen")
	assert_eq(a.max_hp, 85.0)
	assert_eq(a.magazine.cap, 8)


func test_gunslinger_hash_unchanged_by_bomb_hits_signal_existence() -> void:
	# Altın hash testleri (test_acc_determinism vb.) ayrıca koşar; burada çıplak iki koşu eşitliği.
	var a := SimKit.make(21, {"data_kind": "real"})
	var b := SimKit.make(21, {"data_kind": "real"})
	b.bus.bomb_hits.connect(_on_hits)
	SimKit.run(a, 300, Vector2.LEFT)
	SimKit.run(b, 300, Vector2.LEFT)
	assert_eq(a.state_hash(), b.state_hash())
