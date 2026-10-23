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
	bus.level_up.emit(2)
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
				&"level_up",
				&"explosion",
				&"evolution"
			]
			as Array[StringName]
		)
	)


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
