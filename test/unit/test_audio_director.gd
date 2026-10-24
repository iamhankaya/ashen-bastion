extends GutTest
## AudioDirector köprüsü: sim olayı -> ses kimliği (Sfx sessiz iskelet).

var bus: SimBus
var director: AudioDirector
var ids: Array[StringName] = []


func before_each() -> void:
	bus = SimBus.new()
	director = AudioDirector.new()
	add_child_autofree(director)
	director.bind(bus)
	ids = []
	director.played.connect(func(id: StringName) -> void: ids.append(id))


func test_shot_sounds_differ_per_gun() -> void:
	bus.shot_fired.emit(0, Vector2.ZERO, Vector2.RIGHT)
	bus.shot_fired.emit(1, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(ids, [&"shot_right", &"shot_left"] as Array[StringName])


func test_reload_and_misc_events_map_to_sounds() -> void:
	bus.reload_started.emit(1.0)
	bus.reload_finished.emit()
	bus.dry_fire.emit(0)
	bus.enemy_killed.emit(&"curumus_piyade", Vector2.ZERO)
	bus.gem_collected.emit(1)
	bus.player_damaged.emit(5.0, 95.0)
	bus.explosion.emit(Vector2.ZERO, 100.0)
	bus.evolution_gained.emit(&"x")
	assert_eq(
		ids,
		(
			[
				&"reload_spin",
				&"reload_click",
				&"dry_fire",
				&"enemy_die",
				&"xp_pickup",
				&"player_hurt",
				&"explosion",
				&"evolution_1"
			]
			as Array[StringName]
		)
	)


func test_hit_event_maps_to_hit_sound() -> void:
	bus.enemy_hit.emit(Vector2.ZERO)
	assert_eq(ids, [&"hit"] as Array[StringName])


func test_level_up_signal_alone_is_silent() -> void:
	bus.level_up.emit(2)
	assert_eq(ids.size(), 0, "ses kartlar gösterilince çalar (play_level_up)")


func _choice(kind: StringName, skill_id: StringName) -> Choice:
	var c := Choice.new()
	c.kind = kind
	c.skill_id = skill_id
	return c


func test_level_up_sound_depends_on_evolution_card() -> void:
	var plain: Array = [_choice(Choice.KIND_UPGRADE, &"a"), _choice(Choice.KIND_HEAL, &"")]
	var with_evo: Array = [_choice(Choice.KIND_UPGRADE, &"a"), _choice(Choice.KIND_EVOLUTION, &"e")]
	assert_eq(AudioDirector.level_up_sound(plain), &"level_up_normal")
	assert_eq(AudioDirector.level_up_sound(with_evo), &"level_up_evolution")
	assert_eq(AudioDirector.level_up_sound([]), &"level_up_normal")
	director.play_level_up(plain)
	director.play_level_up(with_evo)
	assert_eq(ids, [&"level_up_normal", &"level_up_evolution"] as Array[StringName])


func test_evolution_sound_follows_skill_sfx_field() -> void:
	var gd := GameData.load_dir("res://data")
	var seen := {}
	for sk in gd.skills_of_kind(SkillDef.KIND_EVOLUTION):
		assert_ne(sk.sfx, &"", "%s: sfx alanı" % sk.id)
		assert_eq(AudioDirector.evolution_sound(gd, sk.id), sk.sfx)
		if sk.pool != &"zyfen":
			seen[sk.sfx] = true
	assert_eq(
		seen.size(),
		4,
		"Gunslinger'ın 4 evriminin sesleri birbirinden farklı (Zyfen yer tutucuları ayrı grup)"
	)
	assert_eq(AudioDirector.evolution_sound(gd, &"gurleyen_yelpaze"), &"evolution_1")
	director.bind(bus, gd)
	bus.evolution_gained.emit(&"kiyamet_mermisi")
	assert_eq(ids, [gd.get_skill(&"kiyamet_mermisi").sfx] as Array[StringName])


func test_evolution_without_sfx_field_falls_back_to_evolution_1() -> void:
	var gd := GameData.load_dir("res://data")
	var sk := gd.get_skill(&"mermi_firtinasi")
	var saved := sk.sfx
	sk.sfx = &""
	assert_eq(AudioDirector.evolution_sound(gd, &"mermi_firtinasi"), &"evolution_1")
	assert_eq(AudioDirector.evolution_sound(null, &"mermi_firtinasi"), &"evolution_1")
	assert_eq(AudioDirector.evolution_sound(gd, &"yok_boyle"), &"evolution_1")
	sk.sfx = saved


func test_playing_unknown_assets_is_silent_and_not_a_stub() -> void:
	bus.shot_fired.emit(0, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(Stub.calls().size(), 0)


func test_music_follows_music_plan_and_stinger_ducks_the_bus() -> void:
	var seen: Array[StringName] = []
	director.music_changed.connect(func(t: StringName) -> void: seen.append(t))
	director.update_music(0.0, true, false, false, false)
	director.update_music(0.0, false, false, false, false)
	director.update_music(700.0, false, false, false, false)
	director.update_music(700.0, false, false, true, false)
	assert_eq(seen, [&"menu", &"savas-1", &"savas-2", &"kaybettin"] as Array[StringName])
	bus.boss_warning.emit(&"elit_piyade")
	assert_true(&"boss-uyari" in ids)
	var idx := AudioServer.get_bus_index(&"Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), AudioDirector.DUCK_DB, 0.01)


func test_pause_lowers_music_bus_and_resume_restores() -> void:
	var idx := AudioServer.get_bus_index(&"Music")
	director.set_paused(true)
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), AudioDirector.PAUSE_DB, 0.01)
	director.set_paused(false)
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), 0.0, 0.01)


func test_lord_spawn_switches_to_lord_music_until_it_dies() -> void:
	director.update_music(800.0, false, false, false, false)
	bus.boss_spawned.emit(&"kale_lordu")
	director.update_music(800.0, false, false, false, false)
	assert_eq(director.track, &"kale-lordu")
	bus.enemy_killed.emit(&"kale_lordu", Vector2.ZERO)
	director.update_music(800.0, false, true, false, false)
	assert_eq(director.track, &"kazandin")


## M8c (F-013): kapanışta ana iş parçacığı bloklanmaz ve ses düğümleri sonraki karede serbest kalır.
func test_no_blocking_delay_anywhere_in_scripts() -> void:
	var hits: Array[String] = []
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if (
				f.ends_with(".gd")
				and FileAccess.get_file_as_string(dir.path_join(f)).contains("OS.delay_msec")
			):
				hits.append(dir.path_join(f))
	assert_eq(hits, [] as Array[String], "scripts/ içinde OS.delay_msec yok")


func test_players_are_freed_on_the_next_frame_after_exit() -> void:
	var d := AudioDirector.new()
	add_child(d)
	var kept: Array[AudioStreamPlayer] = []
	for c in d.get_children():
		if c is AudioStreamPlayer:
			kept.append(c)
	assert_gt(kept.size(), 0, "oynatıcılar kurulu")
	remove_child(d)  # _exit_tree
	for p in kept:
		assert_true(is_instance_valid(p), "kapanışta hemen serbest bırakılmaz (bloklama yok)")
	await get_tree().process_frame
	await get_tree().process_frame
	for p in kept:
		assert_false(is_instance_valid(p), "sonraki karede serbest")
	d.free()
