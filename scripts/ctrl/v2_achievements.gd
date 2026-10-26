class_name V2Achievements
extends V2Part
## Başarım bağlama (B sahipli): tracker/depo yaşam döngüsü, `poll`, bildirim kuyruğu/host, `finish` sırası, flush noktaları,
## ekran açılışları, menü sayacı. Karakter bilmez. Kural/sayaç tracker'dadır; burası yalnız bağlar.
## opts: "achievements_path" (depo yolu; yoksa AchievementStore.DEFAULT_PATH), "clock" (tracker saati), "data".

## Depo; build_world kurar. CharacterRoster.resolve ve karakter kilidi bunu okur.
var store: AchievementStore = null
var tracker: AchievementTracker = null
var toast: AchievementToast = null
var queue: ToastQueue = ToastQueue.new()
var screen: AchievementsScreen = null

var _data: GameData = null
var _menu: Node = null
var _result: Node = null
var _set_screen: Callable = Callable()
var _sim: GameSim = null
var _shown: StringName = &""
var _extra: Variant = null


func build_world(refs: Dictionary) -> void:
	_data = opts.get("data", null)
	if _data == null:
		_data = GameData.load_default()
	store = AchievementStore.new(str(opts.get("achievements_path", AchievementStore.DEFAULT_PATH)))
	store.load_file(_data.achievements)  # v1 kaydı aile/kademeye göçer; sonra sayaçların hak ettiği kademeler sessizce verilir
	AchievementMigration.reconcile(store, _data.achievements, _now())
	refs["store"] = store  # V2Characters kilit denetimi için paylaşılan sözlükten tembel okur
	_menu = refs.get("menu", null)
	_result = refs.get("result_screen", null)
	_set_screen = refs.get("set_screen", Callable())
	var hud: Variant = refs.get("hud", null)
	if hud != null and hud.get("toast_host") != null:
		toast = AchievementToast.new()
		toast.name = "AchievementToast"
		(hud.get("toast_host") as Control).add_child(toast)
	var root: Variant = refs.get("ui_root", null)
	if root != null:
		screen = AchievementsScreen.new()
		screen.name = "AchievementsScreen"
		root.add_child(screen)
		screen.back_requested.connect(_on_back)
		if _extra != null:
			screen.apply_safe_area(_extra)
	_refresh_menu()


## Önceki tracker bırakılır (detach + flush: YENİDEN BAŞLAT ve menüye dönüşte açılış kaybı olmaz), yenisi kurulur.
func bind(sim: GameSim) -> void:
	_drop_tracker()
	_sim = sim
	queue.clear()
	_shown = &""
	if toast != null:
		toast.visible = false
	if sim == null or store == null or _data == null or _data.achievements.is_empty():
		return  # tanım yoksa tracker kurulmaz; oyun etkilenmez
	var clock: Callable = opts.get("clock", Callable())
	var cid: StringName = sim.character.id if sim.character != null else &""
	tracker = AchievementTracker.new(_data, store, cid, clock)
	tracker.unlocked.connect(_on_unlocked)
	tracker.attach(sim.bus)


## Her karede: poll (salt okur) + bildirim kuyruğu. view_dt = 0 iken (duraklatma) kuyruk donar.
func update_views(view_dt: float) -> void:
	if tracker != null and _sim != null:
		tracker.poll(_sim)
	if toast == null:
		return
	queue.tick(view_dt)
	var cur := queue.current()
	if cur != _shown:
		_shown = cur
		if cur != &"":
			toast.show_def(_data.get_achievement(cur), store.step_count(cur))
	toast.apply_state(queue)


## Sıra (deterministik): tracker.finish → sonuç ekranına özet. Skor kaydı ve show_result controller'dadır; en sonda flush.
func on_run_ended(won: bool, stats: Dictionary) -> void:
	var names: Array[String] = []
	var families := false
	if tracker != null:
		tracker.finish(won, stats)
		for id in tracker.run_unlocked():
			var d := _data.get_achievement(id)
			if d == null:
				continue
			var fam := not d.steps.is_empty()
			families = families or fam
			names.append(
				(
					"%s %s" % [d.display_name, AchievementStep.roman(store.step_count(id))]
					if fam
					else d.display_name
				)
			)
	# Sonuç ekranı gelirse kuyruk atılır (özet sayar).
	queue.clear()
	_shown = &""
	if toast != null:
		toast.visible = false
	if _result != null and _result.has_method("set_new_achievements"):
		if families:
			_result.call("set_new_achievements", names, tracker.run_new_steps())
		else:
			_result.call("set_new_achievements", names)


func on_screen(next: int) -> void:
	if screen != null:
		var show := next == PauseLogic.Screen.ACHIEVEMENTS
		if show and not screen.visible:
			screen.open(_data, store)
		screen.visible = show
	if next == PauseLogic.Screen.MENU:
		_refresh_menu()


func on_pause() -> void:
	flush()


func flush() -> void:
	if tracker != null:
		tracker.flush()
	elif store != null and store.dirty:
		store.save()


func apply_safe_areas(extra: Variant = null) -> void:
	_extra = extra
	if screen != null:
		screen.apply_safe_area(extra)


func release() -> void:
	_drop_tracker()
	_sim = null
	_menu = null
	_result = null
	_set_screen = Callable()
	if store != null and store.dirty:
		store.save()


## Ana menüden BAŞARIMLAR (yalnız Screen.MENU'de çağrılır; V2Flow denetler).
func open() -> void:
	if _set_screen.is_valid():
		_set_screen.call(PauseLogic.Screen.ACHIEVEMENTS)


func _now() -> int:
	var clock: Callable = opts.get("clock", Callable())
	return maxi(int(clock.call()) if clock.is_valid() else int(Time.get_unix_time_from_system()), 1)


func _on_back() -> void:
	if _set_screen.is_valid():
		_set_screen.call(PauseLogic.Screen.MENU)


func _on_unlocked(def: AchievementDef) -> void:
	queue.push(def.id)  # kuyruk doluysa bildirim düşer; kayıt tracker'da zaten yazıldı


func _drop_tracker() -> void:
	if tracker == null:
		return
	tracker.detach()
	tracker.flush()
	tracker = null


func _refresh_menu() -> void:
	if (
		_menu != null
		and store != null
		and _data != null
		and _menu.has_method("set_achievement_count")
	):
		var total := 0
		for d in _data.achievements:
			total += AchievementStep.total(d)
		_menu.call("set_achievement_count", store.count_steps(_data.achievements), total)
