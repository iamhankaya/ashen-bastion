class_name GameController
extends Node
## Bağlama (U1-9): girdi → zaman biriktirici → `sim.step(input_gate.move())` (kare başına en çok 3 adım;
## yetişemezse yavaş çekim), ekran geçişleri (menü → oyun ⇄ seviye atlama / duraklatma → sonuç → tekrar/menü),
## Android geri tuşu, arka plana alınınca otomatik duraklatma. Karar mantığı InputGate/PauseLogic'tedir;
## bu sınıf yalnız uygular. Tam oyun: 20 dk, Kale Lordu (lord modu).

const CHARACTER := &"gunslinger"
## Tam oyun: 20 dk, 20. dk'da Kale Lordu (ölümü kazandırır).
const RUN_OPTS := {"end_mode": "lord", "end_time": 1200.0}
const WON_SUB := "Şafak söktü; kale seni yutamadı."
const DAMAGE_VIBRATE_MS := 25

var screen: int = PauseLogic.Screen.MENU
var sim: GameSim = null
var gate: InputGate = InputGate.new()

var world: Node2D
var ground: GroundView
var gem_renderer: GemRenderer
var enemy_renderer: EnemyRenderer
var actors: Node2D
var player_view: PlayerView
var projectile_renderer: ProjectileRenderer
var camera: CameraRig
var fx_renderer: FxRenderer
var ruin_view: RuinView = RuinView.new()
var atmosphere: Atmosphere

var ui: CanvasLayer
var hud: Hud
var joystick: JoystickView
var level_up: LevelUpScreen
var pause_screen: PauseScreen
var result_screen: ResultScreen
var menu: MainMenu
## v1.1 (iskelet): ilgili D fazları `_v11_*` işlevlerinde kurar/doldurur; o zamana dek v1 davranışı değişmez.
var highscores: Highscores = Highscores.new()
var scores_screen: HighscoreScreen
var pickup_renderer: PickupRenderer
var enemy_shadows: EnemyShadowLayer
var ghosts: AshGhostRenderer

var audio: AudioDirector
var _stress: StressRun = null
var _stress_label: Label = null
var _render_label: Label = null
var _accum: float = 0.0
var _run_won: bool = false
var _run_stats: Dictionary = {}


func _ready() -> void:
	get_tree().quit_on_go_back = false  # geri tuşunu kendimiz yönetiriz
	_build_world()
	_build_ui()
	_v11_build_world()  # world ve ui kuruldu
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	go_menu()


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	ground = GroundView.new()
	ground.name = "Ground"
	world.add_child(ground)
	gem_renderer = GemRenderer.new()
	gem_renderer.name = "Gems"
	world.add_child(gem_renderer)
	# Düşman MultiMesh'i oyuncu (y-sıralı aktör) katmanının ALTINDA (plan: kasıtlı sınır).
	enemy_renderer = EnemyRenderer.new()
	enemy_renderer.name = "Enemies"
	world.add_child(enemy_renderer)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	world.add_child(actors)
	player_view = PlayerView.new()
	player_view.name = "Player"
	actors.add_child(player_view)
	projectile_renderer = ProjectileRenderer.new()
	projectile_renderer.name = "Projectiles"
	world.add_child(projectile_renderer)
	fx_renderer = FxRenderer.new()
	fx_renderer.name = "Fx"
	world.add_child(fx_renderer)
	camera = CameraRig.new()
	camera.name = "Camera"
	world.add_child(camera)
	var atmo_layer := CanvasLayer.new()
	atmo_layer.name = "AtmosphereLayer"
	atmo_layer.layer = 5
	add_child(atmo_layer)
	atmosphere = Atmosphere.new()
	atmosphere.name = "Atmosphere"
	atmo_layer.add_child(atmosphere)
	world.visible = false


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	# Joystick HUD'ın ALTINDA çizilir: köşede tamburu örtmez (ara denetim #7).
	joystick = JoystickView.new()
	joystick.name = "Joystick"
	ui.add_child(joystick)
	hud = Hud.new()
	hud.name = "Hud"
	ui.add_child(hud)
	hud.pause_pressed.connect(pause_game)
	level_up = LevelUpScreen.new()
	level_up.name = "LevelUp"
	ui.add_child(level_up)
	level_up.chosen.connect(_on_choice)
	pause_screen = PauseScreen.new()
	pause_screen.name = "Pause"
	ui.add_child(pause_screen)
	pause_screen.resume_requested.connect(resume_game)
	pause_screen.restart_confirmed.connect(start_run)
	pause_screen.menu_confirmed.connect(go_menu)
	pause_screen.sound_toggled.connect(_on_sound)
	pause_screen.vibration_toggled.connect(_on_vibration)
	result_screen = ResultScreen.new()
	result_screen.name = "Result"
	ui.add_child(result_screen)
	result_screen.replay_requested.connect(start_run)
	result_screen.menu_requested.connect(go_menu)
	menu = MainMenu.new()
	menu.name = "Menu"
	ui.add_child(menu)
	menu.play_requested.connect(start_run)
	menu.sound_toggled.connect(_on_sound)
	menu.vibration_toggled.connect(_on_vibration)
	menu.debug_stress_requested.connect(start_stress)
	_build_render_debug()


## F-ashen-bastion-002 (B): yalnız debug derlemede. Düşman/taş görünür-sayı etiketi; dokunmak kesme
## dikdörtgeni düzeltmesini (RenderFix) açar/kapatır. Cihazda iki durum karşılaştırılır.
func _build_render_debug() -> void:
	if not OS.is_debug_build():
		return
	_render_label = Label.new()
	_render_label.name = "RenderDebug"
	_render_label.position = Vector2(300, 2236)
	_render_label.size = Vector2(480, 96)
	_render_label.add_theme_font_size_override(&"font_size", 26)
	_render_label.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.75))
	_render_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_render_label.add_theme_constant_override(&"outline_size", 6)
	_render_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_render_label.gui_input.connect(_on_render_label_input)
	_render_label.visible = false
	ui.add_child(_render_label)


func render_debug_text() -> String:
	if sim == null:
		return ""
	return (
		"düşman %d/%d  taş %d/%d\nkesme düzeltmesi: %s (dokun)"
		% [
			enemy_renderer.visible_count(),
			sim.enemies.count,
			gem_renderer.visible_count(),
			sim.gems.count,
			"AÇIK" if RenderFix.enabled else "KAPALI",
		]
	)


func toggle_cull_fix() -> void:
	_settings().set_cull_fix(not RenderFix.enabled)
	enemy_renderer.apply_cull_fix()
	gem_renderer.apply_cull_fix()
	projectile_renderer.apply_cull_fix()


func _on_render_label_input(event: InputEvent) -> void:
	var tap: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tap:
		toggle_cull_fix()


# --- ekran geçişleri ------------------------------------------------------------------------


func go_menu() -> void:
	_stop_stress()
	_bind(null)
	world.visible = false
	atmosphere.visible = false
	menu.open(_settings().sound_on, _settings().vibration_on)
	_set_screen(PauseLogic.Screen.MENU)


## Yeni oyun (menüden OYNA, Baştan Başla, Tekrar Oyna).
func start_run() -> void:
	_stop_stress()
	_bind(GameSim.new(randi(), CHARACTER, RUN_OPTS))
	world.visible = true
	atmosphere.visible = true
	_update_views(0.0)
	_set_screen(PauseLogic.Screen.PLAYING)


## Debug stres koşusu (yalnız debug derleme): 60 sn, sonuç ekranda ve user://perf.json'da.
func start_stress() -> void:
	if not StressRun.available():
		return
	_bind(null)
	_stress = StressRun.new()
	_stress.finished.connect(_on_stress_finished)
	add_child(_stress)
	_bind(_stress.scenario.sim)
	_stress_label = Label.new()
	_stress_label.position = Vector2(36, 520)
	_stress_label.add_theme_font_size_override(&"font_size", 34)
	ui.add_child(_stress_label)
	world.visible = true
	atmosphere.visible = true
	_set_screen(PauseLogic.Screen.PLAYING)
	hud.visible = true
	joystick.visible = false


func _stop_stress() -> void:
	if _stress != null:
		_stress.queue_free()
		_stress = null
	if _stress_label != null:
		_stress_label.queue_free()
		_stress_label = null


func _on_stress_finished(result: Dictionary) -> void:
	_stress_label.text = (
		"STRES BİTTİ\nort %.1f ms (%.0f FPS)\np95 %.1f ms\nçizim %d  nesne %d\nbellek %.0f MB\nuser://perf.json"
		% [
			result["avg_frame_ms"],
			result["avg_fps"],
			result["p95_frame_ms"],
			result["draw_calls_max"],
			result["objects"],
			result["static_memory_mb"],
		]
	)


func pause_game() -> void:
	if screen != PauseLogic.Screen.PLAYING:
		return
	pause_screen.open(
		sim.loadout.actives(),
		sim.loadout.passives(),
		_settings().sound_on,
		_settings().vibration_on
	)
	_set_screen(PauseLogic.Screen.PAUSED)
	_events().pause_requested.emit()


func resume_game() -> void:
	if screen != PauseLogic.Screen.PAUSED:
		return
	_set_screen(PauseLogic.Screen.PLAYING)
	_events().resume_requested.emit()


func _set_screen(next: int) -> void:
	var prev := screen
	screen = next
	if PauseLogic.needs_input_lock(prev, next):
		gate.lock()
	elif next != PauseLogic.Screen.PLAYING:
		gate.reset()
	_accum = 0.0
	menu.visible = next == PauseLogic.Screen.MENU
	hud.visible = (
		sim != null and next != PauseLogic.Screen.MENU and next != PauseLogic.Screen.RESULT
	)
	joystick.visible = next == PauseLogic.Screen.PLAYING
	if _render_label != null:
		_render_label.visible = (
			sim != null and next in [PauseLogic.Screen.PLAYING, PauseLogic.Screen.PAUSED]
		)
	level_up.visible = next == PauseLogic.Screen.LEVEL_UP
	pause_screen.visible = next == PauseLogic.Screen.PAUSED
	result_screen.visible = next == PauseLogic.Screen.RESULT
	_v11_on_screen(next)


func _bind(new_sim: GameSim) -> void:
	if sim != null and sim.bus.run_ended.is_connected(_on_run_ended):
		sim.bus.run_ended.disconnect(_on_run_ended)
		sim.bus.player_damaged.disconnect(_on_player_damaged)
	sim = new_sim
	_run_stats = {}
	_run_won = false
	enemy_renderer.bind(sim)
	projectile_renderer.bind(sim)
	gem_renderer.bind(sim)
	fx_renderer.bind(sim, camera)
	if sim != null:
		ruin_view.bind(actors, sim.map)
	else:
		ruin_view.clear()
	player_view.bind(sim)
	hud.bind(sim)
	if sim != null:
		audio.bind(sim.bus)
		sim.bus.run_ended.connect(_on_run_ended)
		sim.bus.player_damaged.connect(_on_player_damaged)
	_v11_bind(sim)


# --- kare döngüsü ---------------------------------------------------------------------------


func _process(delta: float) -> void:
	gate.tick(delta)
	if _stress != null:
		_stress.advance(delta)
		if not _stress.is_done():
			_stress_label.text = _stress.status_text()
		_update_views(delta)
		return
	if sim != null and PauseLogic.sim_should_step(screen, sim.state):
		_accum += delta
		var n := PauseLogic.steps_for(_accum, GameSim.STEP)
		var done := 0
		for i in n:
			sim.step(gate.move())
			done += 1
			if sim.state != GameSim.State.RUNNING:
				break
		_accum = PauseLogic.leftover(_accum, done, GameSim.STEP)
		_after_step()
	_update_views(delta)
	joystick.show_state(gate)
	_update_music()


func _update_music() -> void:
	var s := sim
	audio.update_music(
		s.time if s != null else 0.0,
		screen == PauseLogic.Screen.MENU,
		s != null and s.state == GameSim.State.WON,
		s != null and s.state == GameSim.State.LOST,
		screen == PauseLogic.Screen.PAUSED
	)


func _after_step() -> void:
	var next := PauseLogic.screen_after_step(screen, sim.state)
	if next == screen:
		return
	if next == PauseLogic.Screen.LEVEL_UP:
		_show_level_up()
	elif next == PauseLogic.Screen.RESULT:
		_show_result()


func _update_views(dt: float) -> void:
	if sim == null:
		return
	player_view.update_view(dt)
	camera.follow(sim.player_pos, dt)
	ruin_view.follow(sim.player_pos)
	ground.follow(camera.position, camera.view_size())
	enemy_renderer.refresh()
	gem_renderer.refresh()
	projectile_renderer.refresh()
	fx_renderer.update_fx(dt)
	atmosphere.follow(camera.position, camera.view_size())
	hud.refresh(dt)
	_v11_update_views(dt if screen == PauseLogic.Screen.PLAYING else 0.0)
	if _render_label != null and _render_label.visible:
		_render_label.text = render_debug_text()


func _show_level_up() -> void:
	var shown_level := sim.level - maxi(sim.pending_levels, 1) + 1
	level_up.show_choices(sim.pending_choices(), shown_level, sim.data)
	_set_screen(PauseLogic.Screen.LEVEL_UP)


func _on_choice(index: int) -> void:
	if screen != PauseLogic.Screen.LEVEL_UP or sim == null:
		return
	sim.choose(index)
	if sim.state == GameSim.State.LEVEL_UP:
		_show_level_up()
	elif sim.state == GameSim.State.RUNNING:
		_set_screen(PauseLogic.Screen.PLAYING)
	else:
		_show_result()


func _show_result() -> void:
	var stats := _run_stats
	if stats.is_empty():
		stats = {"time": sim.time, "level": sim.level, "kills": sim.kills, "evolutions": []}
		_run_won = sim.state == GameSim.State.WON
	var combos := UiKit.combo_rows(stats.get("evolutions", []), sim.data)
	var sub := ""
	if _run_won:
		sub = WON_SUB
	result_screen.show_result(_run_won, stats, combos, sub)
	_set_screen(PauseLogic.Screen.RESULT)


# --- v1.1 bağlama noktaları (S3 sözleşmesi) -------------------------------------------------
# Çağrı satırları S3'te bir kez yerleştirildi; her D fazı YALNIZ kendi bölgesinin gövdesini doldurur, başka işlevi
# yeniden yazmaz (docs/plan/v1.1-plan.md "Paylaşılan dosyalar"). Gövdeler boş: v1 davranışı aynen korunur.


## Açılışta bir kez, `world` ve `ui` kurulduktan sonra: yeni görünümleri ve ekranı kurar.
## D1: enemy_shadows, ghosts (+ oyuncu rig kurulumu). D2: pickup_renderer. D3: scores_screen, highscores.load_file.
func _v11_build_world() -> void:
	pass


## `_bind` sonunda (sim null olabilir): sinyal bağlama/çözme. D1: oyuncu olayları. D2: eklenti olayları ve FX.
@warning_ignore("unused_parameter")
func _v11_bind(new_sim: GameSim) -> void:
	pass


## Her karede `_update_views` sonunda. view_dt = ekran PLAYING iken dt, değilse 0 (plan A4).
## D1: oyuncu/FX/hayalet güncellemesi, vuruş donması, Lord yavaş çekimi. D2: pickup_renderer.refresh.
@warning_ignore("unused_parameter")
func _v11_update_views(view_dt: float) -> void:
	pass


## `run_ended` işleyicisinde (sonuç ekranından önce). D3: skor kaydı (tek yazma), gecikme başlatma.
@warning_ignore("unused_parameter")
func _v11_on_run_ended(won: bool, stats: Dictionary) -> void:
	pass


## `_set_screen` sonunda (next = PauseLogic.Screen). D3: SCORES ekranı, sonuç ekranı gecikmesi.
@warning_ignore("unused_parameter")
func _v11_on_screen(next: int) -> void:
	pass


# --- girdi ve sistem bildirimleri -----------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
		return
	if screen != PauseLogic.Screen.PLAYING:
		return
	if event is InputEventScreenTouch:
		gate.touch(event.index, event.pressed, event.position)
	elif event is InputEventScreenDrag:
		gate.drag(event.index, event.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif PauseLogic.should_auto_pause(what, screen):
		pause_game()


func _current_screen() -> int:
	if screen == PauseLogic.Screen.PAUSED and pause_screen.is_confirm_open():
		return PauseLogic.Screen.CONFIRM
	return screen


func _on_back() -> void:
	match PauseLogic.back_action(_current_screen()):
		PauseLogic.Back.PAUSE:
			pause_game()
		PauseLogic.Back.RESUME:
			resume_game()
		PauseLogic.Back.CANCEL_CONFIRM:
			pause_screen.close_confirm()
		PauseLogic.Back.TO_MENU:
			go_menu()
		PauseLogic.Back.QUIT:
			get_tree().quit()


# Autoload'lara düğüm yolundan erişilir: `-s` betik bağlamında class_name derlemesi autoload adlarını
# henüz tanımayabilir (Identifier not found); yol erişimi her bağlamda derlenir.
func _settings():
	return get_node(^"/root/Settings")


func _events():
	return get_node(^"/root/Events")


# --- sim olayları ve ayarlar ----------------------------------------------------------------


func _on_run_ended(won: bool, stats: Dictionary) -> void:
	_run_won = won
	_run_stats = stats
	_v11_on_run_ended(won, stats)


func _on_player_damaged(_amount: float, _hp: float) -> void:
	_settings().vibrate(DAMAGE_VIBRATE_MS)


func _on_sound(on: bool) -> void:
	_settings().set_sound(on)
	menu.set_settings(_settings().sound_on, _settings().vibration_on)
	pause_screen.set_settings(_settings().sound_on, _settings().vibration_on)


func _on_vibration(on: bool) -> void:
	_settings().set_vibration(on)
	menu.set_settings(_settings().sound_on, _settings().vibration_on)
	pause_screen.set_settings(_settings().sound_on, _settings().vibration_on)
