extends GutTest
## A4: karakter `sfx` sözlüğü, beceri/evrim sesleri, ses spam önlemi. Sesler yalnız görünüm/olay tarafında: sim RNG'si ve
## state_hash değişmez.

const LEGACY_IDS: Array[StringName] = [
	&"shot_right", &"shot_left", &"reload_spin", &"reload_click", &"dry_fire", &"hit"
]
const ZYFEN_SKILLS: Array[StringName] = [
	&"hava_bicaklari",
	&"delen_ruzgar",
	&"girdap",
	&"hortum",
	&"hava_cebi",
	&"nefes_dalgasi",
	&"ay_oragi",
	&"kasirga_patlamasi",
	&"gogun_mizragi",
	&"tufan",
]

var bus: SimBus
var fx: SimFx
var gd: GameData
var director: AudioDirector
var ids: Array[StringName] = []


func before_all() -> void:
	gd = GameData.load_dir("res://data")


func _bind(character_id: StringName) -> void:
	bus = SimBus.new()
	fx = SimFx.new()
	director = AudioDirector.new()
	add_child_autofree(director)
	director.bind(bus, gd, gd.get_character(character_id), fx)
	ids = []
	director.played.connect(func(id: StringName) -> void: ids.append(id))


func _all_events() -> void:
	bus.shot_fired.emit(0, Vector2.ZERO, Vector2.RIGHT)
	bus.shot_fired.emit(1, Vector2.ZERO, Vector2.RIGHT)
	bus.enemy_hit.emit(Vector2.ZERO)
	bus.reload_started.emit(1.0)
	bus.reload_finished.emit()
	bus.dry_fire.emit(0)


func test_zyfen_events_pick_zyfen_sounds_and_no_gunslinger_ones() -> void:
	_bind(&"zyfen")
	_all_events()
	assert_eq(
		ids,
		(
			[&"zyfen_cast", &"zyfen_cast", &"zyfen_wind_hit", &"zyfen_gather", &"zyfen_gather_done"]
			as Array[StringName]
		),
		"atış, isabet, doldurma başı/sonu; boş tetik sessiz"
	)
	for id in ids:
		assert_false(LEGACY_IDS.has(id), "Gunslinger sesi çalmamalı: %s" % id)


func test_characterization_gunslinger_sounds_unchanged() -> void:
	_bind(&"gunslinger")
	_all_events()
	assert_eq(
		ids,
		(
			[&"shot_right", &"shot_left", &"hit", &"reload_spin", &"reload_click", &"dry_fire"]
			as Array[StringName]
		)
	)


func test_unbound_character_keeps_legacy_defaults() -> void:
	bus = SimBus.new()
	director = AudioDirector.new()
	add_child_autofree(director)
	director.bind(bus)
	ids = []
	director.played.connect(func(id: StringName) -> void: ids.append(id))
	_all_events()
	assert_eq(ids[0], &"shot_right")
	assert_eq(ids.size(), 6)


func test_variants_exist_for_zyfen_sounds() -> void:
	assert_eq(Sfx.variant_count(&"zyfen_cast"), 3)
	assert_eq(Sfx.variant_count(&"zyfen_wind_hit"), 2)
	assert_eq(Sfx.variant_count(&"hava_bicaklari"), 3)
	assert_eq(Sfx.variant_count(&"zyfen_gather"), 1)


func test_zyfen_skills_have_existing_cast_sfx() -> void:
	for sid in ZYFEN_SKILLS:
		var sk := gd.get_skill(sid)
		assert_ne(sk.cast_sfx, &"", "%s: cast_sfx" % sid)
		assert_true(DataV2.sfx_exists(String(sk.cast_sfx)), "%s: dosya" % sid)
		assert_ne(sk.pool, &"common")


func test_zyfen_evolutions_have_distinct_evolution_sounds_apart_from_gunslinger() -> void:
	var zy := {}
	var gun := {}
	for sk in gd.skills_of_kind(SkillDef.KIND_EVOLUTION):
		assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % sk.sfx), sk.id)
		if sk.pool == &"zyfen":
			zy[sk.sfx] = true
		else:
			gun[sk.sfx] = true
	assert_eq(zy.size(), 4, "Zyfen'in 4 evrimi 4 ayrı ses")
	assert_true(zy.has(&"evolution_7") and zy.has(&"evolution_8"))
	for k in zy:
		assert_false(gun.has(k), "Gunslinger evrim sesiyle çakışma: %s" % k)


func test_all_character_sfx_files_exist() -> void:
	for cid in gd.character_ids:
		var c := gd.get_character(cid)
		for k in c.sfx:
			var v: Variant = c.sfx[k]
			for id in v if v is Array else [v]:
				assert_true(DataV2.sfx_exists(str(id)), "%s.%s = %s" % [cid, k, id])


func test_skill_sfx_signal_plays_cast_sfx_only_when_defined() -> void:
	_bind(&"zyfen")
	fx.skill_sfx.emit(&"hortum")
	fx.skill_sfx.emit(&"ruzgar_kesigi")  # cast_sfx yok: temel silah sesi karakter sözlüğünden
	fx.skill_sfx.emit(&"yok_boyle")
	assert_eq(ids, [&"hortum"] as Array[StringName])


func test_behaviors_emit_skill_sfx_from_real_sim() -> void:
	for sid in [&"hortum", &"tufan", &"hava_bicaklari", &"delen_ruzgar", &"girdap"]:
		var sim := WindKit.make(sid, 1)
		var got: Array[StringName] = []
		sim.fx.skill_sfx.connect(func(s: StringName) -> void: got.append(s))
		WindKit.dummy(sim, Vector2(120, 0))
		WindKit.skill_steps(sim, 5)
		assert_true(got.has(sid), "%s ateşlenince skill_sfx yayınlar" % sid)


func test_girdap_sound_is_periodic_not_per_pulse() -> void:
	var sim := WindKit.make(&"girdap", 1)
	var n := [0]
	sim.fx.skill_sfx.connect(func(_s: StringName) -> void: n[0] += 1)
	WindKit.dummy(sim, Vector2(60, 0))
	WindKit.skill_steps(sim, 600)  # 10 sn: darbe ~20, ses 3
	assert_between(n[0], 2, 4)


func test_presentation_rng_is_separate_from_sim_rng() -> void:
	var sim := WindKit.make(&"hava_bicaklari", 1)
	var h0 := sim.state_hash()
	var rng0 := sim.rng_combat.state
	Sfx.seed_presentation(7)
	for _i in 20:
		Sfx.pick_stream(&"zyfen_cast")
	assert_eq(sim.state_hash(), h0)
	assert_eq(sim.rng_combat.state, rng0, "varyasyon seçimi sim RNG'sini tüketmez")


func test_variation_never_repeats_back_to_back() -> void:
	Sfx.seed_presentation(3)
	var last: AudioStream = null
	for _i in 30:
		var s := Sfx.pick_stream(&"zyfen_cast")
		assert_ne(s, last)
		last = s


func test_min_gap_blocks_rapid_repeats_of_wind_sounds_only() -> void:
	Sfx.teardown()
	assert_false(Sfx.gap_blocked(&"hortum", 1000))
	Sfx._last_ms[&"hortum"] = 1000
	assert_true(Sfx.gap_blocked(&"hortum", 1200))
	assert_false(Sfx.gap_blocked(&"hortum", 1500))
	for id in LEGACY_IDS + ([&"enemy_die", &"xp_pickup", &"explosion"] as Array[StringName]):
		assert_eq(Sfx.min_gap_of(id), 0, "Gunslinger sesi %s aralık almaz" % id)
	Sfx.teardown()


func test_sfx_players_use_sfx_bus() -> void:
	_bind(&"zyfen")
	assert_true(AudioServer.get_bus_index(&"SFX") >= 0)
	var found := 0
	for p in director.get_children():
		if p is AudioStreamPlayer and (p as AudioStreamPlayer).bus == &"SFX":
			found += 1
	assert_eq(found, Sfx.POOL_SIZE)


func test_sfx_validation_rules() -> void:
	var bad := PackedStringArray()
	DataV2.validate_cast_sfx(bad, "p.json", {"kind": "passive", "cast_sfx": "hortum"})
	DataV2.validate_cast_sfx(bad, "a.json", {"kind": "active", "cast_sfx": ""})
	DataV2.validate_cast_sfx(bad, "b.json", {"kind": "active", "cast_sfx": "yok_boyle"})
	DataV2.validate_character_sfx(bad, "c.json", {"shot": "yok_boyle"})
	DataV2.validate_character_sfx(bad, "d.json", {"bilinmeyen": "hit"})
	DataV2.validate_character_sfx(bad, "e.json", {"shot": []})
	assert_eq(bad.size(), 6, str(bad))
	var ok := PackedStringArray()
	DataV2.validate_cast_sfx(ok, "a.json", {"kind": "active", "cast_sfx": "hava_bicaklari"})
	DataV2.validate_character_sfx(ok, "z.json", {"shot": ["shot_right", "shot_left"], "hit": "hit"})
	assert_eq(ok.size(), 0, str(ok))
