extends GutTest
## Kabul (v2.0 M1–M10): bakım bulguları. M1/M9/M10(ön koşul)/M7/M8b dilimsiz koşar; görsel/yerleşim maddeleri (M2–M6, M8a/c) dilim M bitmeden pending.
## M9 değerleri v1.1 ANA sürümünde (ebc24c8, sözleşme öncesi) üretildi (aşağıdaki PIN); `karakterizasyon (F-ver-001: RNG akışları kaymaz)`.
## test_b4_m5_*: M5 sonuç çipi, B4 işi (ResultScreen.set_new_achievements); ad öneki B dilimine bağlar (check_slices.py), B-tur açar.
## M11 Python tarafında: tools/ci/tests/test_selftest_gate_groups.py.

const ROOT_DATA := "res://data"

# --- M9 PIN: v1.1 (ebc24c8) üzerinde SimKit.make(seed, real, log_events=false) + Bots.KITE 900 adım (Bots.make_rng(7)) ---
const PIN := {
	1:
	{
		"first6":
		{
			"choice": [3606675569, 1211967128, 2215151987, 1298772073, 1346598462, 1258070843],
			"combat": [2427093757, 747300322, 2906945995, 150477160, 2404401853, 2399468470],
			"map": [4181894118, 1069061213, 3221082785, 3524170132, 1270414822, 1040592196],
			"pickup": [245166777, 2379230264, 2565783431, 817520851, 1872055338, 4135013991],
			"spawn": [3362234483, 2238136887, 113079810, 489177237, 3251591212, 2307575701],
		},
		"seed":
		{
			"choice": 3465106396075685222,
			"combat": 5743882920115722605,
			"map": 4231776125065144723,
			"pickup": 4523984181135068307,
			"spawn": 6950604273150918458,
		},
		"state900":
		{
			"choice": 7602194604234413696,
			"combat": -125373345272290117,
			"map": -7747042143014546071,
			"pickup": -8360832167355921885,
			"spawn": 2447776419205908398,
		},
	},
	12345:
	{
		"first6":
		{
			"choice": [745177240, 1438945371, 3405537922, 1912490685, 2729214246, 2887681276],
			"combat": [3301113005, 4193997235, 258021805, 229312990, 20430994, 3601108711],
			"map": [1350275797, 2382323699, 3085577111, 1789758931, 1510901970, 1028937068],
			"pickup": [4216844399, 1288181405, 1979110013, 236224645, 3860492085, 2608490387],
			"spawn": [3039587539, 201995841, 2637813958, 3369610059, 676024529, 4216458229],
		},
		"seed":
		{
			"choice": 8575285777815289508,
			"combat": 5941254793108721036,
			"map": 3443448303692479375,
			"pickup": 9078174372726366853,
			"spawn": 678246303563256117,
		},
		"state900":
		{
			"choice": -5678910929109370778,
			"combat": -1313650804813320402,
			"map": 2323225626080150197,
			"pickup": -5405789792886973763,
			"spawn": 3022633840592981637,
		},
	},
}

var _store_path: String = ""
var _character_id: String = ""
var _ctrl: GameController = null


func before_each() -> void:
	var st := get_node("/root/Settings")
	_store_path = st.store_path
	_character_id = st.character_id
	st.store_path = AchKit.tmp_path("settings")


func after_each() -> void:
	if _ctrl != null and is_instance_valid(_ctrl):  # cleanup'tan önce: _exit_tree flush dosya yazar
		if _ctrl.get_parent() != null:
			_ctrl.get_parent().remove_child(_ctrl)
		_ctrl.free()
	_ctrl = null
	var st := get_node("/root/Settings")
	st.store_path = _store_path
	st.character_id = _character_id
	AchKit.cleanup()


func after_all() -> void:
	SimKit.remove_tmp()
	KitDev.remove_tmp()


func _gate() -> bool:
	return V2Slice.require(self, "M")


## M5 (sonuç ekranı "Yeni başarım" çipi) `ResultScreen.set_new_achievements` ister: B4 işi, M dilimi değil.
func _gate_b() -> bool:
	return V2Slice.require(self, "B")


# --- M1 (F-010): komşu chunk'lardaki katı harabeler MIN_GAP'i korur -----------------------------------------------


func _min_circle_gap(m: MapSim, a: int, b: int) -> float:
	var best := INF
	var fa := m.circ_first[a]
	var fb := m.circ_first[b]
	for i in m.circ_count[a]:
		for j in m.circ_count[b]:
			var d := m.circ_pos[fa + i].distance_to(m.circ_pos[fb + j])
			best = minf(best, d - m.circ_r[fa + i] - m.circ_r[fb + j])
	return best


func test_m1_neighbour_solid_ruins_keep_min_gap() -> void:
	var ruins := GameData.load_default().ruins
	var span := 6
	var cells: Array[Vector2i] = []
	for cy in range(-span, span + 1):
		for cx in range(-span, span + 1):
			cells.append(Vector2i(cx, cy))
	var viol := PackedStringArray()
	var pairs_checked := 0
	var shuffler := RandomNumberGenerator.new()
	shuffler.seed = 20261024  # sabit tohumlu karışık ziyaret sırası
	for seed_value in range(1, 201):
		var m := MapSim.new(seed_value, ruins)
		var order := cells.duplicate()
		for i in range(order.size() - 1, 0, -1):
			var j := shuffler.randi_range(0, i)
			var t: Vector2i = order[i]
			order[i] = order[j]
			order[j] = t
		for c in order:
			m.ensure(Vector2(c.x * MapSim.CHUNK + 512.0, c.y * MapSim.CHUNK + 512.0))
		for c in cells:
			for off in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var n: Vector2i = c + off
				if absi(n.x) > span or absi(n.y) > span:
					continue
				for a in m.chunk_obstacles(c):
					if m.ob_solid[a] != 1:
						continue
					for b in m.chunk_obstacles(n):
						if m.ob_solid[b] != 1:
							continue
						pairs_checked += 1
						var g := m.ob_pos[a].distance_to(m.ob_pos[b]) - m.ob_r[a] - m.ob_r[b]
						if g < MapSim.MIN_GAP - 0.001:
							viol.append(
								(
									"tohum %d chunk %s↔%s sarmalayan boşluk %.1f"
									% [seed_value, c, n, g]
								)
							)
						elif m.circ_count[a] > 0 and m.circ_count[b] > 0:
							var cg := _min_circle_gap(m, a, b)
							if cg < MapSim.MIN_GAP - 0.001:
								viol.append("tohum %d daire boşluğu %.1f" % [seed_value, cg])
	assert_gt(pairs_checked, 1000, "ön koşul: yeterli komşu çifti incelendi (%d)" % pairs_checked)
	assert_eq(viol.size(), 0, "MIN_GAP ihlalleri: %s" % [viol.slice(0, 5)])


func test_m1_generation_is_visit_order_independent() -> void:
	var ruins := GameData.load_default().ruins
	var a := MapSim.new(7, ruins)
	var b := MapSim.new(7, ruins)
	var pts: Array[Vector2] = [
		Vector2(0, 0), Vector2(3000, 1000), Vector2(-2500, 2600), Vector2(900, -4000)
	]
	for p in pts:
		a.ensure(p)
	for i in range(pts.size() - 1, -1, -1):
		b.ensure(pts[i])
	for cy in range(-4, 5):
		for cx in range(-4, 5):
			var ca := a.chunk_obstacles(Vector2i(cx, cy))
			var cb := b.chunk_obstacles(Vector2i(cx, cy))
			assert_eq(ca.size(), cb.size(), "chunk %d,%d" % [cx, cy])
			for k in mini(ca.size(), cb.size()):
				assert_eq(
					a.ob_pos[ca[k]], b.ob_pos[cb[k]], "engel konumu ziyaret sırasından bağımsız"
				)


# --- M9: beş RNG akışı sabit çıktı — karakterizasyon (F-ver-001) -------------------------------------------------


func test_m9_karakterizasyon_rng_streams_first_draws_and_seeds_are_pinned() -> void:
	for seed_value in PIN:
		var sim := SimKit.make(seed_value, {"data_kind": "real", "log_events": false})
		assert_eq(GameSim.RNG_STREAMS.size(), 5, "akış sayısı değişmez")
		for s in GameSim.RNG_STREAMS:
			var r: RandomNumberGenerator = sim.get("rng_" + String(s))
			var want_seed: int = PIN[seed_value]["seed"][String(s)]
			assert_eq(r.seed, want_seed, "%d/%s tohum" % [seed_value, s])
			var fresh := RandomNumberGenerator.new()
			fresh.seed = r.seed
			var got: Array = []
			for i in 6:
				got.append(fresh.randi())
			assert_eq(
				got, PIN[seed_value]["first6"][String(s)], "%d/%s ilk 6 çıktı" % [seed_value, s]
			)


func test_m9_karakterizasyon_rng_states_after_900_kite_steps_unchanged() -> void:
	for seed_value in PIN:
		var sim := SimKit.make(seed_value, {"data_kind": "real", "log_events": false})
		Bots.play(sim, Bots.KITE, 900, Bots.make_rng(7), 0)
		for s in GameSim.RNG_STREAMS:
			var r: RandomNumberGenerator = sim.get("rng_" + String(s))
			assert_eq(
				r.state,
				PIN[seed_value]["state900"][String(s)],
				"%d/%s: v1.1 RNG tüketimi kaymadı" % [seed_value, s]
			)


# --- M10: Lord için yer açma ----------------------------------------------------------------------------------------


func _full_pool_run(disable_hook: bool) -> Dictionary:
	var sim := SimKit.make(201, {"data_kind": "fixture_waves", "start_time": 1198.0})
	SimKit.godmode(sim)
	if disable_hook:
		sim.spawn_director.set("make_room_enabled", false)
	assert_eq(sim.debug_fill(&"curumus_piyade", 400, 1100.0), 400)
	var full_before_spawn := false
	var seen := false
	for i in 400:
		if sim.enemies.count < EnemyPool.CAP:
			sim.debug_fill(&"curumus_piyade", EnemyPool.CAP - sim.enemies.count, 1100.0)
		SimKit.godmode(sim)
		var cnt_before := sim.enemies.count
		var spawned_before := SimKit.count_events(sim, SimEvents.BOSS_SPAWN)
		sim.step(Vector2.ZERO)
		if not seen and SimKit.count_events(sim, SimEvents.BOSS_SPAWN) > spawned_before:
			seen = true
			full_before_spawn = cnt_before >= EnemyPool.CAP
	return {
		"spawned": SimKit.count_events(sim, SimEvents.BOSS_SPAWN), "full_before": full_before_spawn
	}


func test_m10_precondition_pool_is_full_when_lord_spawns_without_hook() -> void:
	var r := _full_pool_run(false)
	assert_eq(r["spawned"], 1, "kancasız v1.1 senaryosu: Lord doğar")
	assert_true(
		r["full_before"], "ön koşul: Lord doğduğu adımda havuz dolu (yer açma gerçekten gerekli)"
	)


func test_m10_lord_spawn_needs_make_room_mutation() -> void:
	var sim := SimKit.make(201, {"data_kind": "fixture_waves", "start_time": 1198.0})
	if not "make_room_enabled" in sim.spawn_director:
		if V2Slice.done("M"):
			fail_test("M işaretli ama SpawnDirector.make_room_enabled kancası yok")
		else:
			pending("M10 kancası (SpawnDirector.make_room_enabled) M-A'da eklenir")
		return
	assert_true(bool(sim.spawn_director.get("make_room_enabled")), "varsayılan true")
	var r := _full_pool_run(true)
	assert_eq(
		r["spawned"], 0, "yer açma kapalı + havuz dolu: Lord doğmaz (test yer açmaya bağımlı)"
	)


func test_m10_hook_default_does_not_change_state_hash() -> void:
	var a := SimKit.make(5, {"data_kind": "fixture_waves"})
	var b := SimKit.make(5, {"data_kind": "fixture_waves"})
	if "make_room_enabled" in b.spawn_director:
		b.spawn_director.set("make_room_enabled", true)
	SimKit.run(a, 120)
	SimKit.run(b, 120)
	assert_eq(a.state_hash(), b.state_hash())


# --- M8b: atlas_cells; M7: ok geometrisi (dilimsiz, bugün geçer) -----------------------------------------------------


func test_m8b_atlas_cells_error_at_17_enemies_and_ok_at_7() -> void:
	var bad := GameData.load_dir(KitDev.data_dir("res://test/fixtures/data_bad_atlas_cells"))
	assert_eq(bad.enemy_ids.size(), 17)
	var has := false
	for e in bad.validate({}, true):
		if e.contains("[atlas_cells]"):
			has = true
	assert_true(has, "17 düşman: atlas_cells hatası")
	var real := GameData.load_default()
	assert_eq(real.enemy_ids.size(), 7)
	for e in real.validate({}, true):
		assert_false(e.contains("[atlas_cells]"), "7 düşman geçer")


func test_m7_offscreen_arrow_keeps_min_edge_for_8_directions_and_4_corners() -> void:
	var view := Vector2(1080.0, 2400.0)
	var dirs: Array[Vector2] = []
	for k in 8:
		dirs.append(Vector2.from_angle(TAU * k / 8.0) * 3000.0)
	for c in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		dirs.append(c * 3000.0)
	var safes := [
		Rect2(Vector2.ZERO, view),
		Rect2(Vector2(0, 100), view - Vector2(0, 250)),
		Rect2(Vector2(24, 60), view - Vector2(48, 150)),
	]
	for safe in safes:
		for d in dirs:
			var r := OffscreenArrow.place(d, Vector2.ZERO, view, safe, OffscreenArrow.MARGIN)
			assert_true(r["visible"], "ekran dışı hedef görünür ok")
			var p: Vector2 = r["pos"]
			var edge := minf(
				minf(p.x - safe.position.x, safe.end.x - p.x),
				minf(p.y - safe.position.y, safe.end.y - p.y)
			)
			assert_gte(
				edge,
				ExpectedLayoutV2.ARROW_GLYPH_MIN_EDGE - 0.01,
				"ok kenardan >= 36 px (%s %s)" % [safe, d]
			)


func test_m7_arrow_hidden_when_target_on_screen() -> void:
	var r := OffscreenArrow.place(
		Vector2(100, 100),
		Vector2.ZERO,
		Vector2(1080, 2400),
		Rect2(0, 0, 1080, 2400),
		OffscreenArrow.MARGIN
	)
	assert_false(r["visible"])


# --- M8c: OS.delay_msec yok ----------------------------------------------------------------------------------------


func test_m8c_no_os_delay_msec_in_scripts() -> void:
	if _gate():
		return
	var offenders := PackedStringArray()
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var n := 0
				for line in FileAccess.get_file_as_string(dir.path_join(f)).split("\n"):
					n += 1
					if (line.split("#")[0] as String).contains("OS.delay_msec"):
						offenders.append("%s/%s:%d" % [dir, f, n])
		for d in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(d))
	assert_eq(offenders, PackedStringArray(), "OS.delay_msec bloklayıcı bekleme yasak")


# --- M2 (N4/N6/N7): seviye atlama + duraklatma güvenli alan, rim tonu, başlık kontrastı -------------------------------


func _host() -> Control:
	var h := Control.new()
	h.custom_minimum_size = ExpectedLayoutV2.REF
	h.size = ExpectedLayoutV2.REF
	add_child_autofree(h)
	return h


func _visible_buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree():
			out.append(b)
	return out


func test_m2_pause_screen_applies_safe_area() -> void:
	if _gate():
		return
	var host := _host()
	var ps := PauseScreen.new()
	host.add_child(ps)
	var a: Array[SkillState] = []
	var p: Array[SkillState] = []
	ps.open(a, p, true, true)
	assert_true(ps.has_method("apply_safe_area"), "PauseScreen.apply_safe_area (N7)")
	if not ps.has_method("apply_safe_area"):
		return
	ps.call("apply_safe_area", ExpectedLayoutV2.SAFE_NOTCH)
	await get_tree().process_frame
	await get_tree().process_frame
	var bs := _visible_buttons(ps)
	assert_gt(bs.size(), 0)
	for b in bs:
		var r := b.get_global_rect()
		assert_gte(r.position.y, ExpectedLayoutV2.SAFE_NOTCH.y - 1.0, "%s üst pay" % b.name)
		assert_lte(
			r.end.y,
			ExpectedLayoutV2.REF.y - ExpectedLayoutV2.SAFE_NOTCH.w + 1.0,
			"%s alt pay" % b.name
		)


func test_m2_level_up_cards_stay_inside_bottom_safe_area() -> void:
	if _gate():
		return
	var host := _host()
	var s := LevelUpScreen.new()
	host.add_child(s)
	var sim := SimKit.make(3, {"data_kind": "real"})
	SimKit.level_up_with(sim, 100)
	s.show_choices(sim.pending_choices(), 2, sim.data)
	assert_true(s.has_method("apply_safe_area"))
	s.call("apply_safe_area", ExpectedLayoutV2.SAFE_NOTCH)
	await get_tree().process_frame
	await get_tree().process_frame
	for c in s.cards:
		assert_lte(
			(c as Control).get_global_rect().end.y,
			ExpectedLayoutV2.REF.y - ExpectedLayoutV2.SAFE_NOTCH.w + 1.0
		)


func test_m2_elite_rim_constant_is_bronze_amber_family_not_bone() -> void:
	if _gate():
		return
	var found: Array[Color] = []
	for scr in [EnemyRenderer, AshGhostRenderer]:
		var consts: Dictionary = scr.get_script_constant_map()
		for k in consts:
			if (
				(String(k).contains("ELITE") or String(k).contains("LORD"))
				and String(k).contains("RIM")
				and consts[k] is Color
			):
				found.append(consts[k])
	assert_gt(
		found.size(),
		0,
		"elit/Lord rim rengi sabiti (…ELITE…RIM… ya da …LORD…RIM…, Color) tanımlı olmalı"
	)
	for c in found:
		assert_between(c.h, 0.05, 0.14, "bronz/amber tonu (hue %.3f)" % c.h)
		assert_gte(c.s, 0.35, "kemik gibi soluk değil (doygunluk %.2f)" % c.s)


func _lum(c: Color) -> float:
	var f := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


func _ratio(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func test_m2_level_up_title_contrast_over_worst_case_portrait_is_at_least_4_5() -> void:
	if _gate():
		return
	var s := LevelUpScreen.new()
	add_child_autofree(s)
	var title: Color = s.title_label.get_theme_color(&"font_color")
	# DESIGN.md §6.1: alt gradyan y860:.72 → y1000:.90; başlık y≈924 => α ≈ .80. En kötü zemin: saf beyaz piksel.
	var alpha := 0.72 + (0.90 - 0.72) * (924.0 - 860.0) / (1000.0 - 860.0)
	var worst_bg := Color(1.0, 1.0, 1.0).lerp(Color.BLACK, alpha)
	assert_gte(_ratio(title, worst_bg), 4.5, "başlık/portre kontrastı >= 4,5:1")


# --- M3: belge --------------------------------------------------------------------------------------------------------


func test_m3_v11_design_states_elite_shadow_limit_8px() -> void:
	if _gate():
		return
	var txt := FileAccess.get_file_as_string("res://docs/design/v1.1/DESIGN.md")
	assert_true(txt.contains("SHADOW_ELITE_HOVER_MAX"), "E3 satırı sabiti anar")
	assert_true(txt.contains("8 px"), "gölge ayrılığı <= 8 px yazılı")
	assert_true(txt.contains("0,02"), "koyulaşma ölçümü +0,02 payı yazılı")
	assert_lte(EnemyRenderer.SHADOW_ELITE_HOVER_MAX, 8.0, "kod sınırı 8 px")


# --- M4: seviye halkası --------------------------------------------------------------------------------------------


func test_m4_level_ring_is_at_least_4px_and_contrasting() -> void:
	if _gate():
		return
	var src := FileAccess.get_file_as_string("res://scripts/view/player_view.gd")
	var i := src.find("if level_ring >= 0.0:")
	assert_gt(i, 0, "halka bloğu bulunamadı")
	var block := src.substr(i, 600)
	var re := RegEx.new()
	re.compile("draw_arc\\([^\\n]*?,\\s*([0-9.]+),\\s*true\\)")
	var m := re.search(block)
	assert_not_null(m, "halka draw_arc çağrısı")
	if m != null:
		assert_gte(float(m.get_string(1)), 4.0, "halka kalınlığı >= 4 px")
	assert_true(block.contains("0.9"), "başlangıç alfa 0.9")
	var tex := ArtLoader.texture(GroundView.GROUND_PATH)
	var img := tex.get_image()
	var ring := Color("#A98BEF")
	var worst := INF
	for y in range(0, img.get_height(), 16):
		for x in range(0, img.get_width(), 16):
			worst = minf(worst, _ratio(ring, img.get_pixel(x, y) * GroundView.TINT))
	assert_gte(worst, 3.0, "koyu zeminde halka kontrastı >= 3:1 (en kötü piksel %.2f)" % worst)


# --- M5: sonuç ekranı ------------------------------------------------------------------------------------------------


func _result_with_chip(combos: int) -> ResultScreen:
	var host := _host()
	var r := ResultScreen.new()
	host.add_child(r)
	var rows: Array[Dictionary] = []
	for k in combos:
		rows.append(
			{"id": &"zincirleme_patlama", "name": "Kombo %d" % k, "pair": "A + B", "icon": ""}
		)
	var names: Array[String] = ["İlk Kan", "Onuncu Basamak", "Eklenti Avcısı"]
	r.call("set_new_achievements", names)
	r.show_result(
		true, {"time": 1290.0, "level": 31, "kills": 4210, "evolutions": [], "score": 1234}, rows
	)
	return r


func test_b4_m5_result_detail_text_is_at_least_26px() -> void:
	if _gate_b():
		return
	var r := _result_with_chip(2)
	await get_tree().process_frame
	await get_tree().process_frame
	var checked := 0
	# Ayrıntı etiketleri satır düğümlerinde ("Detail"); satırlar panelin değil ekranın çocuğudur.
	for row in r.breakdown_rows:
		var l := row.get_node("Detail") as Label
		if l.text.strip_edges() == "":
			continue
		assert_gte(
			l.get_theme_font_size(&"font_size"),
			ExpectedLayoutV2.RESULT_DETAIL_MIN_PX,
			"ayrıntı '%s'" % l.text
		)
		checked += 1
	assert_gt(checked, 0)


func test_b4_m5_result_with_chip_keeps_layout_and_at_most_three_combo_rows() -> void:
	if _gate_b():
		return
	var r := _result_with_chip(5)
	await get_tree().process_frame
	await get_tree().process_frame
	var shown := 0
	for c in r.combo_box.get_children():
		if (c as Control).visible:
			shown += 1
	assert_lte(shown, 3, "çip varken kombolar <= 3 satır")
	assert_gte(
		r.replay_button.get_global_rect().position.y, ExpectedLayoutV2.RESULT_BUTTONS_Y.x - 2.0
	)
	assert_lte(
		r.menu_button.get_global_rect().end.y,
		ExpectedLayoutV2.RESULT_SAFE_BOTTOM,
		"düğmeler güvenli alt sınırın içinde (tasarım tahmini 2181, ölçülen ~2243)"
	)
	assert_lte(
		r.strip_panel.get_global_rect().end.y,
		r.combo_panel.get_global_rect().position.y + 1.0,
		"şerit kombo paneline taşmaz"
	)
	assert_lte(
		r.combo_panel.get_global_rect().end.y,
		r.replay_button.get_global_rect().position.y + 1.0,
		"kombo paneli düğmelere taşmaz"
	)


func test_b4_m5_result_without_chip_is_v11_layout() -> void:
	if _gate_b():
		return
	var host := _host()
	var plain := ResultScreen.new()
	host.add_child(plain)
	plain.show_result(true, {"time": 100.0, "level": 3, "kills": 10, "evolutions": []}, [])
	var host2 := _host()
	var empty_chip := ResultScreen.new()
	host2.add_child(empty_chip)
	var none: Array[String] = []
	empty_chip.call("set_new_achievements", none)
	empty_chip.show_result(true, {"time": 100.0, "level": 3, "kills": 10, "evolutions": []}, [])
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		empty_chip.replay_button.get_global_rect(),
		plain.replay_button.get_global_rect(),
		"boş liste: v1.1 düzeni aynen"
	)
	assert_eq(empty_chip.strip_panel.get_global_rect(), plain.strip_panel.get_global_rect())


# --- M6: debug etiketi -------------------------------------------------------------------------------------------------


func _controller() -> GameController:
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.v2_opts = {
		"data": AchKit.legacy_data(),
		"achievements_path": AchKit.tmp_path("m6"),
		"clock": AchKit.clock()
	}
	add_child(c)
	_ctrl = c
	c.highscores = Highscores.new(AchKit.tmp_path("hs"))
	return c


func _debug_rects(c: GameController) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for n in c.find_children("*Debug", "Label", true, false):
		var l := n as Label
		assert_eq(l.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s dokunuşu yutmaz" % l.name)
		out.append(Rect2(l.global_position, l.size))
	return out


func _assert_no_overlap(c: GameController, label: String) -> void:
	var rects := _debug_rects(c)
	assert_gt(rects.size(), 0, "debug etiketi (…Debug) bulunamadı")
	for r in rects:
		assert_gte(r.position.y, 5.0, "%s: y6'dan başlar" % label)
		assert_lte(r.end.y, 41.0, "%s: y40'ta biter" % label)
		for b in _visible_buttons(c.ui):
			assert_false(
				r.intersects(b.get_global_rect()), "%s: '%s' düğmesiyle kesişmez" % [label, b.text]
			)
		for safe_pay in [ExpectedLayoutV2.SAFE_NONE, ExpectedLayoutV2.SAFE_NOTCH]:
			var view := ExpectedLayoutV2.REF
			var safe := Rect2(
				Vector2(safe_pay.x, safe_pay.y),
				view - Vector2(safe_pay.x + safe_pay.z, safe_pay.y + safe_pay.w)
			)
			for k in 12:
				var tgt := Vector2.from_angle(TAU * k / 12.0) * 4000.0
				var a := OffscreenArrow.place(tgt, Vector2.ZERO, view, safe, OffscreenArrow.MARGIN)
				var ar := Rect2(
					(a["pos"] as Vector2) - Vector2.ONE * OffscreenArrow.SIZE * 0.5,
					Vector2.ONE * OffscreenArrow.SIZE
				)
				assert_false(r.intersects(ar), "%s: ekran dışı okla kesişmez" % label)


func test_m6_debug_label_does_not_overlap_buttons_or_arrows_on_pause_and_result() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	c.pause_game()
	await get_tree().process_frame
	_assert_no_overlap(c, "duraklatma")
	c.resume_game()
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c.flush_delay()
	await get_tree().process_frame
	_assert_no_overlap(c, "sonuç")


# --- M8a: güvenli alan yenileme -----------------------------------------------------------------------------------------


func test_m8a_flow_apply_safe_areas_refreshes_hud_pause_and_level_up() -> void:
	if _gate():
		return
	var host := _host()
	var hud := Hud.new()
	host.add_child(hud)
	var lu := LevelUpScreen.new()
	host.add_child(lu)
	var ps := PauseScreen.new()
	host.add_child(ps)
	var flow := V2Flow.new(
		{"data": AchKit.legacy_data(), "achievements_path": AchKit.tmp_path("m8a")}
	)
	flow.build_world(
		{
			"ui_root": host,
			"menu": null,
			"hud": hud,
			"level_up": lu,
			"result_screen": null,
			"pause_screen": ps,
			"set_screen": func(_i: int) -> void: pass
		}
	)
	flow.apply_safe_areas(ExpectedLayoutV2.SAFE_NOTCH)
	assert_eq(hud.safe.offset_top, 100.0, "HUD üst pay")
	assert_eq(hud.safe.offset_bottom, -150.0, "HUD alt pay")
	flow.apply_safe_areas(ExpectedLayoutV2.SAFE_NONE)
	assert_eq(hud.safe.offset_top, 0.0, "yeniden uygulama birikmez")
	assert_eq(hud.safe.offset_bottom, 0.0)
	flow.release()
