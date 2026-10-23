class_name AudioDirector
extends Node
## Sim olaylarını ses çağrılarına çevirir (U1: yalnız köprü; çalma katmanı Sfx'tedir ve şimdilik sessizdir).
## Crossfade / duck / MusicPlan uygulaması U2-8c'dedir.

## Her ses isteğinde yayınlanır (test ve ileride kayıt için); ardından Sfx.play çağrılır.
signal played(id: StringName)

var sim_bus: SimBus = null


func bind(bus: SimBus) -> void:
	sim_bus = bus
	bus.shot_fired.connect(_on_shot)
	bus.reload_started.connect(func(_d: float) -> void: _play(&"reload_spin"))
	bus.reload_finished.connect(func() -> void: _play(&"reload_click"))
	bus.dry_fire.connect(func(_g: int) -> void: _play(&"dry_fire"))
	bus.enemy_killed.connect(func(_t: StringName, _p: Vector2) -> void: _play(&"enemy_die"))
	bus.gem_collected.connect(func(_v: int) -> void: _play(&"xp_pickup"))
	bus.player_damaged.connect(func(_a: float, _h: float) -> void: _play(&"player_hurt"))
	bus.level_up.connect(func(_l: int) -> void: _play(&"level_up"))
	bus.explosion.connect(func(_p: Vector2, _r: float) -> void: _play(&"explosion"))
	bus.evolution_gained.connect(func(_e: StringName) -> void: _play(&"evolution"))


func _on_shot(gun: int, _origin: Vector2, _dir: Vector2) -> void:
	_play(&"shot_right" if gun == 0 else &"shot_left")


func _play(id: StringName) -> void:
	played.emit(id)
	Sfx.play(id)
