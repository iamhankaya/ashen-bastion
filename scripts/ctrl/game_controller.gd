class_name GameController
extends Node
## Bağlama (U1-9): girdi → zaman biriktirici → `sim.step(input_gate.move())` (kare başına en çok 3 adım;
## yetişemezse yavaş çekim), ekran geçişleri (menü → oyun ⇄ seviye atlama / duraklatma → sonuç → tekrar/menü),
## Android geri tuşu, arka plana alınınca otomatik duraklatma. Karar mantığı InputGate/PauseLogic'tedir;
## bu sınıf yalnız uygular. Tam oyun: 20 dk, Kale Lordu (lord modu).

## Tam oyun: 20 dk, 20. dk'da Kale Lordu (ölümü kazandırır).
const RUN_OPTS := {"end_mode": "lord", "end_time": 1200.0}
const WON_SUB := "Şafak söktü; kale seni yutamadı."
const DAMAGE_VIBRATE_MS := 25
const LORD_ID := &"kale_lordu"
const LORD_SLAM_RING_SEC := 0.45
## Öfkeli Lord kor aurası (E9): en çok 20 parçacık/sn.
const LORD_EMBER_RATE := 18.0
const BOMB_SHAKE := 18.0

var screen: int = PauseLogic.Screen.MENU
var sim: GameSim = null
## v2.1 KOŞU ekranı (U4a kurar; testler yerine sahte Control koyabilir).
var run_screen: Control = null
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
var settings_screen: SettingsScreen
var result_screen: ResultScreen
var menu: MainMenu
## v2.0 cephesi (karakter/başarım/bakım dilimleri); testler `v2_opts`'u add_child'dan ÖNCE doldurur.
var v2: V2Flow
var v2_opts: Dictionary = {}
## v1.1 (iskelet): ilgili D fazları `_v11_*` işlevlerinde kurar/doldurur; o zamana dek v1 davranışı değişmez.
var highscores: Highscores = Highscores.new()
var scores_screen: HighscoreScreen
var pickup_renderer: PickupRenderer
var enemy_shadows: EnemyShadowLayer
var ghosts: AshGhostRenderer
var _escape_label: Label = null
var _bounce_label: Label = null

var audio: AudioDirector
## D1: vuruş donması (sim adımlanmaz, _accum artmaz), Lord ölümü yavaş çekimi ve ardışık patlamaları.
var hit_stop: HitStop = HitStop.new()
## Sim olay bağlantı tabloları (hedefler bu sınıfın metotları: sinyal üçlüsü karakterizasyonu).
var _core_signals := (
	SimSignalBinder
	. new(
		[
			[&"run_ended", Callable(self, &"_on_run_ended")],
			[&"player_damaged", Callable(self, &"_on_player_damaged")],
		]
	)
)
var _player_signals := (
	SimSignalBinder
	. new(
		[
			[&"shot_fired", Callable(self, &"_on_shot_for_shell")],
			[&"player_damaged", Callable(self, &"_on_damage_shake")],
			[&"enemy_killed", Callable(self, &"_on_enemy_killed_fx")],
		]
	)
)
var _pickup_signals := (
	SimSignalBinder
	. new(
		[
			[&"pickup_collected", Callable(self, &"_on_pickup_collected")],
			[&"bomb_exploded", Callable(self, &"_on_bomb_exploded")],
		]
	)
)
var _lord_slow_left: float = 0.0
var _lord_blast_t := PackedFloat32Array()
var _lord_blast_pos := PackedVector2Array()
var _lord_ember_acc: float = 0.0
var _stress: StressRun = null
var _stress_label: Label = null
var _render_label: Label = null
var _accum: float = 0.0
var _run_won: bool = false
var _run_stats: Dictionary = {}
## v1.1 D3: ekran gecikmesi (ölüm 1,3 / kazanma 1,8 / seviye ön vurgusu 0,18 sn), tek yazma bayrağı, rekor bilgisi.
var _delay: ScreenDelay = ScreenDelay.new()
var _run_saved: bool = false
var _result_record: Dictionary = {}


func _ready() -> void:
	get_tree().quit_on_go_back = false  # geri tuşunu kendimiz yönetiriz
	v2 = V2Flow.new(v2_opts)
	WorldBuilder.build_world(self)
	WorldBuilder.build_ui(self)
	_v11_build_world()  # world ve ui kuruldu
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	var refs := {"ui_root": ui, "menu": menu, "hud": hud, "level_up": level_up}
	refs.merge({"result_screen": result_screen, "pause_screen": pause_screen})
	refs["set_screen"] = _set_screen
	v2.build_world(refs)
	go_menu()


func _exit_tree() -> void:
	v2.release()


## F-ashen-bastion-002 (B): yalnız debug derlemede. Düşman/taş görünür-sayı etiketi; dokunmak kesme
## dikdörtgeni düzeltmesini (RenderFix) açar/kapatır. Cihazda iki durum karşılaştırılır.
func _build_render_debug() -> void:
	if not OS.is_debug_build():
		return
	_render_label = DebugLabels.build_render(ui, _on_render_label_input)


func render_debug_text() -> String:
	return RunPresentation.render_text(sim, enemy_renderer, gem_renderer)


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
	_bind(GameSim.new(randi(), v2.selected_character(), V21Runs.run_opts()))
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
		"STRES BİTTİ\nort %.1f ms (%.0f FPS)\np95 %.1f ms\ngörünüm ort %.2f p95 %.2f ms\nçizim %d  nesne %d\nbellek %.0f MB\nuser://perf.json"
		% [
			result["avg_frame_ms"],
			result["avg_fps"],
			result["p95_frame_ms"],
			result["view_ms_avg"],
			result["view_ms_p95"],
			result["draw_calls_max"],
			result["objects"],
			result["static_memory_mb"],
		]
	)


func pause_game() -> void:
	if screen != PauseLogic.Screen.PLAYING:
		return
	v2.on_pause()
	if _v11_skip_delay():  # geri tuşu / arka plan / duraklat düğmesi gecikmeyi atlar; oyun duraklatılmaz
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
	hud.visible = sim != null and PauseLogic.hud_allowed(next)
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
	_core_signals.release()
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
		audio.bind(sim.bus, sim.data, sim.character, sim.fx)
	_core_signals.attach(sim)
	_v11_bind(sim)
	v2.bind(null if _stress != null else sim)  # stres koşusu başarım saymaz


# --- kare döngüsü ---------------------------------------------------------------------------


func _process(delta: float) -> void:
	gate.tick(delta)
	if _stress != null:
		_stress.advance(delta)
		if not _stress.is_done():
			_stress_label.text = _stress.status_text()
		var t0 := Time.get_ticks_usec()
		_update_views(delta)
		_stress.record_view(float(Time.get_ticks_usec() - t0) / 1000.0)  # D1-4: view_ms
		return
	_v11_process(delta)
	if sim != null and not _v11_hit_stop(delta) and PauseLogic.sim_should_step(screen, sim.state):
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
		V21Runs.music_won(s),
		V21Runs.music_lost(s),
		screen == PauseLogic.Screen.PAUSED
	)


func _after_step() -> void:
	_v11_after_step()
	if _delay.active:
		return  # gecikme sürerken ekran geçişi geri sayımın işidir (_v11_process)
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
	player_view.update_view(_v11_view_dt(dt))
	camera.follow(sim.player_pos, dt)
	ruin_view.follow(sim.player_pos)
	ground.follow(camera.position, camera.view_size())
	enemy_renderer.refresh()
	gem_renderer.refresh()
	projectile_renderer.refresh()
	fx_renderer.update_fx(_v11_view_dt(dt))
	atmosphere.follow(camera.position, camera.view_size())
	hud.refresh(dt)
	_v11_update_views(dt if screen == PauseLogic.Screen.PLAYING else 0.0)
	v2.update_views(dt if screen == PauseLogic.Screen.PLAYING else 0.0)
	if _render_label != null and _render_label.visible:
		_render_label.text = render_debug_text()


func _show_level_up() -> void:
	var shown_level := sim.level - maxi(sim.pending_levels, 1) + 1
	level_up.show_choices(sim.pending_choices(), shown_level, sim.data, sim.character)
	audio.play_level_up(sim.pending_choices())
	_set_screen(PauseLogic.Screen.LEVEL_UP)


func _on_choice(index: int) -> void:
	if screen != PauseLogic.Screen.LEVEL_UP or sim == null:
		return
	sim.choose(index)
	player_view.on_level_chosen()
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
		stats.merge(V11State.end_stats(sim))
		_run_won = V21Runs.run_won(sim)
	var combos := UiKit.combo_rows(
		stats.get("evolutions", []), sim.data, sim.character.id if sim.character != null else &""
	)
	var sub := ""
	if _run_won:
		sub = WON_SUB
	result_screen.show_result(_run_won, stats, combos, sub, _result_record)
	_set_screen(PauseLogic.Screen.RESULT)


# --- v1.1 bağlama noktaları (S3 sözleşmesi) -------------------------------------------------
# Çağrı satırları S3'te bir kez yerleştirildi; her D fazı YALNIZ kendi bölgesinin gövdesini doldurur, başka işlevi
# yeniden yazmaz (docs/plan/v1.1-plan.md "Paylaşılan dosyalar"). Gövdeler boş: v1 davranışı aynen korunur.


## Açılışta bir kez, `world` ve `ui` kurulduktan sonra: yeni görünümleri ve ekranı kurar.
## D1: enemy_shadows, ghosts (+ oyuncu rig kurulumu). D2: pickup_renderer. D3: scores_screen, highscores.load_file.
func _v11_build_world() -> void:
	WorldBuilder.build_v11_world(self)


## Yeni ekranların güvenli alanı (çentik, yuvarlak köşe); pencere boyutu değişince yenilenir.
func _apply_safe_areas() -> void:
	menu.apply_safe_area()
	settings_screen.apply_safe_area()
	result_screen.apply_safe_area()
	scores_screen.apply_safe_area()
	if run_screen is RunScreen:  # testler sahte Control koyabilir
		run_screen.apply_safe_area()
	v2.apply_safe_areas()


## Ana menüden En İyi Skorlar ekranı (vurgu yok: sonuçtan sıralamaya bağlantı v1.1 dışı).
## v2.1: boş (mod, zorluk) = geçerli seçim; sonuç ekranından biten koşunun çifti verilir.
func open_scores(p_mode: StringName = &"", p_diff: StringName = &"") -> void:
	if screen != PauseLogic.Screen.MENU and screen != PauseLogic.Screen.RESULT:
		return
	var k := V21Runs.scores_key(p_mode, p_diff)
	scores_screen.show_scores(highscores.list_for(k["mode"], k["diff"]), -1, k["mode"], k["diff"])
	_set_screen(PauseLogic.Screen.SCORES)


## KOŞU ekranı (U4a doldurur; C'de boş) ve "BU AYARLA OYNA".
func open_run_screen() -> void:
	if screen == PauseLogic.Screen.MENU:
		_set_screen(PauseLogic.Screen.RUN)


func play_with(p_mode: StringName, p_diff: StringName) -> void:
	V21Runs.set_selection(p_mode, p_diff)
	start_run()


func open_characters() -> void:
	v2.open_characters()


func open_achievements() -> void:
	v2.open_achievements()


## `_bind` sonunda (sim null olabilir): faz başına alt işlevlere dağıtır (her D yalnız kendi gövdesini doldurur).
func _v11_bind(new_sim: GameSim) -> void:
	_v11_bind_player(new_sim)
	_v11_bind_pickups(new_sim)
	_v11_bind_score(new_sim)


## D1: oyuncu olayları (shot_fired, reload_*, player_damaged, level_up, run_ended).
func _v11_bind_player(new_sim: GameSim) -> void:
	_player_signals.release()
	hit_stop.left = 0.0
	_lord_slow_left = 0.0
	_lord_blast_t.clear()
	_lord_blast_pos.clear()
	_lord_ember_acc = 0.0
	ghosts.bind(new_sim, enemy_renderer)
	_player_signals.attach(new_sim)


## D2: eklenti olayları ve FX (pickup_*, buff_*, bomb_*; bomb_exploded -> kamera + HitStop).
func _v11_bind_pickups(new_sim: GameSim) -> void:
	if pickup_renderer == null:
		pickup_renderer = PickupRenderer.new()
		pickup_renderer.name = "Pickups"
		world.add_child(pickup_renderer)
		world.move_child(pickup_renderer, gem_renderer.get_index() + 1)  # taşlardan sonra, düşmanlardan önce
	_pickup_signals.release()
	pickup_renderer.bind(new_sim)
	_v11_build_escape_debug()
	_bounce_label = BounceDebug.ensure(_bounce_label, ui, BounceDebug.on_input)
	if _escape_label != null and new_sim == null:
		_escape_label.visible = false
	if _bounce_label != null and new_sim == null:
		_bounce_label.visible = false
	_pickup_signals.attach(new_sim)


## D3: skor olayları (score_changed, streak_changed).
@warning_ignore("unused_parameter")
func _v11_bind_score(new_sim: GameSim) -> void:
	_delay = ScreenDelay.new()
	_run_saved = new_sim == null
	_result_record = {}


## Her karede `_update_views` sonunda. view_dt = ekran PLAYING iken dt, değilse 0 (plan A4).
func _v11_update_views(view_dt: float) -> void:
	_v11_update_player(view_dt)
	_v11_update_pickups(view_dt)


## D1: hayalet/Lord efektleri güncellemesi. view_dt = PLAYING iken dt, aksi halde 0; Lord yavaş çekimi ×0,4 uygulanır.
func _v11_update_player(view_dt: float) -> void:
	var vdt := view_dt * (Motion.LORD_SLOWMO_SCALE if _lord_slow_left > 0.0 else 1.0)
	_lord_slow_left = maxf(0.0, _lord_slow_left - view_dt)
	ghosts.update_ghosts(vdt)
	RunPresentation.tick_blasts(self, view_dt)  # gerçek süre: 900 ms içinde 3 patlama, yavaş çekimden bağımsız
	RunPresentation.lord_embers(self, vdt, LORD_EMBER_RATE)


## A4: oyuncu/FX/hayalet görünüm süresi. Yalnız PLAYING iken dt (sonuç gecikmesi dönemleri dahil), aksi halde 0;
## Lord ölümünde 1,2 sn ×0,4 yavaş çekim. Düşman animasyonu sim.time'a bağlıdır, ayrıca yönetilmez.
func _v11_view_dt(dt: float) -> float:
	if screen != PauseLogic.Screen.PLAYING:
		return 0.0
	return dt * (Motion.LORD_SLOWMO_SCALE if _lord_slow_left > 0.0 else 1.0)


## D2: pickup_renderer.refresh.
func _v11_update_pickups(view_dt: float) -> void:
	if pickup_renderer != null:
		pickup_renderer.refresh(view_dt)
	_v11_update_escape_debug()
	BounceDebug.sync(
		_bounce_label,
		sim != null and screen in [PauseLogic.Screen.PLAYING, PauseLogic.Screen.PAUSED]
	)


## F-ashen-bastion-021 (yalnız debug derleme): çıkmaz kaçışı AÇIK/KAPALI etiketi + sayaç; dokunmak bayrağı çevirir
## (cihazda iki durum karşılaştırılır). Etiket oyun/duraklatma ekranında görünür.
func _v11_build_escape_debug() -> void:
	if _escape_label != null or not OS.is_debug_build():
		return
	_escape_label = DebugLabels.build_escape(ui, _on_escape_label_input)


func escape_debug_text() -> String:
	return RunPresentation.escape_text(sim)


func toggle_escape_fix() -> void:
	EnemyEscape.enabled = not EnemyEscape.enabled


func _v11_update_escape_debug() -> void:
	if _escape_label == null:
		return
	_escape_label.visible = (
		sim != null and screen in [PauseLogic.Screen.PLAYING, PauseLogic.Screen.PAUSED]
	)
	if _escape_label.visible:
		_escape_label.text = escape_debug_text()


func _on_escape_label_input(event: InputEvent) -> void:
	if (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	):
		toggle_escape_fix()


## Toplama başlığı: pickups.json `toast` (boşsa yok), oyuncunun üstünde kayar.
func _on_pickup_collected(kind_id: StringName, _pos: Vector2) -> void:
	if sim == null:
		return
	RunPresentation.pickup_toast(self, kind_id)


## Bomba patlaması: kamera 18 px + vuruş donması 0,06 sn (FX halkası/ses mevcut `explosion` yolundan gelir).
func _on_bomb_exploded(_pos: Vector2, _radius: float) -> void:
	camera.shake(BOMB_SHAKE)
	_v11_request_hit_stop(Motion.sec(Motion.HITSTOP_BOMB))


## Vuruş donması isteği: D1-3'ün `hit_stop` (HitStop) üyesi varsa ona iletir; yoksa yok sayılır.
func _v11_request_hit_stop(sec: float) -> void:
	var hs: Variant = get("hit_stop")
	if hs is HitStop:
		(hs as HitStop).request(sec)


## `_process` başında (stres koşusu dışında), her karede. D3: ScreenDelay.tick geri sayımı.
func _v11_process(delta: float) -> void:
	if _delay.tick(delta):
		_fire_delay(_delay.target)


## true = bu karede vuruş donması: sim adımlanmaz ve `_accum` artmaz. D1-3: HitStop.tick(delta).
func _v11_hit_stop(delta: float) -> bool:
	if screen != PauseLogic.Screen.PLAYING:
		return false
	return hit_stop.tick(delta)


## `_after_step` başında (ekran geçişinden önce). D3: gecikme başlatma, seviye ön vurgusu.
func _v11_after_step() -> void:
	if sim != null and sim.state == GameSim.State.LEVEL_UP and screen == PauseLogic.Screen.PLAYING:
		_delay.start(PauseLogic.Screen.LEVEL_UP, PauseLogic.LEVEL_UP_PREROLL)


## Aktif gecikmeyi hemen tetikler (dokunma, geri tuşu, arka plan). Tetiklediyse true.
func _v11_skip_delay() -> bool:
	var target := _delay.target
	if _delay.skip():
		_fire_delay(target)
		return true
	return false


## Gecikme bitti: hedef ekrana geç (seviye atlama kartları ya da sonuç ekranı); tek kez çağrılır.
func _fire_delay(target: int) -> void:
	if sim == null:
		return
	if target == PauseLogic.Screen.LEVEL_UP and sim.state == GameSim.State.LEVEL_UP:
		_show_level_up()
	elif target == PauseLogic.Screen.RESULT and screen == PauseLogic.Screen.PLAYING:
		_show_result()


## Testler ve araçlar için: bekleyen gecikmeyi süresini beklemeden bitirir.
func flush_delay() -> void:
	_v11_skip_delay()


## `run_ended` işleyicisinde (sonuç ekranından önce). D3: skor kaydı (tek yazma), gecikme başlatma.
func _v11_on_run_ended(won: bool, stats: Dictionary) -> void:
	if _stress != null:
		return  # debug stres koşusu skor listesine yazmaz
	_save_score(won, stats)
	_delay.start(PauseLogic.Screen.RESULT, PauseLogic.result_delay(won))


## Skoru yerel listeye yazar: koşu başına tek kez (`_run_saved`), sonuç ekranından önce (çökme riski).
func _save_score(won: bool, stats: Dictionary) -> void:
	if _run_saved:
		return
	_run_saved = true
	_result_record = highscores.submit(V21Runs.score_fields(stats, won))
	if int(_result_record.get("rank", 0)) > 0:
		highscores.save()


func _on_record_stamped() -> void:
	_settings().vibrate(40)


## `_set_screen` sonunda (next = PauseLogic.Screen). D3: SCORES ekranı, sonuç ekranı gecikmesi.
func _v11_on_screen(next: int) -> void:
	scores_screen.visible = next == PauseLogic.Screen.SCORES
	if run_screen != null:
		run_screen.visible = next == PauseLogic.Screen.RUN
	v2.on_screen(next)


# --- D1: oyuncu/Lord görünüm olayları ---------------------------------------------------------


## Boş kovan (P8): silindir hizasından, ateş yönünün tersine yatay fırlar.
func _on_shot_for_shell(gun: int, origin: Vector2, dir: Vector2) -> void:
	if PlayerRig.is_armless(sim.character.rig):  # kolsuz karakterde kovan yok (v2.0.2)
		return
	var port := (origin + player_view.shoulder_view(gun)) * 0.5
	fx_renderer.add_shell(port, Vector2(-signf(dir.x), 0.0))


## Kamera `shake(min(hasar·0,4, 10))` (P10).
func _on_damage_shake(amount: float, _hp: float) -> void:
	camera.shake(minf(amount * 0.4, 10.0))


## Lord ölümü (E10): vuruş donması 150 ms, kamera 18 px, 900 ms içinde 3 patlama (±120 px), yavaş çekim 0,4× (1,2 sn).
func _on_enemy_killed_fx(type_id: StringName, pos: Vector2) -> void:
	if type_id != LORD_ID:
		return
	RunPresentation.lord_killed(self, pos)


## Lord öfkesi (E9): vuruş donması 80 ms, kamera 16 px, halka.
func _on_lord_enraged(pos: Vector2) -> void:
	hit_stop.request(Motion.sec(Motion.HITSTOP_LORD_RAGE))
	camera.shake(16.0)
	fx_renderer.add_ring(pos, 420.0, 0.9, EnemyRenderer.ENRAGE_TINT, 6.0)


## Lord çağırma vuruşu (E8): şok halkası 0→360 px 450 ms, kamera 10 px/200 ms.
func _on_lord_slammed(pos: Vector2) -> void:
	fx_renderer.add_ring(pos, 360.0, LORD_SLAM_RING_SEC, Color(0.91, 0.635, 0.29, 0.9), 6.0)
	camera.shake(10.0)


# --- girdi ve sistem bildirimleri -----------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
		return
	if screen != PauseLogic.Screen.PLAYING:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _v11_skip_delay():
			return
		gate.touch(event.index, event.pressed, event.position)
	elif event is InputEventScreenDrag:
		gate.drag(event.index, event.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif PauseLogic.should_auto_pause(what, screen):
		pause_game()


func open_settings() -> void:
	if screen == PauseLogic.Screen.MENU or screen == PauseLogic.Screen.PAUSED:
		settings_screen.open()


func _current_screen() -> int:
	if screen == PauseLogic.Screen.PAUSED and pause_screen.is_confirm_open():
		return PauseLogic.Screen.CONFIRM
	return screen


func _on_back() -> void:
	if settings_screen.visible:
		settings_screen.close()
		return
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


func _on_run_ended(emitted_won: bool, stats: Dictionary) -> void:
	var won := emitted_won or V21Runs.run_won(sim)  # Sonsuz: sim LOST ama kilometre taşı kazanıldı
	_run_won = won
	_run_stats = stats
	v2.on_run_ended(won, stats)  # tracker.finish: sonuç ekranından ve skor kaydından ÖNCE
	_v11_on_run_ended(won, stats)
	v2.flush()


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
