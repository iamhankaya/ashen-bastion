class_name AudioDirector
extends Node
## Sim olaylarını ses çağrılarına çevirir, müziği yönetir: MusicPlan kararı, iki oyunculu crossfade, boss uyarısında
## kısa uyarı sesi + müzik kısılması, duraklatmada Music bus -8 dB. Sesler dosya yoksa sessizdir.

## Her ses isteğinde yayınlanır (test ve ileride kayıt için); ardından Sfx.play çağrılır.
signal played(id: StringName)
## Müzik parçası değişince yayınlanır (test).
signal music_changed(track: StringName)

const MUSIC_DIR := "res://assets/audio/music/"
const SILENT_DB := -60.0
const DUCK_DB := -6.0
const DUCK_TIME := 6.0
const PAUSE_DB := -8.0

const EVOLUTION_DEFAULT := &"evolution_1"
const LEVEL_UP_NORMAL := &"level_up_normal"
const LEVEL_UP_EVOLUTION := &"level_up_evolution"

var sim_bus: SimBus = null
var data: GameData = null  # evrim `sfx` alanı için (isteğe bağlı)
## v2.0.2 A4: karakterin olay->ses sözlüğü (CharacterDef.sfx). Boş: eski varsayılan sesler (yalıtılmış kullanım/test).
var character_sfx: Dictionary = {}
var sim_fx: SimFx = null
var track: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _stinger: AudioStreamPlayer = null
var _fades: Array[Tween] = [null, null]
var _duck_tween: Tween = null
var _paused: bool = false
var _lord_alive: bool = false


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)
	_stinger = AudioStreamPlayer.new()
	_stinger.bus = &"Music"
	add_child(_stinger)
	Sfx.setup(self)


func _exit_tree() -> void:
	for t in _fades:
		if t != null and t.is_valid():
			t.kill()
	for p in _players:
		p.stop()
	if _stinger != null:
		_stinger.stop()
	# Durdurulan oynatmalar ses iş parçacığı bir sonraki karışımda bırakılana dek bellekte kalır: bekleme yok
	# (F-013: 150 ms uyku ana iş parçacığını bloklardı); düğümler sonraki karede serbest bırakılır.
	for p in _players:
		p.stream = null
		p.call_deferred(&"free")
	_players.clear()
	if _stinger != null:
		_stinger.stream = null
		_stinger.call_deferred(&"free")
		_stinger = null
	Sfx.teardown()
	_reset_bus_volume()


func bind(
	bus: SimBus, game_data: GameData = null, character: CharacterDef = null, fx: SimFx = null
) -> void:
	_unbind()
	sim_bus = bus
	data = game_data
	character_sfx = character.sfx if character != null else {}
	sim_fx = fx
	if fx != null:
		fx.skill_sfx.connect(_on_skill_sfx)
	_lord_alive = false
	bus.shot_fired.connect(_on_shot)
	bus.reload_started.connect(_on_reload_started)
	bus.reload_finished.connect(_on_reload_finished)
	bus.dry_fire.connect(_on_dry)
	bus.enemy_killed.connect(_on_killed)
	bus.enemy_hit.connect(_on_hit)
	bus.gem_collected.connect(_on_gem)
	bus.player_damaged.connect(_on_damaged)
	bus.explosion.connect(_on_explosion)
	bus.evolution_gained.connect(_on_evolution)
	bus.boss_warning.connect(_on_boss_warning)
	bus.boss_spawned.connect(_on_boss_spawned)


func _unbind() -> void:
	if sim_fx != null and sim_fx.skill_sfx.is_connected(_on_skill_sfx):
		sim_fx.skill_sfx.disconnect(_on_skill_sfx)
	sim_fx = null
	character_sfx = {}
	if sim_bus == null:
		return
	for pair in [
		[sim_bus.shot_fired, _on_shot],
		[sim_bus.reload_started, _on_reload_started],
		[sim_bus.reload_finished, _on_reload_finished],
		[sim_bus.dry_fire, _on_dry],
		[sim_bus.enemy_killed, _on_killed],
		[sim_bus.enemy_hit, _on_hit],
		[sim_bus.gem_collected, _on_gem],
		[sim_bus.player_damaged, _on_damaged],
		[sim_bus.explosion, _on_explosion],
		[sim_bus.evolution_gained, _on_evolution],
		[sim_bus.boss_warning, _on_boss_warning],
		[sim_bus.boss_spawned, _on_boss_spawned],
	]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	sim_bus = null


## Müzik durumunu yenile (her kare ucuz): ekran ve sim durumundan MusicPlan bayrakları.
func update_music(time: float, in_menu: bool, won: bool, lost: bool, paused: bool) -> void:
	var flags := {
		"in_menu": in_menu,
		"won": won,
		"lost": lost,
		"lord_alive": _lord_alive,
		"paused": paused,
	}
	_set_track(MusicPlan.track_for(time, flags))
	set_paused(paused)


func set_paused(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	_apply_bus_volume()


func stop_music() -> void:
	_set_track(&"")


## Test için: şu an etkin müzik oyuncusu.
func active_player() -> AudioStreamPlayer:
	return _players[_active] if not _players.is_empty() else null


func _set_track(t: StringName) -> void:
	if t == track:
		return
	var prev := track
	track = t
	music_changed.emit(t)
	if _players.is_empty():
		return
	var fade := MusicPlan.fade_seconds(prev, t)
	var old := _players[_active]
	_active = 1 - _active
	var incoming := _players[_active]
	_fade(old, SILENT_DB, fade, true)
	if t == &"":
		return
	var stream := _music_stream(t)
	if stream == null:
		return
	incoming.stream = stream
	incoming.volume_db = SILENT_DB if fade > 0.0 else 0.0
	incoming.play()
	_fade(incoming, 0.0, fade, false)


func _fade(p: AudioStreamPlayer, to_db: float, seconds: float, stop_after: bool) -> void:
	var idx := _players.find(p)
	if idx >= 0 and _fades[idx] != null and _fades[idx].is_valid():
		_fades[idx].kill()
	if seconds <= 0.0:
		p.volume_db = to_db
		if stop_after:
			p.stop()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, seconds)
	if stop_after:
		tw.tween_callback(p.stop)
	if idx >= 0:
		_fades[idx] = tw


func _music_stream(t: StringName) -> AudioStream:
	var path := MUSIC_DIR + String(t) + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = MusicPlan.LOOPING.has(t)
	return s


func _bus_volume() -> float:
	var db := PAUSE_DB if _paused else 0.0
	return db + (DUCK_DB if _duck_left > 0.0 else 0.0)


var _duck_left: float = 0.0


func _process(delta: float) -> void:
	if _duck_left > 0.0:
		_duck_left = maxf(0.0, _duck_left - delta)
		if _duck_left == 0.0:
			_apply_bus_volume()


## Duraklatma/duck payı Settings'e bildirilir; kanalın nihai dB'sini (kullanıcı seviyesi + pay) Settings hesaplar.
func _apply_bus_volume() -> void:
	_push_extra(_bus_volume())


func _reset_bus_volume() -> void:
	_push_extra(0.0)


func _push_extra(db: float) -> void:
	var st := get_node_or_null(^"/root/Settings") if is_inside_tree() else null
	if st != null:
		st.set_music_extra_db(db)
		return
	var idx := AudioServer.get_bus_index(&"Music")  # Settings yoksa (yalıtılmış kullanım): eski davranış
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func _on_boss_warning(_kind: StringName) -> void:
	var s := _music_stream(MusicPlan.STINGER)
	if s != null and _stinger != null:
		_stinger.stream = s
		_stinger.play()
	_duck_left = DUCK_TIME
	_apply_bus_volume()
	played.emit(MusicPlan.STINGER)


func _on_boss_spawned(type_id: StringName) -> void:
	if type_id == &"kale_lordu":
		_lord_alive = true


func _on_killed(type_id: StringName, _pos: Vector2) -> void:
	if type_id == &"kale_lordu":
		_lord_alive = false
	_play(&"enemy_die")


func _on_hit(_pos: Vector2) -> void:
	_play(sound_for(&"hit", 0, &"hit"))


func _on_shot(gun: int, _origin: Vector2, _dir: Vector2) -> void:
	_play(sound_for(&"shot", gun, &"shot_right" if gun == 0 else &"shot_left"))


func _on_reload_started(_d: float) -> void:
	_play(sound_for(&"reload_start", 0, &"reload_spin"))


func _on_reload_finished() -> void:
	_play(sound_for(&"reload_end", 0, &"reload_click"))


func _on_dry(_g: int) -> void:
	_play(sound_for(&"dry", 0, &"dry_fire"))


func _on_gem(_v: int) -> void:
	_play(&"xp_pickup")


func _on_damaged(_a: float, _h: float) -> void:
	_play(&"player_hurt")


## Seviye atlama kartları gösterilirken çağrılır (kartlar sim.pending_choices()): evrim kartı varsa belirgin ses.
func play_level_up(choices: Array) -> void:
	_play(level_up_sound(choices))


static func level_up_sound(choices: Array) -> StringName:
	for c in choices:
		if c is Choice and (c as Choice).kind == Choice.KIND_EVOLUTION:
			return LEVEL_UP_EVOLUTION
	return LEVEL_UP_NORMAL


## Evrim becerisinin `sfx` alanı; alan ya da veri yoksa evolution_1.
static func evolution_sound(game_data: GameData, evo_id: StringName) -> StringName:
	if game_data != null:
		var sk := game_data.get_skill(evo_id)
		if sk != null and sk.sfx != &"":
			return sk.sfx
	return EVOLUTION_DEFAULT


func _on_explosion(_p: Vector2, _r: float) -> void:
	_play(&"explosion")


func _on_evolution(evo_id: StringName) -> void:
	_play(evolution_sound(data, evo_id))


## Olay için ses kimliği: karakter sözlüğü varsa onun girdisi (girdi yoksa o olay sessiz: karaktere özgü sesler başkasında
## çalmaz; dizide `index` silah indeksidir), sözlük boşsa eski varsayılan `legacy`.
func sound_for(event: StringName, index: int, legacy: StringName) -> StringName:
	if character_sfx.is_empty():
		return legacy
	var v: Variant = character_sfx.get(String(event), null)
	if v is Array and not (v as Array).is_empty():
		return StringName(str(v[clampi(index, 0, (v as Array).size() - 1)]))
	if v is String:
		return StringName(v)
	return &""


## Beceri ateşlendi/doğdu (SimFx.skill_sfx): becerinin `cast_sfx` alanı varsa çalar.
func _on_skill_sfx(skill_id: StringName) -> void:
	var sk := data.get_skill(skill_id) if data != null else null
	if sk != null and sk.cast_sfx != &"":
		_play(sk.cast_sfx)


func _play(id: StringName) -> void:
	if id == &"":
		return
	played.emit(id)
	Sfx.play(id)
