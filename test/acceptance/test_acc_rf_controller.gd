extends GutTest
## Karakterizasyon (plan Faz 4 madde 4, 7, 9): GameController sahne ağacı özeti, sinyal yaşam döngüsü (sinyal, hedef türü,
## metot adı üçlüsü), touch_scroll girişi. R4 (WorldBuilder/SimSignalBinder/RunPresentation) bu testlere karşı yeşil kalır.
## Baz: rf_ctrl_*.json. Ayar ve kayıt yolları geçici (Settings.store_path after_each ile geri alınır).

const TMP := "user://rf_ctrl_tests"

const RUN_SEED := 4242  # start_run randi() ile tohumlanır (harita/harabe sayısı); global RNG sabitlenir

var _settings_path := ""
var _n := 0


func before_each() -> void:
	_n += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	var s: Node = get_node("/root/Settings")
	_settings_path = s.store_path
	s.store_path = "%s/settings_%d_%d.cfg" % [TMP, OS.get_process_id(), _n]


func after_each() -> void:
	var s: Node = get_node("/root/Settings")
	s.store_path = _settings_path
	var abs_dir := ProjectSettings.globalize_path(TMP)
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)


func _controller() -> GameController:
	var c := GameController.new()
	c.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.highscores = Highscores.new("%s/hs_%d_%d.json" % [TMP, OS.get_process_id(), _n])
	return c


## Koşuya özgü adlar kararlı olsun: "@Label@12" -> tür; sonundaki 5+ haneli sayaç ("_root_canvas7730...") atılır.
func _label(n: Node) -> String:
	var nm := String(n.name)
	if nm.begins_with("@"):
		return n.get_class()
	var re := RegEx.new()
	re.compile("[0-9]{5,}$")
	return re.sub(nm, "")


## Düğüm yolu|tür|sıralı gruplar; otomatik adlar ("@Label@12") türle değiştirilir; çocuk sırası korunur.
func _tree(root: Node) -> Array:
	var out := []
	var stack := [[root, _label(root)]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var groups := Array(n.get_groups())
		groups.sort()
		out.append("%s|%s|%s" % [item[1], n.get_class(), ",".join(groups)])
		var kids := n.get_children()
		kids.reverse()
		for k in kids:
			stack.append([k, "%s/%s" % [item[1], _label(k)]])
	return out


func _kind_hist(tree: Array) -> Dictionary:
	var h := {}
	for line in tree:
		var cls: String = String(line).get_slice("|", 1)
		h[cls] = int(h.get(cls, 0)) + 1
	return h


## (sinyal, hedef nesne türü, metot adı) üçlüleri, sıralı; lambda/anonim hedefler "<anon>" olur.
func _triples(obj: Object) -> Array:
	var out := []
	for sig in obj.get_signal_list():
		for conn in obj.get_signal_connection_list(sig["name"]):
			var cb: Callable = conn["callable"]
			var target := cb.get_object()
			var method := String(cb.get_method())
			out.append(
				(
					"%s|%s|%s"
					% [
						sig["name"],
						target.get_class() if target != null else "null",
						method if method != "" else "<anon>"
					]
				)
			)
	out.sort()
	return out


func test_rf_scene_tree_summary_at_run_start() -> void:
	var c := _controller()
	var before := _tree(c)
	seed(RUN_SEED)
	c.start_run()
	var after := _tree(c)
	assert_gt(
		after.size(), before.size(), "koşu başlayınca düğümler eklenir (WorldBuilder çıkarımı)"
	)
	(
		RfBaseline
		. check(
			self,
			"rf_ctrl_scene_tree",
			{
				"before": before,
				"after": after,
				"hist_before": _kind_hist(before),
				"hist_after": _kind_hist(after),
			}
		)
	)


func test_rf_scene_tree_after_restart() -> void:
	# Bulgu: yeniden başlatma düğüm sayısını artırıyor (Sprite2D 153 -> 297, CI 40773133231); davranış korunur,
	# bu yüzden ilişkisel eşitlik değil baz sabitlenir. Düzeltme ayrı Developer işidir (rapor: Bulunan hatalar).
	var c := _controller()
	seed(RUN_SEED)
	c.start_run()
	var first := _kind_hist(_tree(c))
	seed(RUN_SEED)
	c.start_run()
	var second := _kind_hist(_tree(c))
	RfBaseline.check(self, "rf_ctrl_scene_tree_restart", {"first": first, "second": second})


func test_rf_signal_triples_and_restart_leak() -> void:
	var c := _controller()
	seed(RUN_SEED)
	c.start_run()
	var sim1 := c.sim
	var t1 := _triples(sim1.bus)
	var ctrl_t1 := _triples(c)
	c.pause_game()
	c.resume_game()
	assert_eq(_triples(sim1.bus), t1, "duraklat/devam sim bağlantılarını değiştirmez")
	seed(RUN_SEED)
	c.start_run()
	var sim2 := c.sim
	var t2 := _triples(sim2.bus)
	assert_eq(t2, t1, "yeniden başlatma: yeni sim aynı bağlantı üçlülerini taşır")
	assert_eq(_triples(c), ctrl_t1, "denetleyici sinyal bağlantıları birikmez")
	var stale := 0
	for line in _triples(sim1.bus):
		if String(line).get_slice("|", 1) == "GameController":
			stale += 1
	assert_eq(stale, 0, "eski sim'de denetleyiciye giden bağlantı kalmaz")
	RfBaseline.check(
		self,
		"rf_ctrl_signal_triples",
		{"sim_bus": t1, "controller": ctrl_t1, "old_sim_ctrl_conn": stale}
	)


func _scroll(h_open: bool = false) -> ScrollContainer:
	# Fabrika (UiKit.make_scroll) touch_scroll'u kendisi bağlar; ScrollContainer.new() testte de yasak (UI_RULE).
	var axis := UiKit.SCROLL_AXIS_BOTH if h_open else UiKit.SCROLL_AXIS_VERTICAL
	var sc := UiKit.make_scroll(axis, {"custom_min": Vector2(100, 100)})
	sc.size = Vector2(100, 100)
	var content := Control.new()
	content.custom_minimum_size = Vector2(1000, 2000)
	sc.add_child(content)
	add_child_autofree(sc)
	return sc


func _drag(sc: ScrollContainer, rel: Vector2, device: int) -> void:
	var ev := InputEventScreenDrag.new()
	ev.relative = rel
	ev.device = device
	sc.gui_input.emit(ev)


func test_rf_touch_scroll_real_touch_scrolls_once() -> void:
	var sc := _scroll()
	await wait_frames(2)
	_drag(sc, Vector2(0, -30), 0)
	assert_eq(sc.scroll_vertical, 30, "gerçek dokunma: tek kaydırma")
	_drag(sc, Vector2(0, 10), 0)
	assert_eq(sc.scroll_vertical, 20, "ters yön geri kaydırır")


func test_rf_touch_scroll_emulated_mouse_is_ignored() -> void:
	var sc := _scroll()
	await wait_frames(2)
	_drag(sc, Vector2(0, -30), InputEvent.DEVICE_ID_EMULATION)
	assert_eq(sc.scroll_vertical, 0, "fare emülasyonu çift kaydırmaz")


func test_rf_touch_scroll_closed_axis_does_not_move() -> void:
	var sc := _scroll(false)
	await wait_frames(2)
	_drag(sc, Vector2(-40, 0), 0)
	assert_eq(sc.scroll_horizontal, 0, "kapalı yatay eksen kaymaz")


func test_rf_touch_scroll_open_axis_moves() -> void:
	var sc := _scroll(true)
	await wait_frames(2)
	_drag(sc, Vector2(-40, 0), 0)
	assert_eq(sc.scroll_horizontal, 40, "açık yatay eksen kayar")
