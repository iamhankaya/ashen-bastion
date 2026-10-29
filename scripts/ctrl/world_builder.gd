class_name WorldBuilder
extends RefCounted
## GameController düğüm kurulumu (R4): dünya (`World`), arayüz (`UI`) ve v1.1 katmanları. Gövdeler controller'dan AYNEN
## taşındı (düğüm adları, ekleme ve bağlantı sırası aynı; sahne ağacı karakterizasyonu rf_ctrl_scene_tree).
## `host` GameController'dır ama tipi BİLİNMEZ (class_name döngüsü yok; V2Flow ile aynı kural): alanlara ve geri
## çağrılara dinamik erişilir.


static func build_world(host) -> void:
	var world := Node2D.new()
	world.name = "World"
	host.add_child(world)
	var ground := GroundView.new()
	ground.name = "Ground"
	world.add_child(ground)
	var gem_renderer := GemRenderer.new()
	gem_renderer.name = "Gems"
	world.add_child(gem_renderer)
	# Düşman MultiMesh'i oyuncu (y-sıralı aktör) katmanının ALTINDA (plan: kasıtlı sınır).
	var enemy_renderer := EnemyRenderer.new()
	enemy_renderer.name = "Enemies"
	world.add_child(enemy_renderer)
	var actors := Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	world.add_child(actors)
	var player_view := PlayerView.new()
	player_view.name = "Player"
	actors.add_child(player_view)
	var projectile_renderer := ProjectileRenderer.new()
	projectile_renderer.name = "Projectiles"
	world.add_child(projectile_renderer)
	var fx_renderer := FxRenderer.new()
	fx_renderer.name = "Fx"
	world.add_child(fx_renderer)
	var camera := CameraRig.new()
	camera.name = "Camera"
	world.add_child(camera)
	var atmo_layer := CanvasLayer.new()
	atmo_layer.name = "AtmosphereLayer"
	atmo_layer.layer = 5
	host.add_child(atmo_layer)
	var atmosphere := Atmosphere.new()
	atmosphere.name = "Atmosphere"
	atmo_layer.add_child(atmosphere)
	world.visible = false
	host.world = world
	host.ground = ground
	host.gem_renderer = gem_renderer
	host.enemy_renderer = enemy_renderer
	host.actors = actors
	host.player_view = player_view
	host.projectile_renderer = projectile_renderer
	host.fx_renderer = fx_renderer
	host.camera = camera
	host.atmosphere = atmosphere


static func build_ui(host) -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	host.add_child(ui)
	host.ui = ui
	# Joystick HUD'ın ALTINDA çizilir: köşede tamburu örtmez (ara denetim #7).
	var joystick := JoystickView.new()
	joystick.name = "Joystick"
	ui.add_child(joystick)
	host.joystick = joystick
	var hud := Hud.new()
	hud.name = "Hud"
	ui.add_child(hud)
	host.hud = hud
	hud.pause_pressed.connect(host.pause_game)
	var level_up := LevelUpScreen.new()
	level_up.name = "LevelUp"
	ui.add_child(level_up)
	host.level_up = level_up
	level_up.chosen.connect(host._on_choice)
	var pause_screen := PauseScreen.new()
	pause_screen.name = "Pause"
	ui.add_child(pause_screen)
	host.pause_screen = pause_screen
	pause_screen.resume_requested.connect(host.resume_game)
	pause_screen.restart_confirmed.connect(host.start_run)
	pause_screen.menu_confirmed.connect(host.go_menu)
	pause_screen.sound_toggled.connect(host._on_sound)
	pause_screen.vibration_toggled.connect(host._on_vibration)
	pause_screen.settings_requested.connect(host.open_settings)
	var result_screen := ResultScreen.new()
	result_screen.name = "Result"
	ui.add_child(result_screen)
	host.result_screen = result_screen
	result_screen.replay_requested.connect(host.start_run)
	result_screen.menu_requested.connect(host.go_menu)
	var menu := MainMenu.new()
	menu.name = "Menu"
	ui.add_child(menu)
	host.menu = menu
	menu.play_requested.connect(host.start_run)
	menu.settings_requested.connect(host.open_settings)
	# v2.0.1: ayarlar ekranı menü ve duraklatma üstünde bir katmandır (ekran durumu değişmez); geri onu kapatır.
	var settings_screen := SettingsScreen.new()
	settings_screen.name = "Settings"
	ui.add_child(settings_screen)
	host.settings_screen = settings_screen
	settings_screen.vibration_toggled.connect(host._on_vibration)
	settings_screen.sound_toggled.connect(host._on_sound)
	menu.debug_stress_requested.connect(host.start_stress)
	host._build_render_debug()


## Açılışta bir kez, `world` ve `ui` kurulduktan sonra. D1: enemy_shadows, ghosts. D3: scores_screen, run_screen (U4a).
static func build_v11_world(host) -> void:
	var world: Node2D = host.world
	var ui: CanvasLayer = host.ui
	var enemy_renderer: EnemyRenderer = host.enemy_renderer
	var fx_renderer: FxRenderer = host.fx_renderer
	var menu: MainMenu = host.menu
	var enemy_shadows := EnemyShadowLayer.new()
	enemy_shadows.name = "Shadows"
	world.add_child(enemy_shadows)
	host.enemy_shadows = enemy_shadows
	var ghosts := AshGhostRenderer.new()
	ghosts.name = "Ghosts"
	world.add_child(ghosts)
	host.ghosts = ghosts
	enemy_renderer.shadows = enemy_shadows
	enemy_renderer.set_ghosts(ghosts)
	enemy_renderer.set_effects(fx_renderer, host.camera)
	enemy_renderer.apply_cull_fix()
	enemy_renderer.lord_enraged.connect(host._on_lord_enraged)
	enemy_renderer.lord_slammed.connect(host._on_lord_slammed)
	fx_renderer.char_layer.reparent(world)  # kömür zemin ile gölgeler arasında (normal karışım)
	order_world(world)
	host.highscores.load_file()
	var scores_screen := HighscoreScreen.new()
	scores_screen.name = "Scores"
	ui.add_child(scores_screen)
	host.scores_screen = scores_screen
	scores_screen.back_requested.connect(host.go_menu)
	scores_screen.store = host.highscores
	scores_screen.play_with_requested.connect(host.play_with)
	var run_screen := RunScreen.new()
	run_screen.name = "RunScreen"
	ui.add_child(run_screen)
	host.run_screen = run_screen
	run_screen.back_requested.connect(host.go_menu)
	menu.run_requested.connect(host.open_run_screen)
	menu.scores_requested.connect(host.open_scores)
	menu.characters_requested.connect(host.open_characters)
	menu.achievements_requested.connect(host.open_achievements)
	host.result_screen.record_stamped.connect(host._on_record_stamped)
	host.get_viewport().size_changed.connect(host._apply_safe_areas)
	host._apply_safe_areas()


## Katman sırası (plan A3): zemin → kömür → gölgeler → taşlar → eklentiler → düşmanlar → hayaletler → aktörler → mermiler → FX.
## Adlarla yerleştirir; var olmayan düğüm atlanır (D2 `Pickups` ekleyince bu işlevden sonra çağırır ya da adı korur).
static func order_world(world: Node2D) -> void:
	var names: Array[StringName] = [
		&"Ground",
		&"CharLayer",
		&"Shadows",
		&"Gems",
		&"Pickups",
		&"Enemies",
		&"Ghosts",
		&"Actors",
		&"Projectiles",
		&"Fx",
		&"Camera"
	]
	var idx := 0
	for n in names:
		var node := world.get_node_or_null(NodePath(n))
		if node != null:
			world.move_child(node, idx)
			idx += 1
