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
